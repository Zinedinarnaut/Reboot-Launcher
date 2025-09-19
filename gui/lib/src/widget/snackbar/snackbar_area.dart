import 'package:fluent_ui/fluent_ui.dart';
import 'package:reboot_launcher/src/widget/sections.dart';

class SnackBarArea extends StatefulWidget {
  const SnackBarArea({super.key});

  @override
  State<SnackBarArea> createState() => SnackBarAreaState();
}

class SnackBarAreaState extends State<SnackBarArea> {
  final List<Widget> _children = [];

  void insertChild(Widget child) {
    setState(() {
      _children.add(child);
    });
  }

  bool removeChild(Widget child) {
    var result = false;
    setState(() {
      result = _children.remove(child);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: pagesController.stream,
      builder: (context, _) => Padding(
        padding: EdgeInsets.only(
          bottom: hasPageButton ? 72.0 : 16.0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _snackbars,
        ),
      ),
    );
  }

  List<Widget> get _snackbars => _children
      .map((child) => _buildSnackbar(child))
      .toList(growable: false);

  Widget _buildSnackbar(Widget child) => Padding(
    padding: const EdgeInsets.only(top: 12.0),
    child: child,
  );
}