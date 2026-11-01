import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_sound_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/models_provider.dart';
import '../../onboarding/presentation/language_selection_screen.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../plans/presentation/plans_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../subscription/presentation/payment_bottom_sheet.dart';
import '../../subscription/providers/subscription_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref, AppLanguage lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.tr('logout', lang)),
        content: Text(AppStrings.tr('logout_confirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.tr('cancel', lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: Text(AppStrings.tr('logout', lang)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref, AppLanguage lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.tr('profile_delete_dialog_title', lang)),
        content: Text(AppStrings.tr('profile_delete_dialog_content', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.tr('cancel', lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final success =
                  await ref.read(authProvider.notifier).deleteAccount();
              if (success) {
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.primary,
                    content: Text(AppStrings.tr('profile_delete_success', lang)),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text(AppStrings.tr('profile_delete_error', lang)),
                  ),
                );
              }
            },
            child: Text(AppStrings.tr('profile_delete_confirm_btn', lang)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entitlementsAsync = ref.watch(userEntitlementsProvider);
    final subState = ref.watch(subscriptionProvider);
    final backendPlan = (entitlementsAsync.value?['plan_id'] as String?)?.toLowerCase();
    final effectivePlan = (backendPlan != null && backendPlan.isNotEmpty)
        ? backendPlan
        : subState.planId;
    final isUltraUser = effectivePlan == 'ultra';
    final isProUser = effectivePlan == 'pro';
    final isPaidUser = isUltraUser || isProUser;
    final planName = isUltraUser
        ? 'Ultra'
        : (isProUser ? AppStrings.tr('plan_pro', currentLang) : AppStrings.tr('plan_free', currentLang));
    final remaining =
        entitlementsAsync.value?['daily_requests_remaining'] ??
            (isUltraUser ? 1200 : (isProUser ? 400 : 40));
    final dailyLimit =
        entitlementsAsync.value?['daily_requests_limit'] ??
            (isUltraUser ? 1200 : (isProUser ? 400 : 40));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr('profile_title', currentLang)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userEntitlementsProvider);
          await ref.read(userEntitlementsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // 1. User Info Header Card
            Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    user?.fullName.isNotEmpty == true
                        ? user!.fullName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user?.fullName.isNotEmpty == true
                                  ? user!.fullName
                                  : AppStrings.tr('profile_default_user', currentLang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isUltraUser
                                  ? Colors.deepPurpleAccent.withOpacity(0.18)
                                  : (isProUser
                                      ? Colors.amber.withOpacity(0.15)
                                      : AppColors.primary.withOpacity(0.12)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isUltraUser ? 'ULTRA' : (isProUser ? 'PRO' : 'FREE'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isUltraUser
                                    ? Colors.deepPurpleAccent
                                    : (isProUser ? Colors.amber : AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
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

          const SizedBox(height: 20),

          // 2. Plan and Subscription Management
          Text(
            AppStrings.tr('profile_section_plan', currentLang),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isProUser
                    ? Colors.amber.withOpacity(0.5)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isProUser
                              ? Icons.workspace_premium_rounded
                              : Icons.star_border_rounded,
                          color: isProUser ? Colors.amber : AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          planName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 0),
                      ),
                      onPressed: () {
                        UiSoundFeedback.playItemClick();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlansScreen()),
                        );
                      },
                      child: Text(AppStrings.tr('profile_plans_table', currentLang)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: dailyLimit > 0
                      ? (remaining / dailyLimit).clamp(0.0, 1.0)
                      : 1.0,
                  backgroundColor: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE2E8F0),
                  color: isProUser ? Colors.amber : AppColors.primary,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 6),
                Text(
                  '${AppStrings.tr('profile_daily_remaining', currentLang)} $remaining / $dailyLimit',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                if (!isPaidUser) ...[
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      UiSoundFeedback.playActionClick();
                      PaymentBottomSheet.show(context, planId: 'pro');
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(
                      AppStrings.tr('profile_upgrade_pro', currentLang),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Settings Navigation Menu Tile (Settings inside Profile)
          Text(
            AppStrings.tr('profile_section_settings', currentLang),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Language Selector Tile (Priority Item)
          Material(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.translate_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(
                AppStrings.tr('profile_language_tile', currentLang),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              subtitle: Text(
                '${AppStrings.tr('profile_language_desc', currentLang)}${currentLang.flag} ${currentLang.label}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey,
              ),
              onTap: () {
                UiSoundFeedback.playItemClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LanguageSelectionScreen(isStandalone: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Settings Screen Tile
          Material(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.settings_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              title: Text(
                AppStrings.tr('profile_settings_tile', currentLang),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              subtitle: Text(
                AppStrings.tr('profile_settings_desc', currentLang),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey,
              ),
              onTap: () {
                UiSoundFeedback.playItemClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Onboarding Tour Guide Tile
          Material(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              title: Text(
                AppStrings.tr('profile_app_presentation', currentLang),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              subtitle: Text(
                AppStrings.tr('profile_app_presentation_desc', currentLang),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey,
              ),
              onTap: () {
                UiSoundFeedback.playItemClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OnboardingScreen(
                      onFinished: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // 4. Security & Account Actions
          Text(
            AppStrings.tr('profile_section_security', currentLang),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  title: Text(
                    AppStrings.tr('logout', currentLang),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () => _showLogoutDialog(context, ref, currentLang),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    size: 20,
                  ),
                  title: Text(
                    AppStrings.tr('profile_privacy_policy', currentLang),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Clipboard.setData(
                      const ClipboardData(
                        text: 'https://cognidoc.ai/privacy-policy',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${AppStrings.tr('profile_copied_link', currentLang)} (https://cognidoc.ai/privacy-policy)',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    size: 20,
                  ),
                  title: Text(
                    AppStrings.tr('profile_terms_service', currentLang),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () {
                    Clipboard.setData(
                      const ClipboardData(
                        text: 'https://cognidoc.ai/terms',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${AppStrings.tr('profile_copied_link', currentLang)} (https://cognidoc.ai/terms)',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                  title: Text(
                    AppStrings.tr('profile_delete_account', currentLang),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: () => _showDeleteAccountDialog(context, ref, currentLang),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    ));
  }
}
