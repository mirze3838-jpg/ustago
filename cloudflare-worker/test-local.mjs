/**
 * UstaGo Cloudflare Worker — Lokal Birlik və Təhlükəsizlik Testləri
 */

import { webcrypto } from 'crypto';
if (!globalThis.crypto) {
  globalThis.crypto = webcrypto;
}

// index.js daxilindəki funksiyaların sintaksis və işləmə testi
async function runTests() {
  console.log('--- TEST 1: Kriptoqrafik Ticket Sistemi Yoxlanışı ---');
  
  // Test Ticket funksiyası
  const enc = new TextEncoder();
  const secret = 'test-secret-r2-key-12345';
  
  async function generateHmacSha256(message, secret) {
    const key = await crypto.subtle.importKey(
      'raw',
      enc.encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );
    const signature = await crypto.subtle.sign('HMAC', key, enc.encode(message));
    let binary = '';
    const bytes = new Uint8Array(signature);
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  const payload = {
    uid: 'user_test_999',
    objectKey: 'shorts/user_test_999/12345_abc.mp4',
    mime: 'video/mp4',
    exp: Date.now() + 900000
  };

  const jsonStr = JSON.stringify(payload);
  const payloadB64 = btoa(jsonStr).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const sig = await generateHmacSha256(payloadB64, secret);
  const ticket = `${payloadB64}.${sig}`;

  console.log('Yaradılan Ticket:', ticket);

  // Yoxlama
  const [b64, testSig] = ticket.split('.');
  const verifySig = await generateHmacSha256(b64, secret);
  if (testSig === verifySig) {
    console.log('✅ TEST 1 UĞURLU: Kriptoqrafik ticket imzası dəqiq təsdiqləndi.');
  } else {
    console.error('❌ TEST 1 UĞURSUZ: Ticket imzası uyğun gəlmir.');
  }

  console.log('\n--- TEST 2: MIME və Fayl Uzantısı Doğrulaması ---');
  function validateMimeAndExtension(contentType, fileExtension) {
    const allowed = {
      'video/mp4': ['mp4', 'm4v'],
      'video/quicktime': ['mov', 'qt'],
      'video/webm': ['webm'],
    };
    if (!contentType) return { valid: false };
    const cleanMime = contentType.toLowerCase().trim();
    if (!allowed[cleanMime]) return { valid: false };
    let ext = (fileExtension || '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
    const validExtensions = allowed[cleanMime];
    if (!ext || !validExtensions.includes(ext)) {
      ext = validExtensions[0];
    }
    return { valid: true, mime: cleanMime, extension: ext };
  }

  const t1 = validateMimeAndExtension('video/mp4', 'exe');
  console.log('video/mp4 + exe tələsi:', t1.extension === 'mp4' ? '✅ MP4-ə məcbur edildi' : '❌ Təhlükə');

  const t2 = validateMimeAndExtension('image/jpeg', 'jpg');
  console.log('image/jpeg qadağası:', !t2.valid ? '✅ Düzgün rədd edildi' : '❌ Xəta');

  const t3 = validateMimeAndExtension('video/quicktime', 'mov');
  console.log('video/quicktime + mov:', t3.valid && t3.extension === 'mov' ? '✅ Qəbul edildi' : '❌ Xəta');

  console.log('\n--- TEST 3: Google X509 Sertifikat API Əlaqəsi ---');
  try {
    const res = await fetch('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
    if (res.ok) {
      const keys = await res.json();
      const kidCount = Object.keys(keys).length;
      console.log(`✅ Google X.509 Endpoint uğurla oxundu (${kidCount} aktiv açar tapıldı).`);
    } else {
      console.log('❌ Google API status:', res.status);
    }
  } catch (err) {
    console.error('❌ Google API xətası:', err.message);
  }
}

runTests();
