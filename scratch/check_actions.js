const https = require('https');

https.get('https://github.com/ustago-app/ustago/actions', { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => {
    const runs = [...d.matchAll(/\/ustago-app\/ustago\/actions\/runs\/(\d+)/g)].map(m => m[1]);
    const uniqueRuns = [...new Set(runs)];
    console.log('unique runs:', uniqueRuns.slice(0, 5));
    if (uniqueRuns.length > 0) {
      checkRun(uniqueRuns[0]);
    }
  });
});

function checkRun(id) {
  https.get(`https://github.com/ustago-app/ustago/actions/runs/${id}`, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
    let d = '';
    res.on('data', c => d += c);
    res.on('end', () => {
      const isCompleted = d.includes('completed');
      const isInProgress = d.includes('in_progress') || d.includes('In progress') || d.includes('queued');
      const isSuccess = d.includes('Conclusion: success') || d.includes('completed successfully');
      const isFailed = d.includes('Conclusion: failure') || d.includes('failed');
      const commitMatch = d.match(/commit\/([0-9a-f]{7,40})/);
      console.log({
        id,
        commit: commitMatch ? commitMatch[1] : 'unknown',
        isCompleted,
        isInProgress,
        isSuccess,
        isFailed,
      });
      // Look for title or status badge
      const statusMatch = d.match(/<title>(.*?)<\/title>/);
      console.log('title:', statusMatch ? statusMatch[1] : 'no title');
    });
  });
}
