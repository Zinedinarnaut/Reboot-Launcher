import 'package:reboot_launcher/src/util/translations.dart';

enum ServerBrowserFilter {
  all,
  accessible,
  playable;

  String get translatedName => switch(this) {
    ServerBrowserFilter.all => translations.all,
    ServerBrowserFilter.accessible => translations.accessible,
    ServerBrowserFilter.playable => translations.playable
  };
}