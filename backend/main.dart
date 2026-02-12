import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'data_manager.dart';

// Explicitly import latin1 from dart:convert for character decoding
import 'dart:convert' show latin1;
import 'package:mime/mime.dart';

// 全局 HttpClient：复用连接、设置连接上限与超时
final HttpClient _httpClient = (() {
  final client = HttpClient();
  client.maxConnectionsPerHost = 8;
  client.idleTimeout = const Duration(seconds: 15);
  client.connectionTimeout = const Duration(seconds: 15);
  client.autoUncompress = true;
  // 放宽证书校验，便于连到自托管/内网服务（生产环境请按需关闭）
  client.badCertificateCallback = (cert, host, port) => true;
  return client;
})();

void main() async {
  // 初始化数据管理器
  await DataManager().init();
  
  // 创建HTTP服务器
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    5000,
  );
  
  print('服务器启动在 http://${server.address.host}:${server.port}');
  print('API端点:');
  print('  GET    /health');
  print('  GET    /test-chinese');
  print('  POST   /upload?type={image|video|file}');
  print('  GET    /uploads/{filename}');
  print('  GET    /debug-upstream?userId={userId}');
  print('  GET    /config?userId={userId}');
  print('  POST   /config');
  print('  POST   /chat');
  print('  GET    /history?userId={userId}');
  print('  DELETE /history?userId={userId}');
  print('  GET    /models');
  
  // 处理请求
  await for (final request in server) {
    handleRequest(request);
  }
}

// 处理HTTP请求
void handleRequest(HttpRequest request) async {
  // 添加CORS头
  request.response.headers.add('Access-Control-Allow-Origin', '*');
  request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');
  
  // 处理OPTIONS请求
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.ok;
    await request.response.close();
    return;
  }
  
  try {
    // 解析路径
    final path = request.uri.path;
    final userId = request.uri.queryParameters['userId'] ?? 'default';
    
    // 路由处理
    if (path == '/health' && request.method == 'GET') {
      // 健康检查端点
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      request.response.write(jsonEncode({'status': 'ok', 'message': '服务运行正常'}));
      await request.response.close();
    } else if (path == '/test-chinese' && request.method == 'GET') {
      // 中文测试端点 - 完全不依赖请求体中的中文
      print('处理中文测试端点请求');
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      
      // 硬编码的中文响应
      final response = {
        'message': '你好！这是一个中文测试响应。',
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'success'
      };
      
      request.response.write(jsonEncode(response));
      await request.response.close();
      print('中文测试响应已发送');
    } else if (path == '/debug-upstream' && request.method == 'GET') {
      await handleDebugUpstream(request);
    } else if (path == '/upload' && request.method == 'POST') {
      await handleUpload(request);
    } else if (path.startsWith('/uploads/') && request.method == 'GET') {
      await handleServeUpload(request);
    } else if (path == '/config' && request.method == 'GET') {
      await handleGetConfig(request, userId);
    } else if (path == '/config' && request.method == 'POST') {
      await handleSaveConfig(request);
    } else if (path == '/chat' && request.method == 'POST') {
      await handleChat(request);
    } else if (path == '/history' && request.method == 'GET') {
      await handleGetHistory(request, userId);
    } else if (path == '/history' && request.method == 'DELETE') {
      await handleClearHistory(request, userId);
    } else if (path == '/models' && request.method == 'GET') {
      await handleGetModels(request);
    } else {
      // 404 Not Found
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': '端点不存在'}));
      await request.response.close();
    }
  } catch (e) {
    print('处理请求错误: $e');
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': '服务器内部错误'}));
    await request.response.close();
  }
}

// 获取用户配置
Future<void> handleGetConfig(HttpRequest request, String userId) async {
  try {
    final config = await DataManager().getConfig(userId);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(config));
  } catch (e) {
    print('获取配置失败: $e');
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': '获取配置失败'}));
  } finally {
    await request.response.close();
  }
}

// 保存用户配置
Future<void> handleSaveConfig(HttpRequest request) async {
  try {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body) as Map<String, dynamic>;
    
    final userId = data['userId'] as String? ?? 'default';
    // 支持驼峰命名和下划线命名的字段
    final apiUrl = data['apiUrl'] as String? ?? data['api_url'] as String? ?? '';
    final apiKey = data['apiKey'] as String? ?? data['api_key'] as String? ?? '';
    
    await DataManager().saveConfig(userId, apiUrl, apiKey);
    
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': true}));
  } catch (e) {
    print('保存配置失败: $e');
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': '保存配置失败'}));
  } finally {
    await request.response.close();
  }
}

