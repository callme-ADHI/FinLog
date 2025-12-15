import '../../domain/entities/transaction_entity.dart';

class TransactionModel extends TransactionEntity {
  TransactionModel({
    int? id,
    required double amount,
    required TransactionType type,
    required String category,
    required String merchant,
    required String utr,
    required DateTime timestamp,
    required String hash,
    String source = 'SMS',
    String? description,
  }) : super(
          id: id,
          amount: amount,
          type: type,
          category: category,
          merchant: merchant,
          utr: utr,
          timestamp: timestamp,
          hash: hash,
          source: source,
          description: description,
        );

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      amount: map['amount'],
      type: TransactionType.values.firstWhere((e) => e.toString() == map['type']),
      category: map['category'],
      merchant: map['merchant'],
      utr: map['utr'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      hash: map['hash'],
      source: map['source'] ?? 'SMS',
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type.toString(),
      'category': category,
      'merchant': merchant,
      'utr': utr,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'hash': hash,
      'source': source,
      'description': description,
    };
  }
}
