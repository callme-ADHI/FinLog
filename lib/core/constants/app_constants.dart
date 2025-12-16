class AppConstants {
  static const List<String> bankSenders = [
    // Major banks (Axis, SBI, HDFC, ICICI, Federal, Canara, etc.)
    'HDFC', 'HDFCBK', 'SBI', 'SBIUPI', 'SBICRD', 'SBIPSG', 'SBIINB', 
    'ICICI', 'ICICIB', 'CITI', 'CITIAT', 
    'AXIS', 'AXISBK', 
    'KOTAK', 'KKBK',
    'BOI', 'PNB', 'PNBINB', 
    'CANARA', 'CANBNK', 
    'UNION', 'UNIONB', 'UBINB',
    'BOB', 'BOBANK',
    'IDFC', 'IDFCFB', 
    'YES', 'YESBNK', 
    'FEDERAL', 'FEDFBK', 'FEDFBNK', 
    'INDUS', 'INDUSIND',
    'RBL', 'RBLBNK',
    'HSBC', 'SC', 'SCBL',
    'IDBI', 'IDIB', 'IOB', 'UCO', 'CBI', 
    'SIB', 'KVB', 'KTK', 'JSB', 'SVC', 'DBS',
    'PAYTM', 'GPAY', 'AMAZON', 'WAZIR', 'COIN',
    'MAH', 'BOM',
    // Generic suffixes often used
    'BANK', 'BNK', 'BK',
  ];

  static const List<String> debitKeywords = [
    'debited', 'debit', 'debited from', 'debited to', 'debited by',
    'spent', 'paid', 'sent', 'transferred', 'withdrawn', 'withdraw',
    'purchase', 'payment', 'pay', 'charged', 'used at',
    'txn', 'txn of', 'purchase of', 'transaction of'
  ];
  
  static const List<String> creditKeywords = [
    'credited', 'credit', 'credited to', 'credited by',
    'received', 'deposited', 'deposit', 'refund', 'refunded', 'added'
  ];
  
  static const List<String> upiKeywords = ['UPI', 'upi'];

  // Regex Patterns - more flexible for multi-bank support
  static const String amountRegex = r'(?:Rs\.?|INR|₹|MRP)\s?[\.]?\s?([\d,]+(?:\.\d{1,2})?)';
  static const String utrRegex = r'(?:UTR|Ref|Txn|Transaction ID|RRN|IMPS Ref|UPI Ref)\s*(?:No\.?)?[:\-\s]*([A-Za-z0-9]{10,})';
  
  // Category Keywords
  static const Map<String, List<String>> categoryKeywords = {
    'Food': ['swiggy', 'zomato', 'food', 'restaurant', 'cafe', 'baker', 'pizza', 'burger'],
    'Travel': ['uber', 'ola', 'rapido', 'fuel', 'petrol', 'rail', 'air', 'flight', 'bus', 'ticket', 'metro'],
    'Shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'market', 'mall', 'store', 'cloth'],
    'Bills': ['recharge', 'bill', 'electricity', 'water', 'gas', 'broadband', 'jio', 'airtel', 'vi'],
    'Groceries': ['bigbasket', 'blinkit', 'zepto', 'dmart', 'grocery', 'kirana', 'fruit', 'vegetable'],
    'Health': ['pharmacy', 'medical', 'hospital', 'doctor', 'lab', 'clinc'],
    'Entertainment': ['netflix', 'prime', 'hotstar', 'movie', 'cinema', 'bookmyshow'],
    'Investment': ['zerodha', 'groww', 'upstox', 'coin', 'wazirx', 'crypto', 'stock', 'mutual fund', 'sip', 'lic', 'insurance'],
    'Transfer': ['sent to', 'transfer', 'upi', 'gpay', 'phonepe', 'paytm'],
  };
}
