import 'package:fluent_ui/fluent_ui.dart';

import 'package:reboot_launcher/src/util/translations.dart';
import 'dialog.dart';
import 'dialog_button.dart';
import 'generic_dialog.dart';

class ProgressDialog extends Dialog {
  final String text;
  final Function()? onStop;
  final bool showButton;

  const ProgressDialog({required this.text, this.onStop, this.showButton = true, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GenericDialog(
        header: InfoLabel(
          label: text,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              width: double.infinity,
              child: const ProgressBar()
          ),
        ),
        buttons: [
          if(showButton)
            DialogButton(
                text: translations.defaultDialogSecondaryAction,
                type: DialogButtonType.only,
                onTap: onStop
            )
        ]
    );
  }
}