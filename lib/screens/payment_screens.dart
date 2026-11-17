import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// =============================================================================
// FORMATTER-LƏR: KART NÖMRƏSİ VƏ BİTMƏ TARİXİ ÜÇÜN
// =============================================================================
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }

    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '').replaceAll(' ', '');
    if (text.length > 4) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      final nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && nonZeroIndex != text.length) {
        buffer.write(' / ');
      }
    }

    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

// =============================================================================
// 1. KARTLA ÖDƏNİŞ SƏHİFƏSİ (PaymentCheckoutScreen)
// İstifadəçinin göndərdiyi nümunə: media_1794902591890_93f518be.jpg / media_1794902591970_b1cb125f.jpg
// =============================================================================
class PaymentCheckoutScreen extends StatefulWidget {
  final double amount;
  final String title;
  final String description;
  final Future<void> Function() onPaymentSuccess;

  const PaymentCheckoutScreen({
    super.key,
    required this.amount,
    required this.title,
    this.description = 'Online xidmət ödənişi',
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  final _cardNumberController = TextEditingController(text: '4242 4242 4242 4242');
  final _expiryController = TextEditingController(text: '12 / 28');
  final _cvvController = TextEditingController(text: '789');

  bool _isProcessing = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    final cardNo = _cardNumberController.text.replaceAll(' ', '');
    if (cardNo.length < 16) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Zəhmət olmasa 16 rəqəmli kart nömrəsini daxil edin.')),
      );
      return;
    }

