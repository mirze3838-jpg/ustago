const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const PORT = 3839;
const PERM_FILE = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/web/ustago_tiktok_demo.mp4';
const UPLOADS_DIR = 'C:/Users/Acer/.gemini/antigravity/brain/9f2c4d81-a002-4cb9-8ec8-6a7dbc331ae2/browser_sandbox/uploads';
const OUTPUT_FILE = path.join(UPLOADS_DIR, 'ustago_tiktok_demo.mp4');

if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

// 1. HTTP Server to serve HTML and receive the recorded MP4
const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/upload-video') {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => {
      const buffer = Buffer.concat(chunks);
      fs.writeFileSync(OUTPUT_FILE, buffer);
      fs.writeFileSync(PERM_FILE, buffer);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, size: buffer.length }));
      console.log('Video saved successfully. Size:', buffer.length);
      setTimeout(() => {
        server.close();
        process.exit(0);
      }, 1000);
    });
    return;
  }

  if (req.url === '/' || req.url === '/index.html') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(getRecorderHtml());
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`Recorder server running on http://localhost:${PORT}`);
  // Launch Chrome headless to run the recording script
  const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
  const chromeCmd = `"${chromePath}" --headless=new --disable-gpu --autoplay-policy=no-user-gesture-required --no-sandbox "http://localhost:${PORT}/"`;
  console.log('Launching Chrome...');
  exec(chromeCmd, (err, stdout, stderr) => {
    if (err) console.log('Chrome process exited:', err.message);
  });
});

