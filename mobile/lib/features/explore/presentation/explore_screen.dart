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
}
