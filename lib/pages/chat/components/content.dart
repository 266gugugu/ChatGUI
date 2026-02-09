import 'package:chat_gui/pages/chat/chat_controller.dart';
import 'package:chat_gui/pages/chat/components/message_bubble.dart';
import 'package:chat_gui/utils/cxxxr.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

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
                    
                    return AutoScrollTag(
                      key: ValueKey(index),
                      controller: controller.scrollController,
                      index: index,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.05),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                            child: FadeTransition(opacity: anim, child: child),
                          );
                        },
                        child: MessageBubble(
                          message: message,
                          tabletWidth: tabletWidth,
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
}
