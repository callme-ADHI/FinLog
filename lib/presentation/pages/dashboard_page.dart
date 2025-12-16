import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../core/services/sms_service.dart';
import '../widgets/spending_chart.dart'; // Import Chart
import 'transactions_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isRefreshing = false;

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    
    try {
      final smsService = context.read<SmsService>();
      final imported = await smsService.scanTodaySms();
      print('🔄 Dashboard Refresh: Scanned and imported $imported new transactions');
    } catch (e) {
      print('❌ Dashboard Refresh Error: $e');
    }
    
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TransactionRepository>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Deep dark bg
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('FinLog', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          )
        ],
      ),
      body: StreamBuilder<void>(
        stream: repo.onDataChanged,
        builder: (context, snapshot) {
          print('🎨 DASHBOARD: StreamBuilder rebuilding! Snapshot state: ${snapshot.connectionState}');
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Balance Card (Gradient)
              _buildModernBalanceCard(repo),
              const SizedBox(height: 24),
              
              // 2. Spending Trend (Chart)
              const Text('Weekly Spending Trend', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 12),
              FutureBuilder<Map<DateTime, double>>(
                future: repo.getLast7DaysSpending(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                  return SpendingChart(data: snapshot.data!);
                },
              ),
              const SizedBox(height: 24),

              // 3. Quick Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassCard(
                          repo,
                          "Today's Spending",
                          Colors.orangeAccent,
                          (r) => r.getTodaySpending(),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionsPage(filterDate: DateTime.now())));
                          },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGlassCard(
                          repo,
                          "Month's Spending",
                          Colors.purpleAccent,
                          (r) => r.getMonthSpending(),
                          onTap: () {
                             // Maybe later add Month Filter
                          }
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Income Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassCard(
                          repo,
                          "Today's Income",
                          Colors.greenAccent,
                          (r) => r.getTodayIncome(),
                          // onTap: () => Navigate to filtered Income Page? (Not yet implemented)
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGlassCard(
                          repo,
                          "Month's Income",
                          Colors.lightGreenAccent,
                          (r) => r.getMonthIncome(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
               // Net Flow Card
               FutureBuilder(
                 future: Future.wait([
                   repo.getMonthIncome(),
                   repo.getMonthSpending()
                 ]),
                 builder: (context, snapshot) {
                   if (!snapshot.hasData) return const SizedBox();
                   final income = snapshot.data![0];
                   final expense = snapshot.data![1];
                   final net = income - expense;
                   
                   return Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(
                       gradient: LinearGradient(
                         colors: net >= 0 
                           ? [Colors.teal.shade900, Colors.teal.shade800] 
                           : [Colors.red.shade900, Colors.red.shade800],
                         begin: Alignment.topLeft,
                         end: Alignment.bottomRight,
                       ),
                       borderRadius: BorderRadius.circular(24),
                       boxShadow: [BoxShadow(color: (net >= 0 ? Colors.teal : Colors.red).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           'Net Flow (This Month)',
                           style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
                         ),
                         const SizedBox(height: 8),
                         Text(
                           '${net >= 0 ? '+' : '-'} ₹${net.abs().toStringAsFixed(0)}',
                           style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                         ),
                         const SizedBox(height: 4),
                         Text(
                           net >= 0 ? 'You are saving!' : 'Spending exceeds income',
                           style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                         ),
                       ],
                     ),
                   );
                 }
               ),
               const SizedBox(height: 24),

              // 4. Today's Transactions Header & List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text("Today's Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                   TextButton(
                     onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsPage())), 
                     child: const Text('View All')
                   ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<TransactionEntity>>(
                future: repo.getTodayTransactions(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 8),
                            Text('No transactions today', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  final transactions = snapshot.data!;
                  return Column(
                    children: transactions.take(5).map((t) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: const Color(0xFF1E1E1E),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: t.type == TransactionType.credit 
                            ? Colors.green.withOpacity(0.2) 
                            : Colors.red.withOpacity(0.2),
                          child: Icon(
                            t.type == TransactionType.credit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: t.type == TransactionType.credit ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          t.merchant.isNotEmpty ? t.merchant : t.category,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          t.category,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                        trailing: Text(
                          '${t.type == TransactionType.credit ? '+' : '-'}₹${t.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: t.type == TransactionType.credit ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }
    ),
    );
  }

  Widget _buildModernBalanceCard(TransactionRepository repo) {
    return FutureBuilder<double>(
      future: repo.getCurrentBalance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        
        final balance = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Balance',
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white60, size: 20),
                    onPressed: () => _showEditBalanceDialog(context, repo, balance),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₹${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap edit to adjust',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditBalanceDialog(BuildContext context, TransactionRepository repo, double currentBalance) {
    final controller = TextEditingController(text: currentBalance.toStringAsFixed(2));
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Balance'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Balance',
            prefixText: '₹ ',
            border: OutlineInputBorder(),
            helperText: 'Enter your current bank balance',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBalance = double.tryParse(controller.text);
              if (newBalance != null) {
                await repo.updateCurrentBalance(newBalance);
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  setState(() {});
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(TransactionRepository repo, String title, Color accentColor, Future<double> Function(TransactionRepository) fetcher, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset:const Offset(0,2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_outline, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.white60, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<double>(
              future: fetcher(repo),
              builder: (context, snapshot) {
                 if (!snapshot.hasData) return const Text('...');
                 return Text(
                   '₹${snapshot.data!.toStringAsFixed(0)}',
                   style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                 );
              },
            ),
          ],
        ),
      ),
    );
  }
}
