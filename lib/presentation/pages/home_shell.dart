import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'transactions_page.dart';
import 'monthly_analysis_page.dart';
import 'categories_page.dart';
import 'settings_page.dart';
import 'manual_entry_page.dart';
import 'today_analysis_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const TodayAnalysisPage(),
    const TransactionsPage(showAppBar: true),
    const MonthlyAnalysisPage(),
    const CategoriesPage(), // Or Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'main_fab',
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualEntryPage()));
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          indicatorColor: Colors.teal.withOpacity(0.2),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          height: 60,
          backgroundColor: const Color(0xFF1E1E1E), // Match card color
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: Colors.tealAccent),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today, color: Colors.tealAccent),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt),
              selectedIcon: Icon(Icons.list_alt, color: Colors.tealAccent),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart, color: Colors.tealAccent),
              label: 'Analysis',
            ),
            NavigationDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category, color: Colors.tealAccent),
              label: 'Category',
            ),
          ],
        ),
      ),
    );
  }
}
