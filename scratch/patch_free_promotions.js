const fs = require('fs');

let content = fs.readFileSync('lib/screens/market_detail_screens.dart', 'utf8');

const startTarget = '  void _showVipSheet() {';
const endTarget = '  void _shareProduct() {';

const sIdx = content.indexOf(startTarget);
const eIdx = content.indexOf(endTarget);

if (sIdx !== -1 && eIdx !== -1) {
  const freePromotionCode = `  void _showVipSheet() {
    final bool alreadyVip = _prod['isVip'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 18),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                alreadyVip ? '👑 Bu Elan Artıq VIP-dir' : '👑 Elanı VIP Et (İndi Pulsuz)',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                alreadyVip
                    ? 'Elanınız hazırda VIP statusundadır və Alış-Satış bölməsinin ən üstündə nümayiş olunur.'
                    : 'Aksiya çərçivəsində elanınızı 30 günlük tamamilə pulsuz VIP vitrininə qaldırın!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 18),
              _buildBenefitRow(Icons.star_rounded, const Color(0xFFF59E0B), 'Xüsusi VIP Vitrini', 'Alış-satış bölməsinin ən üstündəki VIP lentində daimi nümayiş olunur.'),
              const SizedBox(height: 10),
              _buildBenefitRow(Icons.brush_rounded, const Color(0xFFEA580C), 'Qızılı Fərqləndirici Haşiyə', 'Axtarışda və kateqoriyalarda digər elanlardan seçilən parlaq dizayn.'),
              const SizedBox(height: 10),
              _buildBenefitRow(Icons.bolt_rounded, const Color(0xFF10B981), 'İndi Pulsuz Aktivləşdirmə', 'Heç bir ödəniş tələb olunmur, bir toxunuşla dərhal aktivləşir.'),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: Icon(alreadyVip ? Icons.check_circle_rounded : Icons.bolt_rounded, size: 20),
                  label: Text(
                    alreadyVip ? 'VIP Müddətini Yenilə (30 gün)' : 'İndi Pulsuz VIP Et',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final docId = _prod['id']?.toString();
                    if (docId != null && docId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('market_stores').doc(docId).update({
                        'isVip': true,
                        'vipUntil': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
                      }).catchError((_) {});
                    }
                    setState(() {
                      _prod['isVip'] = true;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Təbriklər! Elanınız pulsuz 30 günlük VIP statusu qazandı! 👑'),
                          backgroundColor: Color(0xFFD97706),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBumpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 18),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF059669)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.trending_up_rounded, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '📈 Elanı İrəli Çək (İndi Pulsuz)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Elanınızın dərc olunma tarixini yeniləyərək bütün siyahının ən önünə keçirin!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              _buildBenefitRow(Icons.arrow_upward_rounded, const Color(0xFF10B981), '1-ci Sıraya Qalxma', 'Elanınız bütün alıcılar üçün ən üstdə və yeni kimi görünür.'),
              const SizedBox(height: 10),
              _buildBenefitRow(Icons.schedule_rounded, const Color(0xFF1769D2), 'Tarix Yenilənməsi', 'Dərc olunma tarixi "İndicə yerləşdirildi" kimi qeyd olunur.'),
              const SizedBox(height: 10),
              _buildBenefitRow(Icons.volunteer_activism_rounded, const Color(0xFF8B5CF6), 'Tamamilə Pulsuz', 'Aksiya müddətində heç bir ödənişsiz dərhal istifadə edin.'),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: const Text('İndi İrəli Çək', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final docId = _prod['id']?.toString();
                    if (docId != null && docId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('market_stores').doc(docId).update({
                        'bumpedAt': FieldValue.serverTimestamp(),
                        'createdAt': FieldValue.serverTimestamp(),
                      }).catchError((_) {});
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Elanınız uğurla ən ön sıraya qaldırıldı! 🚀'),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, Color color, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

`;

  content = content.substring(0, sIdx) + freePromotionCode + content.substring(eIdx);
  fs.writeFileSync('lib/screens/market_detail_screens.dart', content, 'utf8');
  console.log('Successfully updated market_detail_screens.dart to free instant activation!');
} else {
  console.error('Could not find start or end target in market_detail_screens.dart');
}
