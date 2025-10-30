import 'dart:async';

import 'package:chat_gui/components/interactive_drawer.dart';
import 'package:chat_gui/store/app_store.dart';
import 'package:chat_gui/utils/api_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:md_single_block_renderer/md_single_block_renderer.dart';
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

  final testMdBlocks = <Block>[].obs;
  final testMdBlocksLen = 0.obs;

  final testStreamMd = ''.obs;
  final isTyping = false.obs;
  final messageInputHeight = 100.0.obs;
  final isDrawerOpen = false.obs;
  final List<Message> messages = [];
  final RxList<ChatSession> sessions = <ChatSession>[].obs; // 按时间自动分组的历史会话
  final double kChatInputMaxHeight = 200.0;
  final ApiService apiService = Get.find<ApiService>();

  ChatScreenController() : drawerController = InteractiveDrawerController(
    initialValue: Get.find<AppStore>().tabletMode.value ? 1.0 : 0.0,
  );

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // print(DateTime.now());
    // markdownToBlocksAsync(testMd).then((List<Block> v) {
    //   testMdBlocks.value = List<List<Block>>.generate(100, (_) => v).expand((e) => e).toList();
    //   print(DateTime.now());
    // });

    ever(testMdBlocks, (val) {
      testMdBlocksLen.value = testMdBlocks.length;
    });

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
      final raw = await apiService.getChatHistory();
      final all = raw
          .map((e) => Message(
                text: (e['content'] ?? '').toString(),
                role: (e['role'] ?? 'assistant').toString(),
                timestamp: DateTime.tryParse((e['timestamp'] ?? '').toString()) ?? DateTime.now(),
              ))
          .toList();

      // 根据时间间隔分段（>30分钟算新会话）
      const gap = Duration(minutes: 30);
      final List<ChatSession> grouped = [];
      List<Message> current = [];
      for (final m in all) {
        if (current.isEmpty) {
          current = [m];
        } else {
          final last = current.last;
          if (m.timestamp.difference(last.timestamp).abs() > gap) {
            grouped.add(_sessionFrom(current));
            current = [m];
          } else {
            current.add(m);
          }
        }
      }
      if (current.isNotEmpty) grouped.add(_sessionFrom(current));

      sessions.assignAll(grouped);
    } catch (e) {
      print('加载历史失败: $e');
    }
  }

  ChatSession _sessionFrom(List<Message> items) {
    // 标题：优先第一条用户消息的首句；否则第一条消息；都没有则“新对话 + 日期”
    String title = '';
    for (final m in items) {
      if (m.role == 'user' && m.text.trim().isNotEmpty) {
        title = _firstSentence(m.text.trim());
        break;
      }
    }
    if (title.isEmpty && items.isNotEmpty) title = _firstSentence(items.first.text.trim());
    if (title.isEmpty) {
      final ts = items.isNotEmpty ? items.first.timestamp : DateTime.now();
      title = '新对话 ${_fmt(ts)}';
    }
    if (title.length > 20) title = title.substring(0, 20);
    return ChatSession(title: title, messages: List<Message>.from(items));
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
    final placeholder = ChatSession(title: '新对话 ${_fmt(DateTime.now())}', messages: []);
    sessions.add(placeholder);
    await openSession(sessions.length - 1);
  }

  String _firstSentence(String s) {
    if (s.isEmpty) return s;
    final idx = s.indexOf(RegExp(r'[。！？.!?]'));
    return idx > 0 ? s.substring(0, idx) : s;
  }

  String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  void onSendMessage() async {
    final text = inputController.text.trim();
    if (text.isEmpty) return;

    // 1. 先清除输入框并保存消息内容
    final userMessageText = text;
    inputController.clear();
    
    // 2. 创建并添加用户消息
    final userMessage = Message(
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

    // 6. 检查API配置是否完整
    print('当前API配置 - URL: ${apiService.apiUrl.value}, Key长度: ${apiService.apiKey.value.length}, UserId: ${apiService.userId.value}');
    if (apiService.apiUrl.value.isEmpty || apiService.apiKey.value.isEmpty) {
      // 显示提示消息
      messages.add(Message(
        text: '请先在侧边栏设置中配置API地址和Key。',
        role: 'assistant',
        timestamp: DateTime.now(),
      ));
      print('添加API配置提示消息');
      update();
      await scrollToEnd();
      return;
    } else {
      // 配置存在，立即重新加载以确保获取最新配置
      await apiService.loadConfig();
      print('重新加载后的API配置 - URL: ${apiService.apiUrl.value}, Key长度: ${apiService.apiKey.value.length}');
    }

    // 7. 设置为正在输入
    isTyping.value = true;
    update();
    
    try {
      // 8. 创建AI回复消息对象
      final aiMessage = Message(
        text: '',
        role: 'assistant',
        timestamp: DateTime.now(),
      );
      messages.add(aiMessage);
      update();
      
      // 9. 发送消息到API服务
      try {
        final stream = apiService.sendMessageStream(userMessageText);
        await for (final chunk in stream) {
          // 更新AI回复内容
          aiMessage.text += chunk;
          print('收到AI响应块: $chunk');
          update();
          
          // 滚动到底部
          scrollToEnd();
        }
      } catch (error) {
        aiMessage.text = '发送失败: $error';
          print('API错误: $error');
          update();
          scrollToEnd();
      } finally {
        isTyping.value = false;
        update();
        
        // 消息处理完成后重新聚焦到输入框
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(Get.context!).requestFocus(FocusNode());
          Timer(Duration(milliseconds: 100), () {
            FocusScope.of(Get.context!).requestFocus(inputFocusNode);
          });
        });
      }
    } catch (e) {
      isTyping.value = false;
      messages.add(Message(
        text: '请求出错: ${e.toString()}',
        role: 'assistant',
        timestamp: DateTime.now(),
      ));
      print('请求出错: $e');
      update();
      scrollToEnd();
      
      // 消息处理完成后重新聚焦到输入框
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(Get.context!).requestFocus(FocusNode());
        Timer(Duration(milliseconds: 100), () {
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

class Message {
  String text;
  final String role;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.role,
    required this.timestamp,
  });
}

class ChatSession {
  final String title;
  final List<Message> messages;
  ChatSession({required this.title, required this.messages});
}
