import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_sound_feedback.dart';
import '../providers/onboarding_provider.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onFinished;
  final bool isStandalone; // True when opened from Settings/Profile

  const LanguageSelectionScreen({
    super.key,
    this.onFinished,
    this.isStandalone = false,
  });

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  late AppLanguage _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = ref.read(appLanguageProvider);
  }

  Future<void> _handleConfirm() async {
    UiSoundFeedback.playActionClick();
    // 1. Set language globally in Riverpod & storage & backend
    await ref
        .read(appLanguageProvider.notifier)
        .setLanguage(_selectedLanguage);

    // 2. Mark onboarding as completed if this was part of first launch
    if (!widget.isStandalone) {
      await ref.read(onboardingProvider.notifier).completeOnboarding();
    }

    // 3. Callback or pop
    if (widget.onFinished != null) {
      widget.onFinished!();
    } else {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      appBar: widget.isStandalone
          ? AppBar(
              title: Text(
                AppStrings.tr('settings_language', _selectedLanguage),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isStandalone) ...[
                const SizedBox(height: 16),
                // Header Brand Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.25),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.translate_rounded,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Title
              Text(
                AppStrings.tr('lang_screen_title', _selectedLanguage),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                AppStrings.tr('lang_screen_subtitle', _selectedLanguage),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // 3 Language Cards
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildLanguageCard(
                      lang: AppLanguage.uz,
                      titleKey: 'lang_uz_title',
                      descKey: 'lang_uz_desc',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildLanguageCard(
                      lang: AppLanguage.en,
                      titleKey: 'lang_en_title',
                      descKey: 'lang_en_desc',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildLanguageCard(
                      lang: AppLanguage.ru,
                      titleKey: 'lang_ru_title',
                      descKey: 'lang_ru_desc',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Confirm CTA Button
              ElevatedButton(
                onPressed: _handleConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.tr('lang_btn_confirm', _selectedLanguage),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_rounded, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard({
    required AppLanguage lang,
    required String titleKey,
    required String descKey,
    required bool isDark,
  }) {
    final isSelected = _selectedLanguage == lang;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          UiSoundFeedback.playItemClick();
          setState(() {
            _selectedLanguage = lang;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(isDark ? 0.22 : 0.08)
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Flag emoji badge
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E252E) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  lang.flag,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: 16),

              // Title & Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.tr(titleKey, _selectedLanguage),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.tr(descKey, _selectedLanguage),
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

              // Radio Checkmark
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
