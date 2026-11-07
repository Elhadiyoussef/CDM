import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/operation.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import 'operation_form.dart';

enum _Filtre { toutes, apports, rachats, attente, anomalies }

extension on _Filtre {
  String get label => switch (this) {
        _Filtre.toutes => 'Toutes',
        _Filtre.apports => 'Versements',
        _Filtre.rachats => 'Rachats',
        _Filtre.attente => 'En attente',
        _Filtre.anomalies => 'Rejetées / annulées',
      };

  bool test(Operation o) => switch (this) {
        _Filtre.toutes => true,
        _Filtre.apports => o.type.estApport,
        _Filtre.rachats => o.type.estRachat,
        _Filtre.attente => o.statut == StatutOperation.enAttente,
        _Filtre.anomalies => o.statut == StatutOperation.rejetee || o.statut == StatutOperation.annulee,
      };
}

/// Historique financier, groupé par mois, avec filtres.
class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  _Filtre _filtre = _Filtre.toutes;
  String? _contratId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context);
    if (_contratId != null && s.contrat(_contratId!) == null) _contratId = null;
    final ops = s.operations(contratId: _contratId).where(_filtre.test).toList();
    final multi = s.contrats.length > 1;

    final groups = <String, List<Operation>>{};
    for (final o in ops) {
      groups.putIfAbsent('${o.date.year}-${o.date.month}', () => []).add(o);
    }

    return PageBody(children: [
      Row(children: [
        Expanded(child: Text('Opérations', style: t.textTheme.headlineSmall)),
        FilledButton.icon(
          onPressed: s.contrats.any((c) => !c.estCloture) ? () => showOperationForm(context, contratId: _contratId) : null,
          icon: const Icon(Icons.add),
          label: const Text('Saisir'),
        ),
      ]),
      const SizedBox(height: 16),
      if (multi) ...[
        DropdownButtonFormField<String?>(
          initialValue: _contratId,
          decoration: const InputDecoration(labelText: 'Contrat', prefixIcon: Icon(Icons.filter_list)),
          items: [
            const DropdownMenuItem(value: null, child: Text('Tous les contrats')),
            for (final c in s.contrats) DropdownMenuItem(value: c.id, child: Text(c.reference)),
          ],
          onChanged: (v) => setState(() => _contratId = v),
        ),
        const SizedBox(height: 12),
      ],
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final f in _Filtre.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.label),
                selected: _filtre == f,
                onSelected: (_) => setState(() => _filtre = f),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      if (ops.isEmpty)
        const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Aucune opération',
          message: 'Aucune opération ne correspond à ce filtre.',
        )
      else
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(children: [
              Text(_moisLabel(entry.value.first.date),
                  style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              const Spacer(),
              Text(Money.format(entry.value.fold(0, (sum, o) => sum + o.impact), withSign: true),
                  style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ]),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0) const Divider(indent: 56),
                  OperationTile(
                    op: entry.value[i],
                    subtitlePrefix: multi && _contratId == null ? '${s.contrat(entry.value[i].contratId)?.reference} · ' : null,
                    onTap: () => showOperationActions(context, entry.value[i]),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ],
    ]);
  }

  static String _moisLabel(DateTime d) {
    const mois = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${mois[d.month - 1]} ${d.year}';
  }
}

/// Détail d'une opération et changement de statut.
Future<void> showOperationActions(BuildContext context, Operation op) {
  final s = AppScope.read(context);
  final contrat = s.contrat(op.contratId);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) {
      final t = Theme.of(ctx);
      Widget row(String l, String v) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(l, style: TextStyle(color: t.colorScheme.onSurfaceVariant))),
              Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(child: Icon(iconForType(op.type))),
              const SizedBox(width: 12),
              Expanded(child: Text(op.libelle.isEmpty ? op.type.label : op.libelle, style: t.textTheme.titleMedium)),
              StatusChip.operation(op.statut),
            ]),
            const SizedBox(height: 16),
            Text(Money.format(op.type.credit ? op.montant : -op.montant, withSign: true),
                style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            row('Type', op.type.label),
            row('Date', Dates.long(op.date)),
            row('Contrat', contrat?.reference ?? '—'),
            row('Dernière modification', Dates.dateTime(op.updatedAt)),
            const SizedBox(height: 16),
            if (contrat != null && !contrat.estCloture && op.statut == StatutOperation.enAttente) ...[
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.negative),
                    onPressed: () {
                      Navigator.pop(ctx);
                      s.setStatutOperation(op.id, StatutOperation.rejetee);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Rejetée'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (op.type == TypeOperation.rachatTotal) {
                        final ok = await confirmer(ctx,
                            titre: 'Rachat total exécuté ?',
                            message: 'Le contrat sera clôturé définitivement.',
                            confirmer: 'Clôturer',
                            destructive: true);
                        if (!ok) return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await s.setStatutOperation(op.id, StatutOperation.executee);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Exécutée'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  s.setStatutOperation(op.id, StatutOperation.annulee);
                },
                child: const Text('Annuler la demande'),
              ),
            ],
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.negative),
              onPressed: () async {
                final ok = await confirmer(ctx,
                    titre: 'Supprimer cette opération ?',
                    message: 'Elle sera retirée de l’historique et du calcul du capital.',
                    confirmer: 'Supprimer',
                    destructive: true);
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                  await s.deleteOperation(op.id);
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
            ),
          ]),
        ),
      );
    },
  );
}
