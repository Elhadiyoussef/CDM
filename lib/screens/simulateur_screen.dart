import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

class _Scenario {
  const _Scenario(this.nom, this.taux, this.color);
  final String nom;
  final double taux; // annuel, ex. 0.035
  final Color color;
}

/// Projection du capital futur selon trois scénarios (estimation non contractuelle).
class SimulateurScreen extends StatefulWidget {
  const SimulateurScreen({super.key});

  @override
  State<SimulateurScreen> createState() => _SimulateurScreenState();
}

class _SimulateurScreenState extends State<SimulateurScreen> {
  final _capital = TextEditingController();
  final _mensuel = TextEditingController();
  double _annees = 15;
  double _tauxCentral = 3.5;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final s = AppScope.read(context);
    final actifs = s.contrats.where((c) => c.statut == StatutContrat.actif);
    final mensuel = actifs.fold<int>(0, (sum, c) => sum + c.cotisation ~/ c.periodicite.mois);
    _capital.text = Money.toInput(s.capital());
    _mensuel.text = Money.toInput(mensuel == 0 ? 50000 : mensuel);
    final echeances = actifs.where((c) => c.dateEcheance != null).map((c) => c.dateEcheance!).toList()..sort();
    if (echeances.isNotEmpty) {
      final years = echeances.first.difference(Dates.today()).inDays / 365.25;
      _annees = years.clamp(1, 40).roundToDouble();
    }
  }

  /// Valeur (en DH) mois par mois, versements en début de mois, capitalisation mensuelle.
  List<double> _projection(double capital, double mensuel, double tauxAnnuel, int mois) {
    final r = math.pow(1 + tauxAnnuel, 1 / 12) - 1;
    final values = <double>[capital];
    var v = capital;
    for (var i = 0; i < mois; i++) {
      v = (v + mensuel) * (1 + r);
      values.add(v);
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final capital = (Money.parse(_capital.text) ?? 0) / 100;
    final mensuel = (Money.parse(_mensuel.text) ?? 0) / 100;
    final mois = (_annees * 12).round();
    final scenarios = [
      _Scenario('Prudent', math.max(0, _tauxCentral - 1.5) / 100, AppColors.info),
      _Scenario('Central', _tauxCentral / 100, AppColors.brand),
      _Scenario('Favorable', (_tauxCentral + 1.5) / 100, AppColors.gold),
    ];
    final series = [for (final sc in scenarios) _projection(capital, mensuel, sc.taux, mois)];
    final totalVerse = capital + mensuel * mois;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final fin = DateTime(Dates.today().year + _annees.round(), Dates.today().month);

    final params = SectionCard(
      title: 'Hypothèses',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _capital,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Capital de départ', suffixText: 'DH'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _mensuel,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Épargne mensuelle', suffixText: 'DH'),
        ),
        const SizedBox(height: 20),
        _SliderLabel('Durée', '${_annees.round()} ans · ${fin.year}'),
        Slider(
          value: _annees,
          min: 1,
          max: 40,
          divisions: 39,
          label: '${_annees.round()} ans',
          onChanged: (v) => setState(() => _annees = v),
        ),
        _SliderLabel('Rendement annuel central', '${_tauxCentral.toStringAsFixed(1).replaceAll('.', ',')} %'),
        Slider(
          value: _tauxCentral,
          min: 0,
          max: 8,
          divisions: 32,
          label: '${_tauxCentral.toStringAsFixed(2)} %',
          onChanged: (v) => setState(() => _tauxCentral = v),
        ),
        Text('Prudent = central − 1,5 pt · Favorable = central + 1,5 pt',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
      ]),
    );

    final results = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ResponsiveGrid(minItemWidth: 190, children: [
        for (var i = 0; i < scenarios.length; i++)
          _ScenarioCard(
            scenario: scenarios[i],
            capitalFinal: series[i].last,
            totalVerse: totalVerse,
            highlighted: i == 1,
          ),
      ]),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Projection sur ${_annees.round()} ans',
        child: _ProjectionChart(series: series, colors: [for (final s in scenarios) s.color], verse: totalVerse, mois: mois),
      ),
    ]);

    return PageBody(children: [
      Text('Simulateur retraite', style: t.textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text('Estimez votre capital au départ à la retraite selon plusieurs scénarios.',
          style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 20),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 360, child: params),
          const SizedBox(width: 12),
          Expanded(child: results),
        ])
      else ...[
        params,
        const SizedBox(height: 12),
        results,
      ],
      const SizedBox(height: 16),
      const InfoBanner(
        text: 'Simulation indicative et non contractuelle : rendements constants hypothétiques, hors frais, '
            'fiscalité et inflation. Elle ne constitue pas un engagement de l’assureur. '
            'Le retrait mensuel est calculé sur 20 ans, sans revalorisation pendant la phase de retrait.',
      ),
    ]);
  }
}

