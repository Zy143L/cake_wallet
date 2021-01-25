import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/themes/theme_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:package_info/package_info.dart';
import 'package:devicelocale/devicelocale.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/wallet_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cake_wallet/entities/language_service.dart';
import 'package:cake_wallet/entities/balance_display_mode.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/entities/node.dart';
import 'package:cake_wallet/entities/transaction_priority.dart';
import 'package:cake_wallet/entities/action_list_display_mode.dart';

part 'settings_store.g.dart';

class SettingsStore = SettingsStoreBase with _$SettingsStore;

abstract class SettingsStoreBase with Store {
  SettingsStoreBase(
      {@required SharedPreferences sharedPreferences,
      @required FiatCurrency initialFiatCurrency,
      @required TransactionPriority initialTransactionPriority,
      @required BalanceDisplayMode initialBalanceDisplayMode,
      @required bool initialSaveRecipientAddress,
      @required bool initialAllowBiometricalAuthentication,
      @required ThemeBase initialTheme,
      @required int initialPinLength,
      @required String initialLanguageCode,
      // @required String initialCurrentLocale,
      @required this.appVersion,
      @required Map<WalletType, Node> nodes,
      this.actionlistDisplayMode}) {
    fiatCurrency = initialFiatCurrency;
    transactionPriority = initialTransactionPriority;
    balanceDisplayMode = initialBalanceDisplayMode;
    shouldSaveRecipientAddress = initialSaveRecipientAddress;
    allowBiometricalAuthentication = initialAllowBiometricalAuthentication;
    currentTheme = initialTheme;
    pinCodeLength = initialPinLength;
    languageCode = initialLanguageCode;
    this.nodes = ObservableMap<WalletType, Node>.of(nodes);
    _sharedPreferences = sharedPreferences;

    reaction(
        (_) => fiatCurrency,
        (FiatCurrency fiatCurrency) => sharedPreferences.setString(
            PreferencesKey.currentFiatCurrencyKey, fiatCurrency.serialize()));

    reaction(
        (_) => transactionPriority,
        (TransactionPriority priority) => sharedPreferences.setInt(
            PreferencesKey.currentTransactionPriorityKey,
            priority.serialize()));

    reaction(
        (_) => shouldSaveRecipientAddress,
        (bool shouldSaveRecipientAddress) => sharedPreferences.setBool(
            PreferencesKey.shouldSaveRecipientAddressKey,
            shouldSaveRecipientAddress));

    reaction(
        (_) => currentTheme,
        (ThemeBase theme) =>
            sharedPreferences.setInt(PreferencesKey.currentTheme, theme.raw));

    reaction(
        (_) => allowBiometricalAuthentication,
        (bool biometricalAuthentication) => sharedPreferences.setBool(
            PreferencesKey.allowBiometricalAuthenticationKey,
            biometricalAuthentication));

    reaction(
        (_) => pinCodeLength,
        (int pinLength) => sharedPreferences.setInt(
            PreferencesKey.currentPinLength, pinLength));

    reaction(
        (_) => languageCode,
        (String languageCode) => sharedPreferences.setString(
            PreferencesKey.currentLanguageCode, languageCode));

    reaction(
        (_) => balanceDisplayMode,
        (BalanceDisplayMode mode) => sharedPreferences.setInt(
            PreferencesKey.currentBalanceDisplayModeKey, mode.serialize()));

    this
        .nodes
        .observe((change) => _saveCurrentNode(change.newValue, change.key));
  }

  static const defaultPinLength = 4;
  static const defaultActionsMode = 11;

  @observable
  FiatCurrency fiatCurrency;

  @observable
  ObservableList<ActionListDisplayMode> actionlistDisplayMode;

  @observable
  TransactionPriority transactionPriority;

  @observable
  BalanceDisplayMode balanceDisplayMode;

  @observable
  bool shouldSaveRecipientAddress;

  @observable
  bool allowBiometricalAuthentication;

  @observable
  ThemeBase currentTheme;

  @observable
  int pinCodeLength;

  @computed
  ThemeData get theme => currentTheme.themeData;

  @observable
  String languageCode;

  String appVersion;

  SharedPreferences _sharedPreferences;

  ObservableMap<WalletType, Node> nodes;

  Node getCurrentNode(WalletType walletType) => nodes[walletType];

