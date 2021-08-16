import 'package:flutter/foundation.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart' as bitcoin;
import 'package:bitcoin_flutter/src/payments/index.dart' show PaymentData;
import 'package:cake_wallet/bitcoin/bitcoin_address_record.dart';
import 'package:cake_wallet/bitcoin/bitcoin_amount_format.dart';
import 'package:cake_wallet/entities/transaction_direction.dart';
import 'package:cake_wallet/entities/transaction_info.dart';
import 'package:cake_wallet/entities/format_amount.dart';
import 'package:cake_wallet/entities/wallet_type.dart';

class ElectrumTransactionInfo extends TransactionInfo {
  ElectrumTransactionInfo(this.type,
      {@required String id,
      @required int height,
      @required int amount,
      @required int fee,
      @required TransactionDirection direction,
      @required bool isPending,
      @required DateTime date,
      @required int confirmations}) {
    this.id = id;
    this.height = height;
    this.amount = amount;
    this.fee = fee;
    this.direction = direction;
    this.date = date;
    this.isPending = isPending;
    this.confirmations = confirmations;
  }

  factory ElectrumTransactionInfo.fromElectrumVerbose(
      Map<String, Object> obj, WalletType type,
      {@required List<BitcoinAddressRecord> addresses, @required int height}) {
    final addressesSet = addresses.map((addr) => addr.address).toSet();
    final id = obj['txid'] as String;
    final vins = obj['vin'] as List<Object> ?? [];
    final vout = (obj['vout'] as List<Object> ?? []);
    final date = obj['time'] is int
        ? DateTime.fromMillisecondsSinceEpoch((obj['time'] as int) * 1000)
        : DateTime.now();
    final confirmations = obj['confirmations'] as int ?? 0;
    var direction = TransactionDirection.incoming;
    var inputsAmount = 0;
    var amount = 0;
    var totalOutAmount = 0;

    for (dynamic vin in vins) {
      final vout = vin['vout'] as int;
      final out = vin['tx']['vout'][vout] as Map;
      final outAddresses =
          (out['scriptPubKey']['addresses'] as List<Object>)?.toSet();
      inputsAmount +=
          stringDoubleToBitcoinAmount((out['value'] as double ?? 0).toString());

      if (outAddresses?.intersection(addressesSet)?.isNotEmpty ?? false) {
        direction = TransactionDirection.outgoing;
      }
    }

    for (dynamic out in vout) {
      final outAddresses =
          out['scriptPubKey']['addresses'] as List<Object> ?? [];
      final ntrs = outAddresses.toSet().intersection(addressesSet);
      final value = stringDoubleToBitcoinAmount(
          (out['value'] as double ?? 0.0).toString());
      totalOutAmount += value;

      if ((direction == TransactionDirection.incoming && ntrs.isNotEmpty) ||
          (direction == TransactionDirection.outgoing && ntrs.isEmpty)) {
        amount += value;
      }
    }

    final fee = inputsAmount - totalOutAmount;

    return ElectrumTransactionInfo(type,
        id: id,
        height: height,
        isPending: false,
        fee: fee,
        direction: direction,
        amount: amount,
        date: date,
        confirmations: confirmations);
  }

  factory ElectrumTransactionInfo.fromHexAndHeader(WalletType type, String hex,
      {List<String> addresses, int height, int timestamp, int confirmations}) {
    final tx = bitcoin.Transaction.fromHex(hex);
    var exist = false;
    var amount = 0;

    if (addresses != null) {
      tx.outs.forEach((out) {
        try {
          final p2pkh = bitcoin.P2PKH(
              data: PaymentData(output: out.script), network: bitcoin.bitcoin);
          exist = addresses.contains(p2pkh.data.address);

          if (exist) {
            amount += out.value;
          }
        } catch (_) {}
      });
    }

    final date = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
        : DateTime.now();

    return ElectrumTransactionInfo(type,
        id: tx.getId(),
        height: height,
        isPending: false,
        fee: null,
        direction: TransactionDirection.incoming,
        amount: amount,
        date: date,
        confirmations: confirmations);
  }

  factory ElectrumTransactionInfo.fromJson(
      Map<String, dynamic> data, WalletType type) {
    return ElectrumTransactionInfo(type,
        id: data['id'] as String,
        height: data['height'] as int,
        amount: data['amount'] as int,
        fee: data['fee'] as int,
        direction: parseTransactionDirectionFromInt(data['direction'] as int),
        date: DateTime.fromMillisecondsSinceEpoch(data['date'] as int),
        isPending: data['isPending'] as bool,
        confirmations: data['confirmations'] as int);
  }

  final WalletType type;

  String _fiatAmount;

  @override
  String amountFormatted() =>
      '${formatAmount(bitcoinAmountToString(amount: amount))} ${walletTypeToCryptoCurrency(type).title}';

  @override
  String feeFormatted() => fee != null
      ? '${formatAmount(bitcoinAmountToString(amount: fee))} ${walletTypeToCryptoCurrency(type).title}'
      : '';

  @override
  String fiatAmount() => _fiatAmount ?? '';

  @override
  void changeFiatAmount(String amount) => _fiatAmount = formatAmount(amount);

  ElectrumTransactionInfo updated(ElectrumTransactionInfo info) {
    return ElectrumTransactionInfo(info.type,
        id: id,
        height: info.height,
        amount: info.amount,
        fee: info.fee,
        direction: direction ?? info.direction,
        date: date ?? info.date,
        isPending: isPending ?? info.isPending,
        confirmations: info.confirmations);
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    m['id'] = id;
    m['height'] = height;
    m['amount'] = amount;
    m['direction'] = direction.index;
    m['date'] = date.millisecondsSinceEpoch;
    m['isPending'] = isPending;
    m['confirmations'] = confirmations;
    m['fee'] = fee;
    return m;
  }
}
