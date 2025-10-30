# 移动平台配置指南

本指南将帮助您在iOS和Android平台上运行Flutter前端并连接到Flask后端服务。

## 一、配置说明

在移动设备上运行Flutter应用时，需要确保应用能够正确连接到本地运行的Flask后端服务。以下是不同场景的配置方法：

### 1. iOS模拟器

- iOS模拟器可以直接使用 `localhost` 或 `127.0.0.1` 访问主机上的服务
- 确保Flask服务在主机上正常运行在 `5000` 端口

### 2. Android模拟器

- Android模拟器需要使用特殊地址 `10.0.2.2` 来访问主机的 `localhost`
- 这是因为Android模拟器内部有自己的网络栈

### 3. 物理设备

- 对于真实的iOS或Android设备，需要：
  - 确保设备与主机在同一WiFi网络下
  - 使用主机的实际IP地址（如 `192.168.x.x`）

## 二、使用步骤

### 1. 启动Flask后端服务

首先在您的电脑上启动Flask后端服务：

```bash
# Windows
cd backend
python app.py

# macOS/Linux
cd backend
python3 app.py
```

### 2. 获取主机IP地址（针对物理设备）

- **Windows**: 打开命令提示符，输入 `ipconfig` 查看IPv4地址
- **macOS/Linux**: 打开终端，输入 `ifconfig` 或 `ip addr` 查看IP地址

### 3. 配置Flutter应用

在运行Flutter应用前，需要根据您的设备类型配置正确的后端地址。您可以通过以下方式修改连接设置：

#### 方法一：修改API服务配置（开发者）

编辑 `lib/utils/api_service.dart` 文件，根据您的设备类型修改 `baseUrl` getter方法：

```dart
String get baseUrl {
  // iOS模拟器使用 localhost
  // return 'http://localhost:5000/api';
  
  // Android模拟器使用 10.0.2.2
  // return 'http://10.0.2.2:5000/api';
  
  // 物理设备使用主机实际IP
  // return 'http://192.168.x.x:5000/api';
}
```

#### 方法二：使用应用内设置（用户）

1. 在应用中设置自定义API URL为您的主机IP地址
2. 格式为：`http://您的主机IP:5000/api`

### 4. 运行Flutter应用

根据您的设备类型选择适当的命令运行应用：

```bash
# iOS模拟器
flutter run -d ios

# Android模拟器
flutter run -d android

# 连接的物理设备
flutter run -d 设备ID
```

## 三、常见问题排查

### 连接失败

1. 确保Flask服务正在运行
2. 检查防火墙是否阻止了5000端口的连接
3. 验证使用的IP地址是否正确
4. 确认移动设备与主机在同一网络

### API错误

1. 查看Flask服务日志获取详细错误信息
2. 检查网络连接是否稳定
3. 尝试重启前后端服务

## 四、开发提示

- 在开发过程中，建议先确保服务在模拟器上正常工作，再尝试连接物理设备
- 对于跨平台开发，可以考虑使用环境变量或配置文件来管理不同环境的连接设置
- 生产环境中，建议部署后端服务到云服务器，避免本地网络配置问题

---

如果您遇到任何问题，请参考Flutter和Flask的官方文档，或在GitHub上提交issue。