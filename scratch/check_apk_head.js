const https = require('https');

https.request('https://github.com/ustago-app/ustago/releases/download/v1.0.0/ustago.apk', { method: 'HEAD', headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
  console.log('status:', res.statusCode, 'location:', res.headers['location']);
  if (res.headers['location']) {
    https.request(res.headers['location'], { method: 'HEAD', headers: { 'User-Agent': 'Mozilla/5.0' } }, (res2) => {
      console.log('redirect status:', res2.statusCode, 'content-length:', res2.headers['content-length'], 'last-modified:', res2.headers['last-modified']);
    }).end();
  }
}).end();
