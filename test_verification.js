const puppeteer = require('puppeteer');

async function testLiveApp() {
  console.log('🚀 Launching Chrome to test UstaGo live app...');
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 400, height: 850 });

  page.on('console', msg => console.log('WEB CONSOLE:', msg.text()));
  page.on('pageerror', err => console.error('WEB ERROR:', err.message));

  console.log('Opening https://mirze3838-jpg.github.io/ustago/ ...');
  await page.goto('https://mirze3838-jpg.github.io/ustago/', { waitUntil: 'networkidle2', timeout: 60000 });

  // Wait 12 seconds for Flutter web canvas engine to render initial screen
  console.log('Waiting for Flutter app rendering...');
  await new Promise(r => setTimeout(r, 12000));

  await page.screenshot({ path: 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/screenshot_home_rendered.png' });
  console.log('📸 Saved screenshot_home_rendered.png');

  // Click on Shorts tab (second icon at bottom nav: roughly x: 120, y: 815)
  console.log('Clicking on Shorts tab in bottom navigation...');
  await page.mouse.click(120, 815);
  await new Promise(r => setTimeout(r, 4000));

  await page.screenshot({ path: 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/screenshot_shorts_rendered.png' });
  console.log('📸 Saved screenshot_shorts_rendered.png');

  // Click on comments icon on Shorts (right side: roughly x: 365, y: 640)
  console.log('Clicking on Comments button on Shorts video...');
  await page.mouse.click(365, 640);
  await new Promise(r => setTimeout(r, 3000));

  await page.screenshot({ path: 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/screenshot_comments_rendered.png' });
  console.log('📸 Saved screenshot_comments_rendered.png');

  await browser.close();
  console.log('🎉 Test completed successfully!');
}

testLiveApp().catch(err => {
  console.error('Test error:', err);
  process.exit(1);
});
