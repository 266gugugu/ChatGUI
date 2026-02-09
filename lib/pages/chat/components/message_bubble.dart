import 'package:chat_gui/models/chat_message.dart';
import 'package:chat_gui/pages/chat/components/content.dart'; // For C class if needed, or better import cxxxr.dart
import 'package:chat_gui/utils/cxxxr.dart';
import 'package:chat_gui/utils/date_formatter.dart';
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final int tabletWidth;

  const MessageBubble({
    super.key,
    required this.message,
    this.tabletWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final colorScheme = Theme.of(context).colorScheme;
    final displayText = _sanitizeText(message.text);

    return Align(
      alignment: isUser ? Alignment.topRight : Alignment.topLeft,
      child: ConstrainedBox(
        constraints: tabletWidth > 0
            ? BoxConstraints(maxWidth: tabletWidth.toDouble() * 0.75)
            : const BoxConstraints(maxWidth: 500),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUser ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              SelectableText.rich(
                _buildRichSpan(
                  displayText,
                  TextStyle(
                    color: isUser ? Colors.white : colorScheme.onSurface,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormatter.formatRelativeTime(message.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: isUser
                      ? Colors.white.withOpacity(0.7)
                      : colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods moved from content.dart

  String _sanitizeText(String raw) {
    if (raw.isEmpty) return raw;
    final lines = raw.split('\n');
    final bullet = RegExp(r'^\s*[\*\-]\s+');
    final cleaned = lines.map((l) {
      var s = l;
      if (bullet.hasMatch(s)) {
        s = s.replaceFirst(bullet, '• ');
      }
      return s;
    }).join('\n');
    return cleaned;
  }

  TextSpan _buildRichSpan(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final reg = RegExp(r'\*\*(.+?)\*\*');
    int index = 0;
    for (final m in reg.allMatches(text)) {
      if (m.start > index) {
        spans.add(TextSpan(text: text.substring(index, m.start), style: baseStyle));
      }
      final boldText = m.group(1) ?? '';
      spans.add(
          TextSpan(text: boldText, style: baseStyle.copyWith(fontWeight: FontWeight.w600)));
      index = m.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: baseStyle));
    }
    return TextSpan(children: spans, style: baseStyle);
  }
}
