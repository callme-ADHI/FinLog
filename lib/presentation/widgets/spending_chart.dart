import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SpendingChart extends StatelessWidget {
  final Map<DateTime, double> data;

  const SpendingChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    // Prepare Spot Data
    List<FlSpot> spots = [];
    double maxAmount = 100;
    int index = 0;
    List<DateTime> sortedKeys = data.keys.toList()..sort();
    
    for (var date in sortedKeys) {
      final amount = data[date]!;
      if (amount > maxAmount) maxAmount = amount;
      spots.add(FlSpot(index.toDouble(), amount));
      index++;
    }

    return AspectRatio(
      aspectRatio: 1.70,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(
            Radius.circular(18),
          ),
          color: Color(0xFF232C33), // Dark card background
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            right: 18,
            left: 12,
            top: 24,
            bottom: 12,
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: maxAmount / 5,
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return const FlLine(
                    color: Color(0xff37434d),
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return const FlLine(
                    color: Color(0xff37434d),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                       if (value.toInt() >= 0 && value.toInt() < sortedKeys.length) {
                         final date = sortedKeys[value.toInt()];
                         return Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(
                             DateFormat('E').format(date)[0],
                             style: const TextStyle(
                               color: Color(0xff68737d),
                               fontWeight: FontWeight.bold,
                               fontSize: 12,
                             ),
                           ),
                         );
                       }
                       return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxAmount / 4,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        compactNumber(value),
                        style: const TextStyle(
                          color: Color(0xff67727d),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.left,
                      );
                    },
                    reservedSize: 42,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xff37434d)),
              ),
              minX: 0,
              maxX: (data.length - 1).toDouble(),
              minY: 0,
              maxY: maxAmount * 1.1,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff23b6e6),
                      Color(0xff02d39a),
                    ],
                  ),
                  barWidth: 5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xff23b6e6).withOpacity(0.3),
                        const Color(0xff02d39a).withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String compactNumber(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toInt().toString();
  }
}
