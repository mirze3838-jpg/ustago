const { exec } = require('child_process');
const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const html = `
<!DOCTYPE html>
<html>
<body>
<div id="res"></div>
<script>
  const mp4 = typeof MediaRecorder !== 'undefined' && MediaRecorder.isTypeSupported('video/mp4');
  const webm = typeof MediaRecorder !== 'undefined' && MediaRecorder.isTypeSupported('video/webm');
  document.getElementById('res').innerText = JSON.stringify({ mp4, webm });
</script>
</body>
</html>
`;

const fs = require('fs');
fs.writeFileSync('C:\\Users\\Acer\\.gemini\\antigravity\\scratch\\ustago\\scratch\\test.html', html);

exec(`"${chromePath}" --headless --disable-gpu --dump-dom "file:///C:/Users/Acer/.gemini/antigravity/scratch/ustago/scratch/test.html"`, (err, stdout, stderr) => {
  if (err) console.error('Err:', err);
  console.log('Output:', stdout);
});
