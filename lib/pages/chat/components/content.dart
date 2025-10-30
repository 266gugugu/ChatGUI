import 'package:chat_gui/pages/chat/controller.dart';
import 'package:chat_gui/utils/cxxxr.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:url_launcher/url_launcher_string.dart';

class _TypingIndicator extends StatefulWidget {
  final int delay;
  const _TypingIndicator({this.delay = 0});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withOpacity(0.5 + _controller.value * 0.5),
          ),
        );
      },
    );
  }
}

class ChatContent extends GetView<ChatScreenController> {
  final int tabletWidth;
  const ChatContent({super.key, required this.tabletWidth});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
        child: Align(
        alignment: Alignment.topCenter,
        child: SelectionArea(
          child: GetBuilder<ChatScreenController>(
            builder: (controller) {
              print('渲染消息列表，消息数量: ${controller.messages.length}');
              return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16, top: 16),
                  controller: controller.scrollController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: controller.messages.length + (controller.isTyping.value ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 显示"正在输入"状态
                    if (index == controller.messages.length && controller.isTyping.value) {
                      return AutoScrollTag(
                        key: const ValueKey('typing'),
                        controller: controller.scrollController,
                        index: index,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: tabletWidth > 0
                                ? BoxConstraints(maxWidth: tabletWidth.toDouble() * 0.75)
                                : BoxConstraints(maxWidth: 500),
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(4),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Text('AI正在思考...', style: TextStyle(color: Colors.grey)),
                                  SizedBox(width: 8),
                                  SizedBox(
                                    width: 40,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _TypingIndicator(),
                                        _TypingIndicator(delay: 100),
                                        _TypingIndicator(delay: 200),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    
                    final message = controller.messages[index];
                    final isUser = message.role == 'user';
                    print('渲染消息 $index: 角色=$isUser, 内容="${message.text}"');
                    
                    return AutoScrollTag(
                      key: ValueKey(index),
                      controller: controller.scrollController,
                      index: index,
                      child: Align(
                        alignment: isUser ? Alignment.topRight : Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints:
                              tabletWidth > 0
                                  ? BoxConstraints(maxWidth: tabletWidth.toDouble() * 0.75)
                                  : BoxConstraints(maxWidth: 500),
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.blue : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: isUser ? Radius.circular(16) : Radius.circular(4),
                                bottomRight: isUser ? Radius.circular(4) : Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                SelectableText.rich(
                                  TextSpan(
                                    text: message.text,
                                    style: TextStyle(
                                      color: isUser ? Colors.white : colorScheme.onSurface,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatTime(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isUser ? Colors.white.withOpacity(0.7) : colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 16),
              );
            },
          ),
        ),
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    }
  }
}

class ChatContentUserBubble extends GetView<ChatScreenController> {
  const ChatContentUserBubble(this.constraints, {super.key});

  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 12),
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.75),
          decoration: BoxDecoration(
            color: C.g1.r,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            "User Message",
            style: TextStyle(color: C.black.r, fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}

class ChatContentAssistantBubble extends GetView<ChatScreenController> {
  const ChatContentAssistantBubble(this.constraints, this.text, {super.key});

  final BoxConstraints constraints;
  final String text;

  @override
  Widget build(BuildContext context) {
    print("Building Assistant Bubble");
    return SelectionArea(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12),
        // child: MarkdownRenderer(text),
      ),
    );
  }
}

class ChatContentActionButtons extends GetView<ChatScreenController> {
  const ChatContentActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
    );
  }
}