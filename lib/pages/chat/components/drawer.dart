import 'dart:ui';

import 'package:chat_gui/pages/chat/controller.dart';
import 'package:chat_gui/store/app_store.dart';
import 'package:chat_gui/utils/api_service.dart';
import 'package:chat_gui/utils/cxxxr.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

class ChatDrawer extends GetView<ChatScreenController> {
  ChatDrawer({super.key});
  final RxBool _isHistoryExpanded = true.obs;
  final RxBool _isApiSettingsPage = false.obs;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = Get.find<AppStore>().tabletMode.value;
    final isDark = colorScheme.brightness == Brightness.dark;
    return Material(
      color: colorScheme.surface,
      child: Obx(() => AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: _isApiSettingsPage.value
          ? ApiSettingsPanel(onExit: () => _isApiSettingsPage.value = false)
          : _buildHistoryDrawer(context, colorScheme, isTablet, isDark),
      )),
    );
  }

  Widget _buildHistoryDrawer(BuildContext context, ColorScheme colorScheme, bool isTablet, bool isDark) {
    // (正文和交互保持不变，仅在上方加 API 管理按钮，点击切换 _isApiSettingsPage)
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
                          onPressed: () => _isApiSettingsPage.value = true,
                          padding: EdgeInsets.all(9),
                          icon: const Icon(LucideIcons.settings),
                          tooltip: 'API管理',
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
                        ListTile(
                          title: Text('清空聊天历史', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                          leading: Icon(LucideIcons.trash2, color: Colors.red),
                          onTap: () => _showClearHistoryDialog(context),
                          minTileHeight: 48,
                        ),
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

  void _showClearHistoryDialog(BuildContext context) {
    final ApiService apiService = Get.find<ApiService>();
    final ChatScreenController controller = Get.find<ChatScreenController>();
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('清空历史记录', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('确定要清空所有聊天历史吗？该操作不可恢复。'),
        actions: [
          TextButton(
            child: Text('取消', style: TextStyle(color: colorScheme.primary)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text('清空', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await apiService.clearChatHistory();
              if (ok) {
                await controller.refreshSessions();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('历史记录已清空')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('清理失败，请重试')));
              }
            },
          ),
        ],
      ),
    );
  }
}

class ApiSettingsPanel extends StatefulWidget {
  final VoidCallback onExit;
  const ApiSettingsPanel({Key? key, required this.onExit}) : super(key: key);
  @override
  State<ApiSettingsPanel> createState() => _ApiSettingsPanelState();
}

class _ApiSettingsPanelState extends State<ApiSettingsPanel> {
  late List<Map<String, dynamic>> profiles;
  late int currentIdx;
  late int activeIdx;
  final box = GetStorage();
  final List<String> supportedTypes = ['OpenAI', 'Gemini', 'DeepSeek', 'Kimi', '自定义'];
  final Map<String, TextEditingController> ctls = {
    'url': TextEditingController(),
    'key': TextEditingController(),
    'org': TextEditingController(),
    'region': TextEditingController(),
    'token': TextEditingController(),
    'raw': TextEditingController()
  };
  final nameCtrl = TextEditingController();
  String type = 'OpenAI';
  bool dirty = false; // 有未保存更改

  @override
  void initState() {
    super.initState();
    final dynamic localData = box.read('api_profiles');
    profiles = [];
    if (localData != null && localData is List) {
      for (final e in localData) {
        try {
          if (e is Map) {
            profiles.add(Map<String, dynamic>.from(e));
          }
        } catch (_) {}
      }
    }
    int idx = box.read('api_active_index') ?? 0;
    if (idx >= profiles.length) idx = 0;
    if (profiles.isEmpty) {
      final apiService = Get.find<ApiService>();
      profiles.add({
        'type': 'OpenAI',
        'name': '默认',
        'url': apiService.apiUrl.value,
        'key': apiService.apiKey.value,
        'org': ''
      });
      idx = 0;
    }
    currentIdx = idx;
    activeIdx = idx;
    _reloadControllersFromIdx(currentIdx, init:true);
  }

  void _reloadControllersFromIdx(int idx, {bool init = false}) {
    final cur = profiles[idx];
    ctls['url']!.text = (cur['url'] ?? '').toString();
    ctls['key']!.text = (cur['key'] ?? '').toString();
    ctls['org']!.text = (cur['org'] ?? '').toString();
    ctls['region']!.text = (cur['region'] ?? '').toString();
    ctls['token']!.text = (cur['token'] ?? '').toString();
    ctls['raw']!.text = (cur['raw'] ?? '').toString();
    nameCtrl.text = (cur['name'] ?? '').toString();
    setState(() { type = (cur['type'] ?? 'OpenAI').toString(); dirty = !init; });
  }

