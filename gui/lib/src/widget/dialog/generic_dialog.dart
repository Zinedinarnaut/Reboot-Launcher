import 'package:fluent_ui/fluent_ui.dart';

import 'dialog.dart';
import 'dialog_button.dart';

class GenericDialog extends Dialog {
  final Widget header;
  final List<DialogButton> buttons;
  final EdgeInsets? padding;

  const GenericDialog({Key? key, required this.header, required this.buttons, this.padding}) : super(key: key);

  @override
  Widget build(BuildContext context) => ContentDialog(
      style: ContentDialogThemeData(
          padding: padding ?? const EdgeInsets.only(left: 20, right: 20, top: 15.0, bottom: 5.0)
      ),
      content: header,
      actions: buttons
  );
}