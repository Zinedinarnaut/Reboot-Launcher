import 'package:fluent_ui/fluent_ui.dart' as fluent show showDialog;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:reboot_launcher/src/widget/section/sections.dart';

abstract class Dialog extends StatelessWidget {
  static Future<T?> open<T extends Object?>({
    required WidgetBuilder builder,
    bool dismissWithEsc = true
  })  => fluent.showDialog(
      context: appNavigatorKey.currentContext!,
      useRootNavigator: false,
      dismissWithEsc: dismissWithEsc,
      builder: builder
  );

  const Dialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context);
}