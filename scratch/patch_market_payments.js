const fs = require('fs');

let content = fs.readFileSync('lib/screens/market_detail_screens.dart', 'utf8');

// 1. Add import
if (!content.includes("import 'payment_screens.dart';")) {
  content = "import 'payment_screens.dart';\n" + content;
  console.log('Added payment_screens.dart import');
}

// 2. Replace _showVipSheet and _showBumpSheet with navigation to VipPromotionScreen and BumpPromotionScreen
const oldVipSheetStart = '  void _showVipSheet() {';
const oldBumpSheetEnd = '  void _shareProduct() {';

const startIdx = content.indexOf(oldVipSheetStart);
const endIdx = content.indexOf(oldBumpSheetEnd);

if (startIdx !== -1 && endIdx !== -1) {
  const newMethods = `  void _showVipSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VipPromotionScreen(product: _prod),
      ),
    ).then((_) => _refreshProductData());
  }

  void _showBumpSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BumpPromotionScreen(product: _prod),
      ),
    ).then((_) => _refreshProductData());
  }

  void _refreshProductData() {
    final docId = _prod['id']?.toString();
    if (docId != null && docId.isNotEmpty) {
      FirebaseFirestore.instance.collection('market_stores').doc(docId).get().then((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _prod = {'id': doc.id, ...doc.data()!};
          });
        }
      }).catchError((_) {});
    }
  }

`;

  content = content.substring(0, startIdx) + newMethods + content.substring(endIdx);
  console.log('Successfully replaced _showVipSheet and _showBumpSheet with paid promotion screens');
} else {
  console.error('Could not find indices for _showVipSheet or _shareProduct');
}

fs.writeFileSync('lib/screens/market_detail_screens.dart', content, 'utf8');
console.log('Saved market_detail_screens.dart');