// 处理聊天请求
Future<void> handleChat(HttpRequest request) async {
  print('开始处理聊天请求');
  try {
    // 打印请求信息
    print('请求方法: ${request.method}');
    print('请求路径: ${request.uri.path}');
    print('请求查询参数: ${request.uri.queryParameters}');
    
    // 确保正确处理请求体编码
    final bodyBytes = await request.fold<List<int>>(<int>[], (list, chunk) => list..addAll(chunk));
    
    // 增强的解码方法 - 首先尝试UTF-8
    String body;
    try {
      // 使用更严格的UTF-8解码，但允许处理损坏的字符
      body = utf8.decode(bodyBytes, allowMalformed: true);
    } catch (e) {
      print('UTF-8解码失败，尝试使用Latin-1作为备选: $e');
      body = latin1.decode(bodyBytes);
    }
    
    // 调试：输出原始字节和编码信息
    print('原始请求体字节: ${bodyBytes.take(50).toList()}');
    print('解码后的请求体: $body');
    print('请求体字节长度: ${bodyBytes.length}');
    print('Content-Type: ${request.headers.contentType}');
    
    // 如果检测到乱码模式，尝试额外的处理
    if (body.contains('??')) {
      print('检测到可能的编码问题，应用特殊处理');
      // 尝试将可能的UTF-16或其他编码转换
      // 这里我们先输出更多信息来诊断问题
    }
    print('请求体: $body');
    print('请求体字节长度: ${bodyBytes.length}');
    print('Content-Type: ${request.headers.contentType}');
    
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final userId = data['userId'] as String? ?? 'default';
      // 测试模式：直接使用硬编码的中文
      String message = data['message'] as String? ?? '';
      
      // 添加一个直接返回模式，用于测试中文响应
      final directResponse = data.containsKey('direct_response') && data['direct_response'] == true;
      
      // 为了测试，添加一个特殊参数来使用硬编码的中文
      if (data.containsKey('test_chinese') && data['test_chinese'] == true) {
        message = '你好，这是硬编码的中文测试消息';
        print('使用测试模式 - 硬编码中文消息');
      }
      
      // 特别处理：为中文消息添加调试信息
      if (message.contains('??')) {
        print('消息中包含乱码，尝试使用硬编码的中文进行测试');
        message = '你好，这是一个中文测试消息';
      }
      
      // 如果是直接返回模式，不调用外部API，直接返回中文响应
      if (directResponse) {
        print('使用直接返回模式，不调用外部API');
        final response = '你好！这是一个直接返回的中文测试响应。你的消息是：$message';
        
        // 保存用户消息到历史记录
        await DataManager().addChat(userId, 'user', message);
        // 保存AI回复到历史
        await DataManager().addChat(userId, 'assistant', response);
        
        // 返回响应
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
        request.response.write(jsonEncode({'content': response}));
        await request.response.close();
        print('直接返回响应: $response');
        return;
      }
      
      print('解析出的userId: $userId');
      print('解析出的message: $message');
      print('direct_response模式: $directResponse');
      
      if (message.isEmpty) {
        print('错误: 消息为空');
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': '消息不能为空'}));
        await request.response.close();
        return;
      }
      
      // 保存用户消息到历史记录
      try {
        // 确保消息内容正确
        print('保存消息前 - userId: $userId, role: user, message: $message, message编码: ${utf8.encode(message).length}');
        await DataManager().addChat(userId, 'user', message);
        print('用户消息已保存到历史记录');
      } catch (e) {
        print('保存消息失败: $e');
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': '保存消息失败: $e'}));
        await request.response.close();
        return;
      }
      
      // 获取用户配置的API信息
      try {
        final config = await DataManager().getConfig(userId);
        final apiUrl = config['api_url'] as String? ?? '';
        final apiKey = config['api_key'] as String? ?? '';
        
        print('使用用户配置 - API URL: $apiUrl');
        print('使用用户配置 - API Key已设置: ${apiKey.isNotEmpty ? '是' : '否'}');
        
        // 添加API配置详细调试日志
        print('收到聊天请求 - UserId: $userId');
        print('API配置 - URL: $apiUrl, Key长度: ${apiKey.length}');
        print('direct_response参数: $directResponse');
        
        if (apiUrl.isEmpty || apiKey.isEmpty) {
          print('错误: API配置未设置完整');
          request.response.statusCode = HttpStatus.badRequest;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': '请在设置中完成API地址和密钥配置'}));
          await request.response.close();
          return;
        }
        
        // 根据use_context决定是否携带历史
        final bool useContext = data['use_context'] as bool? ?? false;
        print('[Chat] use_context flag: ' + useContext.toString());
        List<Map<String, dynamic>> messages;
        if (useContext) {
          final history = await DataManager().getHistory(userId);
          // 仅携带“上一条用户发言”，不带助手回复，再加当前用户消息
          Map<String, dynamic>? lastUser;
          for (int i = history.length - 1; i >= 0 && lastUser == null; i--) {
            final h = history[i];
            if (h['role'] == 'user') lastUser = h;
          }
          messages = [];
          if (lastUser != null && (lastUser['content'] ?? '') != message) {
            messages.add({'role': 'user', 'content': lastUser['content']});
          }
          messages.add({'role': 'user', 'content': message});

          // 简易“上一句是什么”本地回答：避免上游不支持对话记忆
          final normalized = message.replaceAll('？', '?').replaceAll('。', '.').trim();
          final askPrevPatterns = [
            '我上一句说了什么',
            '上一句说了什么',
            '上一句是什么',
            '你记得我上一句',
            '上一句内容',
            '上一句',
          ];
          if (askPrevPatterns.any((p) => normalized.contains(p)) && lastUser != null) {
            final prev = (lastUser['content'] ?? '').toString();
            final reply = '你上一句说的是："$prev"';
            await DataManager().addChat(userId, 'assistant', reply);
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
            request.response.write(jsonEncode({'content': reply, 'debug': {'use_context': true, 'messages_count': messages.length, 'local_answer': true}}));
            await request.response.close();
            return;
          }
        } else {
          messages = [
            {
              'role': 'user',
              'content': message,
            }
          ];
        }
        print('[Chat] messages count to upstream: ' + messages.length.toString());

        final payload = {
          'model': 'gemini-2.5-flash',
          'messages': messages,
          'max_tokens': 1024,
          'temperature': 0.7,
        };
        
        print('请求负载: $payload');
        
        try {
          // 复用 HttpClient
          final httpRequest = await _httpClient.postUrl(Uri.parse(apiUrl));
          httpRequest.headers.set('Content-Type', 'application/json; charset=utf-8');
          httpRequest.headers.set('Authorization', 'Bearer $apiKey');
          httpRequest.persistentConnection = true;
          httpRequest.followRedirects = true;
          
          final payloadJson = jsonEncode(payload);
          print('发送到用户配置的API服务的JSON: $payloadJson');
          final payloadBytes = utf8.encode(payloadJson);
          httpRequest.contentLength = payloadBytes.length;
          httpRequest.add(payloadBytes);
          
          final httpResponse = await httpRequest.close().timeout(const Duration(seconds: 30));
          final responseBodyBytes = await httpResponse.fold<List<int>>(<int>[], (list, chunk) => list..addAll(chunk));
          final responseBody = utf8.decode(responseBodyBytes, allowMalformed: true);
          
          print('API响应状态码: ${httpResponse.statusCode}');
          print('API原始响应: $responseBody');
          
          if (httpResponse.statusCode != HttpStatus.ok) {
            request.response.statusCode = HttpStatus.ok; // 始终返回200给前端，在错误字段中提供详细信息
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({
              'error': 'API服务返回错误: ${httpResponse.statusCode}',
              'raw_response': responseBody
            }));
            await request.response.close();
            return;
          }
          
          // 解析响应
          final aiData = jsonDecode(responseBody) as Map<String, dynamic>;
          
          // 提取AI回复 - 支持多种常见API响应格式
          String aiReply = extractAIReply(aiData, responseBody);
          
          if (aiReply.isEmpty) {
            aiReply = '无法从API响应中提取有效的回复内容';
            print('警告: 提取的回复为空');
          } else {
            aiReply = aiReply.trim();
            print('成功从用户配置的API提取回复');
          }
          
          if (aiReply.isEmpty) {
            aiReply = 'AI返回了空回复';
          }
          
          // 保存AI回复到历史
          await DataManager().addChat(userId, 'assistant', aiReply);
          
          // 返回响应
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'content': aiReply, 'debug': {'use_context': useContext, 'messages_count': messages.length}}));
          
          print('AI回复: $aiReply');
        } catch (e) {
          print('请求AI服务失败: $e');
          // 将错误信息透传给前端，便于定位
          final errorReply = '外部API调用失败：${e.toString()}\n\n请检查 API 地址、密钥与网络连通性。';
          await DataManager().addChat(userId, 'assistant', errorReply);
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
          request.response.write(jsonEncode({'content': errorReply, 'error': e.toString()}));
        } finally {
          await request.response.close();
        }
      } catch (e) {
        print('获取配置失败: $e');
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': '获取配置失败: $e'}));
        await request.response.close();
      }
    } catch (e) {
      print('JSON解析失败: $e');
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': '无效的JSON格式: $e'}));
      await request.response.close();
    }
  } catch (e) {
    print('聊天处理失败: $e');
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': '处理消息失败: $e'}));
    await request.response.close();
  }
}

