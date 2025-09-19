import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart' as fluentIcons show FluentIcons;
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:reboot_launcher/src/util/os.dart';
import 'package:reboot_launcher/src/util/translations.dart';
import 'package:reboot_launcher/src/widget/file_selector.dart';
import 'package:reboot_launcher/src/widget/section/setting_tile.dart';

class FileSetting extends StatefulWidget {
  final GlobalKey<TextFormBoxState> validatorKey;
  final String title;
  final String description;
  final TextEditingController controller;
  final VoidCallback onReset;
  final String extension;
  final bool folder;

  const FileSetting({
    Key? key,
    required this.validatorKey,
    required this.title,
    required this.description,
    required this.controller,
    required this.onReset,
    this.extension = 'dll',
    this.folder = false,
  }) : super(key: key);

  @override
  State<FileSetting> createState() => _FileSettingState();
}

class _FileSettingState extends State<FileSetting> {
  static const double _kButtonDimensions = 30;
  static const double _kButtonSpacing = 8;

  String? _validationMessage;
  bool _selecting = false;

  @override
  Widget build(BuildContext context) {
    return SettingTile(
      icon: const Icon(FluentIcons.document_24_regular),
      title: Text(widget.title),
      subtitle: Text(widget.description),
      contentWidth: SettingTile.kDefaultContentWidth + _kButtonDimensions,
      content: Row(
        children: [
          Expanded(
            child: FileSelector(
              placeholder: translations.selectPathPlaceholder,
              windowTitle: translations.selectPathWindowTitle,
              controller: widget.controller,
              validator: (text) {
                final result = _checkDll(text);
                setState(() => _validationMessage = result);
                return result;
              },
              extension: widget.extension,
              folder: widget.folder,
              validatorMode: AutovalidateMode.always,
              allowNavigator: false,
              validatorKey: widget.validatorKey,
            ),
          ),
          const SizedBox(width: _kButtonSpacing),
          Padding(
            padding: EdgeInsets.only(bottom: _validationMessage == null ? 0.0 : 20.0),
            child: Tooltip(
              message: translations.selectFile,
              child: Button(
                style: ButtonStyle(padding: WidgetStateProperty.all(EdgeInsets.zero)),
                onPressed: _selecting ? null : _onSelectPressed,
                child: SizedBox.square(
                  dimension: _kButtonDimensions,
                  child: const Icon(fluentIcons.FluentIcons.open_folder_horizontal),
                ),
              ),
            ),
          ),
          const SizedBox(width: _kButtonSpacing),
          Padding(
            padding: EdgeInsets.only(bottom: _validationMessage == null ? 0.0 : 20.0),
            child: Tooltip(
              message: translations.reset,
              child: Button(
                style: ButtonStyle(padding: WidgetStateProperty.all(EdgeInsets.zero)),
                onPressed: widget.onReset,
                child: SizedBox.square(
                  dimension: _kButtonDimensions,
                  child: const Icon(FluentIcons.arrow_reset_24_regular),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSelectPressed() async {
    if (_selecting) return;
    setState(() => _selecting = true);

    try {
      final picked = await compute(openFilePicker, widget.extension);
      _updateText(widget.controller, picked);
    } finally {
      if (mounted) {
        setState(() => _selecting = false);
      }
    }
  }

  void _updateText(TextEditingController controller, String? value) {
    final text = value ?? controller.text;
    controller.text = text;
    controller.selection = TextSelection.collapsed(offset: text.length);
  }

  String? _checkDll(String? text) {
    if (text == null || text.isEmpty) {
      return translations.invalidDllPath;
    }

    final file = File(text);
    try {
      file.readAsBytesSync();
    } catch (_) {
      return translations.dllDoesNotExist;
    }

    if (!text.endsWith('.dll')) {
      return translations.invalidDllExtension;
    }

    return null;
  }
}
