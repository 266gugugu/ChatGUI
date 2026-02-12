import 'package:chat_gui/components/interactive_drawer.dart';
import 'package:chat_gui/pages/chat/components/content.dart';
import 'package:chat_gui/pages/chat/components/drawer.dart';
import 'package:chat_gui/pages/chat/components/input.dart';
import 'package:chat_gui/pages/chat/chat_controller.dart';
import 'package:chat_gui/store/app_store.dart';
import 'package:chat_gui/utils/cxxxr.dart';
import 'package:chat_gui/utils/layout_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatScreen extends GetView<ChatScreenController> {
  const ChatScreen({super.key});

  @override
  Widget build(context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTablet = Get.find<AppStore>().tabletMode.value;
    final tabletWidth =
        isTablet ? calculateTabletWidth(MediaQuery.of(context).size.width.toInt()) : 0;
    return InteractiveDrawer(
      tabletMode: isTablet,
      scrimColor: context.isDarkMode ? C.g1.d : C.black.l,
      controller: controller.drawerController,
      drawer: ChatDrawer(),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        bottomNavigationBar: SizedBox(height: MediaQuery.of(context).padding.bottom),
        appBar: AppBar(
          titleSpacing: -6,
          actionsPadding: const EdgeInsets.only(right: 6),
          title: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton.icon(
              onPressed: () {},
              label: Obx(() => Text(
                    controller.currentModel.value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
              icon: Icon(LucideIcons.chevronDown),
              iconAlignment: IconAlignment.end,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(0, 0),
              ),
            ),
          ),
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.alignLeft),
            onPressed: () => controller.drawerController.toggle(),
          ),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(LucideIcons.squarePen)),
            IconButton(onPressed: () {}, icon: const Icon(LucideIcons.ellipsisVertical)),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 1,
              child: Stack(
                children: [
                  ChatContent(tabletWidth: tabletWidth),
                  Positioned.fill(
                    child: GetBuilder<ChatScreenController>(
                      id: 'scrollBorder',
                      builder: (_) {
                        final percent = controller.scrollOffsetPercent;
                        return IgnorePointer(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: C.g2.r.withAlpha(
                                    percent < 1 && percent != -1 ? 160 : 0,
                                  ),
                                  width: 1,
                                ),
                                top: BorderSide(
                                  color: C.g2.r.withAlpha(
                                    percent > 0 && percent != -1 ? 160 : 0,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentGeometry.center,
              child: ConstrainedBox(
                constraints:
                    isTablet && tabletWidth > 0
                        ? BoxConstraints(maxWidth: tabletWidth.toDouble())
                        : BoxConstraints(),
                child: const ChatInput(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
