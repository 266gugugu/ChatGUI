import '../models/chat_message.dart';

/// Abstract interface for chat services
/// Allows switching between real API, mock, or other implementations
abstract class IChatService {
  /// Send a message and receive streaming response
  Stream<String> sendMessage(String message, {bool withContext = false});

  /// Get all chat sessions (history grouped by time)
  Future<List<ChatSession>> getChatHistory();

  /// Create a new chat session
  /// Returns true if successful
  Future<bool> createNewSession();

  /// Clear all chat history
  Future<bool> clearHistory();

  /// Validate that the API connection is working
  Future<bool> validateApiConnection();

  /// Get the current session messages (if any)
  List<ChatMessage> get currentMessages;
}