  void _saveAllAndActivate() async {
    box.write('api_profiles', profiles);
    box.write('api_active_index', currentIdx);
    setState(() {
      activeIdx = currentIdx;
      dirty = false;
    });
    _syncToApiService();
    // toast反馈+按钮轻微动画
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Row(children:[Icon(Icons.check_circle,color:Theme.of(context).colorScheme.primary),SizedBox(width:8),Text('API配置已保存并设为当前使用！')]),duration:Duration(seconds:1)),
    );
  }

  // 导出配置json
  void _exportProfiles() async {
    final encoded = jsonEncode(profiles);
    await Clipboard.setData(ClipboardData(text: encoded));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('API配置已复制为JSON，可粘贴/保存为文件。建议用记事本/文本编辑器另存。')));
  }

  // 导入配置json
  void _importProfiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions:['json']);
      if (result != null && result.files.single.bytes != null) {
        final jsonText = utf8.decode(result.files.single.bytes!);
        final decoded = jsonDecode(jsonText);
        if (decoded is List) {
          List<Map<String,dynamic>> newProfiles = [];
          for(final e in decoded){ if(e is Map) newProfiles.add(Map<String,dynamic>.from(e)); }
          if(newProfiles.isNotEmpty){
            setState((){
              profiles = newProfiles;
              currentIdx = 0;
              activeIdx = 0;
              _reloadControllersFromIdx(0,init:true);
            });
            _saveAllAndActivate();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('API配置导入成功，已应用。')));
          }
        }
      }
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败：${e.toString()}')));
    }
  }

  void _syncToApiService() {
    final apiService = Get.find<ApiService>();
    final p = profiles[activeIdx];
    if (p['type']=='OpenAI') {
      apiService.saveConfig(p['url']??'',p['key']??'');
    }
  }

  void _addNewProfile() {
    setState(() {
      profiles.add({
        'type':'OpenAI',
        'name':'新配置',
        'url':'',
        'key':'',
        'org':'',
        'region':'',
        'token':'',
        'raw':''
      });
      currentIdx = profiles.length-1;
      _reloadControllersFromIdx(currentIdx, init:true);
    });
  }
  void _removeCurrentProfile() {
    if (profiles.length<=1) return;
    setState(() {
      profiles.removeAt(currentIdx);
      if (currentIdx>=profiles.length) currentIdx=profiles.length-1;
      _reloadControllersFromIdx(currentIdx, init:true);
      dirty=false;
    });
  }
  void _onFieldChanged() {
    setState(() { dirty = true; });
  }
  void _saveCurrentProfileFieldsToList() {
    final p = profiles[currentIdx];
    p['type'] = type;
    p['name'] = nameCtrl.text;
    p['url'] = ctls['url']!.text;
    p['key'] = ctls['key']!.text;
    p['org'] = ctls['org']!.text;
    p['region'] = ctls['region']!.text;
    p['token'] = ctls['token']!.text;
    p['raw'] = ctls['raw']!.text;
    profiles[currentIdx]=p;
    // 不自动saveAll
  }
  void _switchProfile(int idx) async {
    if (idx == currentIdx) return;
    if (dirty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text("未保存更改"),
          content: Text("有未保存更改，切换配置将丢弃这些修改！是否放弃更改？"),
          actions: [
            TextButton(onPressed:()=>Navigator.pop(c,false), child: Text("取消")),
            TextButton(onPressed:()=>Navigator.pop(c,true), child: Text("放弃更改", style: TextStyle(color: Colors.red))),
          ]
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      currentIdx = idx;
      _reloadControllersFromIdx(currentIdx, init:true);
      dirty = false;
    });
  }
  Widget _profileItemLabel(int i) {
    String n = profiles[i]['name']??'未命名';
    String t = profiles[i]['type']??'';
    bool active = i == activeIdx;
    return Row(children:[
      if (active) Icon(Icons.circle, size: 10, color: Theme.of(context).colorScheme.primary),
      SizedBox(width: active?4:0),
      Expanded(
        child: Text("[$t] $n", style: TextStyle(fontWeight:FontWeight.w600, color: active ? Theme.of(context).colorScheme.primary : null), overflow: TextOverflow.ellipsis, maxLines: 1,),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 320,
      constraints: BoxConstraints(maxWidth:360),
      color: colorScheme.surface,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          // 返回按钮
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: widget.onExit,
              tooltip: '返回',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              'API管理',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          // 新建/删除 icon 按钮横向显示，不带label
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.add_circle_outline),
                tooltip: '新建',
                onPressed: _addNewProfile,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: profiles.length>1 ? Colors.red : Colors.grey),
                tooltip: '删除',
                onPressed: profiles.length > 1 ? _removeCurrentProfile : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          // 配置下拉（原有下拉、表单等直接保留）
          const SizedBox(height:10),
          DropdownButton<int>(
            borderRadius: BorderRadius.circular(10),
            isExpanded:true,
            value: currentIdx,
            onChanged:(i){ if(i!=null){_switchProfile(i);} },
            items: List.generate(profiles.length, (i) => 
              DropdownMenuItem(
                value:i,
                child: _profileItemLabel(i),
              )
            ),
          ),
          const SizedBox(height:10),
          TextField(
            controller:nameCtrl,
            decoration:InputDecoration(labelText:'配置名 (备注)',filled:true,fillColor:colorScheme.surfaceVariant.withAlpha(40)),
            onChanged:(_){ _onFieldChanged(); },
          ),
          const SizedBox(height:8),
          DropdownButton<String>(
            borderRadius: BorderRadius.circular(10),
            value: type,
            onChanged:(s){ if(s!=null){setState(()=>type=s);_onFieldChanged();} },
            items:supportedTypes.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
          ),
          const SizedBox(height:10),
          Builder(builder: (_) {
            switch(type){
              case 'OpenAI':
                return Column(children:[
                  TextField(controller:ctls['url'],decoration:InputDecoration(labelText:'API地址(必填)',hintText:'https://api.openai.com/v1/'),onChanged:(_)=>_onFieldChanged()),
                  SizedBox(height:6),
                  TextField(controller:ctls['key'],decoration:InputDecoration(labelText:'API Key',hintText:'sk-...'),onChanged:(_)=>_onFieldChanged(),obscureText:true),
                  SizedBox(height:6),
                  TextField(controller:ctls['org'],decoration:InputDecoration(labelText:'组织ID(可选)',hintText:'org-...'),onChanged:(_)=>_onFieldChanged()),
                ]);
              case 'Gemini':
                return Column(children:[
                  TextField(controller:ctls['key'],decoration:InputDecoration(labelText:'API Key'),onChanged:(_)=>_onFieldChanged(),obscureText:true),
                  SizedBox(height:6),
                  TextField(controller:ctls['region'],decoration:InputDecoration(labelText:'区域',hintText:'us-central1'),onChanged:(_)=>_onFieldChanged()),
                ]);
              case 'DeepSeek':
                return Column(children:[
                  TextField(controller:ctls['url'],decoration:InputDecoration(labelText:'API地址'),onChanged:(_)=>_onFieldChanged()),
                  SizedBox(height:6),
                  TextField(controller:ctls['key'],decoration:InputDecoration(labelText:'API Key'),onChanged:(_)=>_onFieldChanged(),obscureText:true),
                ]);
              case 'Kimi':
                return Column(children:[
                  TextField(controller:ctls['url'],decoration:InputDecoration(labelText:'API地址'),onChanged:(_)=>_onFieldChanged()),
                  SizedBox(height:6),
                  TextField(controller:ctls['token'],decoration:InputDecoration(labelText:'Token'),onChanged:(_)=>_onFieldChanged(),obscureText:true),
                ]);
              case '自定义':
              default:
                return TextField(controller:ctls['raw'],maxLines:6,decoration:InputDecoration(labelText:'自定义配置 (JSON)',helperText:'除非你懂格式原理，无需使用自定义'),onChanged:(_)=>_onFieldChanged());
            }
          }),
          // 保存按钮单独一行
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.save_alt),
                label: Text('保存并设为当前使用', overflow: TextOverflow.ellipsis),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(0, 40),
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  textStyle: TextStyle(fontSize: 15),
                ),
                onPressed: !dirty ? null : () {
                  _saveCurrentProfileFieldsToList();
                  _saveAllAndActivate();
                },
              ),
            ),
          ),
          // 导入导出以及激活状态一独立行
          Row(
            children: [
              if(activeIdx == currentIdx)
                Padding(
                  padding: EdgeInsets.only(left:4),
                  child: Text('已激活', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.upload_file_outlined),
                tooltip: '导入API配置',
                visualDensity: VisualDensity.compact,
                onPressed: _importProfiles,
              ),
              IconButton(
                icon: Icon(Icons.download_outlined),
                tooltip: '导出API配置',
                visualDensity: VisualDensity.compact,
                onPressed: _exportProfiles,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final ctl in ctls.values) {
      ctl.dispose();
    }
    nameCtrl.dispose();
    super.dispose();
  }
}
