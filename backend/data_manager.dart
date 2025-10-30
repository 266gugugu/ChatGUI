import 'dart:convert';
import 'dart:io';
import 'dart:async';

class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  
  final String _configDir = 'configs';
  final String _historyDir = 'history';
  
  DataManager._internal();
  
  // 初始化数据管理器
  Future<void> init() async {
    // 创建必要的目录
    final configPath = Directory(_configDir);
    final historyPath = Directory(_historyDir);
    
    if (!await configPath.exists()) {
      await configPath.create(recursive: true);
    }
    
    if (!await historyPath.exists()) {
      await historyPath.create(recursive: true);
    }
    
    print('数据管理器初始化完成');
  }
  
  // 获取用户配置
  Future<Map<String, dynamic>> getConfig(String userId) async {
    final configFile = File('$_configDir/${userId.replaceAll('/', '_')}.json');
    
    if (await configFile.exists()) {
      try {
        final content = await configFile.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        print('读取配置文件失败: $e');
      }
    }
    
    // 返回默认配置
    return {'api_url': '', 'api_key': ''};
  }
  
  // 保存用户配置
  Future<void> saveConfig(String userId, String apiUrl, String apiKey) async {
    final configFile = File('$_configDir/${userId.replaceAll('/', '_')}.json');
    final config = {
      'api_url': apiUrl,
      'api_key': apiKey,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    await configFile.writeAsString(jsonEncode(config), encoding: utf8);
  }
  
  // 添加聊天记录
  Future<void> addChat(String userId, String role, String content) async {
    final historyFile = File('$_historyDir/${userId.replaceAll('/', '_')}.json');
    List<Map<String, dynamic>> history = [];
    
    // 如果历史文件存在，读取现有记录
    if (await historyFile.exists()) {
      try {
        final fileContent = await historyFile.readAsString(encoding: utf8);
        if (fileContent.isNotEmpty) {
          history = List<Map<String, dynamic>>.from(jsonDecode(fileContent));
        }
      } catch (e) {
        print('读取历史记录失败: $e');
      }
    }
    
    // 添加新消息
    history.add({
      'role': role,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // 保存历史记录，限制最多保存100条消息
    if (history.length > 100) {
      history = history.sublist(history.length - 100);
    }
    
    await historyFile.writeAsString(jsonEncode(history), encoding: utf8);
  }
  
  // 获取聊天历史
  Future<List<Map<String, dynamic>>> getHistory(String userId) async {
    final historyFile = File('$_historyDir/${userId.replaceAll('/', '_')}.json');
    
    if (await historyFile.exists()) {
      try {
        final content = await historyFile.readAsString(encoding: utf8);
        if (content.isNotEmpty) {
          return List<Map<String, dynamic>>.from(jsonDecode(content));
        }
      } catch (e) {
        print('读取历史记录失败: $e');
      }
    }
    
    return [];
  }
  
  // 清除聊天历史
  Future<void> clearHistory(String userId) async {
    final historyFile = File('$_historyDir/${userId.replaceAll('/', '_')}.json');
    
    if (await historyFile.exists()) {
      await historyFile.writeAsString(jsonEncode([]));
    }
  }
}
