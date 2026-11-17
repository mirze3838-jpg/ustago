const https = require('https');

https.get('https://github.com/ustago-app/ustago/releases/expanded_assets/v1.0.0', { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => {
    const apks = [...d.matchAll(/href="([^"]+\.apk)"/g)].map(m => m[1]);
    console.log('apks in v1.0.0:', apks);
    const allLinks = [...d.matchAll(/href="([^"]+)"/g)].map(m => m[1]);
    console.log('all links:', allLinks.filter(l => !l.includes('#') && !l.includes('analytics')));
  });
});
