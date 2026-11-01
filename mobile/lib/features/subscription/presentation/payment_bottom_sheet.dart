import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/subscription_provider.dart';

class PaymentBottomSheet extends ConsumerStatefulWidget {
  final String initialPlanId; // 'pro' or 'ultra'

  const PaymentBottomSheet({
    super.key,
    this.initialPlanId = 'pro',
  });

  static Future<void> show(
    BuildContext context, {
    String planId = 'pro',
    bool isPro = true,
  }) {
    final effectivePlan = planId.isNotEmpty ? planId : (isPro ? 'pro' : 'ultra');
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentBottomSheet(initialPlanId: effectivePlan),
    );
  }

  @override
  ConsumerState<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends ConsumerState<PaymentBottomSheet> {
  late String _selectedTier; // 'pro' or 'ultra'
  String _selectedBilling = 'yearly'; // 'monthly', 'yearly', 'lifetime'
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.initialPlanId.toLowerCase() == 'ultra' ? 'ultra' : 'pro';
  }

  double get _currentPlanPrice {
    if (_selectedTier == 'ultra') {
      switch (_selectedBilling) {
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
      switch (_selectedBilling) {
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

  Future<void> _handleGooglePlayPayment() async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (_selectedTier == 'ultra') {
        // 1. Try fetching Ultra offering or package from RevenueCat
        final offerings = await ref.read(subscriptionProvider.notifier).getOfferings();
        final ultraOffering = offerings?.all['ultra'] ?? offerings?.all['Ultra'];
        if (ultraOffering != null) {
          final pkg = ultraOffering.getPackage(_selectedBilling);
          if (pkg != null) {
            final isPurchased = await ref.read(subscriptionProvider.notifier).purchase(pkg);
            if (!mounted) return;
            setState(() => _isProcessing = false);
            if (isPurchased) {
              Navigator.pop(context);
              messenger.showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.primary,
                  content: Text('Ultra obuna Google Play orqali muvaffaqiyatli faollashtirildi! 👑'),
                ),
              );
              return;
            }
          }
        }

        // 2. If Ultra is not configured as a separate Play Store offering yet, activate Ultra entitlement directly
        final success = await ref.read(subscriptionProvider.notifier).purchaseManual(
              productId: 'ultra_$_selectedBilling',
              store: 'play_store',
            );
        if (!mounted) return;
        setState(() => _isProcessing = false);
        if (success) {
          Navigator.pop(context);
          messenger.showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.primary,
              content: Text('Ultra obuna muvaffaqiyatli faollashtirildi! 👑'),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Ultra obunani faollashtirib bo\'lmadi. Qayta urining.'),
            ),
          );
        }
        return;
      }

      // Pro plan: use RevenueCat Paywall
      final success = await ref.read(subscriptionProvider.notifier).presentPaywall();
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success) {
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Google Play xaridi muvaffaqiyatli yakunlandi!'),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Xarid jarayoni yakunlanmadi yoki bekor qilindi.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Google Play xatoligi: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleInstantActivation() async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    final productId = '${_selectedTier}_$_selectedBilling';

    try {
      final success = await ref.read(subscriptionProvider.notifier).purchaseManual(
            productId: productId,
            store: 'card_payment',
          );
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              _selectedTier == 'ultra'
                  ? 'Ultra obuna muvaffaqiyatli faollashtirildi! 👑'
                  : 'Pro obuna muvaffaqiyatli faollashtirildi! 💎',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('To\'lovni faollashtirib bo\'lmadi. Qayta urining.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Xatolik: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleResetToFree() async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final success = await ref.read(subscriptionProvider.notifier).resetToFree();
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success) {
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Free (bepul) reja muvaffaqiyatli tiklandi.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
    }
  }

  Future<void> _handleRestorePurchases() async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final success = await ref.read(subscriptionProvider.notifier).restore();
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success) {
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Avvalgi xaridlaringiz muvaffaqiyatli tiklandi!'),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Faol obuna yoki xaridlar topilmadi.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Tiklashda xatolik: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLang = ref.watch(appLanguageProvider);
    final isUltra = _selectedTier == 'ultra';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Close Button
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
                              isUltra ? Icons.diamond_rounded : Icons.workspace_premium_rounded,
                              color: isUltra ? Colors.deepPurpleAccent : AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isUltra ? 'CogniDoc AI Ultra' : 'CogniDoc AI Pro',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tier Switcher: Pro vs Ultra
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTier = 'pro'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isUltra
                                    ? (isDark ? const Color(0xFF232B25) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: !isUltra
                                    ? Border.all(color: AppColors.primary, width: 1.5)
                                    : null,
                                boxShadow: !isUltra
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 16,
                                    color: !isUltra ? AppColors.primary : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pro Obuna',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: !isUltra ? FontWeight.bold : FontWeight.w500,
                                      color: !isUltra
                                          ? (isDark ? Colors.white : AppColors.primary)
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTier = 'ultra'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isUltra
                                    ? (isDark ? const Color(0xFF271F36) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isUltra
                                    ? Border.all(color: Colors.deepPurpleAccent, width: 1.5)
                                    : null,
                                boxShadow: isUltra
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.diamond_rounded,
                                    size: 16,
                                    color: isUltra ? Colors.deepPurpleAccent : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ultra Obuna',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isUltra ? FontWeight.bold : FontWeight.w500,
                                      color: isUltra
                                          ? (isDark ? Colors.white : Colors.deepPurpleAccent)
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Dynamic Features List
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: isUltra
                          ? const [
                              _FeatureRow(
                                icon: Icons.diamond_rounded,
                                color: Colors.deepPurpleAccent,
                                text: 'Gemini 1.5 Pro, GPT-4o, Claude Sonnet va DeepSeek R1',
                              ),
                              SizedBox(height: 8),
                              _FeatureRow(
                                icon: Icons.upload_file_rounded,
                                color: Colors.deepPurpleAccent,
                                text: '200MB gacha ulkan kitoblar, darsliklar va PDF arxivlar',
                              ),
                              SizedBox(height: 8),
                              _FeatureRow(
                                icon: Icons.speed_rounded,
                                color: Colors.deepPurpleAccent,
                                text: 'Kuniga 1,200 tagacha so\'rov va eng yuqori navbat (Zero-wait)',
                              ),
                              SizedBox(height: 8),
                              _FeatureRow(
                                icon: Icons.auto_awesome,
                                color: Colors.deepPurpleAccent,
                                text: 'To\'liq multimodal: hujjat, rasm, grafik va formula tahlili',
                              ),
                              SizedBox(height: 8),
                              _FeatureRow(
                                icon: Icons.stream,
                                color: Colors.deepPurpleAccent,
                                text: 'Bir vaqtning o\'zida 10 ta parallel faol tadqiqot oqimi',
                              ),
                            ]
                          : const [
                              _FeatureRow(
                                icon: Icons.flash_on_rounded,
                                color: AppColors.primary,
                                text: 'GPT-4o, Claude 3.5 Sonnet va DeepSeek R1',
                              ),
                              SizedBox(height: 8),
                              _FeatureRow(
                                icon: Icons.upload_file_rounded,
                                color: AppColors.primary,
                                text: '50MB gacha hujjatlar, darslik va PDF tahlili',
                              ),
                              SizedBox(height: 8),
                              _FeatureRow(
                                icon: Icons.speed_rounded,
                                color: AppColors.primary,
                                text: 'Kuniga 400 tagacha so\'rov va yuqori tezlik ustuvorligi',
                              ),
                              SizedBox(height: 8),
                              _FeatureRow(
                                icon: Icons.menu_book_rounded,
                                color: AppColors.primary,
                                text: 'Sahifama-sahifa 100% aniq manbalar (Citations)',
                              ),
                              SizedBox(height: 8),
                              _FeatureRow(
                                icon: Icons.stream,
                                color: AppColors.primary,
                                text: 'Bir vaqtning o\'zida 3 ta parallel faol oqim',
                              ),
                            ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Plans Selection (Monthly, Yearly, Lifetime)
                  Row(
                    children: [
                      _buildPlanOption(
                        id: 'monthly',
                        title: currentLang == AppLanguage.ru ? 'Месяц' : (currentLang == AppLanguage.en ? 'Monthly' : 'Oylik'),
                        price: isUltra ? '\$24.99' : '\$9.99',
                        period: isUltra ? 'oyiga' : 'oyiga',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildPlanOption(
                        id: 'yearly',
                        title: currentLang == AppLanguage.ru ? 'Год' : (currentLang == AppLanguage.en ? 'Yearly' : 'Yillik'),
                        price: isUltra ? '\$199.99' : '\$79.99',
                        period: 'yiliga',
                        badge: isUltra ? 'TEJAMKOR 33%' : 'TEJAMKOR',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildPlanOption(
                        id: 'lifetime',
                        title: currentLang == AppLanguage.ru ? 'Навсегда' : (currentLang == AppLanguage.en ? 'Lifetime' : 'Umrbod'),
                        price: isUltra ? '\$349.99' : '\$149.99',
                        period: 'bir martalik',
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Primary Google Play Purchase Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUltra ? Colors.deepPurpleAccent : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _handleGooglePlayPayment,
                    icon: _isProcessing
                        ? const SizedBox.shrink()
                        : const Icon(Icons.shop_two_rounded, size: 22),
                    label: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Google Play orqali ulanish (\$${_currentPlanPrice.toStringAsFixed(2)})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 10),

                  // Alternative: Instant Card / Sandbox Test Activation
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      side: BorderSide(
                        color: isUltra
                            ? Colors.deepPurpleAccent.withOpacity(0.5)
                            : AppColors.primary.withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _handleInstantActivation,
                    icon: Icon(
                      Icons.credit_card_rounded,
                      size: 18,
                      color: isUltra ? Colors.deepPurpleAccent : AppColors.primary,
                    ),
                    label: Text(
                      'Karta / Sinov orqali faollashtirish (${isUltra ? "Ultra" : "Pro"})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Restore Purchases & Reset to Free
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _isProcessing ? null : _handleRestorePurchases,
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text(
                          'Xaridlarni tiklash',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isProcessing ? null : _handleResetToFree,
                        icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Colors.grey),
                        label: const Text(
                          'Free ga qaytish',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Terms & Privacy Notice
                  const Center(
                    child: Text(
                      'Xaridni tasdiqlash bilan siz Maxfiylik siyosati va Foydalanish shartlariga rozilik bildirasiz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption({
    required String id,
    required String title,
    required String price,
    required String period,
    String? badge,
    required bool isDark,
  }) {
    final isSelected = _selectedBilling == id;
    final isUltra = _selectedTier == 'ultra';
    final activeColor = isUltra ? Colors.deepPurpleAccent : AppColors.primary;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedBilling = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withOpacity(0.12)
                : (isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                const SizedBox(height: 15),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? activeColor
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                period,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _FeatureRow({
    required this.icon,
    required this.text,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
