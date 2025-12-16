import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/db_helper.dart';
import '../models/transaction_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'dart:async';

class TransactionRepositoryImpl implements TransactionRepository {
  final DBHelper dbHelper;
  final _controller = StreamController<void>.broadcast();

  TransactionRepositoryImpl(this.dbHelper);

  @override
  Stream<void> get onDataChanged => _controller.stream;

  @override
  Future<void> addTransaction(TransactionEntity transaction) async {
    print('💾 REPO: addTransaction called - Amount: ${transaction.amount}, Type: ${transaction.type}');
    
    final model = TransactionModel(
      amount: transaction.amount,
      type: transaction.type,
      category: transaction.category,
      merchant: transaction.merchant,
      utr: transaction.utr,
      timestamp: transaction.timestamp,
      hash: transaction.hash,
      source: transaction.source,
      description: transaction.description,
    );
    
    await dbHelper.create(model.toMap());
    print('✅ REPO: Transaction inserted into database');
    
    // Update current balance
    final prefs = await SharedPreferences.getInstance();
    final currentBalance = prefs.getDouble('current_balance') ?? 0.0;
    print('💰 REPO: Current balance: ₹$currentBalance');
    
    double newBalance;
    
    if (transaction.type == TransactionType.credit) {
      newBalance = currentBalance + transaction.amount;
      print('➕ REPO: CREDIT transaction - Adding ${transaction.amount}');
    } else {
      newBalance = currentBalance - transaction.amount;
      print('➖ REPO: DEBIT transaction - Subtracting ${transaction.amount}');
    }
    
    await prefs.setDouble('current_balance', newBalance);
    print('💰 REPO: New balance saved: ₹$newBalance');
    
    print('🔔 REPO: Firing StreamController to notify UI...');
    _controller.add(null);
    print('✅ REPO: StreamController fired! Listeners should rebuild now.');
  }

  @override
  Future<void> batchAddTransactions(List<TransactionEntity> transactions) async {
    if (transactions.isEmpty) return;
    
    print('💾 REPO: batchAddTransactions called with ${transactions.length} transactions');
    final db = await dbHelper.database;
    final batch = db.batch();
    
    // Sort by timestamp (oldest first) so we assume correct order if needed,
    // though for balance calculation we might use the extracted balance instead.
    // Just inserting them here.
    
    for (var transaction in transactions) {
       final model = TransactionModel(
        amount: transaction.amount,
        type: transaction.type,
        category: transaction.category,
        merchant: transaction.merchant,
        utr: transaction.utr,
        timestamp: transaction.timestamp,
        hash: transaction.hash,
        source: transaction.source,
        description: transaction.description,
      );
      batch.insert('transactions', model.toMap());
    }
    
    await batch.commit(noResult: true);
    print('✅ REPO: Batch insert complete');
    
    // Notify UI once
    print('🔔 REPO: Firing StreamController (BATCH)...');
    _controller.add(null);
  }

  @override
  Future<List<TransactionEntity>> getTransactions() async {
    final result = await dbHelper.readAll();
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  @override
  Future<double> getBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final openingBalance = prefs.getDouble('opening_balance') ?? 0.0;

    final result = await dbHelper.readAll();
    double credit = 0;
    double debit = 0;

    for (var row in result) {
      final t = TransactionModel.fromMap(row);
      if (t.type == TransactionType.credit) {
        credit += t.amount;
      } else {
        debit += t.amount;
      }
    }

    return openingBalance + credit - debit;
  }