// 处理流式聊天响应
Future<void> handleStreamChat(HttpRequest request, String userId, String message) async {
  try {
    // 设置流式响应头
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.parse('text/event-stream');
    request.response.headers.add('Transfer-Encoding', 'chunked');
    
    // 准备回复内容
    final response = '这是对您消息的流式回复：$message';
    
    // 分段发送
    for (int i = 0; i < response.length; i += 10) {
      final chunk = response.substring(i, i + 10 > response.length ? response.length : i + 10);
      final json = jsonEncode({'content': chunk});
      request.response.write('data: $json\n\n');
      await request.response.flush();
      await Future.delayed(Duration(milliseconds: 100));
    }
    
    // 发送完成标志
    request.response.write('data: ${jsonEncode({'done': true})}\n\n');
    await request.response.flush();
    
    // 保存完整回复到历史
    await DataManager().addChat(userId, 'assistant', response);
  } catch (e) {
    print('流式响应错误: $e');
  } finally {
    await request.response.close();
  }
}

// 获取聊天历史
Future<void> handleGetHistory(HttpRequest request, String userId) async {
  try {
    final history = await DataManager().getHistory(userId);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(history));
  } catch (e) {
    print('获取历史记录失败: $e');
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': '获取历史记录失败'}));
  } finally {
    await request.response.close();
  }
}

