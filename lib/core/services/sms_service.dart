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

  Future<int> scanAllSms() async {
    try {
      print("FinLog: Starting SMS scan...");
      final List<dynamic> messages = await platform.invokeMethod('scanAllSms');
      print("FinLog: Received ${messages.length} messages from native");
      print("FinLog: Received ${messages.length} messages from native");
      
      // Convert to List<Map<String, dynamic>> safely
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

      print("FinLog: Sending batch of ${batch.length} to processSms");
      final imported = await processSms.batchProcess(batch);
      
      print("FinLog: Scan complete. Imported $imported transactions");
      return imported;
    } catch (e, stack) {
      print("Error scanning SMS: $e");
      print("Stack trace: $stack");
      return 0;
    }
  }
}
