const https = require('https');

https.get('https://github.com/ustago-app/ustago/releases', { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => {
    const apks = [...d.matchAll(/href="([^"]+\.apk)"/g)].map(m => m[1]);
    console.log('apks:', apks);
    const tags = [...d.matchAll(/href="\/ustago-app\/ustago\/releases\/tag\/([^"]+)"/g)].map(m => m[1]);
    console.log('tags:', tags);
  });
});
