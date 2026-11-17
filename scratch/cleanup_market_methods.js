const fs = require('fs');
const filePath = 'C:/Users/Acer/.gemini/antigravity/scratch/ustago/lib/screens/market_screen.dart';
let content = fs.readFileSync(filePath, 'utf8');

const isCRLF = content.includes('\r\n');
if (isCRLF) content = content.replace(/\r\n/g, '\n');

const targetMethodStart = '  Future<void> _showStoreFormSheet({Map<String, dynamic>? existingStore}) async {';
const targetMethodEnd = '  Future<void> _deleteListing(String docId, {bool isStore = false}) async {';

const idxStart = content.indexOf(targetMethodStart);
const idxEnd = content.indexOf(targetMethodEnd, idxStart);

if (idxStart === -1 || idxEnd === -1) {
  console.error('Methods not found!', idxStart, idxEnd);
  process.exit(1);
}

const replaceMethods = `  Future<void> _showStoreFormSheet({Map<String, dynamic>? existingStore}) =>
      MarketScreen.showStoreFormSheet(context, existingStore: existingStore);

  Future<void> _showProductFormSheet({Map<String, dynamic>? existingProduct}) =>
      MarketScreen.showProductFormSheet(context, existingProduct: existingProduct);

`;

content = content.slice(0, idxStart) + replaceMethods + content.slice(idxEnd);

if (isCRLF) content = content.replace(/\n/g, '\r\n');
fs.writeFileSync(filePath, content, 'utf8');
console.log('Old duplicate methods replaced with one-liners successfully!');
