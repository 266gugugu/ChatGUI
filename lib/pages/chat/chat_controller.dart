import 'dart:async';

import 'package:chat_gui/components/interactive_drawer.dart';
import 'package:chat_gui/models/chat_message.dart';
import 'package:chat_gui/services/chat_service.dart';
import 'package:chat_gui/services/i_chat_service.dart';
import 'package:chat_gui/store/app_store.dart';
import 'package:chat_gui/utils/api_service.dart';
import 'package:chat_gui/utils/date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class ChatScreenController extends GetxController with WidgetsBindingObserver {
  final scrollController = AutoScrollController(axis: Axis.vertical);

  final TextEditingController inputController = TextEditingController();
  final RxString inputText = ''.obs;
  final FocusNode inputFocusNode = FocusNode();

  final TextEditingController searchInputController = TextEditingController();
  final RxString searchInputText = ''.obs;

  final InteractiveDrawerController drawerController;
  double scrollOffsetPercent = -1;

  // UI 状态
  final isTyping = false.obs;
  final messageInputHeight = 100.0.obs;
  final isDrawerOpen = false.obs;
  // 当前使用的模型名称，后续可从 API 获取
  final currentModel = 'Gemini-2.5-pro-max-ultra'.obs;
  
  // Use new models
  final List<ChatMessage> messages = [];
  final RxList<ChatSession> sessions = <ChatSession>[].obs;
  
  final double kChatInputMaxHeight = 200.0;
  
  // Service layer - support dependency injection
  final IChatService chatService;

  ChatScreenController({IChatService? service})
      : chatService = service ?? Get.find<ChatService>(),
        drawerController = InteractiveDrawerController(
          initialValue: Get.find<AppStore>().tabletMode.value ? 1.0 : 0.0,
        );

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    ever(Get.find<AppStore>().tabletMode, (isTablet) {
      if (drawerController.isOpen && !isTablet) {
        drawerController.close();
      }
      if (drawerController.isClosed && isTablet) {
        drawerController.open();
      }
    });

    inputController.addListener(() {
      inputText.value = inputController.text;
    });

    searchInputController.addListener(() {
      searchInputText.value = searchInputController.text;
    });

    scrollController.addListener(() {
      if (!scrollController.hasClients ||
          !scrollController.position.hasContentDimensions) {
        return;
      }
      final max = scrollController.position.maxScrollExtent;
      if (max == 0) {
        scrollOffsetPercent = -1;
      } else {
        final current = scrollController.offset.clamp(0, max);
        final percent = max == 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
        scrollOffsetPercent = percent;
      }
      update(['scrollBorder']);
    });

    // 初始加载历史
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    await refreshSessions();
    if (sessions.isNotEmpty) {
      // 默认展示最近一段会话
      messages
        ..clear()
        ..addAll(sessions.last.messages);
      update();
      await Future.microtask(() {});
      scrollToEnd();
    }
  }

  Future<void> refreshSessions() async {
    try {
      final history = await chatService.getChatHistory();
      sessions.assignAll(history);
    } catch (e) {
      // 失败时显示空列表
    }
  }

  Future<void> openSession(int index) async {
    if (index < 0 || index >= sessions.length) return;
    messages
      ..clear()
      ..addAll(sessions[index].messages);
    update();
    await Future.microtask(() {});
    scrollToEnd();
  }

  // 新聊天：清空当前消息并创建一个空会话占位
  Future<void> newChat() async {
    // Use service layer for validation
    final ok = await chatService.validateApiConnection();
    if (!ok) {
      final ctx = Get.context!;
      final colorScheme = Theme.of(ctx).colorScheme;
      await showDialog(
        context: ctx,
        builder: (c) => AlertDialog(
          backgroundColor: colorScheme.background,
          title: const Text('API不可用', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('无法访问外部API（/models 返回非200）。请检查地址/密钥或网络。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: Text('知道了', style: TextStyle(color: colorScheme.primary)),
            ),
          ],
        ),
      );
      return;
    }

    final placeholder = ChatSession(
      title: '新对话 ${DateFormatter.formatDateTime(DateTime.now())}',
      messages: [],
    );
    sessions.add(placeholder);
    await openSession(sessions.length - 1);
  }



  void onSendMessage() async {
    final text = inputController.text.trim();
    if (text.isEmpty) return;
    
    // 防止并发发送
    if (isTyping.value) return;
    
    // 若是首次使用（无任何会话），则先创建一个新会话
    final bool isFirstEverMessage = sessions.isEmpty;
    if (isFirstEverMessage) {
      sessions.add(ChatSession(
        title: '新对话 ${DateFormatter.formatDateTime(DateTime.now())}',
        messages: [],
      ));
    }

    // 1. 先清除输入框并保存消息内容
    final userMessageText = text;
    inputController.clear();
    
    // 2. 创建并添加用户消息
    final userMessage = ChatMessage(
      text: userMessageText,
      role: 'user',
      timestamp: DateTime.now(),
    );
    messages.add(userMessage);
    
    // 3. 立即更新UI，确保用户消息显示
    update();
    
    // 4. 立即滚动到底部
    await scrollToEnd();
    
    // 5. 短暂延迟，确保UI完全更新后再继续
    await Future.microtask(() {});

    // 6. 设置为正在输入
    isTyping.value = true;
    update();
    
    try {
      // 7. 创建AI回复消息对象
      final aiMessage = ChatMessage(
        text: '',
        role: 'assistant',
        timestamp: DateTime.now(),
      );
      messages.add(aiMessage);
      update();
      
      // 8. 使用服务层发送消息（传递上下文设置）
      try {
        // 从 ApiService 获取上下文设置
        final withContext = Get.find<ApiService>().useContext.value;
        final stream = chatService.sendMessage(userMessageText, withContext: withContext);
        await for (final chunk in stream) {
          // 更新AI回复内容
          aiMessage.text += chunk;
          update();
          
          // 滚动到底部
          scrollToEnd();
        }
      } catch (error) {
        aiMessage.text = '发送失败: $error';
        update();
        scrollToEnd();
      } finally {
        isTyping.value = false;
        update();
        
        // 消息处理完成后重新聚焦到输入框
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(Get.context!).requestFocus(FocusNode());
          Timer(const Duration(milliseconds: 100), () {
            FocusScope.of(Get.context!).requestFocus(inputFocusNode);
          });
        });
      }
    } catch (e) {
      isTyping.value = false;
      messages.add(ChatMessage(
        text: '请求出错: ${e.toString()}',
        role: 'assistant',
        timestamp: DateTime.now(),
      ));
      update();
      scrollToEnd();
      
      // 消息处理完成后重新聚焦到输入框
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(Get.context!).requestFocus(FocusNode());
        Timer(const Duration(milliseconds: 100), () {
          FocusScope.of(Get.context!).requestFocus(inputFocusNode);
        });
      });
    }
  }

  Future<void> scrollToEnd() async {
    if (messages.isNotEmpty) {
      await scrollController.scrollToIndex(
        messages.length - 1,
        preferPosition: AutoScrollPosition.end,
      );
    }
  }

  void handleWindowSizeChange() {
    // 处理窗口大小变化
    final appStore = Get.find<AppStore>();
    final size = WidgetsBinding.instance.window.physicalSize;
    appStore.windowSize.value = Size(
      size.width / WidgetsBinding.instance.window.devicePixelRatio,
      size.height / WidgetsBinding.instance.window.devicePixelRatio,
    );
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    handleWindowSizeChange();
  }

  @override
  void onClose() {
    super.onClose();
    WidgetsBinding.instance.removeObserver(this);
    scrollController.dispose();
    inputController.dispose();
    searchInputController.dispose();
    inputFocusNode.dispose();
  }
}
