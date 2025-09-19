import 'package:reboot_launcher/src/util/translations.dart';

enum ServerBrowserOrder {
  timeAscending,
  timeDescending,
  nameAscending,
  nameDescending;

  String get translatedName => switch(this) {
    ServerBrowserOrder.timeAscending => translations.timeAscending,
    ServerBrowserOrder.timeDescending => translations.timeDescending,
    ServerBrowserOrder.nameAscending => translations.nameAscending,
    ServerBrowserOrder.nameDescending => translations.nameDescending
  };
}