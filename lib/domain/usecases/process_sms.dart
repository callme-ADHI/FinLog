import '../repositories/transaction_repository.dart';
import '../../core/logic/sms_parser.dart';
import '../entities/transaction_entity.dart';

class ProcessSms {
  final TransactionRepository repository;

  ProcessSms(this.repository);

  // Returns true if processed and added, false if ignored or duplicate
  Future<bool> call(String sender, String body, int timestamp) async {
    // 0. Live Mode Check: Is this a NEW message?
    final setupTime = await repository.getSetupTimestamp();
    // Use a small buffer (e.g., 1 sec) or strict comparison
    // If setupTime is 0, it means not set up yet, so maybe ignore or allow?
    // Assuming setup is done.
    if (setupTime > 0 && timestamp < setupTime) {
      print('⏭️ ProcessSms: Skipping OLD message (E: $timestamp < S: $setupTime)');
      return false; 
    }

    print('🔍 ProcessSms: Starting to process SMS from $sender');
    
    // 1. Parse and Validate
    final transaction = SmsParser.parseSms(sender, body, timestamp);
    
    if (transaction == null) {
      print('❌ ProcessSms: Parser returned null - SMS rejected');
      return false; // Ignored (Not bank, not UPI, invalid format)
    }

    print('📊 ProcessSms: Transaction parsed - Amount: ${transaction.amount}, Type: ${transaction.type}, UTR: ${transaction.utr}, Hash: ${transaction.hash.substring(0, transaction.hash.length > 16 ? 16 : transaction.hash.length)}...');

    // === 3-Layer Deduplication ===
    
    // Layer 1: UTR Match (only if UTR is meaningful)
    if (transaction.utr != 'UNKNOWN' && transaction.utr != 'Unknown' && transaction.utr.isNotEmpty) {
      final hasByUtr = await repository.isDuplicate(transaction.utr, '');
      if (hasByUtr) {
        print('🔄 ProcessSms: DUPLICATE by UTR: ${transaction.utr}');
        return false;
      }
    }
    
    // Layer 2: Exact Hash Match
    final hasByHash = await repository.isDuplicate('', transaction.hash);
    if (hasByHash) {
      print('🔄 ProcessSms: DUPLICATE by Hash (exact match)');
      return false;
    }
    
    // Layer 3: Similar transaction within time window (±120 seconds)
    final hasSimilar = await repository.hasSimilarRecent(
      transaction.amount,
      transaction.type.toString(),
      transaction.timestamp
    );
    if (hasSimilar) {
      print('🔄 ProcessSms: DUPLICATE by Time Window (similar transaction within 120s)');
      return false;
    }
    
    print('✅ ProcessSms: NOT a duplicate. Proceeding to save...');
    
    await repository.addTransaction(transaction);
    print('💾 ProcessSms: Transaction SAVED to database successfully!');
    print('🔔 ProcessSms: UI should update now via StreamController');
    return true;
  }
  // Batch process multiple SMS messages
  // Returns number of transactions added
  Future<int> batchProcess(List<Map<String, dynamic>> messages) async {
    print('🔄 ProcessSms: Starting BATCH process of ${messages.length} messages');
    
    final List<TransactionEntity> toAdd = [];
    double? latestBalance;
    int latestBalanceTime = 0;
    
    for (var msg in messages) {
      final sender = msg['sender'] as String? ?? '';
      final body = msg['body'] as String? ?? '';
      final timestamp = msg['timestamp'] as int? ?? 0;
      
      // 1. Parse
      final transaction = SmsParser.parseSms(sender, body, timestamp);
      if (transaction == null) continue;
      
      // 2. Extract Balance (Keep the most recent one)
      final balance = SmsParser.extractBalance(body);
      if (balance != null && timestamp > latestBalanceTime) {
        latestBalance = balance;
        latestBalanceTime = timestamp;
      }
      
      // 3. Deduplicate (In-memory + DB)
      // Check if this transaction is already in our "toAdd" list
      if (toAdd.any((t) => t.hash == transaction.hash)) continue;
      
      // Check Layer 1 (UTR)
      if (transaction.utr != 'UNKNOWN' && transaction.utr.isNotEmpty) {
         if (await repository.isDuplicate(transaction.utr, '')) continue;
      }
      
      // Check Layer 2 (Hash)
      if (await repository.isDuplicate('', transaction.hash)) continue;
      
      // Check Layer 3 (Time Window)
      if (await repository.hasSimilarRecent(transaction.amount, transaction.type.toString(), transaction.timestamp)) continue;

      toAdd.add(transaction);
    }
    
    print('📊 ProcessSms: Batch Analysis Complete.');
    print('   - Total Valid Transactions: ${toAdd.length}');
    if (latestBalance != null) {
      print('   - Latest Balance Found: ₹$latestBalance (from timestamp $latestBalanceTime)');
    } else {
      print('   - No Balance information found in SMS batch');
    }
    
    // NOTE: We do NOT auto-update balance from SMS detection
    // Balance only changes when:
    // 1. User manually sets it
    // 2. New transactions are added (handled by anchor system in getCurrentBalance)
    
    // Save Transactions
    if (toAdd.isNotEmpty) {
      await repository.batchAddTransactions(toAdd);
      print('💾 ProcessSms: Batch Saved ${toAdd.length} transactions to Database');
    }
    
    return toAdd.length;
  }

