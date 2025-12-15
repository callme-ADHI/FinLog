import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/transaction_repository.dart';

class MonthlyAnalysisPage extends StatefulWidget {
  const MonthlyAnalysisPage({super.key});

  @override
  State<MonthlyAnalysisPage> createState() => _MonthlyAnalysisPageState();
}

class _MonthlyAnalysisPageState extends State<MonthlyAnalysisPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TransactionRepository>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Monthly Analysis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.pie_chart_outline, size: 20)),
            Tab(text: 'Categories', icon: Icon(Icons.category_outlined, size: 20)),
          ],
        ),
      ),
      body: StreamBuilder(
        stream: repo.onDataChanged,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(repo),
              _buildCategoriesTab(repo),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(TransactionRepository repo) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getOverviewData(repo),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final monthSpending = data['monthSpending'] as double;
        final monthIncome = data['monthIncome'] as double;
        final balance = data['balance'] as double;
        final categoryData = data['categoryData'] as Map<String, double>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Cards Row
              Row(
                children: [
                  _buildSummaryCard(
                    'Month Income',
                    monthIncome,
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'Month Expenses',
                    monthSpending,
                    Icons.arrow_upward,
                    Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Net Balance Card
              _buildNetBalanceCard(monthIncome - monthSpending),
              const SizedBox(height: 24),

              // Pie Chart Section
              if (categoryData.isNotEmpty) ...[
                Text(
                  'Spending by Category',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPieChart(categoryData),
                const SizedBox(height: 24),
              ],

              // Daily Spending Trend
              Text(
                'Daily Spending This Month',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDailyTrendChart(repo),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab(TransactionRepository repo) {
    return FutureBuilder<Map<String, double>>(
      future: repo.getCategoryWiseSpending(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        if (data.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, size: 80, color: Colors.white.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'No spending data yet',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
                ),
              ],
            ),
          );
        }

        final total = data.values.fold(0.0, (sum, val) => sum + val);
        final sortedEntries = data.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedEntries.length,
          itemBuilder: (context, index) {
            final entry = sortedEntries[index];
            final percentage = (entry.value / total * 100);
            return _buildCategoryCard(entry.key, entry.value, percentage, index);
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getOverviewData(TransactionRepository repo) async {
    final results = await Future.wait([
      repo.getMonthSpending(),
      repo.getMonthIncome(),
      repo.getBalance(),
      repo.getCategoryWiseSpending(),
    ]);

    return {
      'monthSpending': results[0],
      'monthIncome': results[1],
      'balance': results[2],
      'categoryData': results[3],
    };
  }

  Widget _buildSummaryCard(String title, double amount, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
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
      color: isPositive ? Colors.green.shade900.withOpacity(0.3) : Colors.red.shade900.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net This Month',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isPositive ? '+' : ''}₹${net.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isPositive ? Colors.green.shade400 : Colors.red.shade400,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              size: 48,
              color: isPositive ? Colors.green.shade400.withOpacity(0.5) : Colors.red.shade400.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> data) {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.pink.shade400,
      Colors.teal.shade400,
      Colors.amber.shade400,
      Colors.red.shade400,
    ];

    final total = data.values.fold(0.0, (sum, val) => sum + val);

    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: data.entries.toList().asMap().entries.map((entry) {
                final index = entry.key;
                final categoryEntry = entry.value;
                final percentage = (categoryEntry.value / total * 100);
                
                return PieChartSectionData(
                  color: colors[index % colors.length],
                  value: categoryEntry.value,
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: 60,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTrendChart(TransactionRepository repo) {
    return FutureBuilder<Map<int, double>>(
      future: repo.getMonthDailySpending(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(height: 200, child: Center(child: Text('No data', style: TextStyle(color: Colors.white60))));
        }

        final data = snapshot.data!;
        final maxY = data.values.fold(0.0, (max, val) => val > max ? val : max);

        return Card(
          color: const Color(0xFF1E1E1E),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() % 5 == 0) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(color: Colors.white60, fontSize: 10),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: data.entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          color: Colors.tealAccent,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(String category, double amount, double percentage, int index) {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.pink.shade400,
      Colors.teal.shade400,
      Colors.amber.shade400,
      Colors.red.shade400,
    ];

    final color = colors[index % colors.length];

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${percentage.toStringAsFixed(1)}% of total spending',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
