import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../core/services/sms_service.dart';
import 'privacy_policy_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, double> _historicalStats = {};
  bool _isLoading = true;
  final TextEditingController _balanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final repo = context.read<TransactionRepository>();
    final stats = await repo.getHistoricalStats();
    
    // Load balance for settings
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getDouble('opening_balance') ?? 0.0;
    _balanceController.text = balance.toString();

    if (mounted) {
      setState(() {
        _historicalStats = stats;
        _isLoading = false;
      });
    }
  }

  // === ACTIONS ===

  Future<void> _reScanHistory() async {
    setState(() => _isLoading = true);
    try {
      final smsService = context.read<SmsService>();
      final stats = await smsService.analyzeAllSms();
      
      setState(() {
        _historicalStats = stats;
        _isLoading = false;
      });
      
      if (mounted) {
        final income = stats['income'] ?? 0.0;
        final spending = stats['spending'] ?? 0.0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan Complete! Lifetime Income: ₹${income.toStringAsFixed(0)}'),
            backgroundColor: Colors.teal,
          )
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan Failed: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  Future<void> _saveBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    await prefs.setDouble('opening_balance', balance);
    
    // Also update current repo balance to match (resetting "Day 0" anchor)
    if (mounted) {
      final repo = context.read<TransactionRepository>();
      await repo.updateCurrentBalance(balance); // This updates the live tracking base
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance Updated Successfully'))
      );
    }
  }

  Future<void> _exportData() async {
    try {
      final repo = context.read<TransactionRepository>();
      final jsonData = await repo.exportDataAsJson();
      await Clipboard.setData(ClipboardData(text: jsonData));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data exported to clipboard!'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text('This will delete all live transactions. Historical stats will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = context.read<TransactionRepository>();
      await repo.clearAllData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared')));
    }
  }

  // === UI BUILDER ===

  @override
  Widget build(BuildContext context) {
    // Calculate Net Flow
    final income = _historicalStats['income'] ?? 0.0;
    final spending = _historicalStats['spending'] ?? 0.0;
    final net = income - spending;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile & Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HISTORICAL STATS CARDS
                  const Text('Lifetime Analysis', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Stats from all SMS (not on dashboard)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Income', income, Colors.greenAccent, Icons.arrow_downward)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Spending', spending, Colors.redAccent, Icons.arrow_upward)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Net Flow Card
                   Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Net Financial Flow', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '${net >= 0 ? '+' : ''}₹${net.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: net >= 0 ? Colors.tealAccent : Colors.redAccent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Re-Analyze SMS History'),
                      onPressed: _reScanHistory,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        side: const BorderSide(color: Colors.tealAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: Colors.grey)),

                  // 2. FINANCIAL SETTINGS
                  const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  const Text('Current Balance (Day 0)', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _balanceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Color(0xFF1E1E1E),
                            border: OutlineInputBorder(borderSide: BorderSide.none),
                            prefixText: '₹ ',
                            prefixStyle: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveBalance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 3. DATA & APP INFO (List Tiles)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.download, color: Colors.blueAccent),
                          title: const Text('Export Data (JSON)', style: TextStyle(color: Colors.white)),
                          onTap: _exportData,
                        ),
                        const Divider(height: 1, color: Colors.black),
                        ListTile(
                          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          title: const Text('Clear Dashboard Data', style: TextStyle(color: Colors.white)),
                          onTap: _clearData,
                        ),
                        const Divider(height: 1, color: Colors.black),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip, color: Colors.grey),
                          title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                             Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Center(
                    child: Text(
                      'FinLog v1.0.1 • Offline First',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
             child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '₹${_compactAmount(amount)}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _compactAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return amount.toStringAsFixed(0);
  }
}
