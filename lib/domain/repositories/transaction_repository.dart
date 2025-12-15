import '../entities/transaction_entity.dart';

abstract class TransactionRepository {
  Stream<void> get onDataChanged;
  Future<void> addTransaction(TransactionEntity transaction);
  Future<void> batchAddTransactions(List<TransactionEntity> transactions);
  Future<List<TransactionEntity>> getTransactions();
  Future<double> getBalance();
  Future<double> getTodaySpending();
  Future<double> getMonthSpending();
  Future<double> getTodayIncome();
  Future<double> getMonthIncome();
  Future<Map<DateTime, double>> getLast7DaysSpending();
  Future<Map<int, double>> getMonthDailySpending();
  Future<Map<String, double>> getCategoryWiseSpending();
  Future<bool> isDuplicate(String utr, String hash);
  Future<void> updateTransaction(TransactionEntity transaction);
  Future<void> deleteTransaction(int id);
  Future<void> clearAllData();
  Future<String> exportDataAsJson();
  Future<void> updateCategoryForAll(String oldCategory, String newCategory);
  
  // Current Balance Management
  Future<double> getCurrentBalance();
  Future<void> updateCurrentBalance(double balance);
  
  // Today's Transactions
  Future<List<TransactionEntity>> getTodayTransactions();
  
  // Deduplication - Layer 3: Time window check
  Future<bool> hasSimilarRecent(double amount, String type, DateTime timestamp);
}