class _SliderLabel extends StatelessWidget {
  const _SliderLabel(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(children: [
      Expanded(child: Text(label, style: t.textTheme.labelLarge)),
      Text(value, style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario, required this.capitalFinal, required this.totalVerse, this.highlighted = false});
  final _Scenario scenario;
  final double capitalFinal;
  final double totalVerse;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final capCents = (capitalFinal * 100).round();
    final gainCents = ((capitalFinal - totalVerse) * 100).round();
    return Card(
      shape: highlighted
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: scenario.color, width: 2))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: scenario.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(scenario.nom, style: t.textTheme.titleSmall),
            const Spacer(),
            Text('${(scenario.taux * 100).toStringAsFixed(1).replaceAll('.', ',')} %/an',
                style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(Money.compact(capCents), style: t.textTheme.titleLarge),
          ),
          const SizedBox(height: 4),
          Text('dont ${Money.compact(gainCents)} d’intérêts',
              style: t.textTheme.bodySmall?.copyWith(color: AppColors.positive, fontWeight: FontWeight.w600)),
          const Divider(height: 20),
          Text('≈ ${Money.compact(capCents ~/ 240)} / mois',
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text('retrait sur 20 ans', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _ProjectionChart extends StatelessWidget {
  const _ProjectionChart({required this.series, required this.colors, required this.verse, required this.mois});
  final List<List<double>> series;
  final List<Color> colors;
  final double verse;
  final int mois;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final step = math.max(1, mois ~/ 60);
    List<FlSpot> spots(List<double> v) => [
          for (var i = 0; i < v.length; i += step) FlSpot(i / 12, v[i]),
          if ((v.length - 1) % step != 0) FlSpot((v.length - 1) / 12, v.last),
        ];
    final maxY = series.last.last * 1.08;
    final first = series[1].first;
    final perMonth = mois == 0 ? 0 : (verse - first) / mois;
    final interval = maxY <= 0 ? 1.0 : _nice(maxY / 4);
    final xInterval = math.max(1, (mois / 12 / 5).ceil()).toDouble();

    return SizedBox(
      height: 260,
      child: LineChart(LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY,
        minX: 0,
        maxX: mois / 12,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: t.colorScheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [4, 4]),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: interval,
              getTitlesWidget: (v, meta) => v == meta.max
                  ? const SizedBox.shrink()
                  : Text(v >= 1e6 ? '${(v / 1e6).toStringAsFixed(1)} M' : '${(v / 1000).round()} k',
                      style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: xInterval,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${v.round()} an${v.round() > 1 ? 's' : ''}',
                    style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => t.colorScheme.inverseSurface,
            getTooltipItems: (items) => [
              for (final s in items)
                LineTooltipItem(
                  Money.compact((s.y * 100).round()),
                  TextStyle(color: s.bar.color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          // Cumul des versements (référence)
          LineChartBarData(
            spots: [FlSpot(0, first), FlSpot(mois / 12, first + perMonth * mois)],
            color: t.colorScheme.outline,
            barWidth: 1.5,
            dashArray: [6, 4],
            dotData: const FlDotData(show: false),
          ),
          for (var i = 0; i < series.length; i++)
            LineChartBarData(
              spots: spots(series[i]),
              isCurved: true,
              color: colors[i],
              barWidth: i == 1 ? 3 : 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: i == 1, color: colors[i].withValues(alpha: 0.08)),
            ),
        ],
      )),
    );
  }

  static double _nice(double raw) {
    var mag = 1.0;
    while (mag * 10 <= raw) {
      mag *= 10;
    }
    for (final m in [1, 2, 2.5, 5, 10]) {
      if (raw <= m * mag) return m * mag;
    }
    return 10 * mag;
  }
}
