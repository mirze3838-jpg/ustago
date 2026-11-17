const fs = require('fs');

// 1. market_detail_screens.dart
let detail = fs.readFileSync('lib/screens/market_detail_screens.dart', 'utf8');

detail = detail.replace(
  "alreadyVip ? '👑 Bu Elan Artıq VIP-dir' : '👑 Elanı VIP Et (İndi Pulsuz)',",
  "alreadyVip ? 'Bu Elan Artıq VIP-dir' : 'Elanı VIP Et (İndi Pulsuz)',"
);
detail = detail.replace(
  "'📈 Elanı İrəli Çək (İndi Pulsuz)',",
  "'Elanı İrəli Çək (İndi Pulsuz)',"
);
detail = detail.replace(
  "String formattedDate = '17.Nov.2026';",
  "String formattedDate = '17.11.2026';"
);
detail = detail.replace(
  `                  if (isVip)
                    Positioned(
                      top: 60,
                      left: 16,`,
  `                  if (isVip)
                    Positioned(
                      bottom: 12,
                      left: 14,`
);

fs.writeFileSync('lib/screens/market_detail_screens.dart', detail, 'utf8');
console.log('Updated market_detail_screens.dart');

// 2. market_screen.dart - add gold VIP border to _buildProductGridCard
let market = fs.readFileSync('lib/screens/market_screen.dart', 'utf8');

const oldCardDeco = `      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 7, offset: const Offset(0, 3)),
          ],
        ),`;

const newCardDeco = `      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: prod['isVip'] == true ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
            width: prod['isVip'] == true ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 7, offset: const Offset(0, 3)),
          ],
        ),`;

if (market.includes(oldCardDeco)) {
  market = market.replace(oldCardDeco, newCardDeco);
  console.log('Added gold VIP border to _buildProductGridCard in market_screen.dart');
}

fs.writeFileSync('lib/screens/market_screen.dart', market, 'utf8');
console.log('Updated market_screen.dart');
