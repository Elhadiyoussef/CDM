import 'package:flutter/material.dart';

import '../models/contrat.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/capital_chart.dart';
import '../widgets/common.dart';
import 'contrat_form.dart';
import 'operation_form.dart';
import 'operations_screen.dart';
import 'referentiels_screen.dart';
import 'saisie_masse_screen.dart';

class ContratsScreen extends StatelessWidget {
  const ContratsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context);
    final contrats = [...s.contrats]..sort((a, b) => a.estCloture == b.estCloture ? 0 : (a.estCloture ? 1 : -1));
    return PageBody(children: [
      Row(children: [
        Expanded(child: Text('Mes contrats', style: t.textTheme.headlineSmall)),
        FilledButton.icon(
          onPressed: () => showContratForm(context),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ),
      ]),
      const SizedBox(height: 20),
      if (contrats.isEmpty)
        EmptyState(
          icon: Icons.description_outlined,
          title: 'Aucun contrat',
          message: 'Ajoutez votre contrat d’épargne retraite pour suivre son évolution.',
          actions: [
            FilledButton.icon(
              onPressed: () => showContratForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un contrat'),
            ),
          ],
        )
      else
        ResponsiveGrid(minItemWidth: 360, children: [for (final c in contrats) _ContratCard(c)]),
    ]);
  }
}

class _ContratCard extends StatelessWidget {
  const _ContratCard(this.c);
  final Contrat c;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context);
    final capital = s.capital(contratId: c.id);
    final progress = c.objectif > 0 ? (capital / c.objectif).clamp(0.0, 1.0) : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContratDetailScreen(id: c.id))),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.nomProduit(c), style: t.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('N° ${c.reference}', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ]),
              ),
              StatusChip.contrat(c.statut),
            ]),
            const SizedBox(height: 18),
            Text('Capital constitué', style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            Text(Money.format(capital), style: t.textTheme.headlineSmall),
            const SizedBox(height: 14),
            if (progress != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  backgroundColor: t.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Text('${(progress * 100).toStringAsFixed(0)} % de l’objectif de ${Money.compact(c.objectif)}',
                  style: t.textTheme.bodySmall),
              const SizedBox(height: 14),
            ],
            Wrap(spacing: 18, runSpacing: 6, children: [
              _Meta(Icons.event_repeat, '${Money.compact(c.cotisation)} · ${c.periodicite.label.toLowerCase()}'),
              _Meta(Icons.play_circle_outline, 'Depuis ${Dates.day(c.dateEffet)}'),
              if (c.dateEcheance != null) _Meta(Icons.flag_outlined, 'Échéance ${Dates.day(c.dateEcheance!)}'),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: t.colorScheme.onSurfaceVariant),
      const SizedBox(width: 5),
      Text(text, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
    ]);
  }
}

