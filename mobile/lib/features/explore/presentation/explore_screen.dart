import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_sound_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/presentation/widgets/hero_chat_bubble.dart';
import '../../conversations/models/conversation.dart';
import '../../conversations/presentation/conversations_drawer.dart';
import '../../profile/presentation/profile_screen.dart';
import '../models/explore_category.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final Function(Conversation) onOpenConversation;
  final Function(String starterText, String category) onStartWithCategory;
  final VoidCallback onOpenChat;

  const ExploreScreen({
    super.key,
    required this.onOpenConversation,
    required this.onStartWithCategory,
    required this.onOpenChat,
  });

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentLang = ref.watch(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = authState.user?.fullName.split(' ').first ?? 'Talaba';

    return Scaffold(
      key: _scaffoldKey,
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: 80.0,
      onDrawerChanged: (isOpen) {
        if (isOpen) {
          UiSoundFeedback.playDrawerOpen();
        } else {
          UiSoundFeedback.playDrawerClose();
        }
      },
      drawer: ConversationsDrawer(
        onSelectConversation: widget.onOpenConversation,
        onNewChat: widget.onOpenChat,
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Pinned Top App Bar: Keeps header visible and prevents status bar clipping
            SliverAppBar(
              pinned: true,
              floating: false,
              elevation: 0,
              backgroundColor:
                  isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
              automaticallyImplyLeading: false,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'EduAI',
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
              actions: [
                Semantics(
                  label: 'Menyu',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.menu_rounded, size: 22),
                    tooltip: 'Menyu',
                    onPressed: () {
                      UiSoundFeedback.playDrawerOpen();
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Semantics(
                  label: 'Profil',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withOpacity(0.18),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Hero Bubble
            SliverToBoxAdapter(
              child: HeroChatBubble(
                userName: userName,
                onTap: widget.onOpenChat,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // Product Hack: 5-Second Aha-Moment (Education Sample Chips)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            AppStrings.tr('ready_sample', currentLang),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.menu_book_rounded,
                                  color: Colors.blueAccent, size: 16),
                              label: Text(
                                AppStrings.tr('sample_physics', currentLang),
                              ),
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.08),
                              side: BorderSide(
                                  color: AppColors.primary.withOpacity(0.2)),
                              onPressed: () => widget.onStartWithCategory(
                                AppStrings.tr(
                                    'sample_physics_prompt', currentLang),
                                'Darslik Tahlili',
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.quiz_rounded,
                                  color: Colors.purpleAccent, size: 16),
                              label: Text(
                                AppStrings.tr('sample_quiz', currentLang),
                              ),
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.08),
                              side: BorderSide(
                                  color: AppColors.primary.withOpacity(0.2)),
                              onPressed: () => widget.onStartWithCategory(
                                AppStrings.tr(
                                    'sample_quiz_prompt', currentLang),
                                'Test Generator',
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.note_alt_rounded,
                                  color: Color(0xFF10B981), size: 16),
                              label: Text(
                                AppStrings.tr('sample_summary', currentLang),
                              ),
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.08),
                              side: BorderSide(
                                  color: AppColors.primary.withOpacity(0.2)),
                              onPressed: () => widget.onStartWithCategory(
                                AppStrings.tr(
                                    'sample_summary_prompt', currentLang),
                                'Konspekt',
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.translate_rounded,
                                  color: Colors.pinkAccent, size: 16),
                              label: Text(
                                AppStrings.tr('sample_language', currentLang),
                              ),
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.08),
                              side: BorderSide(
                                  color: AppColors.primary.withOpacity(0.2)),
                              onPressed: () => widget.onStartWithCategory(
                                AppStrings.tr(
                                    'sample_language_prompt', currentLang),
                                'Til O\'rganish',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Smart Education AI Quick Tools Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.tr('education_tools', currentLang),
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
                        Text(
                          AppStrings.tr('all_count', currentLang),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildQuickToolCard(
                            icon: Icons.menu_book_rounded,
                            title: ExploreCategory.categories[0]
                                .getTitle(currentLang),
                            subtitle: ExploreCategory.categories[0]
                                .getDescription(currentLang),
                            color: const Color(0xFF3B82F6),
                            isDark: isDark,
                            onTap: () => widget.onStartWithCategory(
                              ExploreCategory.categories[0]
                                  .getStarterPrompt(currentLang),
                              ExploreCategory.categories[0].id,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildQuickToolCard(
                            icon: Icons.quiz_rounded,
                            title: ExploreCategory.categories[2]
                                .getTitle(currentLang),
                            subtitle: ExploreCategory.categories[2]
                                .getDescription(currentLang),
                            color: const Color(0xFF8B5CF6),
                            isDark: isDark,
                            onTap: () => widget.onStartWithCategory(
                              ExploreCategory.categories[2]
                                  .getStarterPrompt(currentLang),
                              ExploreCategory.categories[2].id,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildQuickToolCard(
                            icon: Icons.note_alt_rounded,
                            title: ExploreCategory.categories[1]
                                .getTitle(currentLang),
                            subtitle: ExploreCategory.categories[1]
                                .getDescription(currentLang),
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                            onTap: () => widget.onStartWithCategory(
                              ExploreCategory.categories[1]
                                  .getStarterPrompt(currentLang),
                              ExploreCategory.categories[1].id,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildQuickToolCard(
                            icon: Icons.calculate_rounded,
                            title: ExploreCategory.categories[4]
                                .getTitle(currentLang),
                            subtitle: ExploreCategory.categories[4]
                                .getDescription(currentLang),
                            color: const Color(0xFFF59E0B),
                            isDark: isDark,
                            onTap: () => widget.onStartWithCategory(
                              ExploreCategory.categories[4]
                                  .getStarterPrompt(currentLang),
                              ExploreCategory.categories[4].id,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Education Tools Grid Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.tr('education_tools', currentLang),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      AppStrings.tr('all_count', currentLang),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // 2-Column Education Tools Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final cat = ExploreCategory.categories[index];

                  return GestureDetector(
                    onTap: () {
                      UiSoundFeedback.playItemClick();
                      widget.onStartWithCategory(
                        cat.getStarterPrompt(currentLang),
                        cat.id,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: cat.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(cat.icon, color: cat.color, size: 20),
                          ),
                          const Spacer(),
                          Text(
                            cat.getTitle(currentLang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat.getDescription(currentLang),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: ExploreCategory.categories.length),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        UiSoundFeedback.playItemClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 175,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
