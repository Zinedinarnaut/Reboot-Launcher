import 'dart:async';
import 'dart:collection';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:reboot_launcher/src/widget/section/host/page.dart';
import 'package:reboot_launcher/src/widget/section/info/page.dart';
import 'package:reboot_launcher/src/widget/section/settings/page.dart';
import 'package:reboot_launcher/src/widget/snackbar/snackbar_area.dart';
import 'package:reboot_launcher/src/widget/page/page_type.dart';
import 'package:reboot_launcher/src/widget/tutorial/tutorial_overlay.dart';
import 'package:reboot_launcher/src/widget/section/backend/page.dart';
import 'package:reboot_launcher/src/widget/section/browser/page.dart';
import 'package:reboot_launcher/src/widget/page/abstract_page.dart';
import 'package:reboot_launcher/src/widget/section/play/page.dart';

final StreamController<void> pagesController = StreamController.broadcast();
bool hitBack = false;

final List<AbstractPage> pages = [
  const PlayPage(),
  const HostPage(),
  const BrowsePage(),
  const BackendPage(),
  const InfoPage(),
  const SettingsPage()
];

final List<GlobalKey<TutorialOverlayTargetState>> _flyoutPageControllers = List.generate(pages.length, (_) => GlobalKey());

final RxInt pageIndex = RxInt(PageType.play.index);

final HashMap<int, GlobalKey> _pageKeys = HashMap();

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey();

final GlobalKey<OverlayState> appOverlayKey = GlobalKey();

final GlobalKey<SnackBarAreaState> infoBarAreaKey = GlobalKey();

GlobalKey get pageKey => getPageKeyByIndex(pageIndex.value);

GlobalKey getPageKeyByIndex(int index) {
  final key = _pageKeys[index];
  if(key != null) {
    return key;
  }

  final result = GlobalKey();
  _pageKeys[index] = result;
  return result;
}

bool get hasPageButton => currentPage.hasButton(currentPageStack.lastOrNull);

AbstractPage get currentPage => pages[pageIndex.value];

final Queue<Object?> appStack = _createAppStack();
Queue _createAppStack() {
  final queue = Queue();
  var lastValue = pageIndex.value;
  pageIndex.listen((index) {
    if(!hitBack && lastValue != index) {
      queue.add(lastValue);
      pagesController.add(null);
    }

    hitBack = false;
    lastValue = index;
  });
  return queue;
}

final Map<int, Queue<String>> _pagesStack = Map.fromEntries(List.generate(pages.length, (index) => MapEntry(index, Queue<String>())));

Queue<String> get currentPageStack => _pagesStack[pageIndex.value]!;

void addSubPageToCurrent(String pageName) {
  final index = pageIndex.value;
  appStack.add(pageName);
  _pagesStack[index]!.add(pageName);
  pagesController.add(null);
}

GlobalKey<TutorialOverlayTargetState> getOverlayTargetKeyByPage(int pageIndex) => _flyoutPageControllers[pageIndex];

GlobalKey<TutorialOverlayTargetState> get pageOverlayTargetKey => _flyoutPageControllers[pageIndex.value];
