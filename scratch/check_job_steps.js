const https = require('https');

https.get('https://github.com/ustago-app/ustago/actions/runs/43943843122', { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => {
    const jobMatches = [...d.matchAll(/\/ustago-app\/ustago\/actions\/runs\/43943843122\/job\/(\d+)/g)].map(m => m[1]);
    console.log('job ids:', jobMatches);
    if (jobMatches.length > 0) {
      https.get(`https://github.com/ustago-app/ustago/actions/runs/43943843122/job/${jobMatches[0]}`, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res2) => {
        let d2 = '';
        res2.on('data', c => d2 += c);
        res2.on('end', () => {
          const steps = [...d2.matchAll(/class="step-title"[^>]*>(.*?)<\/span>/g)].map(m => m[1].trim());
          console.log('steps count:', steps.length);
          const dpaste = d2.match(/https:\/\/dpaste\.org\/[a-zA-Z0-9]+/);
          if (dpaste) console.log('failed with dpaste:', dpaste[0]);
          else console.log('no dpaste failure');
        });
      });
    }
  });
});
