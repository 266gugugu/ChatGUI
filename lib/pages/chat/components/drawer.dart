import 'dart:ui';

import 'package:chat_gui/pages/chat/controller.dart';
import 'package:chat_gui/store/app_store.dart';
import 'package:chat_gui/utils/api_service.dart';
import 'package:chat_gui/utils/cxxxr.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatDrawer extends GetView<ChatScreenController> {
  ChatDrawer({super.key});
  
  // 历史记录展开状态
  final RxBool _isHistoryExpanded = true.obs;

  void _showApiSettingsDialog(BuildContext context) {
    final apiService = Get.find<ApiService>();
    final apiUrlController = TextEditingController(text: apiService.apiUrl.value);
    final apiKeyController = TextEditingController(text: apiService.apiKey.value);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('API设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: apiUrlController,
                decoration: InputDecoration(
                  labelText: 'API地址',
                  hintText: 'https://api.example.com/v1/chat/completions',
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: apiKeyController,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final success = await apiService.saveConfig(
                apiUrlController.text.trim(),
                apiKeyController.text.trim(),
              );
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('API配置已保存')),
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('保存失败，请重试')),
                );
              }
            },
            child: Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = Get.find<AppStore>().tabletMode.value;
    final isDark = colorScheme.brightness == Brightness.dark;
    return Material(
      color: colorScheme.surface,
      child: Container(
        decoration:
            isTablet && isDark
                ? BoxDecoration(
                  border: Border(right: BorderSide(color: C.g1.r, width: 1)),
                )
                : null,
        child: SafeArea(
          right: false,
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    color: C.white.r,
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              TextField(
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  height: 1.5,
                                ),
                                controller: controller.searchInputController,
                                decoration: InputDecoration(
                                  hintText: 'chat.drawer.search.placeholder'.tr,
                                  contentPadding: EdgeInsets.only(
                                    left: 11 + 32,
                                    right: 11,
                                    top: 9,
                                    bottom: 9,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 5,
                                top: 5,
                                child: IconButton(
                                  onPressed: () {},
                                  icon: const Icon(LucideIcons.search),
                                  padding: EdgeInsets.all(4),
                                  constraints: BoxConstraints(),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.secondary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onSecondary,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        IconButton(
                          onPressed: () {},
                          padding: EdgeInsets.all(9),
                          icon: const Icon(LucideIcons.squarePen),
                        ),
                        IconButton(
                          onPressed: () => _showApiSettingsDialog(context),
                          padding: EdgeInsets.all(9),
                          icon: const Icon(LucideIcons.settings),
                          tooltip: 'API设置',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      children: [
                        ListTile(
                          title: Text(
                            'chat.drawer.actionButton.newChat'.tr,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          leading: Icon(
                            LucideIcons.squarePen,
                            color: colorScheme.onSurface.withAlpha(200),
                          ),
                          onTap: () => controller.newChat(),
                          minTileHeight: 48,
                        ),
                        ListTile(
                          title: Text(
                            'chat.drawer.actionButton.assistant'.tr,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          leading: Icon(
                            LucideIcons.bot,
                            color: colorScheme.onSurface.withAlpha(200),
                          ),
                          onTap: () {},
                          minTileHeight: 48,
                        ),
                        const SizedBox(height: 8),
                        // 历史记录标题和展开/收缩按钮
                        Obx(() => ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '历史记录',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  _isHistoryExpanded.value = !_isHistoryExpanded.value;
                                },
                                icon: Icon(
                                  _isHistoryExpanded.value ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                                  size: 16,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ],
                          ),
                          onTap: () {
                            _isHistoryExpanded.value = !_isHistoryExpanded.value;
                          },
                          minTileHeight: 48,
                        )),
                        // 根据展开状态显示历史记录
                        Obx(() => Column(
                          children: [
                            if (_isHistoryExpanded.value)
                              for (var i = 0; i < controller.sessions.length; i++)
                                ListTile(
                                  title: Text(
                                    controller.sessions[i].title,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: colorScheme.onSurface),
                                  ),
                                  onTap: () => controller.openSession(i),
                                  minTileHeight: 48,
                                ),
                          ],
                        )),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewPadding.bottom,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withAlpha(128),
                      ),
                      child: ListTile(
                        title: Text(
                          "Guest User",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: Colors.purple,
                          ),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
