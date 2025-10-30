import 'dart:convert';
import 'dart:async';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class ApiService extends GetxService {
  static ApiService get to => Get.find();

  // 复用 http.Client，提高连接复用与性能
  final http.Client _httpClient = http.Client();

  // 使用可配置的基础URL，针对不同平台自动适配
  String get baseUrl {
    // 获取平台信息
    final isAndroid = Platform.isAndroid;
    final isIOS = Platform.isIOS;
    
    // 根据不同平台返回适当的连接地址
    if (isAndroid) {
      // Android平台
      // 注：在实际设备上，需要手动配置为您电脑的IP地址
      // 10.0.2.2 是Android模拟器访问主机localhost的特殊地址
      return 'http://10.0.2.2:5000';
    } else if (isIOS) {
      // iOS平台
      // iOS模拟器可以直接使用localhost
      // 注：在实际设备上，需要手动配置为您电脑的IP地址
      return 'http://localhost:5000';
    } else {
      // 默认使用localhost，适用于桌面平台
      return 'http://localhost:5000';
    }
  }
  
  // 提供方法让用户手动设置后端地址（适用于物理设备）
  final RxString _customBaseUrl = ''.obs;
  
  void setCustomBackendUrl(String url) {
    _customBaseUrl.value = url;
  }
  
  // 获取最终使用的API基础URL
  String get currentBaseUrl {
    // 如果用户设置了自定义URL，则使用自定义URL
    if (_customBaseUrl.value.isNotEmpty) {
      return _customBaseUrl.value;
    }
    // 否则使用基于平台的默认URL
    return baseUrl;
  }
  final RxString apiUrl = ''.obs;
  final RxString apiKey = ''.obs;
  final RxString userId = 'test_user'.obs;
  final RxBool isLoading = false.obs;
  // 是否携带上下文（聊天历史）
  final RxBool useContext = false.obs;

  // 上传文件（file/image/video），返回后端生成的url
  Future<Map<String, dynamic>?> uploadFile({required String type, required String path}) async {
    try {
      final uri = Uri.parse('$currentBaseUrl/upload?type=$type');
      final req = http.MultipartRequest('POST', uri);
      req.files.add(await http.MultipartFile.fromPath('file', path));
      final resp = await req.send();
      if (resp.statusCode == 200) {
        final body = await resp.stream.bytesToString();
        return Map<String, dynamic>.from(jsonDecode(body));
      }
      return null;
    } catch (e) {
      print('上传失败: $e');
      return null;
    }
  }

  @override
  void onInit() {
    super.onInit();
    loadConfig();
  }

  @override
  void onClose() {
    _httpClient.close();
    super.onClose();
  }

  // 带重试逻辑的HTTP请求包装器
  Future<http.Response?> _retryRequest(
    Future<http.Response> Function() requestFn,
    {int maxRetries = 3, Duration retryDelay = const Duration(seconds: 2)}
  ) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await requestFn();
        return response;
      } on SocketException catch (e) {
        // 网络连接错误，可能是后端服务尚未启动
        print('第$attempt次尝试连接失败: $e');
        if (attempt < maxRetries) {
          print('等待$retryDelay后重试...');
          await Future.delayed(retryDelay);
        }
      } catch (e) {
        // 其他错误
        print('第$attempt次请求失败: $e');
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }
    return null; // 所有重试都失败
  }
  
  // 已改为固定非流式返回，移除流式重试逻辑

  // 加载API配置
  Future<void> loadConfig() async {
    try {
      final response = await _retryRequest(() => 
        http.get(Uri.parse('$currentBaseUrl/config?userId=${userId.value}'))
      );
      
      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        apiUrl.value = data['api_url'] ?? '';
        apiKey.value = data['api_key'] ?? '';
      } else {
        print('加载API配置失败: 状态码 ${response?.statusCode}');
      }
    } catch (e) {
      print('加载API配置异常: $e');
    }
  }

  // 保存API配置
  Future<bool> saveConfig(String url, String key) async {
    try {
      final response = await _retryRequest(() => 
        http.post(
          Uri.parse('$currentBaseUrl/config'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': userId.value,
            'apiUrl': url,
            'apiKey': key,
          }),
        )
      );
      
      if (response != null && response.statusCode == 200) {
        apiUrl.value = url;
        apiKey.value = key;
        // 保存后立即重新加载配置，确保前后端数据一致
        await loadConfig();
        print('API配置保存成功，当前API URL: ${apiUrl.value}');
        print('当前API Key已设置: ${apiKey.value.isNotEmpty ? '是' : '否'}');
        return true;
      }
      return false;
    } catch (e) {
      print('保存API配置异常: $e');
      return false;
    }
  }

  // 发送消息并获取“固定非流式”响应（一次性完整返回）
  Stream<String> sendMessageStream(String message) async* {
    try {
      isLoading.value = true;

      // 重新加载配置以确保使用最新值
      await loadConfig();

      // 没有配置则让后端走 direct_response（默认文本）
      final useDirectResponse = apiUrl.value.isEmpty || apiKey.value.isEmpty;

      print('发送消息 - URL: ${apiUrl.value}, Key长度: ${apiKey.value.length}, UserId: ${userId.value}');
      print('direct_response模式: $useDirectResponse');

      final uri = Uri.parse('$currentBaseUrl/chat');
      final response = await _retryRequest(() => http.post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'message': message,
              'direct_response': useDirectResponse,
              'userId': userId.value,
              'apiUrl': apiUrl.value,
              'apiKey': apiKey.value,
            'use_context': useContext.value,
            }),
          ));

      if (response == null) {
        yield '请求失败: 无法连接到后端服务';
        return;
      }

      if (response.statusCode != 200) {
        print('后端请求失败: 状态码 ${response.statusCode}');
        yield '请求失败: 状态码 ${response.statusCode}\n${response.body}';
        return;
      }

      try {
        final data = jsonDecode(response.body);
        final content = data['content'] ?? data['reply'] ?? data.toString();
        yield content.toString();
      } catch (e) {
        print('解析后端非流式响应失败: $e');
        yield response.body;
      }
    } catch (e) {
      print('发送消息异常: $e');
      yield '请求失败: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  // 获取聊天历史
  Future<List<Map<String, dynamic>>> getChatHistory() async {
    try {
      final response = await _retryRequest(() => 
        http.get(Uri.parse('$currentBaseUrl/history?userId=${userId.value}'))
      );
      
      if (response != null && response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      print('获取聊天历史异常: $e');
      return [];
    }
  }

  // 清除聊天历史
  Future<bool> clearChatHistory() async {
    try {
      final response = await _retryRequest(() => 
        http.delete(Uri.parse('$currentBaseUrl/history?userId=${userId.value}'))
      );
      
      return response != null && response.statusCode == 200;
    } catch (e) {
      print('清除聊天历史异常: $e');
      return false;
    }
  }

  // 获取可用模型列表
  Future<List<Map<String, String>>> getModels() async {
    try {
      final response = await _retryRequest(() => 
        http.get(Uri.parse('$currentBaseUrl/models'))
      );
      
      if (response != null && response.statusCode == 200) {
        return List<Map<String, String>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      print('获取模型列表异常: $e');
      return [];
    }
  }

}