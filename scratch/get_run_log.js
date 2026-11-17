const https = require('https');

const runId = process.argv[2] || '44041680540';

https.get(`https://github.com/ustago-app/ustago/actions/runs/${runId}`, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => {
    const regex = new RegExp(`/ustago-app/ustago/actions/runs/${runId}/job/(\\d+)`, 'g');
    const jobMatches = [...d.matchAll(regex)].map(m => m[1]);
    console.log('job ids for run', runId, ':', jobMatches);
    if (jobMatches.length > 0) {
      getJob(jobMatches[0], runId);
    }
  });
});

function getJob(jobId, runId) {
  https.get(`https://github.com/ustago-app/ustago/actions/runs/${runId}/job/${jobId}`, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
    let d = '';
    res.on('data', c => d += c);
    res.on('end', () => {
      // Find dpaste or error annotations
      const dpaste = d.match(/https:\/\/dpaste\.org\/[a-zA-Z0-9]+/);
      if (dpaste) {
        console.log('dpaste link:', dpaste[0]);
      } else {
        console.log('no dpaste link in job html');
        // Let's check status of steps
        const stepMatches = [...d.matchAll(/<span class="step-title[^>]*>([^<]+)<\/span>/g)].map(m => m[1].trim());
        console.log('steps:', stepMatches);
        const inProg = d.includes('In progress') || d.includes('in_progress');
        const succ = d.includes('completed successfully') || d.includes('Conclusion: success');
        const fail = d.includes('Conclusion: failure');
        console.log({ inProg, succ, fail });
      }
    });
  });
}
