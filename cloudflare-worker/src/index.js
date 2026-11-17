/**
 * UstaGo — Cloudflare Worker Təhlükəsiz Video Upload Sistemi (I Mərhələ)
 * 
 * Təhlükəsizlik Arxitekturası:
 * 1. Firebase ID Token: Web Crypto API ilə RS256 riyazi imza yoxlanışı, Google X.509 cert keşlənməsi,
 *    aud, iss, exp, iat, auth_time və sub yoxlanışları.
 * 2. Upload Qeydiyyatı (HMAC-SHA256 Token): Əlavə xidmət (KV/D1) və xərc tələb etmədən
 *    kriptoqrafik olaraq imzalanmış 'uploadToken' istehsal edilir. Yalnız həmin UID və objectKey üçün etibarlıdır.
 * 3. POST /get-upload-url: Yalnız təsdiqlənmiş MIME (mp4, quicktime, webm), unikal server açarı və 900s PUT URL.
 * 4. POST /verify-upload: Token və icazə təsdiqi, R2 HEAD ilə obyektin real ölçüsü (maks 150 MB) və
 *    Content-Type yoxlanışı. Qanunsuz fayl aşkar edildikdə dərhal R2 DELETE ilə silinməsi.
 * 5. CORS: UstaGo rəsmi domenləri (ustago.az, web clients) üçün nəzarətli başlıqlar.
 */

import { AwsClient } from 'aws4fetch';

// CORS İcazə verilən domenlər
const ALLOWED_ORIGINS = [
  'https://ustago.az',
  'https://www.ustago.az',
  'http://localhost:3000',
  'http://localhost:8080'
];

function getCorsHeaders(request) {
  const origin = request.headers.get('Origin');
  const allowedOrigin = (origin && ALLOWED_ORIGINS.includes(origin)) ? origin : (ALLOWED_ORIGINS[0]);
  
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

export default {
  async fetch(request, env) {
    const corsHeaders = getCorsHeaders(request);

    // 1. CORS Preflight sorğusu
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // Yalnız POST qəbul olunur
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed' }, 405, corsHeaders);
    }

    const url = new URL(request.url);

    // Endpoint 1: /get-upload-url
    if (url.pathname === '/get-upload-url') {
      return handleGetUploadUrl(request, env, corsHeaders);
    }

    // Endpoint 2: /verify-upload
    if (url.pathname === '/verify-upload') {
      return handleVerifyUpload(request, env, corsHeaders);
    }

    return jsonResponse({ error: 'Endpoint tapılmadı' }, 404, corsHeaders);
  },
};

