import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../chat/providers/models_provider.dart';
import '../../subscription/presentation/payment_bottom_sheet.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../models/plan_model.dart';
import '../providers/plans_provider.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlansScreen()),
    );
  }

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(userEntitlementsProvider);
    });
  }

  void _openCheckout(String planId) {
    PaymentBottomSheet.show(context, planId: planId);
  }

  Future<void> _handleRestore(AppLanguage lang) async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final isRestored = await ref.read(subscriptionProvider.notifier).restore();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (isRestored) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(AppStrings.tr('plans_restore_success', lang)),
          ),
        );
        ref.invalidate(userEntitlementsProvider);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppStrings.tr('plans_restore_not_found', lang)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleResetToFree() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final success = await ref.read(subscriptionProvider.notifier).resetToFree();
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Free plan faollashtirildi!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plansAsync = ref.watch(plansListProvider);
    final entitlementsAsync = ref.watch(userEntitlementsProvider);
    final subState = ref.watch(subscriptionProvider);

    final backendPlan = (entitlementsAsync.value?['plan_id'] as String?)?.toLowerCase();
    final effectivePlan = (backendPlan != null && backendPlan.isNotEmpty)
        ? backendPlan
        : subState.planId;

    final isUltraUser = effectivePlan == 'ultra';
    final isProUser = effectivePlan == 'pro';
    final isFreeUser = !isUltraUser && !isProUser;

    final remainingRequests =
        entitlementsAsync.value?['daily_requests_remaining'] ??
            (isUltraUser ? 1200 : (isProUser ? 400 : 40));
    final dailyLimit = entitlementsAsync.value?['daily_requests_limit'] ??
        (isUltraUser ? 1200 : (isProUser ? 400 : 40));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr('plans_title', currentLang)),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : () => _handleRestore(currentLang),
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: Text(
              AppStrings.tr('plans_restore_btn', currentLang),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      body: plansAsync.when(
        data: (plans) {
          final freePlan = plans.firstWhere(
            (p) => !p.isPro,
            orElse: () => const PlanModel(
              id: 'free',
              name: 'Free',
              description: 'Boshlang\'ich tarif',
              dailyRequests: 40,
              monthlyTokens: 100000,
              maxInputTokens: 4000,
              maxOutputTokens: 1024,
              maxActiveStreams: 1,
              allowedModels: ['nemotron-ultra', 'cohere-code'],
              priceUsdCents: 0,
              isActive: true,
            ),
          );

          final proPlan = plans.firstWhere(
            (p) => p.isPro,
            orElse: () => const PlanModel(
              id: 'pro',
              name: 'Pro Obuna',
              description: 'Cheksiz sifat va premium modellar',
              dailyRequests: 400,
              monthlyTokens: 1000000,
              maxInputTokens: 32000,
              maxOutputTokens: 4096,
              maxActiveStreams: 3,
              allowedModels: [
                'nemotron-ultra',
                'cohere-code',
                'nemotron-super',
                'gpt-4o'
              ],
              priceUsdCents: 999,
              isActive: true,
            ),
          );

          final ultraPlan = plans.firstWhere(
            (p) => p.id == 'ultra',
            orElse: () => const PlanModel(
              id: 'ultra',
              name: 'Ultra Obuna',
              description: 'Maksimal professional imkoniyatlar',
              dailyRequests: 1200,
              monthlyTokens: 30000000,
              maxInputTokens: 128000,
              maxOutputTokens: 8192,
              maxActiveStreams: 10,
              allowedModels: [],
              priceUsdCents: 2499,
              isActive: true,
            ),
          );

          final isUltraUser = entitlementsAsync.value?['plan_id'] == 'ultra';

          final freeFeatures = currentLang == AppLanguage.uz
              ? const [
                  'Kunlik 40 ta tezkor savol-javob',
                  '10 MB gacha darslik va PDF tahlili',
                  'Rasmlar va vizual ma\'lumotlarni tushunish',
                  'Suhbatlar tarixi va kontekst xotirasi',
                  'Standart server navbati',
                ]
              : currentLang == AppLanguage.ru
                  ? const [
                      '40 быстрых ответов в день',
                      'Анализ учебников и PDF до 10 МБ',
                      'Распознавание изображений и схем',
                      'История диалогов и сохранение контекста',
                      'Стандартная очередь обработки',
                    ]
                  : const [
                      '40 daily fast Q&A requests',
                      'Textbook & PDF analysis up to 10 MB',
                      'Image & visual diagram understanding',
                      'Full conversation history & context',
                      'Standard processing queue',
                    ];

          final proFeatures = currentLang == AppLanguage.uz
              ? const [
                  'Kunlik 400 ta so\'rov (10 barobar ko\'proq)',
                  'Ilg\'or fikrlash va chuqur tahlil intellekti',
                  '50 MB gacha katta hujjatlar va PDF tahlili',
                  'Sahifama-sahifa aniq manbalar (Citations)',
                  'Bir vaqtning o\'zida 3 ta parallel suhbat',
                  'Yuqori server ustuvorligi (Tezkor javoblar)',
                ]
              : currentLang == AppLanguage.ru
                  ? const [
                      '400 запросов в день (в 10 раз больше)',
                      'Продвинутый логический анализ и рассуждения',
                      'Анализ крупных книг и PDF до 50 МБ',
                      'Постраничные точные цитаты без выдумок',
                      '3 параллельных активных потока',
                      'Максимальный приоритет скорости на сервере',
                    ]
                  : const [
                      '400 daily requests (10x capacity)',
                      'Advanced reasoning & deep synthesis',
                      'Up to 50 MB textbook & book analysis',
                      'Exact page-by-page verifiable citations',
                      '3 parallel active streams',
                      'High server priority & zero latency',
                    ];

          final ultraFeatures = currentLang == AppLanguage.uz
              ? const [
                  'Kunlik 1,200 ta cheksiz darajadagi so\'rov',
                  '200 MB gacha ulkan hajmdagi kitoblar',
                  'To\'liq multimodal (hujjat, rasm va media tahlili)',
                  'Bir vaqtning o\'zida 10 ta parallel oqim',
                  'Eng yuqori navbat ustuvorligi (Zero-wait queue)',
                  'Maksimal kontekst hajmi va chuqur qidiruv',
                ]
              : currentLang == AppLanguage.ru
                  ? const [
                      '1 200 запросов в день для исследователей',
                      'Огромные архивы книг и документов до 200 МБ',
                      'Полный мультимодальный анализ (текст, формулы, фото)',
                      'До 10 параллельных рабочих процессов',
                      'Мгновенная обработка без очередей',
                      'Максимальное контекстное окно и поиск',
                    ]
                  : const [
                      '1,200 requests/day for power researchers',
                      'Gigantic books and documents up to 200 MB',
                      'Full multimodal reasoning (docs, charts, photos)',
                      'Up to 10 concurrent research sessions',
                      'Zero-wait priority processing queue',
                      'Maximum context window & deep semantic search',
                    ];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userEntitlementsProvider);
              ref.invalidate(plansListProvider);
              await ref.read(userEntitlementsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
              // Header description
              Text(
                AppStrings.tr('plans_header_label', currentLang),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.tr('plans_header_desc', currentLang),
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),

              const SizedBox(height: 16),

              // Current Status Badge Card
              Material(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isUltraUser
                        ? Colors.deepPurpleAccent.withOpacity(0.5)
                        : (isProUser
                            ? Colors.amber.withOpacity(0.5)
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isUltraUser
                              ? Colors.deepPurpleAccent.withOpacity(0.15)
                              : (isProUser
                                  ? Colors.amber.withOpacity(0.15)
                                  : AppColors.primary.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isUltraUser
                              ? Icons.diamond_rounded
                              : (isProUser
                                  ? Icons.workspace_premium_rounded
                                  : Icons.check_circle_outline_rounded),
                          color: isUltraUser
                              ? Colors.deepPurpleAccent
                              : (isProUser ? Colors.amber : AppColors.primary),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppStrings.tr('plans_current_prefix', currentLang)}${isUltraUser ? 'ULTRA' : (isProUser ? 'PRO' : 'FREE')}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${AppStrings.tr('profile_daily_remaining', currentLang)} $remainingRequests / $dailyLimit',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Plan 1: Free Card
              _buildPlanCard(
                context: context,
                plan: freePlan,
                isCurrentPlan: isFreeUser,
                isHighlighted: false,
                features: freeFeatures,
                buttonText: isFreeUser
                    ? AppStrings.tr('plan_current', currentLang)
                    : (currentLang == AppLanguage.ru ? 'Перейти на Free' : 'Free ga qaytish'),
                onPressed: !isFreeUser ? _handleResetToFree : null,
              ),

              const SizedBox(height: 20),

              // Plan 2: Pro Card (Highlighted)
              _buildPlanCard(
                context: context,
                plan: proPlan,
                isCurrentPlan: isProUser,
                isHighlighted: true,
                badgeText: AppStrings.tr('plans_recommended_badge', currentLang),
                features: proFeatures,
                buttonText: isProUser
                    ? AppStrings.tr('plan_current', currentLang)
                    : AppStrings.tr('plans_choose_pro_btn', currentLang),
                isLoading: _isLoading,
                onPressed: isProUser ? null : () => _openCheckout('pro'),
              ),

              const SizedBox(height: 20),

              // Plan 3: Ultra Card
              _buildPlanCard(
                context: context,
                plan: ultraPlan,
                isCurrentPlan: isUltraUser,
                isHighlighted: false,
                badgeText: AppStrings.tr('plans_professional_badge', currentLang),
                features: ultraFeatures,
                buttonText: isUltraUser
                    ? AppStrings.tr('plan_current', currentLang)
                    : AppStrings.tr('plans_choose_ultra_btn', currentLang),
                isLoading: _isLoading,
                onPressed: isUltraUser ? null : () => _openCheckout('ultra'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required PlanModel plan,
    required bool isCurrentPlan,
    required bool isHighlighted,
    String? badgeText,
    required List<String> features,
    required String buttonText,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cleanPlanName = plan.name
        .replaceAll(RegExp(r'\s*\(\$[^)]+\)'), '')
        .replaceAll(RegExp(r'\s*\(Free\)', caseSensitive: false), '')
        .trim();

    return Material(
      color: isHighlighted
          ? (isDark ? const Color(0xFF1E2620) : const Color(0xFFF0FAF4))
          : (isDark ? AppColors.darkCard : AppColors.lightCard),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isHighlighted
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isHighlighted ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (badgeText != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cleanPlanName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  plan.priceFormatted,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? AppColors.primary : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            ...features.map(
              (feat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: isHighlighted ? AppColors.primary : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feat,
                        style: const TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isCurrentPlan && !plan.isPro)
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(buttonText),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isHighlighted ? AppColors.primary : Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isLoading ? null : onPressed,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
