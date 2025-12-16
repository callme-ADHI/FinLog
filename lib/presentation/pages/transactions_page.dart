import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../core/services/sms_service.dart';
import 'package:intl/intl.dart';
import 'manual_entry_page.dart';

enum FilterType { day, week, month, year }

class TransactionsPage extends StatefulWidget {
  final bool showAppBar;
  final DateTime? filterDate;
  final String? filterCategory;
  const TransactionsPage({super.key, this.showAppBar = true, this.filterDate, this.filterCategory});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  FilterType _filterType = FilterType.day;
  DateTime _selectedDate = DateTime.now();
  bool _isScanning = false;

  Future<void> _pickDateAndScan() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select date to scan SMS',
    );
    
    if (picked != null && mounted) {
      setState(() => _isScanning = true);
      
      try {
        final smsService = context.read<SmsService>();
        final imported = await smsService.scanDateSms(picked);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(imported > 0 
                ? 'Found $imported transactions for ${DateFormat('dd MMM').format(picked)}!' 
                : 'No new transactions found'),
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
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select any day in the week',
    );
    if (picked != null) {
      // Get start of that week (Monday)
      final weekStart = picked.subtract(Duration(days: picked.weekday - 1));
      setState(() => _selectedDate = weekStart);
    }
  }

  Future<void> _pickMonth() async {
    int selectedYear = _selectedDate.year;
    int selectedMonth = _selectedDate.month;
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Month'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: Column(
            children: [
              // Year selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      selectedYear--;
                      (ctx as Element).markNeedsBuild();
                    },
                  ),
                  Text('$selectedYear', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: selectedYear < DateTime.now().year ? () {
                      selectedYear++;
                      (ctx as Element).markNeedsBuild();
                    } : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Month grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final isDisabled = selectedYear == DateTime.now().year && month > DateTime.now().month;
                    return InkWell(
                      onTap: isDisabled ? null : () {
                        setState(() {
                          _selectedDate = DateTime(selectedYear, month, 1);
                          _filterType = FilterType.month;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: selectedMonth == month && selectedYear == _selectedDate.year 
                            ? Colors.tealAccent.withOpacity(0.3) 
                            : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDisabled ? Colors.grey : Colors.white24),
                        ),
                        child: Center(
                          child: Text(
                            DateFormat('MMM').format(DateTime(2024, month)),
                            style: TextStyle(color: isDisabled ? Colors.grey : Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickYear() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 2019, (i) => currentYear - i);
    
    await showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Year'),
        children: years.map((year) => SimpleDialogOption(
          onPressed: () {
            setState(() {
              _selectedDate = DateTime(year, 1, 1);
              _filterType = FilterType.year;
            });
            Navigator.pop(ctx);
          },
          child: Text('$year', style: const TextStyle(fontSize: 18)),
        )).toList(),
      ),
    );
  }

  List<TransactionEntity> _applyFilter(List<TransactionEntity> transactions) {
    switch (_filterType) {
      case FilterType.day:
        return transactions.where((t) =>
          t.timestamp.year == _selectedDate.year &&
          t.timestamp.month == _selectedDate.month &&
          t.timestamp.day == _selectedDate.day
        ).toList();
      case FilterType.week:
        final weekStart = _selectedDate;
        final weekEnd = weekStart.add(const Duration(days: 7));
        return transactions.where((t) => 
          t.timestamp.isAfter(weekStart.subtract(const Duration(seconds: 1))) && 
          t.timestamp.isBefore(weekEnd)
        ).toList();
      case FilterType.month:
        return transactions.where((t) =>
          t.timestamp.year == _selectedDate.year &&
          t.timestamp.month == _selectedDate.month
        ).toList();
      case FilterType.year:
        return transactions.where((t) => t.timestamp.year == _selectedDate.year).toList();
    }
  }

  String _getFilterLabel() {
    switch (_filterType) {
      case FilterType.day:
        return DateFormat('dd MMM yyyy').format(_selectedDate);
      case FilterType.week:
        final weekEnd = _selectedDate.add(const Duration(days: 6));
        return '${DateFormat('dd MMM').format(_selectedDate)} - ${DateFormat('dd MMM').format(weekEnd)}';
      case FilterType.month:
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case FilterType.year:
        return '${_selectedDate.year}';
    }
  }

  void _selectFilter(FilterType type) async {
    setState(() => _filterType = type);
    switch (type) {
      case FilterType.day:
        await _pickDate();
        break;
      case FilterType.week:
        await _pickWeek();
        break;
      case FilterType.month:
        await _pickMonth();
        break;
      case FilterType.year:
        await _pickYear();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'History';
    if (widget.filterCategory != null) {
      title = widget.filterCategory!;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: widget.showAppBar ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isScanning 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sms),
            onPressed: _isScanning ? null : _pickDateAndScan,
            tooltip: 'Scan SMS for a date',
          ),
        ],
      ) : null,
      body: Column(
        children: [
          // Filter Type Selector
          if (widget.filterCategory == null && widget.filterDate == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Filter type chips
                  Row(
                    children: [
                      _buildFilterChip('Day', FilterType.day),
                      const SizedBox(width: 8),
                      _buildFilterChip('Week', FilterType.week),
                      const SizedBox(width: 8),
                      _buildFilterChip('Month', FilterType.month),
                      const SizedBox(width: 8),
                      _buildFilterChip('Year', FilterType.year),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Current selection display with navigation
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white70),
                          onPressed: () => _navigate(-1),
                        ),
                        GestureDetector(
                          onTap: () => _selectFilter(_filterType),
                          child: Text(
                            _getFilterLabel(),
                            style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white70),
                          onPressed: _canNavigateForward() ? () => _navigate(1) : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Transactions List
          Expanded(
            child: StreamBuilder<void>(
              stream: context.read<TransactionRepository>().onDataChanged,
              builder: (context, _) {
                return FutureBuilder<List<TransactionEntity>>(
                  future: context.read<TransactionRepository>().getTransactions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    
                    var transactions = snapshot.data ?? [];
                    
                    // Apply widget filters
                    if (widget.filterDate != null) {
                      transactions = transactions.where((t) =>
                        t.timestamp.year == widget.filterDate!.year &&
                        t.timestamp.month == widget.filterDate!.month &&
                        t.timestamp.day == widget.filterDate!.day
                      ).toList();
                    }
                    
                    if (widget.filterCategory != null) {
                      transactions = transactions.where((t) => t.category == widget.filterCategory).toList();
                    }
                    
                    // Apply date filter
                    if (widget.filterCategory == null && widget.filterDate == null) {
                      transactions = _applyFilter(transactions);
                    }
                    
                    // Calculate totals
                    double totalIncome = 0, totalSpending = 0;
                    for (var t in transactions) {
                      if (t.type == TransactionType.credit) {
                        totalIncome += t.amount;
                      } else {
                        totalSpending += t.amount;
                      }
                    }
                    
                    if (transactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text('No transactions', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                          ],
                        ),
                      );
                    }
                    
                    return Column(
                      children: [
                        // Summary Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem('Income', totalIncome, Colors.greenAccent),
                              Container(width: 1, height: 30, color: Colors.white24),
                              _buildSummaryItem('Spent', totalSpending, Colors.redAccent),
                              Container(width: 1, height: 30, color: Colors.white24),
                              _buildSummaryItem('Net', totalIncome - totalSpending, 
                                totalIncome >= totalSpending ? Colors.tealAccent : Colors.orange),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: transactions.length,
                            itemBuilder: (context, index) => _buildTransactionCard(transactions[index]),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(int direction) {
    setState(() {
      switch (_filterType) {
        case FilterType.day:
          _selectedDate = _selectedDate.add(Duration(days: direction));
          break;
        case FilterType.week:
          _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
          break;
        case FilterType.month:
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + direction, 1);
          break;
        case FilterType.year:
          _selectedDate = DateTime(_selectedDate.year + direction, 1, 1);
          break;
      }
    });
  }

  bool _canNavigateForward() {
    final now = DateTime.now();
    switch (_filterType) {
      case FilterType.day:
        return _selectedDate.isBefore(DateTime(now.year, now.month, now.day));
      case FilterType.week:
        return _selectedDate.add(const Duration(days: 7)).isBefore(now);
      case FilterType.month:
        return _selectedDate.year < now.year || 
               (_selectedDate.year == now.year && _selectedDate.month < now.month);
      case FilterType.year:
        return _selectedDate.year < now.year;
    }
  }

  Widget _buildFilterChip(String label, FilterType type) {
    final isSelected = _filterType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectFilter(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.tealAccent.withOpacity(0.2) : Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? Colors.tealAccent : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.tealAccent : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
        const SizedBox(height: 4),
        Text('₹${amount.abs().toStringAsFixed(0)}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTransactionCard(TransactionEntity t) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E1E1E),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: t.type == TransactionType.credit ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
          child: Icon(t.type == TransactionType.credit ? Icons.arrow_downward : Icons.arrow_upward,
            color: t.type == TransactionType.credit ? Colors.green : Colors.red),
        ),
        title: Text(t.merchant.isNotEmpty ? t.merchant : t.category, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text('${DateFormat('dd MMM hh:mm a').format(t.timestamp)}\n${t.category}',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${t.type == TransactionType.credit ? '+' : '-'} ₹${t.amount.toStringAsFixed(0)}',
              style: TextStyle(color: t.type == TransactionType.credit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              onSelected: (v) async {
                if (v == 'edit') {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ManualEntryPage(transaction: t)));
                  setState(() {});
                } else if (v == 'delete') {
                  final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    title: const Text('Delete?'), actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ]));
                  if (c == true && mounted) {
                    await context.read<TransactionRepository>().deleteTransaction(t.id!);
                    setState(() {});
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