  static Future<SettingsStore> load(
      {@required Box<Node> nodeSource,
      FiatCurrency initialFiatCurrency = FiatCurrency.usd,
      TransactionPriority initialTransactionPriority = TransactionPriority.slow,
      BalanceDisplayMode initialBalanceDisplayMode =
          BalanceDisplayMode.availableBalance}) async {
    final sharedPreferences = await getIt.getAsync<SharedPreferences>();
    final currentFiatCurrency = FiatCurrency(
        symbol:
            sharedPreferences.getString(PreferencesKey.currentFiatCurrencyKey));
    final currentTransactionPriority = TransactionPriority.deserialize(
        raw: sharedPreferences
            .getInt(PreferencesKey.currentTransactionPriorityKey));
    final currentBalanceDisplayMode = BalanceDisplayMode.deserialize(
        raw: sharedPreferences
            .getInt(PreferencesKey.currentBalanceDisplayModeKey));
    final shouldSaveRecipientAddress =
        sharedPreferences.getBool(PreferencesKey.shouldSaveRecipientAddressKey);
    final allowBiometricalAuthentication = sharedPreferences
            .getBool(PreferencesKey.allowBiometricalAuthenticationKey) ??
        false;
    final legacyTheme =
        (sharedPreferences.getBool(PreferencesKey.isDarkThemeLegacy) ?? false)
            ? ThemeType.dark.index
            : ThemeType.bright.index;
    final savedTheme = ThemeList.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.currentTheme) ??
            legacyTheme ??
            0);
    final actionListDisplayMode = ObservableList<ActionListDisplayMode>();
    actionListDisplayMode.addAll(deserializeActionlistDisplayModes(
        sharedPreferences.getInt(PreferencesKey.displayActionListModeKey) ??
            defaultActionsMode));
    var pinLength = sharedPreferences.getInt(PreferencesKey.currentPinLength);
    // If no value
    if (pinLength == null || pinLength == 0) {
      pinLength = defaultPinLength;
    }

    final savedLanguageCode =
        sharedPreferences.getString(PreferencesKey.currentLanguageCode) ??
            await LanguageService.localeDetection();
    final nodeId = sharedPreferences.getInt(PreferencesKey.currentNodeIdKey);
    final bitcoinElectrumServerId = sharedPreferences
        .getInt(PreferencesKey.currentBitcoinElectrumSererIdKey);
    final moneroNode = nodeSource.get(nodeId);
    final bitcoinElectrumServer = nodeSource.get(bitcoinElectrumServerId);
    final packageInfo = await PackageInfo.fromPlatform();

    return SettingsStore(
        sharedPreferences: sharedPreferences,
        nodes: {
          WalletType.monero: moneroNode,
          WalletType.bitcoin: bitcoinElectrumServer
        },
        appVersion: packageInfo.version,
        initialFiatCurrency: currentFiatCurrency,
        initialTransactionPriority: currentTransactionPriority,
        initialBalanceDisplayMode: currentBalanceDisplayMode,
        initialSaveRecipientAddress: shouldSaveRecipientAddress,
        initialAllowBiometricalAuthentication: allowBiometricalAuthentication,
        initialTheme: savedTheme,
        actionlistDisplayMode: actionListDisplayMode,
        initialPinLength: pinLength,
        initialLanguageCode: savedLanguageCode);
  }

  Future<void> reload(
      {@required Box<Node> nodeSource,
      FiatCurrency initialFiatCurrency = FiatCurrency.usd,
      TransactionPriority initialTransactionPriority = TransactionPriority.slow,
      BalanceDisplayMode initialBalanceDisplayMode =
          BalanceDisplayMode.availableBalance}) async {
    final settings = await SettingsStoreBase.load(
        nodeSource: nodeSource,
        initialBalanceDisplayMode: initialBalanceDisplayMode,
        initialFiatCurrency: initialFiatCurrency,
        initialTransactionPriority: initialTransactionPriority);
    fiatCurrency = settings.fiatCurrency;
    actionlistDisplayMode = settings.actionlistDisplayMode;
    transactionPriority = settings.transactionPriority;
    balanceDisplayMode = settings.balanceDisplayMode;
    shouldSaveRecipientAddress = settings.shouldSaveRecipientAddress;
    allowBiometricalAuthentication = settings.allowBiometricalAuthentication;
    currentTheme = settings.currentTheme;
    pinCodeLength = settings.pinCodeLength;
    languageCode = settings.languageCode;
    appVersion = settings.appVersion;
  }

  Future<void> _saveCurrentNode(Node node, WalletType walletType) async {
    switch (walletType) {
      case WalletType.bitcoin:
        await _sharedPreferences.setInt(
            PreferencesKey.currentBitcoinElectrumSererIdKey, node.key as int);
        break;
      case WalletType.monero:
        await _sharedPreferences.setInt(
            PreferencesKey.currentNodeIdKey, node.key as int);
        break;
      default:
        break;
    }

    nodes[walletType] = node;
  }
}
