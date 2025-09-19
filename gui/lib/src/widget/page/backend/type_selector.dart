import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:reboot_common/common.dart';
import 'package:reboot_launcher/src/controller/backend_controller.dart';
import 'package:reboot_launcher/src/util/translations.dart';
import 'package:reboot_launcher/src/widget/tutorial/tutorial_overlay.dart';

class BackendTypeSelector extends StatefulWidget {
  final Key overlayKey;
  const BackendTypeSelector({required this.overlayKey});

  @override
  State<BackendTypeSelector> createState() => _BackendTypeSelectorState();
}

class _BackendTypeSelectorState extends State<BackendTypeSelector> {
  late final BackendController _backendController = Get.find<BackendController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() => TutorialOverlayTarget(
      key: widget.overlayKey,
      child: DropDownButton(
          leading: Text(_backendController.type.value.label),
          items: _items
      ),
    ));
  }

  List<MenuFlyoutItem> get _items => AuthBackendType.values
      .map((type) => _createItem(type))
      .toList();

  MenuFlyoutItem _createItem(AuthBackendType type) => MenuFlyoutItem(
      text: Text(type.label),
      onPressed: () async {
        await _backendController.stop();
        _backendController.type.value = type;
      }
  );
}

extension _ServerTypeExtension on AuthBackendType {
  String get label => switch(this) {
    AuthBackendType.embedded => translations.embedded,
    AuthBackendType.remote => translations.remote,
    AuthBackendType.local => translations.local
  };
}