/// Fiche contrat : caractéristiques, bénéficiaires, évolution et historique.
class ContratDetailScreen extends StatelessWidget {
  const ContratDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.contrat(id);
    if (c == null) return const Scaffold(body: Center(child: Text('Contrat supprimé.')));
    final t = Theme.of(context);
    final ops = s.operations(contratId: id);
    final prochaine = c.prochaineCotisation;
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    final infos = SectionCard(
      title: 'Caractéristiques',
      child: Column(children: [
        _InfoRow('Produit', s.nomProduit(c)),
        _InfoRow('Référence', c.reference),
        _InfoRow("Date d'effet", Dates.long(c.dateEffet)),
        _InfoRow('Échéance', c.dateEcheance == null ? 'Non renseignée' : Dates.long(c.dateEcheance!)),
        _InfoRow('Cotisation', '${Money.format(c.cotisation)} · ${c.periodicite.label.toLowerCase()}'),
        _InfoRow('Prochaine cotisation', prochaine == null ? '—' : Dates.long(prochaine)),
        _InfoRow('Objectif', c.objectif == 0 ? 'Non défini' : Money.format(c.objectif)),
        _InfoRow('Rachats partiels', '${s.nbRachatsPartiels(id)} / ${s.produitDe(c).rachatsPartielsMax}'),
      ]),
    );
    final benefs = SectionCard(
      title: 'Bénéficiaires',
      child: c.beneficiaires.isEmpty
          ? Text('Aucun bénéficiaire désigné.', style: t.textTheme.bodyMedium)
          : Column(children: [
              for (final b in c.beneficiaires)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(b.nom.isEmpty ? '?' : b.nom[0].toUpperCase())),
                  title: Text(b.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: b.lien.isEmpty ? null : Text(b.lien),
                  trailing: Text('${b.quotePart} %', style: t.textTheme.titleMedium),
                ),
            ]),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(c.reference),
        actions: [
          IconButton(tooltip: 'Modifier', onPressed: () => showContratForm(context, existing: c), icon: const Icon(Icons.edit_outlined)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'masse') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaisieMasseScreen(contratId: id)));
              } else if (v == 'taux') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => TauxAnnuelsScreen(contratId: id)));
              } else if (v == 'calcul') {
                final ok = await confirmer(context,
                    titre: 'Calculer commissions et rendements ?',
                    message: 'Pour chaque année terminée, l’application crée une opération « Commission » et une '
                        'opération « Rendement » à partir de la table des taux (date : ${s.parametres.jourRevalorisation}/'
                        '${s.parametres.moisRevalorisation}). Les années contenant déjà des revalorisations ou commissions '
                        'saisies à la main ne sont pas modifiées.',
                    confirmer: 'Calculer');
                if (!ok) return;
                final r = await s.genererOperationsAnnuelles(id);
                if (context.mounted) {
                  showMessage(context,
                      '${r.traitees} année(s) calculée(s)${r.ignorees.isEmpty ? '' : ' · ignorées (saisies à la main) : ${r.ignorees.join(', ')}'}.');
                }
              } else if (v == 'delete') {
                final ok = await confirmer(context,
                    titre: 'Supprimer ce contrat ?',
                    message: 'Le contrat et ses ${ops.length} opérations seront supprimés de cet appareil.',
                    confirmer: 'Supprimer',
                    destructive: true);
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  await s.deleteContrat(id);
                }
              }
            },
            itemBuilder: (_) => [
              if (!c.estCloture)
                const PopupMenuItem(value: 'masse', child: ListTile(leading: Icon(Icons.table_rows_outlined), title: Text('Saisie de masse'))),
              const PopupMenuItem(value: 'taux', child: ListTile(leading: Icon(Icons.percent), title: Text('Taux propres au contrat'))),
              const PopupMenuItem(
                  value: 'calcul', child: ListTile(leading: Icon(Icons.calculate_outlined), title: Text('Calculer commissions et rendements'))),
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Supprimer'))),
            ],
          ),
        ],
      ),
      floatingActionButton: c.estCloture
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showOperationForm(context, contratId: id),
              icon: const Icon(Icons.add),
              label: const Text('Opération'),
            ),
      body: PageBody(children: [
        Row(children: [
          Expanded(child: Text(s.nomProduit(c), style: t.textTheme.titleMedium)),
          StatusChip.contrat(c.statut),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!c.estCloture)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaisieMasseScreen(contratId: id))),
              icon: const Icon(Icons.table_rows_outlined),
              label: const Text('Saisie de masse'),
            ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TauxAnnuelsScreen(contratId: id))),
            icon: const Icon(Icons.percent),
            label: const Text('Taux du contrat'),
          ),
        ]),
        const SizedBox(height: 16),
        ResponsiveGrid(minItemWidth: 200, children: [
          StatCard(label: 'Capital constitué', value: Money.compact(s.capital(contratId: id)), icon: Icons.savings_outlined),
          StatCard(label: 'Total versé', value: Money.compact(s.totalVerse(contratId: id)), icon: Icons.account_balance_wallet_outlined),
          StatCard(
            label: 'Écart de valorisation',
            value: Money.compact(s.ecart(contratId: id), withSign: true),
            icon: Icons.trending_up,
            accent: AppColors.positive,
            valueColor: s.ecart(contratId: id) >= 0 ? AppColors.positive : AppColors.negative,
          ),
          StatCard(label: 'Rachats', value: Money.compact(s.totalRachats(contratId: id)), icon: Icons.call_made, accent: AppColors.gold),
        ]),
        if (c.estCloture) ...[
          const SizedBox(height: 12),
          const InfoBanner(
            icon: Icons.lock_outline,
            text: 'Contrat clôturé : l’historique reste consultable mais aucune nouvelle opération financière n’est possible.',
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(title: 'Évolution', child: CapitalChart(points: s.evolutionCapital(contratId: id), height: 200)),
        const SizedBox(height: 12),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: infos),
            const SizedBox(width: 12),
            Expanded(child: benefs),
          ])
        else ...[
          infos,
          const SizedBox(height: 12),
          benefs,
        ],
        if (s.lots(id).isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Saisies groupées',
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(children: [
              for (final l in s.lots(id))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.layers_outlined, size: 20)),
                  title: Text('${l.origine.label} · ${l.nb} opération(s)', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${Dates.day(l.du)} → ${Dates.day(l.au)} · ${Money.format(l.total)}'),
                  trailing: TextButton(
                    onPressed: () async {
                      final ok = await confirmer(context,
                          titre: 'Annuler cette saisie ?',
                          message: 'Les ${l.nb} opérations de ce lot seront supprimées.',
                          confirmer: 'Supprimer le lot',
                          destructive: true);
                      if (ok) {
                        final n = await s.annulerLot(l.lotId);
                        if (context.mounted) showMessage(context, '$n opération(s) supprimée(s).');
                      }
                    },
                    child: const Text('Annuler'),
                  ),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: 'Historique (${ops.length})',
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: ops.isEmpty
              ? const Padding(padding: EdgeInsets.all(8), child: Text('Aucune opération.'))
              : Column(children: [
                  for (final o in ops) OperationTile(op: o, onTap: () => showOperationActions(context, o)),
                ]),
        ),
        const SizedBox(height: 60),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant))),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
