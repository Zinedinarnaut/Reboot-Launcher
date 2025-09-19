import 'package:fluent_ui/fluent_ui.dart';
import 'package:reboot_launcher/src/util/translations.dart';

import 'dialog.dart';
import 'dialog_button.dart';
import 'generic_dialog.dart';

class FutureDialog extends Dialog {
  final Future future;
  final String loadingMessage;
  final Widget successfulBody;
  final Widget unsuccessfulBody;
  final Function(Object) errorMessageBuilder;
  final Function()? onError;
  final bool closeAutomatically;

  const FutureDialog(
      {Key? key,
        required this.future,
        required this.loadingMessage,
        required this.successfulBody,
        required this.unsuccessfulBody,
        required this.errorMessageBuilder,
        this.onError,
        this.closeAutomatically = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: future,
        builder: (context, snapshot) => GenericDialog(
            header: _createBody(context, snapshot),
            buttons: [_createButton(context, snapshot)]
        )
    );
  }

  Widget _createBody(BuildContext context, AsyncSnapshot snapshot){
    if (snapshot.hasError) {
      onError?.call();
      return _buildData(errorMessageBuilder(snapshot.error!));
    }

    if(snapshot.connectionState == ConnectionState.done
        && (snapshot.data == null || (snapshot.data is bool && !snapshot.data))){
      return unsuccessfulBody;
    }

    if (!snapshot.hasData) {
      return _loadingBody;
    }

    if(closeAutomatically){
      WidgetsBinding.instance
          .addPostFrameCallback((_) => Navigator.of(context).pop(true));
      return _loadingBody;
    }

    return successfulBody;
  }

  Widget _buildData(String message) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
            message,
            textAlign: TextAlign.center
        )
    );
  }

  Widget get _loadingBody => InfoLabel(
    label: loadingMessage,
    child: Container(
        padding: const EdgeInsets.only(bottom: 16.0),
        width: double.infinity,
        child: const ProgressBar()),
  );

  DialogButton _createButton(BuildContext context, AsyncSnapshot snapshot)=> DialogButton(
      text: snapshot.hasData
          || snapshot.hasError
          || (snapshot.connectionState == ConnectionState.done && snapshot.data == null) ? translations.defaultDialogSecondaryAction : translations.stopLoadingDialogAction,
      type: DialogButtonType.only,
      onTap: () => Navigator.of(context).pop(!snapshot.hasError && snapshot.hasData)
  );
}