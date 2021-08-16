import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/monero/monero_wallet_service.dart';
import 'package:cake_wallet/bitcoin/bitcoin_wallet_creation_credentials.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/core/wallet_base.dart';
import 'package:cake_wallet/core/wallet_creation_service.dart';
import 'package:cake_wallet/core/wallet_credentials.dart';
import 'package:cake_wallet/entities/wallet_info.dart';
import 'package:cake_wallet/entities/wallet_type.dart';
import 'package:cake_wallet/view_model/wallet_creation_vm.dart';

part 'wallet_new_vm.g.dart';

class WalletNewVM = WalletNewVMBase with _$WalletNewVM;

abstract class WalletNewVMBase extends WalletCreationVM with Store {
  WalletNewVMBase(AppStore appStore, this._walletCreationService,
      Box<WalletInfo> walletInfoSource,
      {@required WalletType type})
      : selectedMnemonicLanguage = '',
        super(appStore, walletInfoSource, type: type, isRecovery: false);

  @observable
  String selectedMnemonicLanguage;

  bool get hasLanguageSelector => type == WalletType.monero;

  final WalletCreationService _walletCreationService;

  @override
  WalletCredentials getCredentials(dynamic options) {
    switch (type) {
      case WalletType.monero:
        return MoneroNewWalletCredentials(
            name: name, language: options as String);
      case WalletType.bitcoin:
        return BitcoinNewWalletCredentials(name: name);
      case WalletType.litecoin:
        return BitcoinNewWalletCredentials(name: name);
      default:
        return null;
    }
  }

  @override
  Future<WalletBase> process(WalletCredentials credentials) async {
    _walletCreationService.changeWalletType(type: type);
    return _walletCreationService.create(credentials);
  }
}
