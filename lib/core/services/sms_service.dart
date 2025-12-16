import 'package:flutter/services.dart';
import '../../domain/usecases/process_sms.dart';

class SmsService {
  static const platform = MethodChannel('com.finlog.finlog/sms');
  final ProcessSms processSms;

  SmsService({required this.processSms});

  void initialize() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final String sender = call.arguments['sender'];
        final String body = call.arguments['body'];
        final int timestamp = call.arguments['timestamp'];

        print('📱 SmsService: Received SMS from $sender');
        print('📱 Message: ${body.substring(0, body.length > 50 ? 50 : body.length)}...');

        try {
          await processSms.call(sender, body, timestamp);
          print('✅ SmsService: Transaction processed successfully');
        } catch (e) {
          print('❌ SmsService: Error processing SMS: $e');
        }
      }
    });
    print('✅ SmsService: Initialized and listening for SMS');
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onSmsReceived':
        final args = call.arguments as Map;
        final sender = args['sender'] as String? ?? '';
        final body = args['body'] as String? ?? '';
        final timestamp = args['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        
        print("FinLog Flutter: Received SMS from $sender");
        
        await processSms.call(sender, body, timestamp);
        return null;
      default:
        throw MissingPluginException();
    }
  }

  // REMOVED: scanAllSms() - was incorrectly importing ALL SMS to database
  // Use analyzeAllSms() for historical stats (Profile)
  // Use scanTodaySms() to save today's transactions (Today page)


  // Analyze all SMS for historical stats WITHOUT importing
  Future<Map<String, double>> analyzeAllSms() async {
    try {
      print("FinLog: Starting SMS ANALYSIS...");
      final List<dynamic> messages = await platform.invokeMethod('scanAllSms');
      
      List<Map<String, dynamic>> batch = [];
      for (var msg in messages) {
        if (msg is Map) {
          batch.add({
            'sender': msg['sender']?.toString() ?? '',
            'body': msg['body']?.toString() ?? '',
            'timestamp': (msg['timestamp'] is int) ? msg['timestamp'] : 0,
          });
        }
      }

      print("FinLog: Sending batch of ${batch.length} to analyzeBatch");
      return await processSms.analyzeBatch(batch);
    } catch (e) {
      print("Error analyzing SMS: $e");
      return {};
    }
  }

  // Scan only TODAY's SMS messages and import them
  Future<int> scanTodaySms() async {
    try {
      print("FinLog: Starting TODAY's SMS scan...");
      final List<dynamic> messages = await platform.invokeMethod('scanAllSms');
      
      // Get today's start timestamp
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      
      print("FinLog: Filtering ${messages.length} messages for today (since $todayStart)");
      
      List<Map<String, dynamic>> todayBatch = [];
      for (var msg in messages) {
        if (msg is Map) {
          final timestamp = (msg['timestamp'] is int) ? msg['timestamp'] : 0;
          // Only include messages from today
          if (timestamp >= todayStart) {
            todayBatch.add({
              'sender': msg['sender']?.toString() ?? '',
              'body': msg['body']?.toString() ?? '',
              'timestamp': timestamp,
            });
          }
        }
      }

      print("FinLog: Found ${todayBatch.length} messages from TODAY");
      
      if (todayBatch.isEmpty) {
        print("FinLog: No new messages from today to process");
        return 0;
      }
      
      final imported = await processSms.batchProcess(todayBatch);
      print("FinLog: Today scan complete. Imported $imported transactions");
      return imported;
    } catch (e, stack) {
      print("Error scanning today's SMS: $e");
      print("Stack trace: $stack");
      return 0;
    }
  }

  // Scan SMS for a specific date and import them
  Future<int> scanDateSms(DateTime date) async {
    try {
      print("FinLog: Starting SMS scan for ${date.toString().split(' ')[0]}...");
      final List<dynamic> messages = await platform.invokeMethod('scanAllSms');
      
      // Get date range
      final dateStart = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
      final dateEnd = DateTime(date.year, date.month, date.day, 23, 59, 59).millisecondsSinceEpoch;
      
      print("FinLog: Filtering ${messages.length} messages for date range $dateStart - $dateEnd");
      
      List<Map<String, dynamic>> dateBatch = [];
      for (var msg in messages) {
        if (msg is Map) {
          final timestamp = (msg['timestamp'] is int) ? msg['timestamp'] : 0;
          // Only include messages from the selected date
          if (timestamp >= dateStart && timestamp <= dateEnd) {
            dateBatch.add({
              'sender': msg['sender']?.toString() ?? '',
              'body': msg['body']?.toString() ?? '',
              'timestamp': timestamp,
            });
          }
        }
      }

      print("FinLog: Found ${dateBatch.length} messages from selected date");
      
      if (dateBatch.isEmpty) {
        print("FinLog: No messages found for this date");
        return 0;
      }
      
      final imported = await processSms.batchProcess(dateBatch);
      print("FinLog: Date scan complete. Imported $imported transactions");
      return imported;
    } catch (e, stack) {
      print("Error scanning date SMS: $e");
      print("Stack trace: $stack");
      return 0;
    }
  }
}