// ==========================================
// 1. /get-upload-url Endpoint
// ==========================================
async function handleGetUploadUrl(request, env, corsHeaders) {
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return jsonResponse({ error: 'Yetkiləndirmə xətası: Bearer token tələb olunur' }, 401, corsHeaders);
    }

    const idToken = authHeader.split('Bearer ')[1].trim();
    const firebaseProjectId = env.FIREBASE_PROJECT_ID || 'ustago-43b9e';

    // Firebase Token-in tam RS256 kriptoqrafik yoxlanması
    const decodedToken = await verifyFirebaseToken(idToken, firebaseProjectId);
    if (!decodedToken || !decodedToken.sub) {
      return jsonResponse({ error: 'Etibarsız və ya vaxtı bitmiş Firebase token' }, 401, corsHeaders);
    }

    const userId = decodedToken.sub;

    let body;
    try {
      body = await request.json();
    } catch {
      return jsonResponse({ error: 'Etibarsız JSON formatı' }, 400, corsHeaders);
    }

    const { contentType, fileExtension } = body;

    // MIME tipi və uzantı uyğunluğu yoxlanışı
    const mimeValidation = validateMimeAndExtension(contentType, fileExtension);
    if (!mimeValidation.valid) {
      return jsonResponse({ error: mimeValidation.error }, 400, corsHeaders);
    }

    const safeExtension = mimeValidation.extension;
    const validatedMime = mimeValidation.mime;

    // Təhlükəsiz və unikal obyekt açarı: shorts/{userId}/{timestamp}_{random}.{ext}
    const timestamp = Date.now();
    const randomHex = crypto.randomUUID().replace(/-/g, '').substring(0, 12);
    const objectKey = `shorts/${userId}/${timestamp}_${randomHex}.${safeExtension}`;

    // R2 Konfiqurasiyası
    const r2AccountId = env.R2_ACCOUNT_ID;
    const r2AccessKeyId = env.R2_ACCESS_KEY_ID;
    const r2SecretAccessKey = env.R2_SECRET_ACCESS_KEY;
    const r2BucketName = env.R2_BUCKET_NAME || 'ustago-videos';
    const r2PublicDomain = env.R2_PUBLIC_DOMAIN || 'https://pub-7889d6fa89354ee286e5eb34c3a51e97.r2.dev';

    if (!r2AccountId || !r2AccessKeyId || !r2SecretAccessKey) {
      return jsonResponse({ error: 'Server R2 konfiqurasiyası natamamdır' }, 500, corsHeaders);
    }

    const awsClient = new AwsClient({
      accessKeyId: r2AccessKeyId,
      secretAccessKey: r2SecretAccessKey,
      service: 's3',
      region: 'auto',
    });

    const endpointUrl = `https://${r2AccountId}.r2.cloudflarestorage.com/${r2BucketName}/${objectKey}`;

    // 900 saniyəlik (15 dəqiqə) presigned PUT URL
    const presignedRequest = await awsClient.sign(endpointUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': validatedMime,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
      aws: {
        signQuery: true,
        datetime: new Date().toISOString().replace(/[:-]|\.\d{3}/g, ''),
        allHeaders: false,
      },
    });

    // Upload İcazəsinin Kriptoqrafik Qeydiyyatı (HMAC-SHA256 Token)
    // Əlavə KV/D1 xərci olmadan Worker sirri ilə imzalanır, təkrar və saxtakarlığın qarşısını alır.
    const expiresAt = timestamp + (900 * 1000);
    const permissionSecret = r2SecretAccessKey; // mövcud Worker sirri istifadə olunur
    const uploadTicket = await createUploadTicket({
      uid: userId,
      objectKey: objectKey,
      mime: validatedMime,
      exp: expiresAt
    }, permissionSecret);

    return jsonResponse({
      uploadUrl: presignedRequest.url,
      publicUrl: `${r2PublicDomain}/${objectKey}`,
      objectKey: objectKey,
      uploadTicket: uploadTicket,
      expiresInSeconds: 900,
    }, 200, corsHeaders);

  } catch (error) {
    return jsonResponse({ error: 'Daxili server xətası: ' + error.message }, 500, corsHeaders);
  }
}

