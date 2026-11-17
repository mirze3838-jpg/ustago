const fs = require('fs');
const readline = require('readline');

async function search() {
  const fileStream = fs.createReadStream('C:/Users/Acer/.gemini/antigravity/brain/9f2c4d81-a002-4cb9-8ec8-6a7dbc331ae2/.system_generated/logs/transcript.jsonl');
  const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });

  for await (const line of rl) {
    if (line.includes('developers.tiktok.com') && (line.includes('client') || line.includes('Key') || line.includes('app/'))) {
      const j = JSON.parse(line);
      const text = (j.content || '') + ' ' + (j.thinking || '');
      const urls = text.match(/https:\/\/developers\.tiktok\.com[^\s"'\)]+/g);
      if (urls) console.log('URLs:', [...new Set(urls)]);
      const keys = text.match(/client_key[^\s]+/gi);
      if (keys) console.log('Keys:', keys);
    }
  }
}
search();
