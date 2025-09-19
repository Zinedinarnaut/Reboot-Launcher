import 'package:fluent_ui/fluent_ui.dart';
import 'package:reboot_launcher/src/util/translations.dart';

import 'dialog.dart';
import 'dialog_button.dart';
import 'generic_dialog.dart';

class InfoDialog extends Dialog {
  final String text;
  final List<DialogButton>? buttons;

  const InfoDialog({required this.text, this.buttons, Key? key}) : super(key: key);

  InfoDialog.ofOnly({required this.text, required DialogButton button, Key? key})
      : buttons = [button], super(key: key);

  @override
  Widget build(BuildContext context) {
    return GenericDialog(
        header: SizedBox(
            width: double.infinity,
            child: Text(text, textAlign: TextAlign.center)
        ),
        buttons: buttons ?? [_defaultCloseButton],
        padding: const EdgeInsets.only(left: 20, right: 20, top: 15.0, bottom: 15.0)
    );
  }

  DialogButton get _defaultCloseButton =>DialogButton(
      text: translations.defaultDialogSecondaryAction,
      type: DialogButtonType.only
  );
}