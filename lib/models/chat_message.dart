/// Chat message model representing a single message in a conversation
import '../utils/date_formatter.dart';

class ChatMessage {
  String text;
  final String role;
  final DateTime timestamp;
  final String? id;

  ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
    this.id,
  });

  /// Create a ChatMessage from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['content']?.toString() ?? json['text']?.toString() ?? '',
      role: json['role']?.toString() ?? 'assistant',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      id: json['id']?.toString(),
    );
  }

  /// Convert ChatMessage to JSON
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'content': text, // Support both field names
      'role': role,
      'timestamp': timestamp.toIso8601String(),
      if (id != null) 'id': id,
    };
  }

  /// Copy with method for immutability where needed
  ChatMessage copyWith({
    String? text,
    String? role,
    DateTime? timestamp,
    String? id,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      id: id ?? this.id,
    );
  }
}

/// Chat session model representing a group of related messages
class ChatSession {
  final String title;
  final List<ChatMessage> messages;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? id;

  ChatSession({
    required this.title,
    required this.messages,
    this.createdAt,
    this.updatedAt,
    this.id,
  });

  /// Create a ChatSession from a list of messages with auto-generated title
  factory ChatSession.fromMessages(List<ChatMessage> messages) {
    String title = _generateTitle(messages);
    return ChatSession(
      title: title,
      messages: List<ChatMessage>.from(messages),
      createdAt: messages.isNotEmpty ? messages.first.timestamp : DateTime.now(),
      updatedAt: messages.isNotEmpty ? messages.last.timestamp : DateTime.now(),
    );
  }

  /// Generate session title from messages
  static String _generateTitle(List<ChatMessage> messages) {
    // Try to find first user message
    for (final m in messages) {
      if (m.role == 'user' && m.text.trim().isNotEmpty) {
        return _firstSentence(m.text.trim());
      }
    }
    
    // Fallback to first message
    if (messages.isNotEmpty && messages.first.text.trim().isNotEmpty) {
      return _firstSentence(messages.first.text.trim());
    }
    
    // Fallback to date-based title
    final timestamp = messages.isNotEmpty ? messages.first.timestamp : DateTime.now();
    return '新对话 ${DateFormatter.formatDateTime(timestamp)}';
  }

  /// Extract first sentence from text
  static String _firstSentence(String text) {
    if (text.isEmpty) return text;
    final idx = text.indexOf(RegExp(r'[。！？.!?]'));
    String sentence = idx > 0 ? text.substring(0, idx) : text;
    
    // Truncate if too long
    if (sentence.length > 20) {
      sentence = sentence.substring(0, 20);
    }
    
    return sentence;
  }

  /// Create from JSON
  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      title: json['title']?.toString() ?? '',
      messages: (json['messages'] as List?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      id: json['id']?.toString(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (id != null) 'id': id,
    };
  }

  /// Copy with method
  ChatSession copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? id,
  }) {
    return ChatSession(
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
    );
  }
}
