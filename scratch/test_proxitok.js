const instances = [
  'https://proxitok.pabloferreiro.es',
  'https://tok.habedieehre.ninja',
  'https://proxitok.privacydev.net',
  'https://tok.artemislena.eu'
];

async function testInstances() {
  for (const inst of instances) {
    try {
      const url = inst + '/@scout2015/rss';
      const res = await fetch(url, {
        headers: { 'User-Agent': 'Mozilla/5.0' },
        signal: AbortSignal.timeout(5000)
      });
      console.log(inst, 'Status:', res.status);
      if (res.status === 200) {
        const text = await res.text();
        console.log('Got RSS feed! Length:', text.length, text.substring(0, 400));
        return;
      }
    } catch(e) {
      console.log(inst, 'Error:', e.message);
    }
  }
}
testInstances();