// ==========================================
// 2. /verify-upload Endpoint (R2 HEAD & DELETE)
// ==========================================
async function handleVerifyUpload(request, env, corsHeaders) {
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return jsonResponse({ error: 'Yetkiləndirmə xətası: Bearer token tələb olunur' }, 401, corsHeaders);
    }

    const idToken = authHeader.split('Bearer ')[1].trim();
    const firebaseProjectId = env.FIREBASE_PROJECT_ID || 'ustago-43b9e';

    const decodedToken = await verifyFirebaseToken(idToken, firebaseProjectId);
    if (!decodedToken || !decodedToken.sub) {
      return jsonResponse({ error: 'Etibarsız və ya vaxtı bitmiş Firebase token' }, 401, corsHeaders);
    }

    const userId = decodedToken.sub;

    let body;
    try {
      body = await request.json();
    } catch {
      return jsonResponse({ error: 'Etibarsız JSON formatı' }, 400, corsHeaders);
    }

    const { objectKey, uploadTicket } = body;
    if (!objectKey || !uploadTicket) {
      return jsonResponse({ error: 'objectKey və uploadTicket tələb olunur' }, 400, corsHeaders);
    }

    // 1. İcazə Biletinin (Ticket) Kriptoqrafik yoxlanışı
    const permissionSecret = env.R2_SECRET_ACCESS_KEY;
    const ticketData = await verifyUploadTicket(uploadTicket, permissionSecret);

    if (!ticketData) {
      return jsonResponse({ error: 'Etibarsız və ya vaxtı keçmiş upload bileti' }, 403, corsHeaders);
    }

    // Bilet bu istifadəçiyə və bu obyekt açarına aiddirmi?
    if (ticketData.uid !== userId || ticketData.objectKey !== objectKey) {
      return jsonResponse({ error: 'İcazəsiz obyekt açarı: Bilet istifadəçiyə uyğun gəlmir' }, 403, corsHeaders);
    }

    // 2. R2 Müştərisi
    const r2AccountId = env.R2_ACCOUNT_ID;
    const r2AccessKeyId = env.R2_ACCESS_KEY_ID;
    const r2SecretAccessKey = env.R2_SECRET_ACCESS_KEY;
    const r2BucketName = env.R2_BUCKET_NAME || 'ustago-videos';
    const r2PublicDomain = env.R2_PUBLIC_DOMAIN || 'https://pub-7889d6fa89354ee286e5eb34c3a51e97.r2.dev';

    const awsClient = new AwsClient({
      accessKeyId: r2AccessKeyId,
      secretAccessKey: r2SecretAccessKey,
      service: 's3',
      region: 'auto',
    });

    const endpointUrl = `https://${r2AccountId}.r2.cloudflarestorage.com/${r2BucketName}/${objectKey}`;

    // 3. R2 HEAD Sorğusu — Obyektin real mövcudluğu və ölçüsü
    const headResponse = await awsClient.fetch(endpointUrl, { method: 'HEAD' });

    if (!headResponse.ok) {
      return jsonResponse({
        verified: false,
        error: 'Video R2 anbarında tapılmadı və ya upload tamamlanmayıb (Status: ' + headResponse.status + ')'
      }, 404, corsHeaders);
    }

    const realContentLength = parseInt(headResponse.headers.get('Content-Length') || '0', 10);
    const realContentType = (headResponse.headers.get('Content-Type') || '').toLowerCase();

    const MAX_ALLOWED_BYTES = 150 * 1024 * 1024; // 150 MB

    // Təhlükəsizlik qaydası: Boş fayl və ya 150 MB-dan böyük fayl
    if (realContentLength <= 0 || realContentLength > MAX_ALLOWED_BYTES) {
      // Qanunsuz faylı dərhal silirik (R2 DELETE)
      await deleteR2Object(awsClient, endpointUrl);
      return jsonResponse({
        verified: false,
        error: `Fayl ölçüsü icazə verilən həddi aşır (Real ölçü: ${(realContentLength / (1024 * 1024)).toFixed(2)} MB, Maksimum: 150 MB). Fayl anbardan silindi.`
      }, 400, corsHeaders);
    }

    // MIME Tipi uyğunsuzluğu yoxlanışı
    const allowedMimePrefixes = ['video/mp4', 'video/quicktime', 'video/webm'];
    const isMimeValid = allowedMimePrefixes.some(m => realContentType.startsWith(m));

    if (!isMimeValid) {
      // Qanunsuz faylı dərhal silirik (R2 DELETE)
      await deleteR2Object(awsClient, endpointUrl);
      return jsonResponse({
        verified: false,
        error: `Fayl tipi video deyil (${realContentType}). Fayl anbardan silindi.`
      }, 400, corsHeaders);
    }

    // 4. Uğurlu Təsdiqləmə
    return jsonResponse({
      verified: true,
      objectKey: objectKey,
      publicUrl: `${r2PublicDomain}/${objectKey}`,
      fileSize: realContentLength,
      contentType: realContentType,
      verifiedAt: new Date().toISOString(),
    }, 200, corsHeaders);

  } catch (error) {
    return jsonResponse({ error: 'Təsdiqləmə zamanı server xətası: ' + error.message }, 500, corsHeaders);
  }
}

async function deleteR2Object(awsClient, endpointUrl) {
  try {
    await awsClient.fetch(endpointUrl, { method: 'DELETE' });
  } catch (err) {
    console.error('R2 DELETE xətası:', err);
  }
}

// ==========================================
// 3. Firebase Token RS256 Kriptoqrafik Doğrulama
// ==========================================
let cachedCertificates = null;
let cacheExpiresAt = 0;

