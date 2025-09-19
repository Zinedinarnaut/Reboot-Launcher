import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:clipboard/clipboard.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as fluentIcons show FluentIcons;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:reboot_common/common.dart';
import 'package:reboot_launcher/src/controller/backend_controller.dart';
import 'package:reboot_launcher/src/controller/game_controller.dart';
import 'package:reboot_launcher/src/controller/hosting_controller.dart';
import 'package:reboot_launcher/src/controller/server_browser_controller.dart';
import 'package:reboot_launcher/src/widget/dialog/dialog.dart';
import 'package:reboot_launcher/src/widget/dialog/dialog_button.dart';
import 'package:reboot_launcher/src/widget/dialog/form_dialog.dart';
import 'package:reboot_launcher/src/widget/snackbar/snackbar.dart';
import 'package:reboot_launcher/src/widget/section/browser/filter.dart';
import 'package:reboot_launcher/src/widget/section/browser/order.dart';
import 'package:reboot_launcher/src/widget/section/sections.dart';
import 'package:reboot_launcher/src/widget/page/page_type.dart';
import 'package:reboot_launcher/src/util/cryptography.dart';
import 'package:reboot_launcher/src/util/extensions.dart';
import 'package:reboot_launcher/src/util/matchmaker.dart';
import 'package:reboot_launcher/src/util/translations.dart';
import 'package:reboot_launcher/src/widget/section/setting_tile.dart';
import 'package:reboot_launcher/src/widget/page/abstract_page.dart';

class BrowsePage extends AbstractPage {
  const BrowsePage({Key? key}) : super(key: key);

  @override
  String get name => translations.browserName;

  @override
  PageType get type => PageType.browser;

  @override
  String get iconAsset => "assets/images/server_browser.png";

  @override
  bool hasButton(String? pageName) => false;

