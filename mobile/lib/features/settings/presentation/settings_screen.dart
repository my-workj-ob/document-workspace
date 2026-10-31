import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/ui_sound_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/models_provider.dart';
import '../../plans/presentation/plans_screen.dart';
import '../../subscription/presentation/payment_bottom_sheet.dart';
import '../../subscription/providers/subscription_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ref.read(apiBaseUrlProvider));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showLogoutDialog(AppLanguage lang) {
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
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: Text(AppStrings.tr('logout', lang)),
          ),
        ],
      ),
    );
  }

  void _openCheckout(bool isPro) {
    PaymentBottomSheet.show(context, isPro: isPro);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);
    final currentLang = ref.watch(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr('settings_title', currentLang)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Section: Plan & Subscription
          Text(
            AppStrings.tr('profile_section_plan', currentLang),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (ctx) {
              final entitlementsAsync = ref.watch(userEntitlementsProvider);
              final subState = ref.watch(subscriptionProvider);
              final isProUser =
                  subState.isPro || (entitlementsAsync.value?['is_pro'] == true);
              final planName = entitlementsAsync.value?['plan_name'] as String? ??
                  (isProUser
                      ? AppStrings.tr('plan_pro', currentLang)
                      : AppStrings.tr('plan_free', currentLang));
              final remaining =
                  entitlementsAsync.value?['daily_requests_remaining'] ?? 40;
              final dailyLimit =
                  entitlementsAsync.value?['daily_requests_limit'] ?? 40;

              return Container(
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
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              planName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isProUser
                                ? Colors.amber.withOpacity(0.2)
                                : Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isProUser
                                ? AppStrings.tr('settings_pro_active', currentLang)
                                : AppStrings.tr('settings_free_badge', currentLang),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isProUser ? Colors.amber : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${AppStrings.tr('profile_daily_remaining', currentLang)} $remaining / $dailyLimit',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (!isProUser)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          UiSoundFeedback.playActionClick();
                          _openCheckout(false);
                        },
                        icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                        label: Text(
                          AppStrings.tr('settings_upgrade_play_btn', currentLang),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          UiSoundFeedback.playItemClick();
                          _openCheckout(true);
                        },
                        icon: const Icon(Icons.workspace_premium_rounded,
                            size: 18, color: Colors.amber),
                        label: Text(
                          AppStrings.tr('settings_manage_sub_btn', currentLang),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        UiSoundFeedback.playItemClick();
                        PlansScreen.show(context);
                      },
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text(
                        AppStrings.tr('settings_view_all_plans', currentLang),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // Section: App Language (3 Languages: UZ, RU, EN)
          Text(
            AppStrings.tr('settings_language', currentLang).toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
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
                RadioListTile<AppLanguage>(
                  title: const Text('🇺🇿 O\'zbekcha'),
                  subtitle: Text(AppStrings.tr('lang_uz_desc', currentLang)),
                  value: AppLanguage.uz,
                  groupValue: currentLang,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (val != null) {
                      UiSoundFeedback.playItemClick();
                      ref.read(appLanguageProvider.notifier).setLanguage(val);
                    }
                  },
                ),
                const Divider(height: 1),
                RadioListTile<AppLanguage>(
                  title: const Text('🇷🇺 Русский'),
                  subtitle: Text(AppStrings.tr('lang_ru_desc', currentLang)),
                  value: AppLanguage.ru,
                  groupValue: currentLang,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (val != null) {
                      UiSoundFeedback.playItemClick();
                      ref.read(appLanguageProvider.notifier).setLanguage(val);
                    }
                  },
                ),
                const Divider(height: 1),
                RadioListTile<AppLanguage>(
                  title: const Text('🇬🇧 English'),
                  subtitle: Text(AppStrings.tr('lang_en_desc', currentLang)),
                  value: AppLanguage.en,
                  groupValue: currentLang,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (val != null) {
                      UiSoundFeedback.playItemClick();
                      ref.read(appLanguageProvider.notifier).setLanguage(val);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Section: Appearance
          Text(
            AppStrings.tr('settings_appearance_section', currentLang),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
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
                RadioListTile<ThemeMode>(
                  title: Text(AppStrings.tr('settings_theme_dark_title', currentLang)),
                  subtitle: Text(
                    AppStrings.tr('settings_theme_dark_desc', currentLang),
                  ),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (val != null) {
                      UiSoundFeedback.playItemClick();
                      ref.read(themeModeProvider.notifier).setThemeMode(val);
                    }
                  },
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  title: Text(AppStrings.tr('settings_theme_light_title', currentLang)),
                  subtitle: Text(
                    AppStrings.tr('settings_theme_light_desc', currentLang),
                  ),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (val != null) {
                      UiSoundFeedback.playItemClick();
                      ref.read(themeModeProvider.notifier).setThemeMode(val);
                    }
                  },
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  title: Text(AppStrings.tr('settings_theme_system_title', currentLang)),
                  subtitle: Text(
                    AppStrings.tr('settings_theme_system_desc', currentLang),
                  ),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (val != null) {
                      UiSoundFeedback.playItemClick();
                      ref.read(themeModeProvider.notifier).setThemeMode(val);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Section: Server API Base URL
          Text(
            AppStrings.tr('settings_network_section', currentLang),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'API Base URL',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Emulator: http://10.0.2.2:8080\nWeb/Desktop: http://localhost:8080\nServer: https://api.cognidoc.ai',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.link_rounded, size: 20),
                    hintText: 'http://localhost:8080',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('localhost:8080', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        _urlController.text = 'http://localhost:8080';
                        ref.read(apiBaseUrlProvider.notifier).setBaseUrl('http://localhost:8080');
                      },
                    ),
                    ActionChip(
                      label: const Text('192.168.199.192:8080', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        _urlController.text = 'http://192.168.199.192:8080';
                        ref.read(apiBaseUrlProvider.notifier).setBaseUrl('http://192.168.199.192:8080');
                      },
                    ),
                    ActionChip(
                      label: const Text('10.0.2.2:8080', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        _urlController.text = 'http://10.0.2.2:8080';
                        ref.read(apiBaseUrlProvider.notifier).setBaseUrl('http://10.0.2.2:8080');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await ref
                            .read(apiBaseUrlProvider.notifier)
                            .resetToDefault();
                        _urlController.text = ref.read(apiBaseUrlProvider);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              AppStrings.tr('settings_api_reset', currentLang),
                            ),
                          ),
                        );
                      },
                      child: Text(AppStrings.tr('settings_default_btn', currentLang)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await ref
                              .read(apiBaseUrlProvider.notifier)
                              .setBaseUrl(_urlController.text);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                AppStrings.tr('settings_api_saved', currentLang),
                              ),
                            ),
                          );
                        },
                        child: Text(AppStrings.tr('save', currentLang)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Section: Account & Session
          Text(
            AppStrings.tr('settings_account_section', currentLang),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Text(
                        authState.user?.fullName.isNotEmpty == true
                            ? authState.user!.fullName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authState.user?.fullName.isNotEmpty == true
                                ? authState.user!.fullName
                                : AppStrings.tr('profile_default_user', currentLang),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            authState.user?.email ?? '',
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
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _showLogoutDialog(currentLang),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(AppStrings.tr('logout', currentLang)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