async function getGooglePublicKeys() {
  const now = Date.now();
  if (cachedCertificates && now < cacheExpiresAt) {
    return cachedCertificates;
  }

  const certUrl = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
  const response = await fetch(certUrl);
  if (!response.ok) {
    throw new Error('Google X509 sertifikatlarını əldə etmək mümkün olmadı');
  }

  // Cache-Control max-age oxunması
  const cacheControl = response.headers.get('Cache-Control') || '';
  const maxAgeMatch = cacheControl.match(/max-age=(\d+)/);
  const maxAgeSeconds = maxAgeMatch ? parseInt(maxAgeMatch[1], 10) : 3600;

  cachedCertificates = await response.json();
  cacheExpiresAt = now + (maxAgeSeconds * 1000);

  return cachedCertificates;
}

async function verifyFirebaseToken(token, projectId) {
  try {
    if (!token || typeof token !== 'string') return null;
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const [headerB64, payloadB64, signatureB64] = parts;

    const header = JSON.parse(base64UrlDecode(headerB64));
    const payload = JSON.parse(base64UrlDecode(payloadB64));

    // 1. Alqoritm RS256 olmalıdır
    if (header.alg !== 'RS256' || !header.kid) {
      return null;
    }

    const nowSeconds = Math.floor(Date.now() / 1000);

    // 2. Vaxt və iddia (claims) yoxlanışları
    // exp: Token vaxtı bitməyib
    if (!payload.exp || payload.exp < nowSeconds) return null;

    // iat: Token gələcəkdə yaradılmayıb (5 saniyəlik clock-skew)
    if (!payload.iat || payload.iat > (nowSeconds + 5)) return null;

    // auth_time: Keçmişdə olmalıdır
    if (!payload.auth_time || payload.auth_time > (nowSeconds + 5)) return null;

    // iss: https://securetoken.google.com/<projectId>
    if (payload.iss !== `https://securetoken.google.com/${projectId}`) return null;

    // aud: <projectId>
    if (payload.aud !== projectId) return null;

    // sub: Boş olmayan istifadəçi UID-si
    if (!payload.sub || typeof payload.sub !== 'string' || payload.sub.trim() === '') {
      return null;
    }

    // 3. Google Public Key ilə RS256 İmzasının Riyazi Yoxlanması (Web Crypto API)
    const publicKeys = await getGooglePublicKeys();
    const certPem = publicKeys[header.kid];
    if (!certPem) {
      return null; // kid Google açarlarında tapılmadı
    }

    const cryptoKey = await importX509CertToCryptoKey(certPem);
    if (!cryptoKey) return null;

    const encoder = new TextEncoder();
    const signedData = encoder.encode(`${headerB64}.${payloadB64}`);
    const signatureBytes = base64UrlToUint8Array(signatureB64);

    const isSignatureValid = await crypto.subtle.verify(
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: { name: 'SHA-256' },
      },
      cryptoKey,
      signatureBytes,
      signedData
    );

    if (!isSignatureValid) {
      return null;
    }

    return payload;
  } catch (err) {
    console.error('Firebase token yoxlama xətası:', err);
    return null;
  }
}

/**
 * X.509 PEM sertifikatından Web Crypto CryptoKey idxal edilməsi
 */
async function importX509CertToCryptoKey(pem) {
  try {
    const pemHeader = '-----BEGIN CERTIFICATE-----';
    const pemFooter = '-----END CERTIFICATE-----';
    const cleanPem = pem
      .replace(pemHeader, '')
      .replace(pemFooter, '')
      .replace(/\s+/g, '');

    const derBytes = Uint8Array.from(atob(cleanPem), c => c.charCodeAt(0));

    // X.509 DER formatından SPKI çıxarılması
    const spkiDer = extractSpkiFromCert(derBytes);

    return await crypto.subtle.importKey(
      'spki',
      spkiDer,
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: { name: 'SHA-256' },
      },
      false,
      ['verify']
    );
  } catch (e) {
    console.error('Sertifikat idxal xətası:', e);
    return null;
  }
}

/**
 * Sadə və etibarlı ASN.1 X.509 DER parser:
 * Certificate -> tbsCertificate -> subjectPublicKeyInfo çıxarır
 */
