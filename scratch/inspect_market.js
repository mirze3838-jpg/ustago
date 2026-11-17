const fs = require('fs');
const content = fs.readFileSync('C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/market_screen.dart', 'utf8');
const regex = /collection\(['"]([^'"]+)['"]\)/g;
const sets = new Set();
let match;
while ((match = regex.exec(content)) !== null) {
  sets.add(match[1]);
}
console.log('Collections in market_screen:', Array.from(sets));

// Also check tabs and main methods
const methods = content.match(/void\s+(_\w+)\s*\(/g);
console.log('Private methods in market_screen:', methods ? methods.slice(0, 30) : []);
