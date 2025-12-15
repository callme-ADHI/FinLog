import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/entities/transaction_entity.dart';

class TodayAnalysisPage extends StatelessWidget {
  const TodayAnalysisPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Analysis'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Trigger rebuild by accessing repository
          context.read<TransactionRepository>();
        },
        child: StreamBuilder(
          stream: context.watch<TransactionRepository>().onDataChanged,
          builder: (context, snapshot) {
            return FutureBuilder<Map<String, dynamic>>(
              future: _getTodayData(context),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
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
                            Colors.green,
                            Icons.arrow_downward,
                          ),
                          const SizedBox(width: 16),
                          _buildSummaryCard(
                            'Expenses',
                            expenses,
                            Colors.red,
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
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      
                      if (transactions.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('No transactions today'),
                          ),
                        )
                      else
                        ..._buildTransactionList(transactions),
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