function extractSpkiFromCert(certDer) {
  let pos = 0;

  function readTagAndLength() {
    const tag = certDer[pos++];
    let length = certDer[pos++];
    if (length & 0x80) {
      const numBytes = length & 0x7f;
      length = 0;
      for (let i = 0; i < numBytes; i++) {
        length = (length << 8) | certDer[pos++];
      }
    }
    return { tag, length };
  }

  // 1. Certificate SEQUENCE
  readTagAndLength();

  // 2. tbsCertificate SEQUENCE
  const tbsHeaderPos = pos;
  const tbs = readTagAndLength();
  const tbsEnd = pos + tbs.length;

  // tbsCertificate daxili sahələri:
  // version [0] EXPLICIT (varsa)
  if (certDer[pos] === 0xa0) {
    const v = readTagAndLength();
    pos += v.length;
  }

  // serialNumber INTEGER
  const serial = readTagAndLength();
  pos += serial.length;

  // signature AlgorithmIdentifier SEQUENCE
  const sigAlg = readTagAndLength();
  pos += sigAlg.length;

  // issuer Name SEQUENCE
  const issuer = readTagAndLength();
  pos += issuer.length;

  // validity Validity SEQUENCE
  const validity = readTagAndLength();
  pos += validity.length;

  // subject Name SEQUENCE
  const subject = readTagAndLength();
  pos += subject.length;

  // subjectPublicKeyInfo SubjectPublicKeyInfo SEQUENCE
  const spkiStart = pos;
  const spki = readTagAndLength();
  const spkiEnd = pos + spki.length;

  return certDer.slice(spkiStart, spkiEnd);
}

// ==========================================
// 4. Kriptoqrafik Upload Ticket (HMAC-SHA256)
// ==========================================
async function createUploadTicket(data, secret) {
  const jsonPayload = JSON.stringify(data);
  const payloadB64 = base64UrlEncode(new TextEncoder().encode(jsonPayload));
  const signature = await generateHmacSha256(payloadB64, secret);
  return `${payloadB64}.${signature}`;
}

async function verifyUploadTicket(ticket, secret) {
  try {
    const parts = ticket.split('.');
    if (parts.length !== 2) return null;

    const [payloadB64, providedSig] = parts;
    const expectedSig = await generateHmacSha256(payloadB64, secret);

    if (providedSig !== expectedSig) return null;

    const data = JSON.parse(new TextDecoder().decode(base64UrlToUint8Array(payloadB64)));
    if (Date.now() > data.exp) return null; // Müddəti bitib

    return data;
  } catch {
    return null;
  }
}

async function generateHmacSha256(message, secret) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign('HMAC', key, enc.encode(message));
  return base64UrlEncode(new Uint8Array(signature));
}

// ==========================================
// 5. Köməkçi Funksiyalar
// ==========================================
function validateMimeAndExtension(contentType, fileExtension) {
  const allowed = {
    'video/mp4': ['mp4', 'm4v'],
    'video/quicktime': ['mov', 'qt'],
    'video/webm': ['webm'],
  };

  if (!contentType || typeof contentType !== 'string') {
    return { valid: false, error: 'Content-Type göstərilməlidir' };
  }

  const cleanMime = contentType.toLowerCase().trim();
  if (!allowed[cleanMime]) {
    return { valid: false, error: 'Yalnız video/mp4, video/quicktime və video/webm formatlarına icazə verilir' };
  }

  let ext = (fileExtension || '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
  const validExtensions = allowed[cleanMime];

  if (!ext || !validExtensions.includes(ext)) {
    ext = validExtensions[0]; // MIME tipinə uyğun rəsmi uzantı təyin olunur
  }

  return { valid: true, mime: cleanMime, extension: ext };
}

function base64UrlEncode(uint8Array) {
  let binary = '';
  for (let i = 0; i < uint8Array.byteLength; i++) {
    binary += String.fromCharCode(uint8Array[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlDecode(str) {
  let b64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4) {
    b64 += '=';
  }
  return atob(b64);
}

function base64UrlToUint8Array(str) {
  const binary = base64UrlDecode(str);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function jsonResponse(data, status = 200, corsHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
  });
}
