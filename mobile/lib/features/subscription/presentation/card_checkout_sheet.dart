import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_sound_feedback.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/models_provider.dart';
import '../providers/subscription_provider.dart';

class CardCheckoutSheet extends ConsumerStatefulWidget {
  final String planId; // 'ultra' or 'pro'
  final String billingCycle; // 'monthly', 'yearly', 'lifetime'

  const CardCheckoutSheet({
    super.key,
    required this.planId,
    required this.billingCycle,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String planId,
    required String billingCycle,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CardCheckoutSheet(
        planId: planId,
        billingCycle: billingCycle,
      ),
    );
  }

  @override
  ConsumerState<CardCheckoutSheet> createState() => _CardCheckoutSheetState();
}

class _CardCheckoutSheetState extends ConsumerState<CardCheckoutSheet> {
  final _cardNumberController = TextEditingController(text: '8600 5512 3456 7890');
  final _expiryController = TextEditingController(text: '12/28');
  final _cvcController = TextEditingController(text: '888');
  final _holderController = TextEditingController(text: 'COGNIDOC MEMBER');

  bool _isProcessing = false;

  double get _amountUsd {
    final isUltra = widget.planId.toLowerCase() == 'ultra';
    if (isUltra) {
      switch (widget.billingCycle) {
        case 'monthly':
          return 24.99;
        case 'yearly':
          return 199.99;
        case 'lifetime':
          return 349.99;
        default:
          return 24.99;
      }
    } else {
      switch (widget.billingCycle) {
        case 'monthly':
          return 9.99;
        case 'yearly':
          return 79.99;
        case 'lifetime':
          return 149.99;
        default:
          return 9.99;
      }
    }
  }

  int get _amountUzs => (_amountUsd * 13000).round();

  String get _detectedCardBrand {
    final clean = _cardNumberController.text.replaceAll(' ', '');
    if (clean.startsWith('8600')) return 'UZCARD';
    if (clean.startsWith('9860')) return 'HUMO';
    if (clean.startsWith('4')) return 'VISA';
    if (clean.startsWith('5')) return 'MASTERCARD';
    return 'KARTA';
  }

  void _fillTestCard(String brand) {
    setState(() {
      if (brand == 'uzcard') {
        _cardNumberController.text = '8600 5512 3456 7890';
        _expiryController.text = '12/28';
        _cvcController.text = '888';
        _holderController.text = 'AZIZBEK TOHIROV';
      } else if (brand == 'humo') {
        _cardNumberController.text = '9860 1234 5678 9012';
        _expiryController.text = '10/29';
        _cvcController.text = '321';
        _holderController.text = 'AZIZBEK TOHIROV';
      } else {
        _cardNumberController.text = '4000 1234 5678 9010';
        _expiryController.text = '05/27';
        _cvcController.text = '777';
        _holderController.text = 'AZIZBEK TOHIROV';
      }
    });
    UiSoundFeedback.playActionClick();
  }

