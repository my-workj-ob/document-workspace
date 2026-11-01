import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/providers/onboarding_provider.dart';
import 'home_shell.dart';

class AiChatApp extends ConsumerWidget {
  const AiChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);
    final onboardingState = ref.watch(onboardingProvider);

    return MaterialApp(
      title: 'EduAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: (authState.isLoading || !onboardingState.isLoaded)
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : !onboardingState.hasCompleted
              ? OnboardingScreen(
                  onFinished: () {
                    ref.read(onboardingProvider.notifier).completeOnboarding();
                  },
                )
              : authState.isAuthenticated
                  ? const HomeShell()
                  : const LoginScreen(),
    );
  }
}
