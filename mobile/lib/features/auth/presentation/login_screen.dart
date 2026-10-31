import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_sound_feedback.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    UiSoundFeedback.playActionClick();

    await ref
        .read(authProvider.notifier)
        .login(_emailController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentLang = ref.watch(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Bar: Language Switcher
                    Align(
                      alignment: Alignment.topRight,
                      child: PopupMenuButton<AppLanguage>(
                        initialValue: currentLang,
                        tooltip: AppStrings.tr('settings_language', currentLang),
                        onSelected: (lang) {
                          UiSoundFeedback.playItemClick();
                          ref
                              .read(appLanguageProvider.notifier)
                              .setLanguage(lang);
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(currentLang.flag,
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                currentLang.code.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: AppLanguage.uz,
                            child: Row(
                              children: [
                                Text('🇺🇿', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 8),
                                Text('O\'zbekcha'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: AppLanguage.en,
                            child: Row(
                              children: [
                                Text('🇬🇧', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 8),
                                Text('English'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: AppLanguage.ru,
                            child: Row(
                              children: [
                                Text('🇷🇺', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 8),
                                Text('Русский'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Brand Logo & Title
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cognidoc AI',
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
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.tr('auth_login_subtitle', currentLang),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error Banner
                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Email Field
                    Text(
                      AppStrings.tr('auth_email_label', currentLang),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: AppStrings.tr('auth_email_hint', currentLang),
                        prefixIcon: const Icon(
                          Icons.alternate_email_rounded,
                          size: 20,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return AppStrings.tr(
                              'auth_val_email_empty', currentLang);
                        }
                        if (!val.contains('@')) {
                          return AppStrings.tr(
                              'auth_val_email_invalid', currentLang);
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Password Field
                    Text(
                      AppStrings.tr('auth_password_label', currentLang),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return AppStrings.tr(
                              'auth_password_label', currentLang);
                        }
                        if (val.length < 8) {
                          return AppStrings.tr(
                              'auth_val_pwd_short', currentLang);
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 26),

                    // Login Button
                    ElevatedButton(
                      onPressed: authState.isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              AppStrings.tr('auth_login_btn', currentLang),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.tr('auth_no_account', currentLang),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            AppStrings.tr('auth_sign_up_link', currentLang),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
