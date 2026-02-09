import 'package:get/get.dart';
import '../models/chat_message.dart';
import '../utils/api_service.dart';
import 'i_chat_service.dart';

/// Real chat service implementation using ApiService
class ChatService implements IChatService {
  final ApiService _apiService;

  // 构造函数依赖注入，提高可测试性
  ChatService({ApiService? apiService})
      : _apiService = apiService ?? Get.find<ApiService>();

  @override
  List<ChatMessage> get currentMessages => throw UnimplementedError(
      'ChatService 不再管理状态，请使用 Controller 的 messages');

  @override
  Stream<String> sendMessage(String message, {bool withContext = false}) async* {
    try {
      // 传递 withContext 参数到 ApiService
      // 注意：ApiService.useContext 是全局状态，这里直接设置
      _apiService.useContext.value = withContext;
      
      final stream = _apiService.sendMessageStream(message);
      
      await for (final chunk in stream) {
        yield chunk;
      }
    } catch (e) {
      print('ChatService error: $e');
      yield '发送失败: ${e.toString()}';
    }
  }

  @override
  Future<List<ChatSession>> getChatHistory() async {
    try {
      final raw = await _apiService.getChatHistory();
      final allMessages = raw
          .map((e) => ChatMessage.fromJson(e))
          .toList();

      // Group messages by 30-minute intervals
      return _groupMessagesByTime(allMessages);
    } catch (e) {
      print('获取历史失败: $e');
      return [];
    }
  }

  /// Group messages into sessions based on time gaps
  List<ChatSession> _groupMessagesByTime(List<ChatMessage> messages) {
    const gap = Duration(minutes: 30);
    final List<ChatSession> grouped = [];
    List<ChatMessage> current = [];

    for (final message in messages) {
      if (current.isEmpty) {
        current = [message];
      } else {
        final lastTimestamp = current.last.timestamp;
        final timeDiff = message.timestamp.difference(lastTimestamp).abs();
        
        if (timeDiff > gap) {
          // Time gap exceeded, create new session
          grouped.add(ChatSession.fromMessages(current));
          current = [message];
        } else {
          current.add(message);
        }
      }
    }

    if (current.isNotEmpty) {
      grouped.add(ChatSession.fromMessages(current));
    }

    return grouped;
  }

  @override
  Future<bool> createNewSession() async {
    // Validate API first
    final isValid = await validateApiConnection();
    return isValid;
  }

  @override
  Future<bool> clearHistory() async {
    try {
      return await _apiService.clearChatHistory();
    } catch (e) {
      print('清除历史失败: $e');
      return false;
    }
  }

  @override
  Future<bool> validateApiConnection() async {
    try {
      return await _apiService.validateExternalApi();
    } catch (e) {
      print('API校验失败: $e');
      return false;
    }
  }
}
