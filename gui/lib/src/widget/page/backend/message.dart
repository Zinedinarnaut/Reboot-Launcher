import 'package:fluent_ui/fluent_ui.dart';
import 'package:reboot_common/common.dart';
import 'package:reboot_launcher/src/widget/snackbar/snackbar.dart';
import 'package:reboot_launcher/src/util/translations.dart';
import 'package:url_launcher/url_launcher.dart';

SnackBar? onBackendResult(AuthBackendType type, AuthBackendEvent event) {
  switch (event.type) {
    case AuthBackendEventType.starting:
      return SnackBar.open(
          translations.startingServer,
          severity: InfoBarSeverity.info,
          loading: true,
          duration: null
      );
    case AuthBackendEventType.startSuccess:
      return SnackBar.open(
          type == AuthBackendType.local
              ? translations.checkedServer
              : translations.startedServer,
          severity: InfoBarSeverity.success
      );
    case AuthBackendEventType.startError:
      return SnackBar.open(
          type == AuthBackendType.local
              ? translations.localServerError(event.error ?? translations.unknownError)
              : translations.startServerError(event.error ?? translations.unknownError),
          severity: InfoBarSeverity.error,
          duration: infoBarLongDuration
      );
    case AuthBackendEventType.stopping:
      return SnackBar.open(
          translations.stoppingServer,
          severity: InfoBarSeverity.info,
          loading: true,
          duration: null
      );
    case AuthBackendEventType.stopSuccess:
      return SnackBar.open(
          translations.stoppedServer,
          severity: InfoBarSeverity.success
      );
    case AuthBackendEventType.stopError:
      return SnackBar.open(
          translations.stopServerError(event.error ?? translations.unknownError),
          severity: InfoBarSeverity.error,
          duration: infoBarLongDuration
      );
    case AuthBackendEventType.startMissingHostError:
      return SnackBar.open(
          translations.missingHostNameError,
          severity: InfoBarSeverity.error
      );
    case AuthBackendEventType.startMissingPortError:
      return SnackBar.open(
          translations.missingPortError,
          severity: InfoBarSeverity.error
      );
    case AuthBackendEventType.startIllegalPortError:
      return SnackBar.open(
          translations.illegalPortError,
          severity: InfoBarSeverity.error
      );
    case AuthBackendEventType.startFreeingPort:
      return SnackBar.open(
          translations.freeingPort,
          loading: true,
          duration: null
      );
    case AuthBackendEventType.startFreePortSuccess:
      return SnackBar.open(
          translations.freedPort,
          severity: InfoBarSeverity.success,
          duration: infoBarShortDuration
      );
    case AuthBackendEventType.startFreePortError:
      return SnackBar.open(
          translations.freePortError(event.error ?? translations.unknownError),
          severity: InfoBarSeverity.error,
          duration: infoBarLongDuration
      );
    case AuthBackendEventType.startPingingRemote:
      return SnackBar.open(
          translations.pingingServer(AuthBackendType.remote.name),
          severity: InfoBarSeverity.info,
          loading: true,
          duration: null
      );
    case AuthBackendEventType.startPingingLocal:
      return SnackBar.open(
          translations.pingingServer(type.name),
          severity: InfoBarSeverity.info,
          loading: true,
          duration: null
      );
    case AuthBackendEventType.startPingError:
      return SnackBar.open(
          translations.pingError(type.name),
          severity: InfoBarSeverity.error
      );
    case AuthBackendEventType.startedImplementation:
      return null;
    }
}

void onBackendError(Object error) {
    SnackBar.open(
        translations.backendErrorMessage,
        severity: InfoBarSeverity.error,
        duration: infoBarLongDuration,
        action: Button(
          onPressed: () => launchUrl(launcherLogFile.uri),
          child: Text(translations.openLog),
        )
    );
}