  @override
  Future<double> getTodaySpending() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND timestamp BETWEEN ? AND ?',
      [TransactionType.debit.toString(), startOfDay, endOfDay]
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as double;
    }
    return 0.0;
  }

  @override
  Future<double> getMonthSpending() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final nextMonth = DateTime(now.year, now.month + 1, 1).millisecondsSinceEpoch;

    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND timestamp >= ? AND timestamp < ?',
      [TransactionType.debit.toString(), startOfMonth, nextMonth]
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as double;
    }
    return 0.0;
  }

  @override
  Future<double> getTodayIncome() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND timestamp BETWEEN ? AND ?',
      [TransactionType.credit.toString(), startOfDay, endOfDay]
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as double;
    }
    return 0.0;
  }

  @override
  Future<double> getMonthIncome() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final nextMonth = DateTime(now.year, now.month + 1, 1).millisecondsSinceEpoch;

    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND timestamp >= ? AND timestamp < ?',
      [TransactionType.credit.toString(), startOfMonth, nextMonth]
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as double;
    }
    return 0.0;
  }

  @override
  Future<Map<DateTime, double>> getLast7DaysSpending() async {
    final now = DateTime.now();
    final db = await dbHelper.database;
    Map<DateTime, double> stats = {};

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;

      final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND timestamp BETWEEN ? AND ?',
        [TransactionType.debit.toString(), start, end]
      );

      double total = 0.0;
      if (result.isNotEmpty && result.first['total'] != null) {
        total = result.first['total'] as double;
      }
      stats[DateTime(day.year, day.month, day.day)] = total;
    }
    return stats;
  }

  @override
  Future<Map<int, double>> getMonthDailySpending() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final nextMonth = DateTime(now.year, now.month + 1, 1).millisecondsSinceEpoch;

    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT timestamp, amount FROM transactions WHERE type = ? AND timestamp >= ? AND timestamp < ?',
      [TransactionType.debit.toString(), startOfMonth, nextMonth]
    );

    Map<int, double> stats = {};
    // Initialize all days of month with 0
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    for (int i = 1; i <= daysInMonth; i++) {
      stats[i] = 0.0;
    }

    for (var row in result) {
      if (row['timestamp'] != null && row['amount'] != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int);
        final amount = row['amount'] as double;
        stats[date.day] = (stats[date.day] ?? 0) + amount;
      }
    }
    return stats;
  }

  @override
  Future<Map<String, double>> getCategoryWiseSpending() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final nextMonth = DateTime(now.year, now.month + 1, 1).millisecondsSinceEpoch;

    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT category, SUM(amount) as total FROM transactions WHERE type = ? AND timestamp >= ? AND timestamp < ? GROUP BY category',
      [TransactionType.debit.toString(), startOfMonth, nextMonth]
    );

    Map<String, double> stats = {};
    for (var row in result) {
      if (row['category'] != null && row['total'] != null) {
        stats[row['category'] as String] = row['total'] as double;
      }
    }
    return stats;
  }

  @override
  Future<bool> isDuplicate(String utr, String hash) async {
    final hashPreview = hash.length > 16 ? '${hash.substring(0, 16)}...' : hash;
    print('🔍 REPO: Checking duplicate - UTR: $utr, Hash: $hashPreview');
    
    // Layer 1: UTR check - ONLY if UTR is meaningful (not UNKNOWN or empty)
    if (utr != 'UNKNOWN' && utr != 'Unknown' && utr.isNotEmpty) {
      final byUtr = await dbHelper.readByUtr(utr);
      if (byUtr != null) {
        print('🔄 REPO: DUPLICATE found by UTR: $utr');
        return true;
      }
    } else {
      print('⚠️  REPO: UTR is "$utr" - skipping UTR check');
    }

    // Layer 2: Hash check - exact match on hash
    // Note: Hash includes timestamp (milliseconds), so same amount at different times = different hash
    final db = await dbHelper.database;
    final byHash = await db.query('transactions', where: 'hash = ?', whereArgs: [hash]);
    if (byHash.isNotEmpty) {
      print('🔄 REPO: DUPLICATE found by Hash');
      return true;
    }

    print('✅ REPO: NOT a duplicate - will save');
    return false;
  }

  @override
  Future<bool> hasSimilarRecent(double amount, String type, DateTime timestamp) async {
    // Layer 3: Check for similar transaction within PAST 120 seconds only
    // Don't check future to avoid blocking legitimate sequential transactions
    final windowStart = timestamp.subtract(const Duration(seconds: 120));
    
    print('🕐 REPO: Checking past 120s for similar transaction...');
    
    final db = await dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'amount = ? AND type = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        amount,
        type,
        windowStart.millisecondsSinceEpoch,
        timestamp.millisecondsSinceEpoch  // Changed from windowEnd to timestamp
      ],
    );
    
    if (result.isNotEmpty) {
      print('⏰ REPO: Found ${result.length} similar transaction(s) in past 120s');
      return true;
    }
    
    print('✅ REPO: No similar transactions in time window');
    return false;
  }

  // === Historical Analysis & Setup Implementation ===

  @override
  Future<void> saveHistoricalStats(double income, double spending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('historical_income', income);
    await prefs.setDouble('historical_spending', spending);
    print('💾 REPO: Saved Historical Stats - Income: $income, Spending: $spending');
  }

  @override
  Future<Map<String, double>> getHistoricalStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'income': prefs.getDouble('historical_income') ?? 0.0,
      'spending': prefs.getDouble('historical_spending') ?? 0.0,
    };
  }

  @override
  Future<void> setSetupTimestamp(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('setup_timestamp', timestamp);
    print('💾 REPO: Set Setup Timestamp: $timestamp');
  }

  @override
  Future<int> getSetupTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('setup_timestamp') ?? 0;
  }

  @override
  Future<void> updateTransaction(TransactionEntity transaction) async {
    // Get old transaction to calculate balance difference
    final db = await dbHelper.database;
    final result = await db.query('transactions', where: 'id = ?', whereArgs: [transaction.id!]);
    final oldTransaction = TransactionModel.fromMap(result.first);
    
    // Update current balance by reversing old and applying new
    final prefs = await SharedPreferences.getInstance();
    final currentBalance = prefs.getDouble('current_balance') ?? 0.0;
    
    // Reverse old transaction
    double adjustedBalance = currentBalance;
    if (oldTransaction.type == TransactionType.credit) {
      adjustedBalance -= oldTransaction.amount;
    } else {
      adjustedBalance += oldTransaction.amount;
    }
    
    // Apply new transaction
    if (transaction.type == TransactionType.credit) {
      adjustedBalance += transaction.amount;
    } else {
      adjustedBalance -= transaction.amount;
    }
    
    await prefs.setDouble('current_balance', adjustedBalance);
    
    final model = TransactionModel(
      id: transaction.id,
      amount: transaction.amount,
      type: transaction.type,
      category: transaction.category,
      merchant: transaction.merchant,
      utr: transaction.utr,
      timestamp: transaction.timestamp,
      hash: transaction.hash,
      source: transaction.source,
      description: transaction.description,
    );
    await dbHelper.update(model.toMap());
    _controller.add(null);
  }

  @override
  Future<void> deleteTransaction(int id) async {
    // Get transaction to reverse its effect on balance
    final db = await dbHelper.database;
    final result = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    final transaction = TransactionModel.fromMap(result.first);
    
    // Update current balance by reversing the deleted transaction
    final prefs = await SharedPreferences.getInstance();
    final currentBalance = prefs.getDouble('current_balance') ?? 0.0;
    double newBalance;
    
    if (transaction.type == TransactionType.credit) {
      newBalance = currentBalance - transaction.amount;
    } else {
      newBalance = currentBalance + transaction.amount;
    }
    
    await prefs.setDouble('current_balance', newBalance);
    
    await dbHelper.delete(id);
    _controller.add(null);
  }

  @override
  Future<void> clearAllData() async {
    final db = await dbHelper.database;
    await db.delete('transactions');
    _controller.add(null);
  }

  @override
  Future<String> exportDataAsJson() async {
    final transactions = await getTransactions();
    final List<Map<String, dynamic>> jsonList = transactions.map((t) => {
      'id': t.id,
      'amount': t.amount,
      'type': t.type.toString(),
      'category': t.category,
      'merchant': t.merchant,
      'utr': t.utr,
      'timestamp': t.timestamp.millisecondsSinceEpoch,
      'hash': t.hash,
      'source': t.source,
      'description': t.description,
    }).toList();
    
    return jsonEncode({'transactions': jsonList, 'exportDate': DateTime.now().toIso8601String()});
  }

  @override
  Future<void> updateCategoryForAll(String oldCategory, String newCategory) async {
    final db = await dbHelper.database;
    await db.update(
      'transactions',
      {'category': newCategory},
      where: 'category = ?',
      whereArgs: [oldCategory],
    );
    _controller.add(null);
  }

  @override
  Future<double> getCurrentBalance() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get the anchor balance and the time it was set
    final anchorBalance = prefs.getDouble('anchor_balance') ?? 0.0;
    final anchorTimestamp = prefs.getInt('anchor_timestamp') ?? 0;
    
    // Only count transactions AFTER the anchor was set
    final db = await dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'timestamp > ?',
      whereArgs: [anchorTimestamp],
    );
    
    double credit = 0;
    double debit = 0;

    for (var row in result) {
      final t = TransactionModel.fromMap(row);
      if (t.type == TransactionType.credit) {
        credit += t.amount;
      } else {
        debit += t.amount;
      }
    }

    final calculated = anchorBalance + credit - debit;
    print('💰 Balance: Anchor(₹$anchorBalance @ $anchorTimestamp) + Credits(₹$credit) - Debits(₹$debit) = ₹$calculated');
    return calculated;
  }

  @override
  Future<void> updateCurrentBalance(double balance) async {
    // Simply store the new balance and current timestamp as anchor
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await prefs.setDouble('anchor_balance', balance);
    await prefs.setInt('anchor_timestamp', now);
    
    print('💰 Balance Anchor Set: ₹$balance at $now');
    _controller.add(null);
  }

  @override
  Future<List<TransactionEntity>> getTodayTransactions() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    final db = await dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'timestamp DESC',
    );

    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }
}

