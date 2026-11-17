const https = require('https');

https.get('https://github.com/ustago-app/ustago/actions/runs/43943843122', { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => {
    // Check if job is still in progress
    const inProg = d.includes('In progress') || d.includes('in_progress');
    const comp = d.includes('completed');
    const succ = d.includes('completed successfully') || d.includes('Conclusion: success');
    const fail = d.includes('Conclusion: failure');
    console.log({ inProg, comp, succ, fail });
  });
});
