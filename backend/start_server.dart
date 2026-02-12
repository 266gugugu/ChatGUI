import 'dart:io';
import 'dart:convert';

void main() async {
  print('开始启动Dart后端服务...');
  
  try {
    // 检查是否安装了必要的依赖
    print('检查依赖...');
    final pubGetResult = await Process.run('dart', ['pub', 'get']);
    
    if (pubGetResult.exitCode != 0) {
      print('安装依赖失败: ${pubGetResult.stderr}');
      print('尝试再次安装...');
      // 再次尝试安装依赖
      final secondAttempt = await Process.run('dart', ['pub', 'get']);
      if (secondAttempt.exitCode != 0) {
        print('再次安装失败: ${secondAttempt.stderr}');
        print('请手动运行: dart pub get');
      } else {
        print('依赖安装成功');
      }
    } else {
      print('依赖安装成功');
    }
    
    // 启动服务器
    print('启动服务器...');
    final serverProcess = await Process.start(
      'dart',
      ['main.dart'],
      runInShell: true,
    );
    
    print('Dart后端服务启动成功，PID: ${serverProcess.pid}');
    
    // 输出服务器日志
    serverProcess.stdout.transform(utf8.decoder).listen((data) {
      print('[Dart Server] $data');
    });
    
    serverProcess.stderr.transform(utf8.decoder).listen((data) {
      print('[Dart Server Error] $data');
    });
    
    // 监听进程退出
    serverProcess.exitCode.then((code) {
      print('Dart后端服务退出，退出码: $code');
    });
    
  } catch (e) {
    print('启动失败: $e');
    print('请确保已安装Dart SDK并添加到系统PATH');
  }
}
