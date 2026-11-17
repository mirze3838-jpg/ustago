const https = require('https');

async function testProfile(username) {
  try {
    const res = await fetch(`https://www.tiktok.com/@${username}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      }
    });
    console.log('Status:', res.status);
    const html = await res.text();
    console.log('HTML length:', html.length);

    const rehyd = html.match(/<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>([\s\S]*?)<\/script>/);
    if (rehyd) {
      console.log('Found __UNIVERSAL_DATA_FOR_REHYDRATION__');
      const data = JSON.parse(rehyd[1]);
      const scope = data['__DEFAULT_SCOPE__'] || {};
      const userDetail = scope['webapp.user-detail'] || {};
      const items = userDetail.itemList || [];
      console.log('Items found:', items.length);
      console.log('Item IDs:', items.slice(0, 10));
      return items;
    }

    const sigi = html.match(/<script id="SIGI_STATE"[^>]*>([\s\S]*?)<\/script>/);
    if (sigi) {
      console.log('Found SIGI_STATE');
      const data = JSON.parse(sigi[1]);
      const itemList = data.ItemList?.['user-post']?.list || [];
      console.log('SIGI items found:', itemList.length);
      return itemList;
    }

    console.log('No script tag found directly. Matching video links...');
    const videoMatches = [...html.matchAll(/href="https:\/\/www\.tiktok\.com\/@[^\/]+\/video\/(\d+)"/g)];
    const ids = [...new Set(videoMatches.map(m => m[1]))];
    console.log('Regex extracted video IDs:', ids.length, ids.slice(0, 5));
    return ids;
  } catch (err) {
    console.error('Error:', err);
  }
}

testProfile('scout2015');
