import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

class ManualEntryPage extends StatefulWidget {
  final TransactionEntity? transaction;
  const ManualEntryPage({super.key, this.transaction});

  @override
  State<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends State<ManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  TransactionType _selectedType = TransactionType.debit;
  String _selectedCategory = 'Others';
  DateTime _selectedDate = DateTime.now();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _isEditing = true;
      final t = widget.transaction!;
      _amountController.text = t.amount.toString();
      _descriptionController.text = t.description ?? '';
      _selectedType = t.type;
      _selectedCategory = t.category;
      _selectedDate = t.timestamp;
      
      // Ensure category exists in dropdown, else add it temporarily (or use Others)
      // This logic will be handled in build or here.
     }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);
    final timestamp = _selectedDate.millisecondsSinceEpoch;
    
    // Generate Logic as per algorithm
    final randomSuffix = Random().nextInt(10000).toString().padLeft(4, '0');
    final manualId = "MANUAL_${timestamp}_$randomSuffix"; // Acts as UTR
    final description = _descriptionController.text.isEmpty ? "Manual Entry" : _descriptionController.text;

    // Hash Generation
    // hash = SHA256(amount + type + date + "MANUAL")
    // Using md5 as per existing pattern or SHA256 as per request?
    // Current app uses md5 for SMS. Request asked for SHA256. 
    // To match existing `crypto` import which likely has sha256.
    // Let's stick to existing hash pattern for consistency or strictly follow new algo?
    // Request specifically said: hash = SHA256(...)
    // I need to import sha256. 'package:crypto/crypto.dart' has it.
    
    final hashInput = "$amount${_selectedType.toString()}$timestamp" "MANUAL";
    final hash = sha256.convert(utf8.encode(hashInput)).toString();

    final transaction = TransactionEntity(
      id: widget.transaction?.id, // Keep ID if editing
      amount: amount,
      type: _selectedType,
      category: _selectedCategory,
      merchant: widget.transaction?.merchant ?? "Manual Entry", 
      utr: widget.transaction?.utr ?? manualId, // Keep UTR if editing
      timestamp: _selectedDate,
      hash: hash,
      source: widget.transaction?.source ?? 'MANUAL',
      description: description,
    );

    final repo = context.read<TransactionRepository>();
    if (_isEditing) {
      await repo.updateTransaction(transaction);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction Updated')));
    } else {
      await repo.addTransaction(transaction);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction Added')));
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _loadCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        // Ensure selected category is in list (if it was a custom one)
        var categories = snapshot.data!;
        if (!categories.contains(_selectedCategory)) {
           // If editing a deleted category or just not loaded yet?
           // Actually _loadCategories fetches defaults + custom.
           // If _selectedCategory isn't there, we better add it or defaults to Others.
           if (_selectedCategory != 'Others') {
             categories = [...categories, _selectedCategory];
           }
        }

        return Scaffold(
          appBar: AppBar(title: Text(_isEditing ? 'Edit Transaction' : 'Add Manual Transaction')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Amount
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter amount';
                      if (double.tryParse(value) == null) return 'Invalid amount';
                      if (double.parse(value) <= 0) return 'Amount must be > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
    
                  // Type
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(value: TransactionType.debit, label: Text('Debit')),
                      ButtonSegment(value: TransactionType.credit, label: Text('Credit')),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<TransactionType> newSelection) {
                      setState(() {
                        _selectedType = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
    
                  // Category
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: categories.contains(_selectedCategory) ? _selectedCategory : 'Others',
                          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) => setState(() => _selectedCategory = val!),
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.withOpacity(0.5)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.tealAccent),
                          onPressed: _addCustomCategory,
                          tooltip: 'Add New Category',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
    
                  // Date
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(_selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Colors.white24)),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(), // Future dates rejected
                      );
                      if (date != null && mounted) {
                         final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_selectedDate));
                         if (time != null) {
                           setState(() {
                             _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                           });
                         }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
    
                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
    
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isEditing ? 'Update Transaction' : 'Save Transaction'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Future<void> _addCustomCategory() async {
      final controller = TextEditingController();
      final name = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('New Category'),
              content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: 'e.g. Taxi'),
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                      child: const Text('Add'),
                  )
              ],
          )
      );

      if (name != null && name.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final userCats = prefs.getStringList('user_categories') ?? [];
          if (!userCats.contains(name)) {
              userCats.add(name);
              await prefs.setStringList('user_categories', userCats);
              setState(() {
                  _selectedCategory = name; // Auto-select
              });
          }
      }
  }

  Future<List<String>> _loadCategories() async {
      final prefs = await SharedPreferences.getInstance();
      final userCategories = prefs.getStringList('user_categories') ?? [];
      final defaultCategories = AppConstants.categoryKeywords.keys.toList();
      final all = [...defaultCategories, 'Others', ...userCategories].toSet().toList();
      all.sort();
      return all;
  }
}