  Future<void> _handleConfirmPayment() async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hisobga kirish talab etiladi'),
          content: const Text(
            'Obunani hisobingizga biriktirish uchun avval tizimga kirishingiz lozim.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kirish'),
            ),
          ],
        ),
      );

      if (shouldLogin == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);
    final isUltra = widget.planId.toLowerCase() == 'ultra';
    final productId = '${widget.planId.toLowerCase()}_${widget.billingCycle}';
    final cleanNumber = _cardNumberController.text.replaceAll(' ', '');
    final last4 = cleanNumber.length >= 4 ? cleanNumber.substring(cleanNumber.length - 4) : '8600';

    try {
      final success = await ref.read(subscriptionProvider.notifier).purchaseManual(
            productId: productId,
            store: 'card_payment',
            last4: last4,
          );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success) {
        UiSoundFeedback.playActionClick();
        ref.invalidate(userEntitlementsProvider);

        Navigator.pop(context, true); // Close checkout sheet

        _showSuccessCelebration(context, isUltra: isUltra);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('To\'lovni tasdiqlashda xatolik yuz berdi. Qayta urining.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Xatolik: $e'),
          ),
        );
      }
    }
  }

  void _showSuccessCelebration(BuildContext context, {required bool isUltra}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isUltra
                      ? [Colors.deepPurpleAccent, Colors.purple]
                      : [AppColors.primary, Colors.teal],
                ),
              ),
              child: Icon(
                isUltra ? Icons.diamond_rounded : Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isUltra
                  ? 'Tabriklaymiz! CogniDoc AI Ultra faollashtirildi! 👑'
                  : 'Tabriklaymiz! CogniDoc AI Pro faollashtirildi! 💎',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              isUltra
                  ? 'Hisobingizga kunlik 1,200 ta so\'rov, 200MB gacha darslik va kitoblar tahlili hamda barcha eng kuchli AI modellari biriktirildi.'
                  : 'Hisobingizga kunlik 400 ta so\'rov, 50MB kitoblar tahlili va yuqori tezlik biriktirildi.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.grey),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUltra ? Colors.deepPurpleAccent : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Foydalanishni boshlash',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUltra = widget.planId.toLowerCase() == 'ultra';
    final cardBrand = _detectedCardBrand;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isUltra
                                  ? Colors.deepPurpleAccent.withOpacity(0.15)
                                  : AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.credit_card_rounded,
                              color: isUltra ? Colors.deepPurpleAccent : AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUltra ? 'Ultra Obuna To\'lovi' : 'Pro Obuna To\'lovi',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Xavfsiz bank kartasi orqali to\'lov',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Virtual Card Graphic
                  Container(
                    height: 190,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isUltra
                            ? const [
                                Color(0xFF2E1A47),
                                Color(0xFF4A154B),
                                Color(0xFF1E1035),
                              ]
                            : const [
                                Color(0xFF1B4332),
                                Color(0xFF2D6A4F),
                                Color(0xFF081C15),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isUltra ? Colors.deepPurpleAccent : AppColors.primary)
                              .withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // Chip visual
                                Container(
                                  width: 38,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2B755),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: const Icon(
                                    Icons.sim_card_rounded,
                                    size: 18,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.contactless_rounded,
                                  color: Colors.white70,
                                  size: 22,
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cardBrand,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Live Card Number
                        Text(
                          _cardNumberController.text.isEmpty
                              ? '•••• •••• •••• ••••'
                              : _cardNumberController.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        // Expiry & Holder
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'KARTA EGASI',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _holderController.text.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'MUDDATI',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Quick test card chips
                  Row(
                    children: [
                      const Text(
                        'Sinov kartalari: ',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      _buildQuickChip('Uzcard', () => _fillTestCard('uzcard')),
                      const SizedBox(width: 6),
                      _buildQuickChip('Humo', () => _fillTestCard('humo')),
                      const SizedBox(width: 6),
                      _buildQuickChip('Visa', () => _fillTestCard('visa')),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Card Number Input
                  TextFormField(
                    controller: _cardNumberController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                      _CardNumberFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Karta raqami',
                      hintText: '8600 0000 0000 0000',
                      prefixIcon: const Icon(Icons.credit_card_rounded),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1F242C) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 12),

                  // Expiry and CVC Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _CardExpiryFormatter(),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Muddati (MM/YY)',
                            hintText: '12/28',
                            prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1F242C) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cvcController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: InputDecoration(
                            labelText: 'CVC / CVV',
                            hintText: '•••',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1F242C) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Cardholder Input
                  TextFormField(
                    controller: _holderController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Karta egasining ismi',
                      hintText: 'AZIZBEK TOHIROV',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1F242C) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 18),

                  // Price Summary Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (isUltra ? Colors.deepPurpleAccent : AppColors.primary)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (isUltra ? Colors.deepPurpleAccent : AppColors.primary)
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUltra ? 'CogniDoc AI Ultra' : 'CogniDoc AI Pro',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '${widget.billingCycle == "yearly" ? "Yillik obuna (Tejamkor)" : widget.billingCycle == "lifetime" ? "Umrbod litsenziya" : "Oylik obuna"} • 0% komissiya',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${_amountUsd.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isUltra ? Colors.deepPurpleAccent : AppColors.primary,
                              ),
                            ),
                            Text(
                              '~${_formatUzs(_amountUzs)} UZS',
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Confirm Payment Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUltra ? Colors.deepPurpleAccent : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    onPressed: _isProcessing ? null : _handleConfirmPayment,
                    icon: _isProcessing
                        ? const SizedBox.shrink()
                        : const Icon(Icons.lock_rounded, size: 20),
                    label: _isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'To\'lovni tasdiqlash (\$${_amountUsd.toStringAsFixed(2)})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security_rounded, size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        '256-bit SSL shifrlash va xavfsiz to\'lov tizimi',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _formatUzs(int val) {
    final s = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && (i + 1) != text.length) {
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

class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
