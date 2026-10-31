import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = authState.user?.fullName.split(' ').first ?? 'Do\'stim';

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
            // Pinned Top App Bar: Keeps header visible and prevents status bar / battery / notch clipping
            SliverAppBar(
              pinned: true,
              floating: false,
              elevation: 0,
              backgroundColor: isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
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
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'The Go-getters AI',
                    style: TextStyle(
                      fontSize: 17,
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
                  label: 'Foydalanuvchi profili',
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

            // Hero Bubble "Salom, [Name] / Suhbatni boshlash"
            SliverToBoxAdapter(
              child: HeroChatBubble(
                userName: userName,
                onTap: widget.onOpenChat,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // Product Hack #1: 5 soniyalik Aha-Moment (Tayyor namunalar bilan sinash)
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
                          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Tayyor namuna bilan sinab ko\'ring:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
                              avatar: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 16),
                              label: const Text('📄 Mehnat kodeksi.pdf'),
                              backgroundColor: AppColors.primary.withOpacity(0.08),
                              side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                              onPressed: () => widget.onStartWithCategory(
                                'O\'zbekiston Respublikasi Mehnat kodeksiga asosan ish vaqti, sinov muddati va xodimning asosiy kafolatlari bo\'yicha aniq moddalarni ko\'rsatib bering.',
                                'Mehnat Kodeksi',
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.gavel, color: Colors.amber, size: 16),
                              label: const Text('⚖️ Ijara shartnomasi (Xavflar)'),
                              backgroundColor: AppColors.primary.withOpacity(0.08),
                              side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                              onPressed: () => widget.onStartWithCategory(
                                'Ijara yoki xizmat ko\'rsatish shartnomasida e\'tibor berish kerak bo\'lgan 5 ta eng xavfli nuqta va yashirin jarimalarni tahlil qiling.',
                                'Shartnoma Tahlili',
                              ),
                            ),
                            const SizedBox(width: 8),
                            ActionChip(
                              avatar: const Icon(Icons.quiz, color: Colors.teal, size: 16),
                              label: const Text('🎓 Kitobdan Test (Quiz)'),
                              backgroundColor: AppColors.primary.withOpacity(0.08),
                              side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                              onPressed: () => widget.onStartWithCategory(
                                'Iltimos, ushbu mavzu yoki kitob bo\'yicha to\'rtta variantli 10 ta qiziqarli test savolini tuzib bering.',
                                'Test Generator',
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

            // Smart AI Quick Tools Feature Section
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
                              'Tezkor AI Asboblar',
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
                          '1 marta bosish',
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
                            icon: Icons.gavel_rounded,
                            title: 'Shartnoma Rentgeni',
                            subtitle: 'Xavf va jarimalarni tahlil qilish',
                            color: const Color(0xFFF59E0B),
                            isDark: isDark,
                            onTap: () => widget.onStartWithCategory(
                              'Ushbu shartnoma matnini chuqur tahlil qilib, yashirin xavflar, muddatlar va bir tomonlama jarimalarni ko\'rsatib bering:\n\n',
                              'Shartnoma',
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildQuickToolCard(
                            icon: Icons.quiz_outlined,
                            title: 'PDF -> Test (Quiz)',
                            subtitle: 'Ma\'ruzadan 20 ta test tuzish',
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                            onTap: () => widget.onStartWithCategory(
                              'Iltimos, ushbu ma\'ruza yoki kitob bo\'limi asosida 4 ta variantli 15 ta test savoli tuzib bering:\n\n',
                              'Testlar',
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildQuickToolCard(
                            icon: Icons.summarize_outlined,
                            title: 'Tezkor Xulosa',
                            subtitle: 'Katta PDF-ni 1 daqiqada tushunish',
                            color: const Color(0xFF3B82F6),
                            isDark: isDark,
                            onTap: () => widget.onStartWithCategory(
                              'Ushbu uzun matn yoki hisobotning eng muhim 5 ta asosiy xulosasini chiqarib bering:\n\n',
                              'Xulosa',
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildQuickToolCard(
                            icon: Icons.edit_note_rounded,
                            title: 'Matn Tahriri',
                            subtitle: 'Imlo va rasmiy uslub',
                            color: const Color(0xFFEC4899),
                            isDark: isDark,
                            onTap: () => widget.onStartWithCategory(
                              'Iltimos, quyidagi matnimni imlo va uslubiy jihatdan tekshirib, yanada ravon va professional qilib bering:\n\n',
                              'Tahrir',
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildQuickToolCard(
                            icon: Icons.slideshow_rounded,
                            title: 'Slayd & Taqdimot',
                            subtitle: '10 ta slayd rejasini tuzish',
                            color: const Color(0xFF8B5CF6),
                            isDark: isDark,
                            onTap: () => widget.onStartWithCategory(
                              'Ushbu mavzu yoki hujjat asosida taqdimot uchun 10 ta slayd rejasini tayyorlab bering:\n\n',
                              'Taqdimot',
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

            // Document AI Tools Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hujjat & PDF AI Asboblar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      '8 ta vosita',
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

            // 2-Column Category Grid
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
                      widget.onStartWithCategory(cat.starterPrompt, cat.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
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
                            cat.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat.description,
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
