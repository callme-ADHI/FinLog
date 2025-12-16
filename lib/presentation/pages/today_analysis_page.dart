import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../core/services/sms_service.dart';

class TodayAnalysisPage extends StatefulWidget {
  const TodayAnalysisPage({Key? key}) : super(key: key);

  @override
  State<TodayAnalysisPage> createState() => _TodayAnalysisPageState();
}

class _TodayAnalysisPageState extends State<TodayAnalysisPage> {
  bool _isScanning = false;

  Future<void> _scanTodaySms() async {
    setState(() => _isScanning = true);
    
    try {
      final smsService = context.read<SmsService>();
      final imported = await smsService.scanTodaySms();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imported > 0 
              ? 'Found $imported new transactions!' 
              : 'No new transactions found today'),
            backgroundColor: imported > 0 ? Colors.teal : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TransactionRepository>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Today\'s Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isScanning 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scanTodaySms,
            tooltip: 'Scan Today\'s SMS',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? null : _scanTodaySms,
        backgroundColor: _isScanning ? Colors.grey : Colors.tealAccent,
        foregroundColor: Colors.black,
        icon: _isScanning 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : const Icon(Icons.sms),
        label: Text(_isScanning ? 'Scanning...' : 'Scan Today'),
      ),
      body: RefreshIndicator(
        onRefresh: _scanTodaySms,
        child: StreamBuilder(
          stream: repo.onDataChanged,
          builder: (context, snapshot) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _getTodayData(context),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
                }

                final data = snapshot.data!;
                final income = data['income'] as double;
                final expenses = data['expenses'] as double;
                final transactions = data['transactions'] as List<TransactionEntity>;
                final net = income - expenses;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards
                      Row(
                        children: [
                          _buildSummaryCard(
                            'Income',
                            income,
                            Colors.greenAccent,
                            Icons.arrow_downward,
                          ),
                          const SizedBox(width: 16),
                          _buildSummaryCard(
                            'Expenses',
                            expenses,
                            Colors.redAccent,
                            Icons.arrow_upward,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildNetBalanceCard(net),
                      const SizedBox(height: 24),
                      
                      // Today's Transactions
                      Text(
                        'Today\'s Transactions (${transactions.length})',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      
                      if (transactions.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text('No transactions today', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                                const SizedBox(height: 8),
                                Text('Tap "Scan Today" to check for new SMS', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._buildTransactionList(transactions),
                      
                      const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getTodayData(BuildContext context) async {
    final repo = context.read<TransactionRepository>();
    final income = await repo.getTodayIncome();
    final expenses = await repo.getTodaySpending();
    final transactions = await repo.getTodayTransactions();

    return {
      'income': income,
      'expenses': expenses,
      'transactions': transactions,
    };
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetBalanceCard(double net) {
    final isPositive = net >= 0;
    return Card(
      color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net Balance Today',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${net.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              size: 48,
              color: isPositive ? Colors.green.shade300 : Colors.red.shade300,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTransactionList(List<TransactionEntity> transactions) {
    return transactions.map((t) {
      final isCredit = t.type == TransactionType.credit;
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isCredit ? Colors.green.shade50 : Colors.red.shade50,
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? Colors.green : Colors.red,
            ),
          ),
          title: Text(t.merchant),
          subtitle: Text(
            '${t.category} • ${_formatTime(t.timestamp)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          trailing: Text(
            '₹${t.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isCredit ? Colors.green : Colors.red,
            ),
          ),
        ),
      );
    }).toList();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}
