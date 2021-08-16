import 'dart:convert';
import 'package:cake_wallet/bitcoin/bitcoin_address_record.dart';
import 'package:cake_wallet/bitcoin/electrum_balance.dart';
import 'package:cake_wallet/bitcoin/file.dart';
import 'package:cake_wallet/entities/pathForWallet.dart';
import 'package:cake_wallet/entities/wallet_type.dart';

class ElectrumWallletSnapshot {
  ElectrumWallletSnapshot(this.name, this.type, this.password);

  final String name;
  final String password;
  final WalletType type;

  String mnemonic;
  List<BitcoinAddressRecord> addresses;
  ElectrumBalance balance;
  int accountIndex;

  Future<void> load() async {
    try {
      final path = await pathForWallet(name: name, type: type);
      final jsonSource = await read(path: path, password: password);
      final data = json.decode(jsonSource) as Map;
      final addressesTmp = data['addresses'] as List ?? <Object>[];
      mnemonic = data['mnemonic'] as String;
      addresses = addressesTmp
          .whereType<String>()
          .map((addr) => BitcoinAddressRecord.fromJSON(addr))
          .toList();
      balance = ElectrumBalance.fromJSON(data['balance'] as String) ??
          ElectrumBalance(confirmed: 0, unconfirmed: 0);
      accountIndex = 0;

      try {
        accountIndex = int.parse(data['account_index'] as String);
      } catch (_) {}
    } catch (e) {
      print(e);
    }
  }
}
