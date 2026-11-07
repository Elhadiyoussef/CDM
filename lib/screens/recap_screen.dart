import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/transfer_service.dart';
import '../models/parametres.dart';
import '../models/taux_annuel.dart';
import '../services/calcul_annuel.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../utils/tableur.dart';
import '../widgets/common.dart';
import 'referentiels_screen.dart';

/// Récapitulatif annuel : épargne brute, commissions, épargne nette, rendement net, capital.
class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  String? _contratId;
  bool _selonTaux = true;

  Future<void> _exporter(Recap r, AppState s) async {
    String m(int c) => '${c < 0 ? '-' : ''}${Money.toInput(c.abs())}';
    final b = StringBuffer()
      ..writeln([
        'Année', 'Capital 1er janvier', 'Épargne brute', 'Taux commission', 'Commission', 'Épargne nette',
        'Taux rendement', 'Rendement net', 'Rachats et frais', 'Capital 31 décembre', 'Remarque',
      ].join(';'));
    for (final a in r.annees) {
      b.writeln([
        a.annee, m(a.capitalDebut), m(a.epargneBrute), _selonTaux ? Taux.toInput(a.tauxCommission) : '', m(a.commission),
        m(a.epargneNette), _selonTaux ? Taux.toInput(a.tauxRendement) : '', m(a.rendement), m(a.sorties), m(a.capitalFin),
        Tableur.cellule([if (a.tauxEstime) 'taux estimé', if (a.rendementManquant && _selonTaux) 'taux de rendement manquant', if (a.enCours) 'année en cours'].join(', ')),
      ].join(';'));
    }
    b.writeln(['Total', '', m(r.epargneBrute), '', m(r.commission), m(r.epargneNette), '', m(r.rendement), m(r.sorties), m(r.capitalFin), ''].join(';'));
    final c = _contratId == null ? null : s.contrat(_contratId!);
    final nom = 'recap_${c?.reference ?? 'tous_contrats'}_${_selonTaux ? 'taux' : 'operations'}.csv';
    try {
      await TransferService.enregistrer(b.toString(), nom, mimeType: 'text/csv');
      if (mounted) showMessage(context, 'Récapitulatif exporté.');
    } catch (e) {
      if (mounted) showMessage(context, 'Export impossible : $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context);
    if (_contratId != null && s.contrat(_contratId!) == null) _contratId = null;
    final r = s.recap(contratId: _contratId, selonTaux: _selonTaux);
    // Les taux et le détail par cotisation n'ont de sens que pour un contrat donné.
    final colTaux = _selonTaux && _contratId != null;
    final p = s.parametres;
    final manquants = r.annees.where((a) => _selonTaux && !a.enCours && (a.rendementManquant || a.commissionManquante)).map((a) => a.annee).toList();
    final reval = '${p.jourRevalorisation} ${const ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'][p.moisRevalorisation - 1]}';

    return PageBody(children: [
      Row(children: [
        Expanded(child: Text('Récapitulatif annuel', style: t.textTheme.headlineSmall)),
        IconButton.outlined(
          tooltip: 'Exporter en CSV (Excel)',
          onPressed: r.annees.isEmpty ? null : () => _exporter(r, s),
          icon: const Icon(Icons.table_view),
        ),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 320,
          child: DropdownButtonFormField<String?>(
            initialValue: _contratId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Contrat', prefixIcon: Icon(Icons.filter_list)),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tous les contrats')),
              for (final c in s.contrats) DropdownMenuItem(value: c.id, child: Text('${c.reference} · ${s.nomProduit(c)}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _contratId = v),
          ),
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Selon les taux'), icon: Icon(Icons.percent)),
            ButtonSegment(value: false, label: Text('Selon les opérations'), icon: Icon(Icons.receipt_long)),
          ],
          selected: {_selonTaux},
          onSelectionChanged: (v) => setState(() => _selonTaux = v.first),
        ),
      ]),
      const SizedBox(height: 12),
      InfoBanner(
        icon: Icons.event_available,
        text: _selonTaux
            ? 'Calcul selon la table des taux : commission retenue sur chaque versement, rendement calculé '
                '${p.methode == MethodeInteret.quinzaines ? 'par quinzaine comme un compte sur carnet (un versement rapporte à partir de la quinzaine suivante)' : 'au prorata des jours'}, '
                'versé par l’assureur au $reval de chaque année. '
                '${_contratId == null ? 'Choisissez un contrat pour voir les taux et le détail par cotisation.' : 'Touchez une année pour voir le détail par cotisation.'}'
            : 'Montants réellement enregistrés : commissions et revalorisations saisies dans les opérations. '
                'Comparez avec « Selon les taux » pour repérer un écart avec les relevés de l’assureur.',
      ),
      if (manquants.isNotEmpty) ...[
        const SizedBox(height: 8),
        InfoBanner(
          icon: Icons.warning_amber,
          color: AppColors.warning,
          text: 'Taux manquants pour : ${manquants.join(', ')}. Les montants de ces années sont calculés sans commission ou sans rendement.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TauxAnnuelsScreen())),
            icon: const Icon(Icons.edit_note),
            label: const Text('Compléter la table des taux'),
          ),
        ),
      ],
      const SizedBox(height: 12),
      if (r.annees.isEmpty)
        const EmptyState(icon: Icons.table_chart_outlined, title: 'Aucune donnée', message: 'Aucune opération exécutée sur la sélection.')
      else ...[
        ResponsiveGrid(minItemWidth: 200, children: [
          StatCard(label: 'Épargne brute', value: Money.compact(r.epargneBrute), icon: Icons.account_balance_wallet_outlined, caption: 'Total des versements'),
          StatCard(
            label: 'Commissions retenues',
            value: Money.compact(-r.commission),
            icon: Icons.percent,
            accent: AppColors.gold,
            caption: r.epargneBrute == 0 ? '—' : '${Money.percent(r.commission, r.epargneBrute)} des versements',
          ),
          StatCard(label: 'Épargne nette', value: Money.compact(r.epargneNette), icon: Icons.savings_outlined, caption: 'Brute − commissions'),
          StatCard(
            label: 'Rendement net',
            value: Money.compact(r.rendement, withSign: true),
            icon: Icons.trending_up,
            accent: AppColors.positive,
            valueColor: r.rendement >= 0 ? AppColors.positive : AppColors.negative,
            caption: 'Total des intérêts',
          ),
          StatCard(
            label: 'Capital au 31/12',
            value: Money.compact(r.capitalFin),
            icon: Icons.account_balance,
            accent: AppColors.info,
            caption: r.annees.last.enCours ? 'Fin ${r.annees.last.annee} (estimé)' : 'Fin ${r.annees.last.annee}',
          ),
        ]),
        const SizedBox(height: 12),
        SectionCard(title: 'Par année', child: _Graphique(r)),
        const SizedBox(height: 12),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingTextStyle: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: t.colorScheme.onSurfaceVariant),
              columnSpacing: 22,
              columns: [
                const DataColumn(label: Text('Année')),
                const DataColumn(label: Text('Épargne brute'), numeric: true),
                if (colTaux) const DataColumn(label: Text('Taux com.'), numeric: true),
                const DataColumn(label: Text('Commission'), numeric: true),
                const DataColumn(label: Text('Épargne nette'), numeric: true),
                if (colTaux) const DataColumn(label: Text('Taux rend.'), numeric: true),
                const DataColumn(label: Text('Rendement net'), numeric: true),
                const DataColumn(label: Text('Rachats / frais'), numeric: true),
                const DataColumn(label: Text('Capital au 31/12'), numeric: true),
              ],
              rows: [
                for (final a in r.annees.reversed)
                  DataRow(
                    onSelectChanged: colTaux ? (_) => _detail(context, a) : null,
                    cells: [
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${a.annee}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (a.enCours) ...[const SizedBox(width: 6), const StatusChip(label: 'en cours', color: AppColors.info)],
                        if (a.cloture) ...[const SizedBox(width: 6), const StatusChip(label: 'clôture', color: Colors.blueGrey)],
                      ])),
                      DataCell(Text(Money.format(a.epargneBrute))),
                      if (colTaux) DataCell(_taux(a.tauxCommission, a.tauxEstime && a.tauxCommission != null, a.commissionManquante && !a.enCours)),
                      DataCell(Text(a.commission == 0 ? '—' : Money.format(-a.commission), style: const TextStyle(color: AppColors.warning))),
                      DataCell(Text(Money.format(a.epargneNette))),
                      if (colTaux) DataCell(_taux(a.tauxRendement, a.tauxEstime, a.rendementManquant)),
                      DataCell(Text(Money.format(a.rendement, withSign: true),
                          style: TextStyle(
                              color: a.rendement >= 0 ? AppColors.positive : AppColors.negative,
                              fontStyle: a.tauxEstime ? FontStyle.italic : null))),
                      DataCell(Text(a.sorties == 0 ? '—' : Money.format(-a.sorties))),
                      DataCell(Text(Money.format(a.capitalFin), style: const TextStyle(fontWeight: FontWeight.w700))),
                    ],
                  ),
                DataRow(
                  color: WidgetStatePropertyAll(t.colorScheme.primaryContainer.withValues(alpha: 0.35)),
                  cells: [
                    const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text(Money.format(r.epargneBrute), style: const TextStyle(fontWeight: FontWeight.w800))),
                    if (colTaux) const DataCell(Text('')),
                    DataCell(Text(Money.format(-r.commission), style: const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text(Money.format(r.epargneNette), style: const TextStyle(fontWeight: FontWeight.w800))),
                    if (colTaux) const DataCell(Text('')),
                    DataCell(Text(Money.format(r.rendement, withSign: true), style: const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text(Money.format(-r.sorties), style: const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text(Money.format(r.capitalFin), style: const TextStyle(fontWeight: FontWeight.w800))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selonTaux && r.annees.any((a) => a.tauxEstime))
          InfoBanner(
            text: 'Valeurs en italique : taux estimé pour l’année en cours '
                '(${p.tauxEstimation != null ? 'taux paramétré ${Taux.format(p.tauxEstimation)}' : 'dernier taux connu'}). '
                'Modifiable dans Paramètres → Calcul.',
          ),
      ],
    ]);
  }

  Widget _taux(int? bp, bool estime, bool manquant) {
    if (manquant && bp == null) {
      return const Tooltip(message: 'Taux non renseigné', child: Icon(Icons.warning_amber, size: 18, color: AppColors.warning));
    }
    return Text(Taux.format(bp), style: TextStyle(fontStyle: estime ? FontStyle.italic : null));
  }

  void _detail(BuildContext context, RecapAnnee a) {
    final s = AppScope.read(context);
    final quinz = s.parametres.methode == MethodeInteret.quinzaines;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 820),
      builder: (ctx) {
        final t = Theme.of(ctx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (ctx, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text('Détail ${a.annee}', style: t.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Taux de rendement ${Taux.format(a.tauxRendement)}${a.tauxEstime ? ' (estimé)' : ''} · '
                'commission ${Taux.format(a.tauxCommission)}${a.sourceTaux.isEmpty ? '' : ' · source : ${a.sourceTaux}'}',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 18,
                  headingTextStyle: t.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                  columns: [
                    const DataColumn(label: Text('Date')),
                    const DataColumn(label: Text('Mouvement')),
                    const DataColumn(label: Text('Brut'), numeric: true),
                    const DataColumn(label: Text('Commission'), numeric: true),
                    const DataColumn(label: Text('Base nette'), numeric: true),
                    DataColumn(label: Text(quinz ? 'Quinzaines' : 'Jours'), numeric: true),
                    const DataColumn(label: Text('Intérêts'), numeric: true),
                  ],
                  rows: [
                    for (final l in a.details)
                      DataRow(cells: [
                        DataCell(Text(Dates.day(l.date))),
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(l.libelle, overflow: TextOverflow.ellipsis),
                        )),
                        DataCell(Text(l.brut == 0 ? '' : Money.format(l.brut))),
                        DataCell(Text(l.commission == 0 ? '' : Money.format(-l.commission))),
                        DataCell(Text(Money.format(l.base))),
                        DataCell(Text('${l.periodes} / ${l.periodesAnnee}')),
                        DataCell(Text(Money.format(l.interets, withSign: true),
                            style: TextStyle(color: l.interets >= 0 ? AppColors.positive : AppColors.negative))),
                      ]),
                    DataRow(cells: [
                      const DataCell(Text('')),
                      const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text(Money.format(a.epargneBrute))),
                      DataCell(Text(Money.format(-a.commission))),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      DataCell(Text(Money.format(a.rendement, withSign: true), style: const TextStyle(fontWeight: FontWeight.w800))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoBanner(
                text: quinz
                    ? 'Intérêts = base × taux × quinzaines / 24. Un versement porte intérêt à partir de la quinzaine suivante '
                        '(1er ou 16 du mois) ; un retrait cesse de porter intérêt dès le début de sa quinzaine.'
                    : 'Intérêts = base × taux × jours restants dans l’année / nombre de jours de l’année.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Graphique extends StatelessWidget {
  const _Graphique(this.r);
  final Recap r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final annees = r.annees.length > 16 ? r.annees.sublist(r.annees.length - 16) : r.annees;
    double v(int c) => c / 100;
    final maxY = annees.map((a) => v(a.epargneBrute) + (a.rendement > 0 ? v(a.rendement) : 0)).fold<double>(1, (m, x) => x > m ? x : m);
    Widget legende(Color c, String l) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(l, style: t.textTheme.labelSmall),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 16, runSpacing: 6, children: [
        legende(t.colorScheme.primary, 'Épargne nette'),
        legende(AppColors.gold, 'Commission'),
        legende(AppColors.positive.withValues(alpha: 0.55), 'Rendement'),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 220,
        child: BarChart(BarChartData(
          maxY: maxY * 1.1,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: t.colorScheme.outlineVariant.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [4, 4]),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, m) => v == m.max
                    ? const SizedBox.shrink()
                    : Text(v >= 1000 ? '${(v / 1000).round()} k' : v.round().toString(),
                        style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= annees.length) return const SizedBox.shrink();
                  final y = annees[i].annee;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(annees.length > 10 ? "'${y % 100}" : '$y',
                        style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => t.colorScheme.inverseSurface,
              getTooltipItem: (g, gi, rod, ri) {
                final a = annees[g.x];
                return BarTooltipItem(
                  '${a.annee}\nNette ${Money.compact(a.epargneNette)}\nCommission ${Money.compact(a.commission)}\nRendement ${Money.compact(a.rendement)}',
                  TextStyle(color: t.colorScheme.onInverseSurface, fontSize: 11, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < annees.length; i++)
              () {
                final a = annees[i];
                final n = v(a.epargneNette), c = v(a.commission), r = a.rendement > 0 ? v(a.rendement) : 0.0;
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: n + c + r,
                    width: annees.length > 10 ? 10 : 18,
                    borderRadius: BorderRadius.circular(3),
                    rodStackItems: [
                      BarChartRodStackItem(0, n, t.colorScheme.primary),
                      BarChartRodStackItem(n, n + c, AppColors.gold),
                      BarChartRodStackItem(n + c, n + c + r, AppColors.positive.withValues(alpha: 0.55)),
                    ],
                  ),
                ]);
              }(),
          ],
        )),
      ),
    ]);
  }
}
