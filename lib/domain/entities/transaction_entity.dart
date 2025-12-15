enum TransactionType { debit, credit }

class TransactionEntity {
  final int? id;
  final double amount;
  final TransactionType type;
  final String category;
  final String merchant; // or "Description" / "Sender"
  final String utr;
  final DateTime timestamp;
  final String hash;
  final String source; // 'SMS' or 'MANUAL'
  final String? description;

  TransactionEntity({
    this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.utr,
    required this.timestamp,
    required this.hash,
    this.source = 'SMS',
    this.description,
  });
}