  @override
  AbstractPageState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends AbstractPageState<BrowsePage> {
  final GameController _gameController = Get.find<GameController>();
  final HostingController _hostingController = Get.find<HostingController>();
  final BackendController _backendController = Get.find<BackendController>();
  final ServerBrowserController _serverBrowserController = Get.find<ServerBrowserController>();
  final TextEditingController _filterController = TextEditingController();
  final StreamController<String> _filterControllerStream = StreamController.broadcast();

  final Rx<ServerBrowserFilter> _filter = Rx(ServerBrowserFilter.all);
  final Rx<ServerBrowserOrder> _sort = Rx(ServerBrowserOrder.timeDescending);

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAppLink();
    });
    super.initState();
  }

  void _initAppLink() async {
    final appLinks = AppLinks();
    final initialUrl = await appLinks.getInitialLink();
    if(initialUrl != null) {
      _onAppLink(initialUrl);
    }

    appLinks.uriLinkStream.listen(_onAppLink);
  }

  void _onAppLink(Uri uri) {
    final uuid = uri.host;
    final server = _serverBrowserController.getServerById(uuid);
    if(server != null) {
      _joinServer(_hostingController.uuid, server);
    }else {
      SnackBar.open(
          translations.noServerFound,
          duration: infoBarLongDuration,
          severity: InfoBarSeverity.error
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      final servers = _serverBrowserController.servers.value;
      return servers?.isEmpty == true
          ? _noServers
          : _buildPageBody(servers);
    });
  }

  Widget get _noServers => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        translations.noServersAvailableTitle,
        style: FluentTheme.of(context).typography.titleLarge,
      ),
      Text(
          translations.noServersAvailableSubtitle,
          style: FluentTheme.of(context).typography.body
      ),
    ],
  );

  Widget _buildPageBody(List<ServerBrowserEntry>? data) => StreamBuilder(
      stream: _filterControllerStream.stream,
      builder: (context, filterSnapshot)  {
        final items = data
            ?.where((entry) => _isValidItem(entry, filterSnapshot.data))
            .toList(growable: false);
        return Column(
          children: [
            _searchBar,
            const SizedBox(
              height: 24,
            ),
            Row(
              children: [
                _buildFilterSection(context),
                const SizedBox(
                    width: 16.0
                ),
                _buildOrderSection(context),
              ],
            ),
            const SizedBox(
              height: 24,
            ),
            Expanded(
                child: _buildPopulatedListBody(items)
            ),
          ],
        );
      }
  );

  Widget _buildOrderSection(BuildContext context) => Row(
    children: [
      Icon(
          fluentIcons.FluentIcons.arrow_sort_24_regular,
          color: FluentTheme.of(context).resources.textFillColorDisabled
      ),
      const SizedBox(width: 4.0),
      Text(
        "Sort by: ",
        style: TextStyle(
            color: FluentTheme.of(context).resources.textFillColorDisabled
        ),
      ),
      const SizedBox(width: 4.0),
      Obx(() => SizedBox(
        width: 230,
        child: DropDownButton(
            leading: Text(
                _sort.value.translatedName,
                textAlign: TextAlign.start
            ),
            title: const Spacer(),
            items: _orders
        ),
      ))
    ],
  );

  List<MenuFlyoutItem> get _orders => ServerBrowserOrder.values
      .map(_buildOrder)
      .toList();

  MenuFlyoutItem _buildOrder(ServerBrowserOrder entry) => MenuFlyoutItem(
      text: Text(entry.translatedName),
      onPressed: () => _sort.value = entry
  );

  Widget _buildFilterSection(BuildContext context) => Row(
      children: [
        Icon(
            fluentIcons.FluentIcons.filter_24_regular,
            color: FluentTheme.of(context).resources.textFillColorDisabled
        ),
        const SizedBox(width: 4.0),
        Text(
          "Filter by: ",
          style: TextStyle(
              color: FluentTheme.of(context).resources.textFillColorDisabled
          ),
        ),
        const SizedBox(width: 4.0),
        Obx(() => SizedBox(
          width: 125,
          child: DropDownButton(
              leading: Text(
                  _filter.value.translatedName,
                  textAlign: TextAlign.start
              ),
              title: const Spacer(),
              items: _filters
          ),
        ))
      ],
    );

  List<MenuFlyoutItem> get _filters => ServerBrowserFilter.values
      .map((entry) => _buildFilter(entry))
      .toList();

  MenuFlyoutItem _buildFilter(ServerBrowserFilter entry) => MenuFlyoutItem(
      text: Text(entry.translatedName),
      onPressed: () => _filter.value = entry
  );

  Widget _buildPopulatedListBody(List<ServerBrowserEntry>? items) => Obx(() {
    final filter = _filter.value;
    final sorted = items?.where((element) {
      switch(filter) {
        case ServerBrowserFilter.all:
          return true;
        case ServerBrowserFilter.accessible:
          return element.password.isNotEmpty;
        case ServerBrowserFilter.playable:
          return _gameController.getVersionByGame(element.version) != null;
      }
    }).toList();
    final sort = _sort.value;
    sorted?.sort((first, second) {
      switch(sort) {
        case ServerBrowserOrder.timeAscending:
          return first.timestamp.compareTo(second.timestamp);
        case ServerBrowserOrder.timeDescending:
          return second.timestamp.compareTo(first.timestamp);
        case ServerBrowserOrder.nameAscending:
          return first.name.compareTo(second.name);
        case ServerBrowserOrder.nameDescending:
          return second.name.compareTo(first.name);
      }
    });
    if(sorted?.isEmpty == true) {
      return _noServersByQuery;
    }

    return ListView.builder(
        itemCount: sorted?.length,
        physics: sorted == null ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final entry = sorted?.elementAt(index);
          if (entry == null) {
            return const SettingTile();
          } else {
            final hasPassword = entry.password.isNotEmpty;
            return SettingTile(
                icon: Icon(
                    hasPassword ? FluentIcons.lock : FluentIcons.globe
                ),
                title: Text(
                    "${_formatName(entry)} • ${entry.author}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis
                ),
                subtitle: Text(
                    "${_formatDescription(entry)} • ${_formatVersion(entry)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis
                ),
                content: Button(
                  onPressed: () => _joinServer(_hostingController.uuid, entry),
                  child: Text(
                      _backendController.type.value == AuthBackendType.embedded
                          ? translations.joinServer
                          : translations.copyIp),
                )
            );
          }
        }
    );
  });

  Widget get _noServersByQuery => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        translations.noServersAvailableByQueryTitle,
        style: FluentTheme.of(context).typography.titleLarge,
      ),
      Text(
          translations.noServersAvailableByQuerySubtitle,
          style: FluentTheme.of(context).typography.body
      ),
    ],
  );

  bool _isValidItem(ServerBrowserEntry entry, String? filter) =>
      filter == null || filter.isEmpty || _filterServer(entry, filter);

  bool _filterServer(ServerBrowserEntry element, String filter) {
    filter = filter.toLowerCase();

    final uri = Uri.tryParse(filter);
    if(uri != null && uri.host.isNotEmpty && element.id.toLowerCase().contains(uri.host.toLowerCase())) {
      return true;
    }

    return element.id.toLowerCase().contains(filter.toLowerCase())
        || element.name.toLowerCase().contains(filter)
        || element.author.toLowerCase().contains(filter)
        || element.description.toLowerCase().contains(filter);
  }

  Widget get _searchBar => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: 350
      ),
      child: TextBox(
        placeholder: translations.findServer,
        controller: _filterController,
        autofocus: true,
        onChanged: (value) => _filterControllerStream.add(value),
        suffix: _searchBarIcon,
      ),
    ),
  );

  Widget get _searchBarIcon => Button(
      onPressed: _filterController.text.isEmpty ? null : () {
        _filterController.clear();
        _filterControllerStream.add("");
      },
      style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(Border())
      ),
      child: _searchBarIconData
  );

  Widget get _searchBarIconData {
    final color = FluentTheme.of(context).resources.textFillColorPrimary;
    if (_filterController.text.isNotEmpty) {
      return Icon(
          FluentIcons.clear,
          size: 8.0,
          color: color
      );
    }

    return Transform.flip(
      flipX: true,
      child: Icon(
          FluentIcons.search,
          size: 12.0,
          color: color
      ),
    );
  }

  String _formatName(ServerBrowserEntry server) {
    final result = server.name;
    return result.isEmpty ? translations.defaultServerName : result;
  }

  String _formatDescription(ServerBrowserEntry server) {
    final result = server.description;
    return result.isEmpty ? translations.defaultServerDescription : result;
  }

  String _formatVersion(ServerBrowserEntry server) => "Fortnite ${server.version.toString()}";

  Future<void> _joinServer(String uuid, ServerBrowserEntry server) async {
    if(!kDebugMode && uuid == server.id) {
      SnackBar.open(
          translations.joinSelfServer,
          duration: infoBarLongDuration,
          severity: InfoBarSeverity.error
      );
      return;
    }

    final version = _gameController.getVersionByGame(server.version.toString());
    if(version == null) {
      SnackBar.open(
          translations.cannotJoinServerVersion(server.version.toString()),
          duration: infoBarLongDuration,
          severity: InfoBarSeverity.error
      );
      return;
    }

    final hashedPassword = server.password;
    final embedded = _backendController.type.value == AuthBackendType.embedded;
    final author = server.author;
    final encryptedIp = server.ip;
    if(hashedPassword.isEmpty) {
      final valid = await _isServerValid(server.name, encryptedIp);
      if(!valid) {
        return;
      }

      _onServerJoined(embedded, encryptedIp, author, version);
      return;
    }

    final confirmPassword = await _askForPassword();
    if(confirmPassword == null) {
      return;
    }

    if(!checkPassword(confirmPassword, hashedPassword)) {
      SnackBar.open(
          translations.wrongServerPassword,
          duration: infoBarLongDuration,
          severity: InfoBarSeverity.error
      );
      return;
    }

    final decryptedIp = aes256Decrypt(encryptedIp, confirmPassword);
    final valid = await _isServerValid(server.name, decryptedIp);
    if(!valid) {
      return;
    }

    _onServerJoined(embedded, decryptedIp, author, version);
  }

  Future<bool> _isServerValid(String name, String address) async {
    final loadingBar = SnackBar.open(
        translations.joiningServer(name),
        duration: infoBarLongDuration,
        loading: true,
        severity: InfoBarSeverity.info
    );
    final result = await pingGameServer(address)
        .withMinimumDuration(const Duration(seconds: 1));
    loadingBar.close();
    if(result) {
      return true;
    }

    SnackBar.open(
        translations.offlineServer,
        duration: infoBarLongDuration,
        severity: InfoBarSeverity.error
    );
    return false;
  }

  Future<String?> _askForPassword() async {
    final confirmPasswordController = TextEditingController();
    final showPassword = RxBool(false);
    final showPasswordTrailing = RxBool(false);
    return await Dialog.open<String?>(
        builder: (context) => FormDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoLabel(
                    label: translations.serverPassword,
                    child: Obx(() => TextFormBox(
                        placeholder: translations.serverPasswordPlaceholder,
                        controller: confirmPasswordController,
                        autovalidateMode: AutovalidateMode.always,
                        obscureText: !showPassword.value,
                        enableSuggestions: false,
                        autofocus: true,
                        autocorrect: false,
                        onChanged: (text) => showPasswordTrailing.value = text.isNotEmpty,
                        suffix: !showPasswordTrailing.value ? null : Button(
                          onPressed: () => showPassword.value = !showPassword.value,
                          style: ButtonStyle(
                              shape: WidgetStateProperty.all(const CircleBorder()),
                              backgroundColor: WidgetStateProperty.all(Colors.transparent)
                          ),
                          child: Icon(
                              showPassword.value ? fluentIcons.FluentIcons.eye_off_24_regular : fluentIcons.FluentIcons.eye_24_regular
                          ),
                        )
                    ))
                ),
                const SizedBox(height: 8.0)
              ],
            ),
            buttons: [
              DialogButton(
                  text: translations.serverPasswordCancel,
                  type: DialogButtonType.secondary
              ),

              DialogButton(
                  text: translations.serverPasswordConfirm,
                  type: DialogButtonType.primary,
                  onTap: () => Navigator.of(context).pop(confirmPasswordController.text)
              )
            ]
        )
    );
  }

  void _onServerJoined(bool embedded, String decryptedIp, String author, GameVersion version) {
    if(embedded) {
      _backendController.gameServerAddress.text = decryptedIp;
      pageIndex.value = PageType.play.index;
    }else {
      FlutterClipboard.controlC(decryptedIp);
    }
    Get.find<GameController>().selectedVersion.value = version;
    WidgetsBinding.instance.addPostFrameCallback((_) => SnackBar.open(
        embedded ? translations.joinedServer(author) : translations.copiedIp,
        duration: infoBarLongDuration,
        severity: InfoBarSeverity.success
    ));
  }
  
  @override
  Widget? get button => null;

  @override
  List<Widget> get settings => [];
}