    if (_expiryController.text.replaceAll('/', '').replaceAll(' ', '').length < 4) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Zəhmət olmasa bitmə tarixini daxil edin (MM / YY).')),
      );
      return;
    }

    if (_cvvController.text.length < 3) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(duration: Duration(milliseconds: 1300), content: Text('Zəhmət olmasa CVV/CVV2 kodunu daxil edin.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1.5 saniyəlik real bank 3D Secure / Yığım Gateway emuliyasiyası
      await Future.delayed(const Duration(milliseconds: 1400));

      // Əməliyyatı qeydə alırıq
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .add({
          'title': widget.title,
          'description': widget.description,
          'amount': widget.amount,
          'method': 'card',
          'cardLast4': cardNo.substring(cardNo.length - 4),
          'status': 'success',
          'createdAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }

      // Xidmətin əsas funksiyasını çağırırıq (isVip və ya bumpedAt yeniləməsi)
      await widget.onPaymentSuccess();

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Uğur dialoqu
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 44),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ödəniş Uğurla Tamamlandı!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.amount.toStringAsFixed(2)} AZN məbləğində ödənişiniz qəbul edildi. Xidmət dərhal aktivləşdirildi.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1769D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); // dialoqu bağla
                    Navigator.pop(context); // ödəniş səhifəsini bağla
                  },
                  child: const Text('Əla, Davam Et', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1300), content: Text('Xəta baş verdi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ödəniş', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Ana Səhifə',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Ağ Ödəniş Kartı (Nümunə Şəkil 2 & 4-ə tam uyğun)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant Başlığı: UstaGo.az və Kart Loqoları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'UstaGo.az',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'VISA',
                              style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.w900, fontSize: 13, fontStyle: FontStyle.italic),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Mastercard',
                              style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Təsvir
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Təsvir: ',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Expanded(
                        child: Text(
                          widget.description,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Kart nömrəsi sahəsi
                  const Text(
                    'Kart nömrəsi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cardNumberController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CardNumberInputFormatter(),
                    ],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                    decoration: InputDecoration(
                      hintText: '4242 4242 4242 4242',
                      hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 1.2),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5),
                      ),
                      prefixIcon: const Icon(Icons.credit_card_rounded, color: Color(0xFF64748B), size: 22),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bitmə tarixi və CVV yan-yana
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bitmə tarixi',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _expiryController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CardExpiryInputFormatter(),
                              ],
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'MM / YY',
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CVV/CVV2',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _cvvController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 3,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '***',
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Mavi Ödəniş Düyməsi (Nümunə Şəkil 2 & 4)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing ? null : _handlePayment,
                      child: _isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              '${widget.amount.toStringAsFixed(2)} AZN Ödəniş et',
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // "Ya da daha sürətli ödə" ayırıcısı
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Ya da daha sürətli ödə',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Apple Pay / Google Pay Düyməsi
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _isProcessing ? null : _handlePayment,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.apple, color: Colors.black, size: 22),
                          SizedBox(width: 4),
                          Text('Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                          SizedBox(width: 14),
                          Text('|', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          SizedBox(width: 14),
                          Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 28),
                          Text('Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Dəstəklənən loqolar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildLogoBadge('VISA', const Color(0xFF1E3A8A)),
                      _buildLogoBadge('Mastercard', const Color(0xFFEA580C)),
                      _buildLogoBadge('Apple Pay', Colors.black),
                      _buildLogoBadge('Google Pay', const Color(0xFF4285F4)),
                      _buildLogoBadge('YIĞIM', const Color(0xFFD97706)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Təhlükəsizlik bildirişi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.verified_user_outlined, size: 15, color: Color(0xFF64748B)),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Təhlükəsiz ödəniş YIĞIM Payment Services tərəfindən təmin olunur',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

// =============================================================================
// 2. VIP PROMOSİYA SEÇİM SƏHİFƏSİ (VipPromotionScreen)
// İstifadəçinin göndərdiyi nümunə: media_1794902591971_f2a4fc08.jpg
// =============================================================================
class VipPromotionScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const VipPromotionScreen({
    super.key,
    required this.product,
  });

  @override
  State<VipPromotionScreen> createState() => _VipPromotionScreenState();
}

class _VipPromotionScreenState extends State<VipPromotionScreen> {
  // Seçilmiş plan: 0 = 25 AZN / 30 gün, 1 = 10 AZN / 10 gün
  int _selectedPlanIndex = 0;

  // Ödəniş üsulu: 'card' = Visa / Mastercard, 'balance' = Hesabdan ödə
  String _paymentMethod = 'card';

  double _userBalance = 0.0;
  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final b = doc.data()?['balance'];
          if (b is num) {
            _userBalance = b.toDouble();
          }
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _isLoadingBalance = false);
    }
  }

  double get _currentAmount => _selectedPlanIndex == 0 ? 25.0 : 10.0;
  int get _currentDays => _selectedPlanIndex == 0 ? 30 : 10;
  String get _currentPlanLabel => _selectedPlanIndex == 0 ? '25 AZN / 30 gün' : '10 AZN / 10 gün';

  Future<void> _activateVip() async {
    final docId = widget.product['id']?.toString();
    if (docId != null && docId.isNotEmpty) {
      final now = DateTime.now();
      final until = now.add(Duration(days: _currentDays));
      await FirebaseFirestore.instance.collection('market_stores').doc(docId).update({
        'isVip': true,
        'vipUntil': Timestamp.fromDate(until),
        'vipPlan': _currentPlanLabel,
      }).catchError((_) {});
    }
  }

  void _onPayPressed() {
    if (_paymentMethod == 'card') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentCheckoutScreen(
            amount: _currentAmount,
            title: 'VIP Elan: ${widget.product['title'] ?? 'Məhsul'} ($_currentPlanLabel)',
            description: 'VIP Elan Xidməti ($_currentPlanLabel) - UstaGo',
            onPaymentSuccess: _activateVip,
          ),
        ),
      );
    } else {
      // Hesabdan ödə
      if (_userBalance < _currentAmount) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1300), 
            content: Text(
              'Balansınızda kifayət qədər vəsait yoxdur (Hazırki: ${_userBalance.toStringAsFixed(2)} AZN). Zəhmət olmasa balansı artırın və ya Visa/Mastercard seçin.',
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        return;
      }

      _payFromBalance();
    }
  }

  Future<void> _payFromBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'balance': FieldValue.increment(-_currentAmount),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').add({
        'title': 'VIP Elan Xidməti ($_currentPlanLabel)',
        'amount': _currentAmount,
        'method': 'balance',
        'status': 'success',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _activateVip();

      setState(() {
        _userBalance -= _currentAmount;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(duration: Duration(milliseconds: 1300), 
          content: Text('Təbriklər! Hesabınızdan ödəniş edildi və elanınız VIP oldu! 👑'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1300), content: Text('Xəta baş verdi: $e')),
      );
    }
  }

  void _showTopUpDialog() {
    final amountCtrl = TextEditingController(text: '25');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Balansı Artır',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Balansınıza əlavə etmək istədiyiniz məbləği seçin və ya daxil edin:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [10, 25, 50, 100].map((amt) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => amountCtrl.text = amt.toString(),
                      child: Text('$amt ₼', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Məbləğ (AZN)',
                suffixText: 'AZN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final entered = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (entered <= 0) return;
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentCheckoutScreen(
                        amount: entered,
                        title: 'Balans Artırma (${entered.toStringAsFixed(2)} AZN)',
                        description: 'UstaGo Hesab Balansının Artırılması',
                        onPaymentSuccess: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                              'balance': FieldValue.increment(entered),
                            }, SetOptions(merge: true));
                            _loadBalance();
                          }
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Balansı Artırmağa Keç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('VIP et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Ana Səhifə',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. Məbləğ seçin (Nümunə Şəkil 1 & 3)
                const Text(
                  'Məbləğ seçin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),

                _buildPlanRadio(
                  index: 0,
                  label: '25 AZN / 30 gün',
                  isSelected: _selectedPlanIndex == 0,
                  onTap: () => setState(() => _selectedPlanIndex = 0),
                ),
                const Divider(height: 1),

                _buildPlanRadio(
                  index: 1,
                  label: '10 AZN / 10 gün',
                  isSelected: _selectedPlanIndex == 1,
                  onTap: () => setState(() => _selectedPlanIndex = 1),
                ),
                const Divider(height: 1),

                const SizedBox(height: 24),

                // 2. Ödəniş üsulu (Nümunə Şəkil 1 & 3)
                const Text(
                  'Ödəniş üsulu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),

                _buildPaymentMethodRadio(
                  value: 'card',
                  label: 'Visa / Mastercard',
                  isSelected: _paymentMethod == 'card',
                  onTap: () => setState(() => _paymentMethod = 'card'),
                ),
                const Divider(height: 1),

                _buildPaymentMethodRadio(
                  value: 'balance',
                  label: 'Hesabdan ödə  (Hesabda: ${_userBalance.toStringAsFixed(0)} Azn)',
                  isSelected: _paymentMethod == 'balance',
                  onTap: () => setState(() => _paymentMethod = 'balance'),
                ),
                const Divider(height: 1),

                const SizedBox(height: 32),

                // Mavi "Ödə" Düyməsi (Nümunə Şəkil 1 & 3)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _onPayPressed,
                    child: const Text('Ödə', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // Alt Sabit Balans Kartı (Nümunə Şəkil 1 & 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: _showTopUpDialog,
                  child: const Text('Balansı artır', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
                _isLoadingBalance
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        'Hazırki balans: ${_userBalance.toStringAsFixed(0)} AZN',
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanRadio({
    required int index,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                  width: isSelected ? 6.5 : 2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodRadio({
    required String value,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                  width: isSelected ? 6.5 : 2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. İRƏLİ ÇƏK PROMOSİYA SEÇİM SƏHİFƏSİ (BumpPromotionScreen)
// Qiymət: 1.00 AZN (Nümunə Şəkil 4-ə tam uyğun)
// =============================================================================
class BumpPromotionScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const BumpPromotionScreen({
    super.key,
    required this.product,
  });

  @override
  State<BumpPromotionScreen> createState() => _BumpPromotionScreenState();
}

class _BumpPromotionScreenState extends State<BumpPromotionScreen> {
  int _selectedPlanIndex = 0; // 0 = 1.00 AZN / 1 dəfə, 1 = 2.50 AZN / 3 dəfə
  String _paymentMethod = 'card';

  double _userBalance = 0.0;
  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final b = doc.data()?['balance'];
          if (b is num) {
            _userBalance = b.toDouble();
          }
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _isLoadingBalance = false);
    }
  }

  double get _currentAmount => _selectedPlanIndex == 0 ? 1.00 : 2.50;
  String get _currentPlanLabel => _selectedPlanIndex == 0 ? '1.00 AZN / 1 dəfə irəli çək' : '2.50 AZN / 3 dəfə irəli çək';

  Future<void> _activateBump() async {
    final docId = widget.product['id']?.toString();
    if (docId != null && docId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('market_stores').doc(docId).update({
        'bumpedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
  }

  void _onPayPressed() {
    if (_paymentMethod == 'card') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentCheckoutScreen(
            amount: _currentAmount,
            title: 'Elanı İrəli Çək: ${widget.product['title'] ?? 'Məhsul'}',
            description: 'İrəli çək xidməti ($_currentPlanLabel) - UstaGo',
            onPaymentSuccess: _activateBump,
          ),
        ),
      );
    } else {
      if (_userBalance < _currentAmount) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1300), 
            content: Text(
              'Balansınızda kifayət qədər vəsait yoxdur (Hazırki: ${_userBalance.toStringAsFixed(2)} AZN). Zəhmət olmasa balansı artırın və ya Visa/Mastercard seçin.',
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        return;
      }

      _payFromBalance();
    }
  }

  Future<void> _payFromBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'balance': FieldValue.increment(-_currentAmount),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').add({
        'title': 'İrəli çək xidməti ($_currentPlanLabel)',
        'amount': _currentAmount,
        'method': 'balance',
        'status': 'success',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _activateBump();

      setState(() {
        _userBalance -= _currentAmount;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(duration: Duration(milliseconds: 1300), 
          content: Text('Təbriklər! Hesabınızdan ödəniş edildi və elanınız ən ön sıraya keçirildi! 🚀'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1300), content: Text('Xəta baş verdi: $e')),
      );
    }
  }

  void _showTopUpDialog() {
    final amountCtrl = TextEditingController(text: '10');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Balansı Artır',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Balansınıza əlavə etmək istədiyiniz məbləği seçin və ya daxil edin:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [5, 10, 20, 50].map((amt) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => amountCtrl.text = amt.toString(),
                      child: Text('$amt ₼', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Məbləğ (AZN)',
                suffixText: 'AZN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final entered = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (entered <= 0) return;
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentCheckoutScreen(
                        amount: entered,
                        title: 'Balans Artırma (${entered.toStringAsFixed(2)} AZN)',
                        description: 'UstaGo Hesab Balansının Artırılması',
                        onPaymentSuccess: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                              'balance': FieldValue.increment(entered),
                            }, SetOptions(merge: true));
                            _loadBalance();
                          }
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Balansı Artırmağa Keç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('İrəli çək', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Ana Səhifə',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. Məbləğ / Xidmət seçin (Nümunə Şəkil 4: 1.00 AZN)
                const Text(
                  'Məbləğ seçin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),

                _buildPlanRadio(
                  index: 0,
                  label: '1.00 AZN / 1 dəfə irəli çək',
                  isSelected: _selectedPlanIndex == 0,
                  onTap: () => setState(() => _selectedPlanIndex = 0),
                ),
                const Divider(height: 1),

                _buildPlanRadio(
                  index: 1,
                  label: '2.50 AZN / 3 dəfə irəli çək',
                  isSelected: _selectedPlanIndex == 1,
                  onTap: () => setState(() => _selectedPlanIndex = 1),
                ),
                const Divider(height: 1),

                const SizedBox(height: 24),

                // 2. Ödəniş üsulu
                const Text(
                  'Ödəniş üsulu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),

                _buildPaymentMethodRadio(
                  value: 'card',
                  label: 'Visa / Mastercard',
                  isSelected: _paymentMethod == 'card',
                  onTap: () => setState(() => _paymentMethod = 'card'),
                ),
                const Divider(height: 1),

                _buildPaymentMethodRadio(
                  value: 'balance',
                  label: 'Hesabdan ödə  (Hesabda: ${_userBalance.toStringAsFixed(0)} Azn)',
                  isSelected: _paymentMethod == 'balance',
                  onTap: () => setState(() => _paymentMethod = 'balance'),
                ),
                const Divider(height: 1),

                const SizedBox(height: 32),

                // Mavi "Ödə" Düyməsi
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _onPayPressed,
                    child: Text(
                      '${_currentAmount.toStringAsFixed(2)} AZN Ödə',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Alt Sabit Balans Kartı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: _showTopUpDialog,
                  child: const Text('Balansı artır', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
                _isLoadingBalance
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        'Hazırki balans: ${_userBalance.toStringAsFixed(0)} AZN',
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanRadio({
    required int index,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                  width: isSelected ? 6.5 : 2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodRadio({
    required String value,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                  width: isSelected ? 6.5 : 2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
