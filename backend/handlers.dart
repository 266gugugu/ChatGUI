import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'data_manager.dart';

class Handlers {
  // 获取用户配置
  static Future<Response> getConfig(Request request) async {
    try {
      final userId = request.url.queryParameters['userId'] ?? 'default';
      final config = await DataManager().getConfig(userId);
      
      return Response.ok(
        jsonEncode(config),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取配置失败: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': '获取配置失败'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 保存用户配置
  static Future<Response> saveConfig(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final userId = data['userId'] as String? ?? 'default';
      // 支持驼峰命名和下划线命名的字段
      final apiUrl = data['apiUrl'] as String? ?? data['api_url'] as String? ?? '';
      final apiKey = data['apiKey'] as String? ?? data['api_key'] as String? ?? '';
      
      await DataManager().saveConfig(userId, apiUrl, apiKey);
      
      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('保存配置失败: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': '保存配置失败'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 处理聊天请求
  static Future<Response> chat(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      final userId = data['userId'] as String? ?? 'default';
      final message = data['message'] as String? ?? '';
      final isStream = data['stream'] as bool? ?? true; // 默认使用流式响应
      final directResponse = data['direct_response'] as bool? ?? false;
      
      // 从请求中获取API配置
      final apiUrl = data['apiUrl'] as String? ?? '';
      final apiKey = data['apiKey'] as String? ?? '';
      
      if (message.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': '消息不能为空'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      // 保存消息到历史记录
      await DataManager().addChat(userId, 'user', message);
      
      // 判断使用哪种响应模式
      String responseContent;
      
      // 检查API配置是否有效
      final hasValidConfig = apiUrl.isNotEmpty && apiKey.isNotEmpty;
      
      if (directResponse || !hasValidConfig) {
        if (!hasValidConfig) {
          // 如果没有有效的API配置，返回提示消息
          responseContent = '请在设置中完成API地址和密钥配置';
        } else {
          // 如果设置了直接响应模式，使用默认响应
          responseContent = '你好！这是一个直接返回的中文测试响应。你的消息是：$message';
        }
      } else {
        try {
          // 获取用户聊天历史
          final history = await DataManager().getHistory(userId);
          
          // 构建消息格式 [{"role": "user", "content": "消息内容"}, ...]
          final messages = history.map((msg) => {
            'role': msg['role'],
            'content': msg['content']
          }).toList();
          
          // 构建请求头
          final headers = {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey'
          };
          
          // 构建请求体，按照Flask示例格式
          final payload = {
            'model': 'gemini-2.5-flash',
            'messages': messages
          };
          
          print('发送消息到API: $message');
          print('使用API地址: $apiUrl');
          print('使用密钥: $apiKey');
          
          // 发送POST请求
          final client = HttpClient();
          final request = await client.postUrl(Uri.parse(apiUrl));
          
          // 设置请求头
          headers.forEach((key, value) {
            request.headers.add(key, value);
          });
          
          // 写入请求体
          request.write(jsonEncode(payload));
          
          // 发送请求并获取响应
          final response = await request.close();
          final responseBody = await response.transform(utf8.decoder).join();
          
          print('响应状态码: ${response.statusCode}');
          print('原始响应: $responseBody');
          
          if (response.statusCode != 200) {
            return Response(response.statusCode,
              body: jsonEncode({
                'error': 'AI 服务返回 ${response.statusCode}',
                'raw_response': responseBody
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
          
          // 解析JSON响应
          Map<String, dynamic> aiData;
          try {
            aiData = jsonDecode(responseBody) as Map<String, dynamic>;
          } catch (e) {
            print('JSON 解析失败: $e');
            return Response.internalServerError(
              body: jsonEncode({
                'error': 'AI 返回的不是有效 JSON',
                'raw_response': responseBody
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
          
          // 提取回复内容
          try {
            responseContent = aiData['choices'][0]['message']['content'].toString().trim();
          } catch (e) {
            print('提取回复失败: $e');
            return Response.internalServerError(
              body: jsonEncode({
                'error': '无法从响应中提取回复内容',
                'raw_response': aiData
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
          
          if (responseContent.isEmpty) {
            responseContent = 'AI 返回了空回复';
          }
          
          print('AI 回复: $responseContent');
          
        } catch (e) {
          print('API调用失败: $e');
          responseContent = 'API调用失败: $e';
        }
      }
      
      // 如果需要流式响应
      if (isStream) {
        // 对于流式响应，我们需要传递responseContent
        return _createStreamResponse(userId, responseContent);
      }
      
      // 非流式响应
      await DataManager().addChat(userId, 'assistant', responseContent);
      
      return Response.ok(
        jsonEncode({'reply': responseContent}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('聊天处理失败: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': '处理消息失败: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 创建流式响应
  static Response _createStreamResponse(String userId, String responseContent) {
    final controller = StreamController<List<int>>();
    
    // 模拟流式响应
    _sendStreamResponse(controller, userId, responseContent).catchError((e) {
      print('流式响应错误: $e');
      controller.close();
    });
    
    return Response.ok(
      controller.stream,
      headers: {
        'Content-Type': 'text/event-stream',
        'Transfer-Encoding': 'chunked',
      },
    );
  }

  // 发送流式响应
    static Future<void> _sendStreamResponse(
        StreamController<List<int>> controller, String userId, String responseContent) async {
      try {
        // 直接使用传入的响应内容
        
        // 分段发送
        for (int i = 0; i < responseContent.length; i += 10) {
          final chunk = responseContent.substring(i, i + 10 > responseContent.length ? responseContent.length : i + 10);
          final json = jsonEncode({'content': chunk});
          controller.add('data: $json\n\n'.codeUnits);
          await Future.delayed(Duration(milliseconds: 100));
        }
        
        // 发送完成标志
        controller.add('data: ${jsonEncode({'done': true})}\n\n'.codeUnits);
        
        // 保存完整回复到历史
        await DataManager().addChat(userId, 'assistant', responseContent);
    } finally {
      controller.close();
    }
  }

  // 获取聊天历史
  static Future<Response> getHistory(Request request) async {
    try {
      final userId = request.url.queryParameters['userId'] ?? 'default';
      final history = await DataManager().getHistory(userId);
      
      return Response.ok(
        jsonEncode(history),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取历史记录失败: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': '获取历史记录失败'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 清除聊天历史
  static Future<Response> clearHistory(Request request) async {
    try {
      final userId = request.url.queryParameters['userId'] ?? 'default';
      await DataManager().clearHistory(userId);
      
      return Response.ok(
        jsonEncode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('清除历史记录失败: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': '清除历史记录失败'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取模型列表
  static Future<Response> getModels(Request request) async {
    try {
      // 这里返回示例模型列表
      final models = [
        {'id': 'model-1', 'name': '默认模型'},
        {'id': 'model-2', 'name': '高级模型'},
      ];
      
      return Response.ok(
        jsonEncode(models),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取模型列表失败: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': '获取模型列表失败'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
