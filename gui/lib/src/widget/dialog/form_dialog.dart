import 'package:fluent_ui/fluent_ui.dart';

import 'dialog.dart';
import 'dialog_button.dart';
import 'generic_dialog.dart';

class FormDialog extends Dialog {
  final Widget content;
  final List<DialogButton> buttons;

  const FormDialog({Key? key, required this.content, required this.buttons}) : super(key: key);

  @override
  Widget build(BuildContext context) => Form(
      child: Builder(
          builder: (context) => GenericDialog(
              header: content,
              buttons: buttons.map((entry) => _createFormButton(entry, context)).toList()
          )
      )
  );

  DialogButton _createFormButton(DialogButton entry, BuildContext context) {
    if (entry.type != DialogButtonType.primary) {
      return entry;
    }

    return DialogButton(
        text: entry.text,
        type: entry.type,
        onTap: () {
          if(!Form.of(context).validate()) {
            return;
          }

          entry.onTap?.call();
        }
    );
  }
}
