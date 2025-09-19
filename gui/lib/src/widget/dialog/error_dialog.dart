import 'package:clipboard/clipboard.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:reboot_launcher/src/util/translations.dart';
import 'package:reboot_launcher/src/widget/snackbar/snackbar.dart';

import 'dialog.dart';
import 'dialog_button.dart';
import 'info_dialog.dart';

class ErrorDialog extends Dialog {
  final Object exception;
  final StackTrace? stackTrace;
  final Function(Object) errorMessageBuilder;

  const ErrorDialog({Key? key, required this.exception, required this.errorMessageBuilder, this.stackTrace})  : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InfoDialog(
      text: errorMessageBuilder(exception),
      buttons: [
        DialogButton(
            type: stackTrace == null ? DialogButtonType.only : DialogButtonType.secondary
        ),

        if(stackTrace != null)
          DialogButton(
            text: translations.copyErrorDialogTitle,
            type: DialogButtonType.primary,
            onTap: () async {
              FlutterClipboard.controlC("$exception\n$stackTrace");
              SnackBar.open(translations.copyErrorDialogSuccess);
              Navigator.pop(context);
            },
          )
      ],
    );
  }
}