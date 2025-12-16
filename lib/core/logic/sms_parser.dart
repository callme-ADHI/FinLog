import '../constants/app_constants.dart';
import '../../domain/entities/transaction_entity.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SmsParser {
  // Returns TransactionEntity if parsing successful and valid, else null
  static TransactionEntity? parseSms(String sender, String body, int timestamp) {
    // 1. Loose Sender Filter
    // We process EVERYTHING that looks even remotely useful. 
    // We only skip purely numeric shortcodes if they don't look like banks, 
    // but honestly, if it has "debited Rs 500", it's a transaction.
    // So we primarily rely on content extraction.

    // 2. Extract transaction details
    var type = detectType(body);
    final amount = extractAmount(body);
    
    // Fallback: If "txn of" or "UPI txn" is found present but no explicit debit/credit keyword
    if (type == null && amount != null) {
       if (body.toLowerCase().contains('txn of') || 
           body.toLowerCase().contains('upi txn') ||
           body.toLowerCase().contains('purchase of')) {
         type = TransactionType.debit;
       }
    }

    if (type == null) {
      // print("❌ PARSER: No debit/credit found in: ${body.substring(0, body.length > 50 ? 50 : body.length)}...");
      return null;  
    }

    if (amount == null) {
      // print("❌ PARSER: No amount found in: ${body.substring(0, body.length > 50 ? 50 : body.length)}...");
      return null; 
    }

    // Extract other details
    final utr = extractUtr(body);
    final merchant = extractMerchant(body, type) ?? 'Unknown';
    final category = assignCategory(body);
    final accountNumber = extractAccountNumber(body);
    final txnDate = extractTransactionDate(body);

    // print("✅ PARSER: Valid transaction! Amount: $amount, Type: $type, Sender: $sender");
    // if (accountNumber != null) print("   Account: $accountNumber");
    // if (txnDate != null) print("   Date: ${txnDate.toString().split(' ')[0]}");

    // Create transaction
    final transaction = TransactionEntity(
      id: null,
      amount: amount,
      type: type,
      category: category,
      merchant: merchant,
      utr: utr ?? 'Unknown',
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      hash: generateHash(amount, type, timestamp, accountNumber, txnDate),
      source: 'SMS:$sender', // Store sender to track source
      description: body,
    );
    
    return transaction;
  }

  static bool isValidSender(String sender) {
     // Deprecated: We now check content first. 
     // This method is kept for legacy or UI helpers if needed.
     return sender.length >= 3;
  }

  static TransactionType? detectType(String body) {
    final lowerBody = body.toLowerCase();
    
    // Check for explicit keywords first
    for (var keyword in AppConstants.debitKeywords) {
      if (lowerBody.contains(keyword.toLowerCase())) return TransactionType.debit;
    }
    for (var keyword in AppConstants.creditKeywords) {
      if (lowerBody.contains(keyword.toLowerCase())) return TransactionType.credit;
    }
    
    // Contextual Checks
    if (lowerBody.contains('sent to') || lowerBody.contains('paid to')) return TransactionType.debit;
    if (lowerBody.contains('received from')) return TransactionType.credit;

    return null;
  }

  static double? extractAmount(String body) {
    // Matches Rs. 1,234.50 or INR 500 or ₹1000
    // Uses regex from AppConstants which handles Rs/INR/₹
    final regex = RegExp(AppConstants.amountRegex, caseSensitive: false);
    final match = regex.firstMatch(body);
    if (match != null) {
      String raw = match.group(1) ?? '';
      raw = raw.replaceAll(',', ''); // Remove commas
      // Remove trailing dot if present (e.g. "500.")
      if (raw.endsWith('.')) raw = raw.substring(0, raw.length - 1);
      return double.tryParse(raw);
    }
    return null;
  }

  static String extractUtr(String body) {
    final regex = RegExp(AppConstants.utrRegex, caseSensitive: false);
    final match = regex.firstMatch(body);
    if (match != null) {
      // Clean up the UTR (remove "Ref", "No", ":", etc if captured accidentally, though group 1 should be clean)
      return match.group(1) ?? 'UNKNOWN';
    }
    // Fallback: search for 12-digit numeric sequences common in UPI/IMPS
    final fallbackRegex = RegExp(r'\b\d{12}\b');
    final fallbackMatch = fallbackRegex.firstMatch(body);
    if (fallbackMatch != null) {
      return fallbackMatch.group(0)!;
    }
    return 'UNKNOWN';
  }

  static String? extractAccountNumber(String body) {
    // Pattern: "account XXXX3095" or "A/c XX3095" or "A/C 3095"
    final regex = RegExp(r'(?:account|a/c|acc)[:\s]+(?:XX)*(\d{4,})', caseSensitive: false);
    final match = regex.firstMatch(body);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  static DateTime? extractTransactionDate(String body) {
    // Pattern: "on 15/12/2025" or "on 15-12-25" or "on 15/12/25"
    final regex = RegExp(r'(?:on|at)\s+(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
    final match = regex.firstMatch(body);
    if (match != null) {
      try {
        int day = int.parse(match.group(1)!);
        int month = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);
        if (year < 100) year += 2000; // Convert 25 → 2025
        return DateTime(year, month, day);
      } catch (e) {
        // print('⚠️ PARSER: Error parsing date - $e');
        return null;
      }
    }
    return null;
  }

  static double? extractBalance(String body) {
    // Matches: "Avail Bal", "Avl Bal", "Total Bal", "Ebalk", "Avail.bal", etc.
    // Captures the amount afterwards
    final regex = RegExp(r'(?:avail|avl|tot|total|acct|act)[\s\.]*(?:bal|balance|amt|amount)(?:[\s\.:\-]*)(?:inr|rs|₹)?[\s]*([\d,\.]+)', caseSensitive: false);
    final match = regex.firstMatch(body);
    if (match != null) {
      try {
        String raw = match.group(1) ?? '';
        raw = raw.replaceAll(',', ''); // Remove commas
        // Remove trailing dot if present (e.g. "500.")
        if (raw.endsWith('.')) raw = raw.substring(0, raw.length - 1);
        return double.tryParse(raw);
      } catch (e) {
        // print('⚠️ PARSER: Error parsing balance - $e');
        return null;
      }
    }
    return null;
  }

  static String? extractMerchant(String body, TransactionType type) {
    final lowerBody = body.toLowerCase();
    
    // Strategy 0: Check for common payment apps FIRST
    final paymentApps = {
      'phonepe': 'PhonePe',
      'phone pe': 'PhonePe',
      'paytm': 'Paytm',
      'googlepay': 'Google Pay',
      'google pay': 'Google Pay',
      'gpay': 'GPay',
      'bhim': 'BHIM UPI',
      'amazonpay': 'Amazon Pay',
    };
    
    for (var entry in paymentApps.entries) {
      if (lowerBody.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Strategy 1: Look for "at [MERCHANT]" or "to [MERCHANT]"
    final merchantRegex = RegExp(r'(?:at|to)\s+([A-Za-z0-9\s\.\-&]+?)(?=\s+(?:on|via|ref|bal|avl)|$)', caseSensitive: false);
    final match = merchantRegex.firstMatch(body);
    if (match != null) {
      return _cleanMerchant(match.group(1));
    }

    // Strategy 2: Look for VPA (e.g. merchant@upi)
    final vpaRegex = RegExp(r'[a-zA-Z0-9\.\-_]+@[a-zA-Z]+');
    final vpaMatch = vpaRegex.firstMatch(body);
    if (vpaMatch != null) {
      return vpaMatch.group(0);
    }

    // Strategy 3: Check category keywords in body to use as merchant name if generic
    for (var entry in AppConstants.categoryKeywords.entries) {
      for (var keyword in entry.value) {
        if (lowerBody.contains(keyword.toLowerCase())) {
          return keyword[0].toUpperCase() + keyword.substring(1); // Capitalize
        }
      }
    }

    return 'Unknown';
  }

  static String _cleanMerchant(String? raw) {
    if (raw == null) return 'Unknown';
    String cleaned = raw.trim();
    cleaned = cleaned.replaceAll(RegExp(r'\.$'), ''); // Remove trailing dot
    if (cleaned.length > 25) cleaned = cleaned.substring(0, 25); // Cap length
    return cleaned.isNotEmpty ? cleaned : 'Unknown';
  }

  static String assignCategory(String body) {
    final lowerBody = body.toLowerCase();
    for (var entry in AppConstants.categoryKeywords.entries) {
      for (var keyword in entry.value) {
        if (lowerBody.contains(keyword.toLowerCase())) {
          return entry.key;
        }
      }
    }
    return 'Others';
  }

  static String generateHash(
    double amount, 
    TransactionType type, 
    int timestamp,
    String? accountNumber,
    DateTime? txnDate
  ) {
    // Generate a unique hash for deduplication
    // Include account number and date for stronger uniqueness
    final acct = accountNumber ?? 'NONE';
    final date = txnDate?.toIso8601String().split('T')[0] ?? 'NONE';
    
    final data = '$amount-$type-$timestamp-$acct-$date';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
