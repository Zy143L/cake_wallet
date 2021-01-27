import 'package:cake_wallet/bitcoin/bitcoin_transaction_priority.dart';

class BitcoinTransactionCredentials {
  BitcoinTransactionCredentials(this.address, this.amount, this.priority);

  final String address;
  final String amount;
  BitcoinTransactionPriority priority;
}
