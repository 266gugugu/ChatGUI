import '../models/chat_message.dart';
import 'i_chat_service.dart';

/// Mock chat service for testing and development
/// Provides dummy responses without requiring backend
class MockChatService implements IChatService {
  final List<ChatMessage> _messages = [];
  final List<ChatSession> _sessions = [];

  @override
  List<ChatMessage> get currentMessages => List.unmodifiable(_messages);

  @override
  Stream<String> sendMessage(String message, {bool withContext = false}) async* {
    // Simulate typing delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate mock response based on message
    final responses = [
      '这是一个模拟回复。你的消息是："$message"',
      '我明白了。让我来帮你分析一下...',
      '根据你的问题，我建议：\n1. 首先考虑这个方面\n2. 然后关注那个方面\n3. 最后不要忘记验证结果',
      '这是一个很好的问题！让我详细解释一下相关概念。',
    ];

    // Pick a response based on message length
    final responseIndex = message.length % responses.length;
    final response = responses[responseIndex];

    // Stream the response character by character to simulate real streaming
    for (int i = 0; i < response.length; i += 3) {
      await Future.delayed(const Duration(milliseconds: 50));
      final chunk = response.substring(
        i,
        i + 3 > response.length ? response.length : i + 3,
      );
      yield chunk;
    }
  }

  @override
  Future<List<ChatSession>> getChatHistory() async {
    // Return mock sessions
    if (_sessions.isEmpty) {
      _initializeMockSessions();
    }
    return List.from(_sessions);
  }

  void _initializeMockSessions() {
    final now = DateTime.now();
    
    // Create some mock sessions
    _sessions.addAll([
      ChatSession(
        title: '关于Flutter开发的讨论',
        messages: [
          ChatMessage(
            text: 'Flutter中如何实现MVVM架构？',
            role: 'user',
            timestamp: now.subtract(const Duration(hours: 2)),
          ),
          ChatMessage(
            text: 'Flutter中实现MVVM架构通常使用GetX或Provider...',
            role: 'assistant',
            timestamp: now.subtract(const Duration(hours: 2, minutes: 1)),
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      ChatSession(
        title: '如何优化应用性能？',
        messages: [
          ChatMessage(
            text: '如何优化Flutter应用的性能？',
            role: 'user',
            timestamp: now.subtract(const Duration(days: 1)),
          ),
          ChatMessage(
            text: '优化Flutter性能的几个关键点：\n1. 使用const构造函数\n2. 避免不必要的重建\n3. 使用ListView.builder',
            role: 'assistant',
            timestamp: now.subtract(const Duration(days: 1, minutes: 2)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  @override
  Future<bool> createNewSession() async {
    // Mock always succeeds
    await Future.delayed(const Duration(milliseconds: 100));
    _messages.clear();
    return true;
  }

  @override
  Future<bool> clearHistory() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _messages.clear();
    _sessions.clear();
    return true;
  }

  @override
  Future<bool> validateApiConnection() async {
    // Mock always validates successfully
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// Add message to mock service (for testing)
  void addMessage(ChatMessage message) {
    _messages.add(message);
  }

  /// Load a session
  void loadSession(ChatSession session) {
    _messages.clear();
    _messages.addAll(session.messages);
  }
}
