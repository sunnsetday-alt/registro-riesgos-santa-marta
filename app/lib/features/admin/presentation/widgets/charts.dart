import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/common.dart';

/// Tarjeta indicador (KPI).
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, required this.icon, required this.color, this.onTap});
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, __) =>
                  Text('${v.round()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}

/// Tarjeta contenedora de un gráfico.
class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.title, required this.child, this.subtitle, this.height = 220});
  final String title;
  final String? subtitle;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        if (subtitle != null)
          Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        SizedBox(height: height, child: child),
      ]),
    );
  }
}

/// Barras horizontales con etiqueta, valor y color (legibles en móvil).
class HorizontalBars extends StatelessWidget {
  const HorizontalBars({super.key, required this.items, this.maxItems = 8});
  final List<({String label, int value, Color color})> items;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final list = items.take(maxItems).toList();
    final max = list.fold<int>(1, (m, e) => e.value > m ? e.value : m);
    if (list.isEmpty) return const Center(child: Text('Sin datos'));
    return Column(children: [
      for (final e in list)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(
              width: 110,
              child: Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: c.maxWidth * e.value / max),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (_, w, __) => Container(
                      height: 16,
                      width: w < 3 ? 3 : w,
                      decoration: BoxDecoration(color: e.color, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 30,
              child: Text('${e.value}', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
    ]);
  }
}

/// Gráfico de dona (estados).
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.items});
  final List<({String label, int value, Color color})> items;

  @override
  Widget build(BuildContext context) {
    final nonZero = items.where((e) => e.value > 0).toList();
    final total = nonZero.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) return const Center(child: Text('Sin datos'));
    return Row(children: [
      Expanded(
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 46,
            sections: [
              for (final e in nonZero)
                PieChartSectionData(value: e.value.toDouble(), color: e.color, radius: 26, showTitle: false),
            ],
          )),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const Text('total', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
      ),
      const SizedBox(width: 12),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${e.label} (${e.value})', style: const TextStyle(fontSize: 12)),
              ]),
            ),
        ],
      ),
    ]);
  }
}

/// Serie diaria de reportes.
class DailyLineChart extends StatelessWidget {
  const DailyLineChart({super.key, required this.points});
  final List<({DateTime date, int count})> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('Sin datos'));
    final maxY = points.fold<int>(1, (m, p) => p.count > m ? p.count : m).toDouble();
    final step = (points.length / 5).ceil().clamp(1, 1000);
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxY + 1,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: (maxY / 4).ceilToDouble().clamp(1.0, 1000.0),
            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: step.toDouble(),
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= points.length) return const SizedBox.shrink();
              final d = points[i].date;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].count.toDouble())],
          isCurved: true,
          preventCurveOverShooting: true,
          color: AppColors.ocean,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [AppColors.turquoise.withAlpha(110), AppColors.turquoise.withAlpha(0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    ));
  }
}

/// Barras verticales por nivel de importancia.
class SeverityBarChart extends StatelessWidget {
  const SeverityBarChart({super.key, required this.counts, required this.colors, required this.labels});
  final List<int> counts;
  final List<Color> colors;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final maxY = counts.fold<int>(1, (m, c) => c > m ? c : m).toDouble();
    return BarChart(BarChartData(
      maxY: maxY * 1.2,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= labels.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(labels[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < counts.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: counts[i].toDouble(),
              color: colors[i],
              width: 26,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ]),
      ],
    ));
  }
}