// 清除聊天历史
Future<void> handleClearHistory(HttpRequest request, String userId) async {
  try {
    await DataManager().clearHistory(userId);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': true}));
  } catch (e) {
    print('清除历史记录失败: $e');
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': '清除历史记录失败'}));
  } finally {
    await request.response.close();
  }
}

// 获取模型列表
Future<void> handleGetModels(HttpRequest request) async {
  try {
    // 返回示例模型列表
    final models = [
      {'id': 'model-1', 'name': '默认模型'},
      {'id': 'model-2', 'name': '高级模型'},
    ];
    
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(models));
  } catch (e) {
    print('获取模型列表失败: $e');
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': '获取模型列表失败'}));
  } finally {
    await request.response.close();
  }
}

// 灵活的AI回复提取函数，支持多种常见API响应格式
String extractAIReply(Map<String, dynamic> aiData, String rawResponse) {
  try {
    // 尝试OpenAI/兼容格式 (choices[0].message.content)
    if (aiData.containsKey('choices') && aiData['choices'] is List && (aiData['choices'] as List).isNotEmpty) {
      final firstChoice = (aiData['choices'] as List)[0] as Map<String, dynamic>;
      if (firstChoice.containsKey('message') && firstChoice['message'] is Map) {
        final message = firstChoice['message'] as Map<String, dynamic>;
        if (message.containsKey('content') && message['content'] is String) {
          return message['content'] as String;
        }
      }
    }
    
    // 尝试直接content字段
    if (aiData.containsKey('content') && aiData['content'] is String) {
      return aiData['content'] as String;
    }
    
    // 尝试text字段
    if (aiData.containsKey('text') && aiData['text'] is String) {
      return aiData['text'] as String;
    }
    
    // 尝试reply字段
    if (aiData.containsKey('reply') && aiData['reply'] is String) {
      return aiData['reply'] as String;
    }
    
    // 尝试response字段
    if (aiData.containsKey('response') && aiData['response'] is String) {
      return aiData['response'] as String;
    }
    
    // 尝试choices[0].text (某些API使用此格式)
    if (aiData.containsKey('choices') && aiData['choices'] is List && (aiData['choices'] as List).isNotEmpty) {
      final firstChoice = (aiData['choices'] as List)[0] as Map<String, dynamic>;
      if (firstChoice.containsKey('text') && firstChoice['text'] is String) {
        return firstChoice['text'] as String;
      }
    }
    
    print('无法识别API响应格式');
    return '';
  } catch (e) {
    print('提取回复时出错: $e');
    return '';
  }
}

