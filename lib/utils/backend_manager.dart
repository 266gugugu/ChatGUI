import 'dart:async'; // 已包含TimeoutException
import 'dart:io';
import 'dart:convert'; // 添加utf8导入
import 'package:flutter/foundation.dart';

class BackendManager {
  static final BackendManager _instance = BackendManager._internal();
  Process? _flaskProcess;
  bool _isRunning = false;
  final StreamController<bool> _statusController = StreamController<bool>.broadcast();

  factory BackendManager() => _instance;

  BackendManager._internal();

  Stream<bool> get statusStream => _statusController.stream;

  bool get isRunning => _isRunning;

  /// 启动Dart后端服务
  Future<bool> startBackend() async {
    // 在Web平台不支持启动后端进程
    if (kIsWeb) {
      print('Web平台不支持启动后端服务');
      return false;
    }

    // 如果已经在运行，直接返回
    if (_isRunning && _flaskProcess != null) {
      print('后端服务已经在运行');
      return true;
    }

    try {
      print('开始启动Dart后端服务...');
      
      // 获取当前目录
      final currentDir = Directory.current.path;
      final backendDir = '$currentDir\\backend';
      
      // 构建启动命令：优先使用 PATH 里的 dart；找不到则回退到 flutter 自带 dart
      final dartExecutable = await _resolveDartExecutable();
      if (dartExecutable == null) {
        print('未能找到 dart 可执行文件，请确认已安装 Flutter/Dart');
        return false;
      }

      // 启动Dart服务
      _flaskProcess = await Process.start(
        dartExecutable,
        ['start_server.dart'],
        workingDirectory: backendDir,
        runInShell: true,
      );

      _isRunning = true;
      _statusController.add(true);
      print('Dart后端服务启动成功，PID: ${_flaskProcess?.pid}');

      // 处理输出
      _flaskProcess?.stdout.transform(utf8.decoder).listen((data) {
        print('[Dart Server stdout] $data');
      });

      _flaskProcess?.stderr.transform(utf8.decoder).listen((data) {
        print('[Dart Server stderr] $data');
      });

      // 监听进程退出
      _flaskProcess?.exitCode.then((int code) {
        print('Dart后端服务退出，退出码: $code');
        _isRunning = false;
        _statusController.add(false);
        _flaskProcess = null;
      });

      // 等待服务启动
      await Future.delayed(const Duration(seconds: 3));
      
      // 检查服务是否正常运行
      final isReady = await _checkBackendHealth();
      if (isReady) {
        print('后端服务健康检查通过');
        return true;
      } else {
        print('后端服务健康检查失败');
        await stopBackend();
        return false;
      }
    } catch (e) {
      print('启动后端服务失败: $e');
      _isRunning = false;
      _statusController.add(false);
      return false;
    }
  }

  /// 解析 dart 可执行文件路径：PATH > 通过 flutter 推导
  Future<String?> _resolveDartExecutable() async {
    try {
      // 1) PATH 中查找
      ProcessResult whichDart;
      if (Platform.isWindows) {
        whichDart = await Process.run('where', ['dart'], runInShell: true);
      } else {
        whichDart = await Process.run('which', ['dart'], runInShell: true);
      }
      if (whichDart.exitCode == 0) {
        final out = (whichDart.stdout ?? '').toString().trim();
        if (out.isNotEmpty) {
          final first = out.split(RegExp(r'[\r\n]+')).first.trim();
          if (first.isNotEmpty) return first;
        }
      }

      // 2) 通过 flutter 定位到内置 dart（Windows: flutter.bat 在 <FLUTTER>\bin\flutter.bat）
      ProcessResult whichFlutter;
      if (Platform.isWindows) {
        whichFlutter = await Process.run('where', ['flutter'], runInShell: true);
      } else {
        whichFlutter = await Process.run('which', ['flutter'], runInShell: true);
      }
      if (whichFlutter.exitCode == 0) {
        final flutterPath = (whichFlutter.stdout ?? '').toString().trim().split(RegExp(r'[\r\n]+')).first.trim();
        if (flutterPath.isNotEmpty) {
          final flutterBinDir = Platform.isWindows
              ? flutterPath.replaceAll('flutter.bat', '')
              : flutterPath.replaceAll('/flutter', '/');
          final dartPath = Platform.isWindows
              ? '${flutterBinDir}cache\\dart-sdk\\bin\\dart.exe'
              : '${flutterBinDir}cache/dart-sdk/bin/dart';
          if (await File(dartPath).exists()) {
            return dartPath;
          }
        }
      }
    } catch (e) {
      print('解析 dart 可执行文件失败: $e');
    }
    return null;
  }

  /// 停止Dart后端服务
  Future<void> stopBackend() async {
    if (_flaskProcess != null) {
      print('停止Dart后端服务...');
      try {
        final process = _flaskProcess!;
        _flaskProcess = null; // 先置空，避免重复停止
        
        if (Platform.isWindows) {
          // Windows上使用taskkill终止进程树
          await Process.run(
            'taskkill',
            ['/F', '/T', '/PID', process.pid.toString()],
            runInShell: true,
          );
        } else {
          // Unix-like系统上发送SIGTERM信号
          process.kill(ProcessSignal.sigterm);
        }
        
        // 等待进程退出，使用Future.microtask避免返回值类型问题
        await Future.microtask(() async {
          try {
            await process.exitCode.timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                try {
                  process.kill(ProcessSignal.sigkill);
                } catch (_) {
                  // 忽略可能的错误
                }
                return 1; // 返回一个int值而不是bool
              },
            );
          } catch (_) {
            // 忽略可能的错误
          }
        });
      } catch (e) {
        print('停止后端服务时出错: $e');
      } finally {
        _flaskProcess = null; // 确保置空
        _isRunning = false;
        _statusController.add(false);
        print('Dart后端服务已停止');
      }
    }
  }

  /// 检查后端服务健康状态（带重试逻辑）
  Future<bool> _checkBackendHealth() async {
    const int maxRetries = 5; // 增加重试次数
    const Duration retryDelay = Duration(seconds: 1);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('进行后端健康检查（第$attempt次尝试）...');
        final client = HttpClient();
        // 使用轻量 /health 路由避免依赖业务逻辑
        final request = await client.getUrl(Uri.parse('http://localhost:5000/health'));
        
        // 设置超时以避免长时间阻塞
        request.headers.contentType = ContentType.json;
        
        final response = await request.close().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            client.close();
            throw TimeoutException('健康检查请求超时');
          },
        );
        
        client.close();
        
        if (response.statusCode == 200) {
          print('后端服务健康检查成功，状态码: 200');
          return true;
        } else {
          print('后端服务返回非200状态码: ${response.statusCode}');
        }
      } on SocketException catch (e) {
        print('后端健康检查连接失败（第$attempt次）: $e');
      } on TimeoutException catch (e) {
        print('后端健康检查超时（第$attempt次）: $e');
      } catch (e) {
        print('后端健康检查异常（第$attempt次）: $e');
      }
      
      if (attempt < maxRetries) {
        print('等待$retryDelay后进行下一次健康检查...');
        await Future.delayed(retryDelay);
      }
    }
    
    print('所有健康检查尝试均失败');
    return false;
  }

  /// 重启后端服务
  Future<bool> restartBackend() async {
    await stopBackend();
    return startBackend();
  }

  /// 资源释放
  void dispose() {
    _statusController.close();
    stopBackend();
  }
}
