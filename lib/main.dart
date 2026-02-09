import 'dart:async';
import 'package:chat_gui/theme/app_theme.dart';
import 'package:chat_gui/utils/api_service.dart';
import 'package:chat_gui/utils/backend_manager.dart';
import 'package:chat_gui/utils/rx_persist.dart';
import 'package:chat_gui/utils/translation_service.dart';
import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'routes/app_pages.dart';
import 'services/chat_service.dart';
import 'store/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 启动集成的 Dart 后端服务（若本机未启动）
  final backendManager = BackendManager();
  try {
    print('正在初始化后端服务...');
    // 强制重启，避免旧进程占用5000端口导致连接到旧版本后端
    final ok = await backendManager.restartBackend();
    if (!ok) {
      print('后端服务未能自动启动，将继续使用已运行的后端或稍后重试');
    }
  } catch (e) {
    print('后端服务初始化失败: $e');
  }
  
  // Init persistent store
  await StorageManager.initStorage('ChatGUI');
  
  // Init translations
  await TranslationService.init();
  final store = await Get.putAsync<AppStore>(() async => AppStore().init());
  Get.put(ApiService());
  
  // Register chat service (using real implementation)
  Get.put<ChatService>(ChatService());
  
  // 运行应用
  runApp(MainApp(store: store));
  
  // 应用退出时清理资源
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    // 在错误发生时可以考虑停止后端服务
  };
  
  // 捕获未处理的异步错误
  runZonedGuarded(() {
    // 空实现，仅用于错误处理
  }, (error, stackTrace) {
    print('未处理的错误: $error\n$stackTrace');
    // 可以在这里添加错误报告逻辑
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GetMaterialApp(
        title: 'ChatGUI',
        themeMode: store.themeMode.value,
        debugShowCheckedModeBanner: false,
        theme: lightTheme.useSystemChineseFont(Theme.of(context).brightness),
        darkTheme: darkTheme.useSystemChineseFont(Theme.of(context).brightness),
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        locale: Get.deviceLocale,
        fallbackLocale: const Locale('en', 'US'),
        translations: TranslationService(),
      ),
    );
  }
}