function getRecorderHtml() {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>UstaGo Demo Recorder</title>
  <style>
    body { margin: 0; background: #000; overflow: hidden; display: flex; justify-content: center; align-items: center; height: 100vh; }
    canvas { width: 1280px; height: 720px; }
  </style>
</head>
<body>
<canvas id="canvas" width="1280" height="720"></canvas>
<script>
  const canvas = document.getElementById('canvas');
  const ctx = canvas.getContext('2d');

  // Animation timeline (total ~450 frames = 15 seconds at 30 fps)
  const FPS = 30;
  const TOTAL_FRAMES = 450;
  let currentFrame = 0;

  function drawFrame(frame) {
    // 1. Background
    ctx.fillStyle = '#0B1120';
    ctx.fillRect(0, 0, 1280, 720);

    // Decorative gradient circles
    const grad1 = ctx.createRadialGradient(200, 200, 20, 200, 200, 400);
    grad1.addColorStop(0, 'rgba(37, 99, 235, 0.25)');
    grad1.addColorStop(1, 'transparent');
    ctx.fillStyle = grad1;
    ctx.fillRect(0, 0, 600, 600);

    const grad2 = ctx.createRadialGradient(1080, 520, 20, 1080, 520, 400);
    grad2.addColorStop(0, 'rgba(254, 44, 85, 0.2)');
    grad2.addColorStop(1, 'transparent');
    ctx.fillStyle = grad2;
    ctx.fillRect(800, 300, 480, 420);

    // Left info card
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 32px sans-serif';
    ctx.fillText('UstaGo Platform', 80, 260);

    ctx.font = '20px sans-serif';
    ctx.fillStyle = '#94A3B8';
    ctx.fillText('TikTok Display API & Login Kit', 80, 300);
    ctx.fillText('Artisan Portfolio Integration', 80, 330);

    // Flow badge
    ctx.fillStyle = '#1E293B';
    roundRect(ctx, 80, 370, 320, 140, 12, true, false);
    ctx.fillStyle = '#38BDF8';
    ctx.font = 'bold 15px sans-serif';
    ctx.fillText('INTEGRATION FLOW:', 100, 405);
    ctx.font = '14px sans-serif';
    ctx.fillStyle = frame > 80 ? '#4ADE80' : '#64748B';
    ctx.fillText('1. Open Shorts & Add Video', 100, 435);
    ctx.fillStyle = frame > 180 ? '#4ADE80' : '#64748B';
    ctx.fillText('2. Connect TikTok (OAuth 2.0)', 100, 465);
    ctx.fillStyle = frame > 300 ? '#4ADE80' : '#64748B';
    ctx.fillText('3. Direct Video Sync & Stream', 100, 495);

    // 2. Phone Frame Mockup (Centered at x=640, y=360, w=340, h=660)
    const px = 520, py = 30, pw = 340, ph = 660, r = 36;
    ctx.save();
    // Phone shadow
    ctx.shadowColor = 'rgba(0,0,0,0.6)';
    ctx.shadowBlur = 30;
    ctx.shadowOffsetY = 10;
    ctx.fillStyle = '#020617';
    roundRect(ctx, px, py, pw, ph, r, true, false);
    ctx.restore();

    // Phone border
    ctx.strokeStyle = '#334155';
    ctx.lineWidth = 4;
    roundRect(ctx, px, py, pw, ph, r, false, true);

    // Phone screen clip
    ctx.save();
    roundRect(ctx, px + 4, py + 4, pw - 8, ph - 8, r - 4, false, false);
    ctx.clip();

    // Screen Content
    drawPhoneScreen(ctx, px + 4, py + 4, pw - 8, ph - 8, frame);

    ctx.restore();

    // Phone Speaker notch
    ctx.fillStyle = '#1E293B';
    roundRect(ctx, px + pw/2 - 40, py + 12, 80, 8, 4, true, false);
  }

  function drawPhoneScreen(ctx, x, y, w, h, frame) {
    // Background video simulation
    ctx.fillStyle = '#000000';
    ctx.fillRect(x, y, w, h);

    // Video preview image representation (artisan tiling / carpentry)
    const vg = ctx.createLinearGradient(x, y, x, y + h);
    vg.addColorStop(0, '#1E293B');
    vg.addColorStop(0.5, '#0F172A');
    vg.addColorStop(1, '#020617');
    ctx.fillStyle = vg;
    ctx.fillRect(x, y, w, h);

    // Video mockup graphic
    ctx.fillStyle = '#1E3A8A';
    roundRect(ctx, x + 20, y + 100, w - 40, h - 220, 16, true, false);

    ctx.fillStyle = '#38BDF8';
    ctx.font = 'bold 16px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('Usta İşi: Kafel və Santexnik', x + w/2, y + 260);
    ctx.fillStyle = '#94A3B8';
    ctx.font = '13px sans-serif';
    ctx.fillText('Canlı TikTok Shorts Yayımı', x + w/2, y + 285);
    ctx.textAlign = 'left';

    // Play icon on video
    ctx.fillStyle = 'rgba(255,255,255,0.2)';
    ctx.beginPath();
    ctx.arc(x + w/2, y + 180, 36, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath();
    ctx.moveTo(x + w/2 - 10, y + 165);
    ctx.lineTo(x + w/2 + 16, y + 180);
    ctx.lineTo(x + w/2 - 10, y + 195);
    ctx.fill();

    // Top Header: UstaGo Shorts + "Video Əlavə Et"
    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    ctx.fillRect(x, y, w, 54);

    ctx.fillStyle = '#F59E0B';
    ctx.beginPath();
    ctx.arc(x + 24, y + 28, 8, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 14px sans-serif';
    ctx.fillText('UstaGo Shorts', x + 38, y + 33);

    // "+ Video Əlavə Et" button
    const btnX = x + w - 128, btnY = y + 14, btnW = 114, btnH = 28;
    ctx.fillStyle = '#1769D2';
    roundRect(ctx, btnX, btnY, btnW, btnH, 14, true, false);
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 11px sans-serif';
    ctx.fillText('+ Video Əlavə Et', btnX + 12, btnY + 18);

    // Bottom Navigation Bar
    ctx.fillStyle = 'rgba(15, 23, 42, 0.95)';
    ctx.fillRect(x, y + h - 50, w, 50);
    ctx.strokeStyle = '#334155';
    ctx.beginPath();
    ctx.moveTo(x, y + h - 50);
    ctx.lineTo(x + w, y + h - 50);
    ctx.stroke();

    ctx.fillStyle = '#38BDF8';
    ctx.font = 'bold 10px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('Shorts', x + w/2, y + h - 18);
    ctx.fillStyle = '#64748B';
    ctx.fillText('Ana Səhifə', x + 50, y + h - 18);
    ctx.fillText('Profil', x + w - 50, y + h - 18);
    ctx.textAlign = 'left';

    // ANIMATION PHASE 1: Click "+ Video Əlavə Et" (Frame 50-130)
    if (frame >= 60 && frame < 180) {
      // Bottom Sheet pops up
      const sheetProgress = Math.min(1, (frame - 60) / 20);
      const sheetH = 340 * sheetProgress;
      const sheetY = y + h - sheetH;

      ctx.fillStyle = 'rgba(0,0,0,0.5)';
      ctx.fillRect(x, y, w, h);

      ctx.fillStyle = '#FFFFFF';
      roundRect(ctx, x, sheetY, w, 360, 20, true, false);

      // Sheet Header
      ctx.fillStyle = '#0F172A';
      ctx.font = 'bold 15px sans-serif';
      ctx.fillText('Shorts Video Əlavə Et', x + 18, sheetY + 30);

      // TikTok Card inside modal
      const tcY = sheetY + 50;
      ctx.fillStyle = '#0F172A';
      roundRect(ctx, x + 14, tcY, w - 28, 110, 12, true, false);
      ctx.strokeStyle = 'rgba(254, 44, 85, 0.6)';
      ctx.lineWidth = 1.5;
      roundRect(ctx, x + 14, tcY, w - 28, 110, 12, false, true);

      // TikTok icon + title
      ctx.fillStyle = '#FE2C55';
      ctx.font = 'bold 13px sans-serif';
      ctx.fillText('🎵 TikTok Hesabı ilə Qoşul', x + 26, tcY + 28);
      ctx.fillStyle = '#CBD5E1';
      ctx.font = '11px sans-serif';
      ctx.fillText('Videolarınızı UstaGo-ya birbaşa çəkin', x + 26, tcY + 48);

      // Two Buttons
      // Button 1: TikTok ilə Qoşul
      const tkBtnX = x + 24, tkBtnY = tcY + 64, tkBtnW = (w - 60)/2, tkBtnH = 32;
      ctx.fillStyle = '#FE2C55';
      roundRect(ctx, tkBtnX, tkBtnY, tkBtnW, tkBtnH, 8, true, false);
      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 11px sans-serif';
      ctx.fillText('TikTok ilə Qoşul', tkBtnX + 14, tkBtnY + 20);

      // Button 2: Toplu Video İdxalı
      const bBtnX = tkBtnX + tkBtnW + 10;
      ctx.strokeStyle = '#25F4EE';
      ctx.lineWidth = 1.2;
      roundRect(ctx, bBtnX, tkBtnY, tkBtnW, tkBtnH, 8, false, true);
      ctx.fillStyle = '#25F4EE';
      ctx.fillText('Toplu İdxal', bBtnX + 24, tkBtnY + 20);

      // Other buttons (Gallery etc.)
      ctx.fillStyle = '#F1F5F9';
      roundRect(ctx, x + 14, tcY + 124, w - 28, 44, 10, true, false);
      ctx.fillStyle = '#1769D2';
      ctx.font = 'bold 12px sans-serif';
      ctx.fillText('📁 Qalereyadan Video Seç', x + 26, tcY + 150);

      // Animated cursor clicking TikTok button
      if (frame >= 110) {
        drawCursor(ctx, tkBtnX + tkBtnW/2, tkBtnY + tkBtnH/2, frame > 130);
      }
    }

    // ANIMATION PHASE 2: Official TikTok Authorization Screen (Frame 180-360)
    if (frame >= 180) {
      // Dim background
      ctx.fillStyle = 'rgba(0,0,0,0.85)';
      ctx.fillRect(x, y, w, h);

      // TikTok OAuth Dialog
      const diaX = x + 16, diaY = y + 70, diaW = w - 32, diaH = 460;
      ctx.fillStyle = '#0F172A';
      roundRect(ctx, diaX, diaY, diaW, diaH, 18, true, false);
      ctx.strokeStyle = '#FE2C55';
      ctx.lineWidth = 2;
      roundRect(ctx, diaX, diaY, diaW, diaH, 18, false, true);

      // TikTok Header
      ctx.fillStyle = '#000000';
      roundRect(ctx, diaX, diaY, diaW, 58, 18, true, false);
      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 15px sans-serif';
      ctx.fillText('TikTok for Developers', diaX + 20, diaY + 36);

      // Authorization details
      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 14px sans-serif';
      ctx.fillText('UstaGo tətbiqi qoşulmaq istəyir', diaX + 16, diaY + 95);

      ctx.fillStyle = '#94A3B8';
      ctx.font = '12px sans-serif';
      ctx.fillText('İstifadəçi: @usta_elnur (Usta)', diaX + 16, diaY + 120);

      // Scopes box
      ctx.fillStyle = '#1E293B';
      roundRect(ctx, diaX + 16, diaY + 140, diaW - 32, 120, 10, true, false);

      ctx.fillStyle = '#38BDF8';
      ctx.font = 'bold 12px sans-serif';
      ctx.fillText('Tələb olunan icazələr:', diaX + 26, diaY + 165);

      ctx.fillStyle = '#4ADE80';
      ctx.font = '12px sans-serif';
      ctx.fillText('✓ user.info.basic (Ad və profil fotosu)', diaX + 26, diaY + 195);
      ctx.fillText('✓ video.list (İctimai video siyahısı)', diaX + 26, diaY + 225);

      ctx.fillStyle = '#94A3B8';
      ctx.font = '11px sans-serif';
      ctx.fillText('UstaGo videolarınızı müştərilərə təqdim edəcək.', diaX + 16, diaY + 285);

      // Success checkmark after frame 280
      if (frame >= 280) {
        ctx.fillStyle = '#22C55E';
        roundRect(ctx, diaX + 16, diaY + 310, diaW - 32, 44, 8, true, false);
        ctx.fillStyle = '#FFFFFF';
        ctx.font = 'bold 12px sans-serif';
        ctx.fillText('✓ TikTok Hesabı Uğurla Qoşuldu!', diaX + 26, diaY + 338);
      } else {
        // Authorize Button
        const authBtnY = diaY + 310;
        ctx.fillStyle = '#FE2C55';
        roundRect(ctx, diaX + 16, authBtnY, diaW - 32, 44, 8, true, false);
        ctx.fillStyle = '#FFFFFF';
        ctx.font = 'bold 13px sans-serif';
        ctx.fillText('Qoşul və Təsdiqlə (Authorize)', diaX + 40, authBtnY + 28);

        // Animated cursor clicking Authorize
        if (frame >= 230 && frame < 280) {
          drawCursor(ctx, diaX + diaW/2, authBtnY + 22, frame > 250);
        }
      }

      // Close button
      ctx.fillStyle = '#64748B';
      ctx.font = '12px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('Ləğv et', diaX + diaW/2, diaY + 390);
      ctx.textAlign = 'left';
    }
  }

  function drawCursor(ctx, x, y, isClick) {
    ctx.save();
    ctx.fillStyle = isClick ? '#22C55E' : '#FFFFFF';
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(x, y, isClick ? 14 : 10, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }

  function roundRect(ctx, x, y, w, h, r, fill, stroke) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
    if (fill) ctx.fill();
    if (stroke) ctx.stroke();
  }

  // Set up MediaRecorder on canvas stream
  const stream = canvas.captureStream(FPS);
  let mime = 'video/mp4; codecs=avc1';
  if (!MediaRecorder.isTypeSupported(mime)) {
    mime = 'video/mp4';
    if (!MediaRecorder.isTypeSupported(mime)) mime = 'video/webm';
  }
  console.log('Using MIME:', mime);

  const recorder = new MediaRecorder(stream, {
    mimeType: mime,
    videoBitsPerSecond: 2500000
  });

  const chunks = [];
  recorder.ondataavailable = e => {
    if (e.data && e.data.size > 0) chunks.push(e.data);
  };

  recorder.onstop = async () => {
    console.log('Recording finished, saving...');
    const blob = new Blob(chunks, { type: mime });
    console.log('Blob size:', blob.size);
    try {
      const res = await fetch('/upload-video', {
        method: 'POST',
        headers: { 'Content-Type': mime },
        body: blob
      });
      console.log('Uploaded video:', await res.json());
    } catch (e) {
      console.error('Upload failed:', e);
    }
  };

  recorder.start();

  function animate() {
    drawFrame(currentFrame);
    currentFrame++;
    if (currentFrame < TOTAL_FRAMES) {
      requestAnimationFrame(animate);
    } else {
      recorder.stop();
    }
  }

  animate();
</script>
</body>
</html>
  `;
}