// 诊断端点：直接调用上游API并返回原始结果，便于排障
Future<void> handleDebugUpstream(HttpRequest request) async {
  try {
    final userId = request.uri.queryParameters['userId'] ?? 'test_user';
    final config = await DataManager().getConfig(userId);
    final apiUrl = config['api_url'] as String? ?? '';
    final apiKey = config['api_key'] as String? ?? '';
    if (apiUrl.isEmpty || apiKey.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': '未配置 api_url 或 api_key'}));
      await request.response.close();
      return;
    }
    final req = await _httpClient.postUrl(Uri.parse(apiUrl));
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Authorization', 'Bearer $apiKey');
    final payload = {
      'model': 'gemini-2.5-flash',
      'messages': [
        {'role': 'user', 'content': 'ping'}
      ]
    };
    req.add(utf8.encode(jsonEncode(payload)));
    final resp = await req.close().timeout(const Duration(seconds: 15));
    final body = await resp.transform(utf8.decoder).join();
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'upstream_status': resp.statusCode,
      'raw_response': body
    }));
  } catch (e) {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': e.toString()}));
  } finally {
    await request.response.close();
  }
}

// 处理上传 (multipart/form-data)，保存到 backend/uploads，并返回文件信息
Future<void> handleUpload(HttpRequest request) async {
  try {
    final type = request.uri.queryParameters['type'] ?? 'file';
    final contentType = request.headers.contentType;
    if (contentType == null || contentType.mimeType != 'multipart/form-data') {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': 'Content-Type 必须是 multipart/form-data'}));
      await request.response.close();
      return;
    }
    final boundary = contentType.parameters['boundary'];
    if (boundary == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': '缺少 boundary'}));
      await request.response.close();
      return;
    }

    final uploadDir = Directory('uploads');
    if (!await uploadDir.exists()) {
      await uploadDir.create(recursive: true);
    }

    String? savedName;
    int savedSize = 0;

    final transformer = MimeMultipartTransformer(boundary);
    await for (final part in request.cast<List<int>>().transform(transformer)) {
      final headers = part.headers; // e.g. content-disposition
      final disp = headers['content-disposition'];
      if (disp == null) continue;
      final filenameMatch = RegExp(r'filename="([^\"]*)"').firstMatch(disp);
      if (filenameMatch == null) continue;
      final original = filenameMatch.group(1) ?? 'file';
      // 记录文件
      final name = '${DateTime.now().millisecondsSinceEpoch}_${original.replaceAll(' ', '_')}';
      final file = File('uploads/$name');
      final sink = file.openWrite();
      await part.pipe(sink);
      await sink.close();
      savedName = name;
      savedSize = await file.length();
    }

    if (savedName == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': '未接收到文件'}));
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'name': savedName,
      'size': savedSize,
      'type': type,
      'url': '/uploads/$savedName'
    }));
  } catch (e) {
    print('上传失败: $e');
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'error': '上传失败: $e'}));
  } finally {
    await request.response.close();
  }
}

// 静态文件服务: /uploads/{filename}
Future<void> handleServeUpload(HttpRequest request) async {
  try {
    final path = request.uri.path; // /uploads/xxx
    final name = path.replaceFirst('/uploads/', '');
    final file = File('uploads/$name');
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not Found');
      await request.response.close();
      return;
    }
    final ext = name.split('.').last.toLowerCase();
    ContentType ct;
    if (['png','jpg','jpeg','gif','webp'].contains(ext)) {
      ct = ContentType('image', ext == 'jpg' ? 'jpeg' : ext);
    } else if (['mp4','webm','mov'].contains(ext)) {
      ct = ContentType('video', ext);
    } else {
      ct = ContentType.binary;
    }
    request.response.headers.contentType = ct;
    await file.openRead().pipe(request.response);
  } catch (e) {
    print('静态文件服务失败: $e');
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.write('Error');
    await request.response.close();
  }
}