  // Analyze batch of messages for historical stats (Income/Spending/Balance)
  // Does NOT save transactions to DB
  Future<Map<String, double>> analyzeBatch(List<Map<String, dynamic>> messages) async {
    print('📊 ProcessSms: Starting HISTORICAL ANALYSIS of ${messages.length} messages');
    
    double totalIncome = 0;
    double totalSpending = 0;
    double? latestBalance;
    int latestBalanceTime = 0;
    
    // Sort messages by timestamp (oldest first) to track balance progression if needed
    // But for total sums, order doesn't strictly matter
    
    int processedCount = 0;
    int validCount = 0;
    
    for (var msg in messages) {
      processedCount++;
      final sender = msg['sender'] as String? ?? '';
      final body = msg['body'] as String? ?? '';
      final timestamp = msg['timestamp'] as int? ?? 0;
      
      // 1. Parse
      final transaction = SmsParser.parseSms(sender, body, timestamp);
      if (transaction == null) {
        // Log every 100th skipped message to avoid spam but show progress
        if (processedCount % 100 == 0) {
          print('📨 Progress: $processedCount/${messages.length} messages scanned (Valid: $validCount)');
        }
        continue;
      }
      
      validCount++;
      
      // 2. Extract Stats
      if (transaction.type == TransactionType.credit) {
        totalIncome += transaction.amount;
        print('💚 [$validCount] CREDIT ₹${transaction.amount} from ${sender.length > 15 ? sender.substring(0, 15) : sender} → Total Income: ₹$totalIncome');
      } else {
        totalSpending += transaction.amount;
        print('🔴 [$validCount] DEBIT ₹${transaction.amount} from ${sender.length > 15 ? sender.substring(0, 15) : sender} → Total Spending: ₹$totalSpending');
      }
      
      // 3. Extract Balance (Keep the most recent one)
      final balance = SmsParser.extractBalance(body);
      if (balance != null && timestamp > latestBalanceTime) {
        latestBalance = balance;
        latestBalanceTime = timestamp;
        print('   💰 Balance detected: ₹$balance');
      }
    }
    
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 ANALYSIS COMPLETE');
    print('   - Total Income: ₹$totalIncome');
    print('   - Total Spending: ₹$totalSpending');
    print('   - Latest Detect Bal: ${latestBalance ?? "Not Found"}');
    
    // Save these stats to repository
    await repository.saveHistoricalStats(totalIncome, totalSpending);
    
    return {
      'income': totalIncome,
      'spending': totalSpending,
      'balance': latestBalance ?? 0.0,
      'hasBalance': latestBalance != null ? 1.0 : 0.0,
    };
  }
}
