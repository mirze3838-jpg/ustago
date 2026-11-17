const fs = require('fs');
const c = fs.readFileSync('C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/home_screen.dart', 'utf8');

const diffCurly = c.split('{').length - c.split('}').length;
const diffParen = c.split('(').length - c.split(')').length;
const diffSquare = c.split('[').length - c.split(']').length;

console.log('diff {}:', diffCurly, '():', diffParen, '[]:', diffSquare);
if (diffCurly !== 0 || diffParen !== 0 || diffSquare !== 0) {
  process.exit(1);
}
console.log('ALL BRACKETS PERFECTLY BALANCED!');
