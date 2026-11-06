const puppeteer = require('puppeteer');
const fs = require('fs');

async function runAudit() {
  console.log('🚀 Starting automated browser audit...');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844 }); // iPhone 14 / modern mobile size

  page.on('console', msg => console.log('BROWSER LOG:', msg.text()));
  page.on('pageerror', err => console.error('BROWSER ERROR:', err.message));

  console.log('Navigating to UstaGo...');
  await page.goto('https://mirze3838-jpg.github.io/ustago/', { waitUntil: 'networkidle2', timeout: 60000 });
  await new Promise(r => setTimeout(r, 6000));

  await page.screenshot({ path: 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/screenshot_home.png' });
  console.log('📸 Screenshot saved: screenshot_home.png');

  // Check shorts
  await page.screenshot({ path: 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/screenshot_shorts.png' });
  console.log('📸 Screenshot saved: screenshot_shorts.png');

  await browser.close();
  console.log('✅ Audit finished successfully!');
}

runAudit().catch(err => {
  console.error('Audit failed:', err);
  process.exit(1);
});
