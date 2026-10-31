import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_presenter.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_sound_feedback.dart';
import '../../conversations/presentation/conversations_drawer.dart';
import '../../conversations/providers/conversations_provider.dart';
import '../models/chat_state.dart';
import '../providers/chat_provider.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToExplore;

  const ChatScreen({super.key, this.onBackToExplore});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  // Scroll State Machine variables
  bool _isNearBottom = true;
  bool _isUserScrolling = false;
  bool _hasNewMessages = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool smooth = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (smooth) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _handleScrollToBottomTap() {
    _scrollToBottom(smooth: true);
    setState(() {
      _isNearBottom = true;
      _hasNewMessages = false;
    });
  }

  void _showRenameDialog(
    BuildContext context,
    String currentTitle,
    String convId,
    AppLanguage lang,
  ) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.tr('chat_rename_dialog_title', lang)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppStrings.tr('chat_rename_hint', lang),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.tr('cancel', lang)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                await ref
                    .read(conversationsProvider.notifier)
                    .updateTitle(convId, newTitle);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(AppStrings.tr('save', lang)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(appLanguageProvider);
    final chatState = ref.watch(chatProvider);
    final conversationsAsync = ref.watch(conversationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine current conversation title
    String title = AppStrings.tr('chat_new_dialog', currentLang);
    if (chatState.conversationId != null) {
      final convList = conversationsAsync.value ?? [];
      final match = convList.where((c) => c.id == chatState.conversationId);
      if (match.isNotEmpty) {
        title = match.first.title;
      }
    }

    // Scroll state machine listener
    ref.listen(chatProvider, (previous, next) {
      final bool hasNewMessage =
          previous?.messages.length != next.messages.length;
      final bool hasDelta = next.isGenerating &&
          previous?.messages.lastOrNull?.content !=
              next.messages.lastOrNull?.content;

      if (hasNewMessage || hasDelta) {
        if (_isNearBottom && !_isUserScrolling) {
          final bool isRapidStream =
              next.isGenerating && hasDelta && !hasNewMessage;
          _scrollToBottom(smooth: !isRapidStream);
        } else {
          if (!_hasNewMessages) {
            setState(() {
              _hasNewMessages = true;
            });
          }
        }
      }
    });

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
        onSelectConversation: (conv) {
          ref.read(selectedConversationIdProvider.notifier).state = conv.id;
          ref.read(chatProvider.notifier).loadConversation(conv.id);
        },
        onNewChat: () {
          ref.read(selectedConversationIdProvider.notifier).state = null;
          ref.read(chatProvider.notifier).startNewChat();
        },
      ),
      appBar: AppBar(
        leading: widget.onBackToExplore != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: widget.onBackToExplore,
              )
            : IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () {
                  UiSoundFeedback.playDrawerOpen();
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
        title: GestureDetector(
          onTap: () {
            if (chatState.conversationId != null) {
              _showRenameDialog(context, title, chatState.conversationId!, currentLang);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (chatState.conversationId != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ],
            ],
          ),
        ),
        actions: [
          // New chat button
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: AppStrings.tr('chat_new_dialog', currentLang),
            onPressed: () {
              ref.read(selectedConversationIdProvider.notifier).state = null;
              ref.read(chatProvider.notifier).startNewChat();
            },
          ),
          // History drawer trigger
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: AppStrings.tr('chat_history_tooltip', currentLang),
            onPressed: () {
              UiSoundFeedback.playDrawerOpen();
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          // Chat Options Menu (Copy, Clear)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: AppStrings.tr('chat_actions_tooltip', currentLang),
            onSelected: (value) {
              if (value == 'copy') {
                _copyFullConversation(context, chatState, currentLang);
              } else if (value == 'clear') {
                ref.read(selectedConversationIdProvider.notifier).state = null;
                ref.read(chatProvider.notifier).startNewChat();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    const Icon(Icons.copy_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(AppStrings.tr('chat_copy_full', currentLang)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(AppStrings.tr('chat_clear_start', currentLang)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Inline Error Notification (Centralized ErrorPresenter)
          InlineErrorBanner(
            error: chatState.topError ??
                (chatState.errorMessage != null
                    ? PresentableError.fromRaw(chatState.errorMessage!)
                    : null),
            onDismiss: () =>
                ref.read(chatProvider.notifier).dismissTopError(),
            onAction: () {
              final err = chatState.topError;
              if (err?.actionType == ErrorActionType.retry) {
                final lastAsst = chatState.messages.reversed
                    .where((m) => m.isAssistant)
                    .firstOrNull;
                if (lastAsst != null) {
                  ref
                      .read(chatProvider.notifier)
                      .retryAssistantResponse(lastAsst.id);
                }
              }
              ref.read(chatProvider.notifier).dismissTopError();
            },
          ),

          // Message list area with precision scroll and floating button
          Expanded(
            child: chatState.isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : chatState.messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppStrings.tr('chat_how_can_help', currentLang),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.tr('chat_help_desc', currentLang),
                            textAlign: TextAlign.center,
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
                  )
                : Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollStartNotification) {
                            if (notification.dragDetails != null) {
                              _isUserScrolling = true;
                            }
                          } else if (notification is ScrollEndNotification) {
                            _isUserScrolling = false;
                          } else if (notification is ScrollUpdateNotification) {
                            if (_scrollController.hasClients) {
                              final maxExtent =
                                  _scrollController.position.maxScrollExtent;
                              final offset = _scrollController.offset;
                              final isNear = (maxExtent - offset) <= 100;
                              if (isNear != _isNearBottom) {
                                setState(() {
                                  _isNearBottom = isNear;
                                  if (isNear) {
                                    _hasNewMessages = false;
                                  }
                                });
                              }
                            }
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          cacheExtent: 500,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: chatState.messages.length,
                          itemBuilder: (context, index) {
                            final msg = chatState.messages[index];
                            return RepaintBoundary(
                              child: MessageBubble(
                                message: msg,
                                isEditing: chatState.activeEditingMessageId == msg.id,
                                isGenerating: chatState.isGenerating,
                                onStartEdit: () => ref
                                    .read(chatProvider.notifier)
                                    .startEditingMessage(msg.id),
                                onCancelEdit: () => ref
                                    .read(chatProvider.notifier)
                                    .cancelEditingMessage(),
                                onSaveEdit: (newText) => ref
                                    .read(chatProvider.notifier)
                                    .saveAndResubmitEditedMessage(msg.id, newText),
                                onRetry: msg.isAssistant
                                    ? () => ref
                                        .read(chatProvider.notifier)
                                        .retryAssistantResponse(msg.id)
                                    : null,
                                onReport: msg.isAssistant
                                    ? (reason, comment) => ref
                                        .read(chatProvider.notifier)
                                        .reportMessage(
                                          messageId: msg.id,
                                          reason: reason,
                                          comment: comment,
                                        )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),

                      // Floating "Pastga tushish" (Scroll to bottom) button with unread indicator
                      Positioned(
                        right: 16,
                        bottom: 12,
                        child: AnimatedScale(
                          scale: (!_isNearBottom) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: AnimatedOpacity(
                            opacity: (!_isNearBottom) ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 150),
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(24),
                              color: isDark
                                  ? const Color(0xFF1E2530)
                                  : Colors.white,
                              child: InkWell(
                                onTap: _handleScrollToBottomTap,
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: _hasNewMessages
                                          ? AppColors.primary
                                          : (isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder),
                                      width: _hasNewMessages ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_hasNewMessages) ...[
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Text(
                                          AppStrings.tr('chat_new_messages_badge', currentLang),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // Message Composer anchored at bottom
          MessageComposer(
            isGenerating: chatState.isGenerating,
            onSend: (text, {fileIds}) {
              ref
                  .read(chatProvider.notifier)
                  .sendMessage(text, fileIds: fileIds);
              _scrollToBottom(smooth: true);
            },
            onStop: () {
              ref.read(chatProvider.notifier).stopGeneration();
            },
          ),
        ],
      ),
    );
  }

  void _copyFullConversation(BuildContext context, ChatState chatState, AppLanguage lang) {
    if (chatState.messages.isEmpty) {
      return;
    }

    final sb = StringBuffer();
    for (final m in chatState.messages) {
      final role = m.isUser ? 'User' : 'Cognidoc AI';
      sb.writeln('[$role]:\n${m.content}\n');
    }

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.tr('chat_copy_full_done', lang)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
