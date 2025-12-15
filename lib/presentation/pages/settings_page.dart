import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/transaction_repository.dart';
import 'package:flutter/services.dart';
import '../../core/services/sms_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'privacy_policy_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _balanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getDouble('opening_balance') ?? 0.0;
    _balanceController.text = balance.toString();
  }

  Future<void> _saveBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    await prefs.setDouble('opening_balance', balance);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Balance Updated')));
    }
  }

  Future<void> _exportData() async {
    try {
      final repo = context.read<TransactionRepository>();
      final jsonData = await repo.exportDataAsJson();
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: jsonData));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported to clipboard! Paste it in a file or send it.'),
            duration: Duration(seconds: 3),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'))
        );
      }
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text('This will delete all transactions permanently. This action cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = context.read<TransactionRepository>();
        await repo.clearAllData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data cleared successfully'))
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear data: $e'))
          );
        }
      }
    }
  }

  Future<void> _importHistoricalSms() async {
    // Step 1: Request SMS permission
    final status = await Permission.sms.request();
    
    if (!status.isGranted) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text('SMS permission is needed to scan your message inbox for bank transactions. Please grant permission in Settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Step 2: Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan SMS History?'),
        content: const Text('This will scan all messages in your inbox and import bank/UPI transactions. Duplicates will be automatically skipped.\n\nThis may take a few moments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start Scan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Step 3: Show progress dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Scanning SMS messages...'),
              SizedBox(height: 8),
              Text('This may take a moment', style: TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );

    // Step 4: Perform scan
    try {
      final smsService = context.read<SmsService>();
      final imported = await smsService.scanAllSms();
      
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                const Text('Import Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Successfully imported $imported transaction${imported == 1 ? '' : 's'} from your SMS history.'),
                const SizedBox(height: 12),
                if (imported == 0)
                  const Text(
                    'No new transactions found. Either no bank SMS exist, or all transactions were already imported.',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                const Text('Import Failed'),
              ],
            ),
            content: Text('Error: $e\n\nPlease ensure SMS permission is granted and try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
           const Text('Financial Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
           const SizedBox(height: 16),
           TextField(
             controller: _balanceController,
             keyboardType: TextInputType.number,
             decoration: const InputDecoration(
               labelText: 'Opening Balance',
               border: OutlineInputBorder(),
               prefixText: '₹ ',
             ),
           ),
           const SizedBox(height: 16),
           ElevatedButton(onPressed: _saveBalance, child: const Text('Save Opening Balance')),
           
           const Divider(height: 32),
            
            const Text(
              'App Info',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              subtitle: const Text('How we handle your data'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About FinLog'),
              subtitle: const Text('v1.0.1 • Offline First'),
            ),
           const Divider(height: 32),
           const Text('Data Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
           ListTile(
             leading: const Icon(Icons.download),
             title: const Text('Export Data (JSON)'),
             subtitle: const Text('Copy transaction data to clipboard'),
             onTap: _exportData,
           ),
           const SizedBox(height: 16),
           ListTile(
             leading: const Icon(Icons.cloud_download, color: Colors.blueAccent),
             title: const Text('Import SMS History'),
             subtitle: const Text('Scan all messages and import transactions'),
             trailing: const Icon(Icons.arrow_forward_ios, size: 16),
             onTap: _importHistoricalSms,
           ),
           ListTile(
             leading: const Icon(Icons.delete_forever, color: Colors.red),
             title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
             subtitle: const Text('Delete all transactions permanently'),
             onTap: _clearData,
           ),
        ],
      ),
    );
  }
}
