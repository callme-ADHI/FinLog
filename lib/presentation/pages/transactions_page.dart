import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/entities/transaction_entity.dart';
import 'package:intl/intl.dart';
import 'manual_entry_page.dart';

class TransactionsPage extends StatefulWidget {
  final bool showAppBar;
  final DateTime? filterDate;
  final String? filterCategory;
  const TransactionsPage({super.key, this.showAppBar = true, this.filterDate, this.filterCategory});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  @override
  Widget build(BuildContext context) {
    String title = 'Transactions';
    if (widget.filterDate != null) {
        title = 'Transactions (${DateFormat('dd MMM').format(widget.filterDate!)})';
    } else if (widget.filterCategory != null) {
        title = widget.filterCategory!;
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Allow embedding
      appBar: widget.showAppBar ? AppBar(title: Text(title)) : null,
      body: StreamBuilder<void>(
        stream: context.read<TransactionRepository>().onDataChanged,
        builder: (context, _) {
          return FutureBuilder<List<TransactionEntity>>(
            future: context.read<TransactionRepository>().getTransactions(),
            builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
           if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          var transactions = snapshot.data ?? [];
          
          if (widget.filterDate != null) {
            transactions = transactions.where((t) {
               return t.timestamp.year == widget.filterDate!.year &&
                      t.timestamp.month == widget.filterDate!.month &&
                      t.timestamp.day == widget.filterDate!.day;
            }).toList();
          }

          if (widget.filterCategory != null) {
            transactions = transactions.where((t) => t.category == widget.filterCategory).toList();
          }

          if (transactions.isEmpty) {
             return const Center(child: Text('No transactions found.'));
          }
          
          return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: transaction.type == TransactionType.credit 
                            ? Colors.green.withOpacity(0.2) 
                            : Colors.red.withOpacity(0.2),
                        child: Icon(
                          transaction.type == TransactionType.credit 
                              ? Icons.arrow_downward 
                              : Icons.arrow_upward,
                          color: transaction.type == TransactionType.credit 
                              ? Colors.green 
                              : Colors.red,
                        ),
                      ),
                      title: Text(transaction.merchant.isNotEmpty ? transaction.merchant : transaction.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${DateFormat('dd MMM hh:mm a').format(transaction.timestamp)}\n${transaction.category} • ${transaction.source}'),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${transaction.type == TransactionType.credit ? '+' : '-'} ₹${transaction.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: transaction.type == TransactionType.credit ? Colors.greenAccent : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                // Open ManualEntryPage in Edit Mode
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ManualEntryPage(transaction: transaction)),
                                );
                                setState((){}); // Refresh
                              } else if (value == 'delete') {
                                // Confirm Delete
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Transaction?'),
                                    content: const Text('This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  if (!mounted) return;
                                  await context.read<TransactionRepository>().deleteTransaction(transaction.id!);
                                  setState((){}); // Refresh
                                }
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
            },
          );
        },
          );
        }
      ),
    );
  }
}
