import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import 'transactions_page.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/transaction_repository.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<String> _userCategories = [];
  List<String> _systemCategories = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final userCats = prefs.getStringList('user_categories') ?? [];
    
    // System categories
    final sysCats = AppConstants.categoryKeywords.keys.toList();
    sysCats.sort();
    
    // Default sort for user cats
    userCats.sort();

    setState(() {
      _userCategories = userCats;
      _systemCategories = sysCats;
    });
  }

  Future<void> _addCategory(String name) async {
    if (name.isEmpty) return;
    
    // Check duplicates in both lists
    if (_userCategories.contains(name) || _systemCategories.contains(name)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category already exists')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _userCategories.add(name);
    await prefs.setStringList('user_categories', _userCategories);

    _loadCategories();
    _controller.clear();
    if(mounted) Navigator.pop(context);
  }

  Future<void> _editCategory(String oldName) async {
    _controller.text = oldName;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'New Name'),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = _controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                 final prefs = await SharedPreferences.getInstance();
                 final repo = context.read<TransactionRepository>();
                 
                 // Update category in all existing transactions
                 await repo.updateCategoryForAll(oldName, newName);
                 
                 // Update List in SharedPreferences
                 final index = _userCategories.indexOf(oldName);
                 if (index != -1) {
                   _userCategories[index] = newName;
                   await prefs.setStringList('user_categories', _userCategories);
                   _loadCategories();
                 }
              }
              if(mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
     _controller.clear();
  }

  Future<void> _deleteCategory(String name) async {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('Delete Category?'),
              content: Text('Delete "$name"?'),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
              ]
          )
      );

      if (confirm == true) {
          final prefs = await SharedPreferences.getInstance();
          _userCategories.remove(name);
          await prefs.setStringList('user_categories', _userCategories);
          _loadCategories();
      }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: ListView(
        children: [
          _buildSectionHeader('My Categories'),
          if (_userCategories.isEmpty)
             const Padding(
               padding: EdgeInsets.all(16.0),
               child: Text('No custom categories. Add one below!', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
             ),
          ..._userCategories.map((category) => ListTile(
            onTap: () {
               // Navigation to Transactions filtered by this category
               Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionsPage(filterCategory: category)));
            },
            leading: CircleAvatar(
              backgroundColor: Colors.teal.withOpacity(0.2),
              child: Text(category.isNotEmpty ? category[0].toUpperCase() : '?', style: const TextStyle(color: Colors.tealAccent)),
            ),
            title: Text(category),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white60),
              onSelected: (value) {
                if (value == 'edit') _editCategory(category);
                if (value == 'delete') _deleteCategory(category);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Rename')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          )),
          
          const Divider(height: 32, thickness: 1, color: Colors.white10),

          _buildSectionHeader('System Categories'),
          ..._systemCategories.map((category) => ListTile(
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionsPage(filterCategory: category)));
            },
            leading: const CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(Icons.lock_outline, size: 16, color: Colors.white54),
            ),
            title: Text(category, style: const TextStyle(color: Colors.white70)),
            // No trailing action for system cats
          )),
          const SizedBox(height: 80), // Bottom padding for FAB
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'cat_fab',
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('New Category'),
              content: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'e.g. Gym, Freelance',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => _addCategory(_controller.text.trim()),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
