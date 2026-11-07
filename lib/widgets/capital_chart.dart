import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/dates.dart';
import '../utils/money.dart';

/// Courbe d'évolution du capital (valeurs en centimes).
class CapitalChart extends StatelessWidget {
  const CapitalChart({super.key, required this.points, this.height = 240});
  final List<MapEntry<DateTime, int>> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (points.length < 2) {
      return SizedBox(
        height: height * 0.6,
        child: Center(
          child: Text('Pas encore assez d’opérations pour tracer la courbe.',
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ),
      );
    }
    final first = points.first.key;
    double x(DateTime d) => d.difference(first).inDays.toDouble();
    final spots = [for (final p in points) FlSpot(x(p.key), p.value / 100)];
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxX = spots.last.x;
    final color = t.colorScheme.primary;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.1,
          minX: 0,
          maxX: maxX,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: _niceStep(maxY * 1.1),
            getDrawingHorizontalLine: (_) =>
                FlLine(color: t.colorScheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: _niceStep(maxY * 1.1),
                getTitlesWidget: (v, meta) => v == meta.max
                    ? const SizedBox.shrink()
                    : Text(_short(v), style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: maxX / 4 < 1 ? 1 : maxX / 4,
                getTitlesWidget: (v, meta) {
                  if (v == meta.max && v != 0 && meta.max - v < maxX / 8) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(Dates.month(first.add(Duration(days: v.round()))),
                        style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => t.colorScheme.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${Dates.day(first.add(Duration(days: s.x.round())))}\n${Money.compact((s.y * 100).round())}',
                    TextStyle(color: t.colorScheme.onInverseSurface, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _niceStep(double max) {
    if (max <= 0) return 1;
    final raw = max / 4;
    var mag = 1.0;
    while (mag * 10 <= raw) {
      mag *= 10;
    }
    for (final m in [1, 2, 2.5, 5, 10]) {
      if (raw <= m * mag) return m * mag;
    }
    return 10 * mag;
  }

  static String _short(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)} M';
    if (v >= 1000) return '${(v / 1000).round()} k';
    return v.round().toString();
  }
}
