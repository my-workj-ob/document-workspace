import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/ui_sound_feedback.dart';

class HeroChatBubble extends ConsumerWidget {
  final String userName;
  final VoidCallback onTap;

  const HeroChatBubble({
    super.key,
    required this.userName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLang = ref.watch(appLanguageProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            UiSoundFeedback.playItemClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        AppColors.darkCard,
                        const Color(0xFF1E293B),
                      ]
                    : [
                        Colors.white,
                        const Color(0xFFF8FAFC),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(isDark ? 0.3 : 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(isDark ? 0.12 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Greeting and AI Sparkle badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(userName, currentLang),
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getTitle(currentLang),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Interactive mock search/input bar prompting action
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _getPlaceholder(currentLang),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Feature tags (PDF, Summary, Q&A)
                Row(
                  children: [
                    _buildFeatureTag(
                      icon: Icons.picture_as_pdf_rounded,
                      label: _getPdfTag(currentLang),
                      color: const Color(0xFFEF4444),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFeatureTag(
                      icon: Icons.summarize_rounded,
                      label: _getSummaryTag(currentLang),
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFeatureTag(
                      icon: Icons.psychology_rounded,
                      label: _getAiTag(currentLang),
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTag({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting(String userName, AppLanguage lang) {
    switch (lang) {
      case AppLanguage.ru:
        return 'Привет, $userName 👋';
      case AppLanguage.uz:
        return 'Salom, $userName 👋';
      case AppLanguage.en:
      default:
        return 'Hello, $userName 👋';
    }
  }

  String _getTitle(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.ru:
        return 'С чего начнем сегодня?';
      case AppLanguage.uz:
        return 'Nimadan boshlaymiz?';
      case AppLanguage.en:
      default:
        return 'What are we exploring today?';
    }
  }

  String _getPlaceholder(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.ru:
        return 'Задайте вопрос или выберите инструмент...';
      case AppLanguage.uz:
        return 'Savol bering yoki asbob tanlang...';
      case AppLanguage.en:
      default:
        return 'Ask a question or select a tool...';
    }
  }

  String _getPdfTag(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.ru:
        return 'PDF Анализ';
      case AppLanguage.uz:
        return 'PDF Tahlil';
      case AppLanguage.en:
      default:
        return 'PDF Analysis';
    }
  }

  String _getSummaryTag(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.ru:
        return 'Конспект';
      case AppLanguage.uz:
        return 'Konspekt';
      case AppLanguage.en:
      default:
        return 'Summary';
    }
  }

  String _getAiTag(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.ru:
        return 'AI Suhbat';
      case AppLanguage.uz:
        return 'AI Suhbat';
      case AppLanguage.en:
      default:
        return 'AI Chat';
    }
  }
}
