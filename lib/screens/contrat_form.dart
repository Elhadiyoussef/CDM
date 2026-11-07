import 'package:flutter/material.dart';

import '../models/contrat.dart';
import '../models/enums.dart';
import '../state/app_state.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/adaptive_form.dart';
import '../widgets/common.dart';

/// Création ou modification d'un contrat.
Future<void> showContratForm(BuildContext context, {Contrat? existing}) async {
  final key = GlobalKey<_ContratFormState>();
  await showAdaptiveForm<void>(
    context,
    title: existing == null ? 'Nouveau contrat' : 'Modifier le contrat',
    body: (_) => _ContratForm(key: key, existing: existing),
    actions: (ctx) => Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler'))),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: () async {
            final ok = await key.currentState?.save() ?? false;
            if (ok && ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Enregistrer'),
        ),
      ),
    ]),
  );
}

class _ContratForm extends StatefulWidget {
  const _ContratForm({super.key, this.existing});
  final Contrat? existing;

  @override
  State<_ContratForm> createState() => _ContratFormState();
}

class _BenefRow {
  _BenefRow(this.id, String nom, String lien, int part)
      : nom = TextEditingController(text: nom),
        lien = TextEditingController(text: lien),
        part = TextEditingController(text: part == 0 ? '' : '$part');
  final String id;
  final TextEditingController nom;
  final TextEditingController lien;
  final TextEditingController part;
}

class _ContratFormState extends State<_ContratForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _ref;
  late final TextEditingController _cotisation;
  late final TextEditingController _objectif;
  late String _produitId;
  late DateTime _dateEffet;
  DateTime? _echeance;
  late Periodicite _periodicite;
  late StatutContrat _statut;
  late final List<_BenefRow> _benefs;
  String? _benefError;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _ref = TextEditingController(text: c?.reference ?? '');
    _cotisation = TextEditingController(text: c == null ? '' : Money.toInput(c.cotisation));
    _objectif = TextEditingController(text: c == null || c.objectif == 0 ? '' : Money.toInput(c.objectif));
    final s = AppScope.read(context);
    final actifs = s.produits.where((p) => p.actif || p.id == c?.produitId).toList();
    _produitId = c?.produitId ?? (actifs.isEmpty ? s.produits.first.id : actifs.first.id);
    _dateEffet = c?.dateEffet ?? Dates.today();
    _echeance = c?.dateEcheance;
    _periodicite = c?.periodicite ?? Periodicite.mensuelle;
    _statut = c?.statut ?? StatutContrat.actif;
    _benefs = [
      for (final b in c?.beneficiaires ?? const <Beneficiaire>[]) _BenefRow(b.id, b.nom, b.lien, b.quotePart),
    ];
  }

  Future<bool> save() async {
    final state = AppScope.read(context);
    setState(() => _benefError = null);
    if (!_form.currentState!.validate()) return false;
    final total = _benefs.fold<int>(0, (s, b) => s + (int.tryParse(b.part.text) ?? 0));
    if (_benefs.isNotEmpty && total != 100) {
      setState(() => _benefError = 'La somme des quotes-parts doit être égale à 100 % (actuellement $total %).');
      return false;
    }
    final base = widget.existing ??
        Contrat(
          id: newId(),
          reference: '',
          produitId: _produitId,
          dateEffet: _dateEffet,
          cotisation: 0,
          updatedAt: DateTime.now().toUtc(),
        );
    final c = base.copyWith(
      reference: _ref.text.trim(),
      produitId: _produitId,
      dateEffet: _dateEffet,
      dateEcheance: _echeance,
      clearEcheance: _echeance == null,
      cotisation: Money.parse(_cotisation.text) ?? 0,
      objectif: Money.parse(_objectif.text) ?? 0,
      periodicite: _periodicite,
      statut: _statut,
      beneficiaires: [
        for (final b in _benefs)
          Beneficiaire(id: b.id, nom: b.nom.text.trim(), lien: b.lien.text.trim(), quotePart: int.parse(b.part.text)),
      ],
    );
    await state.saveContrat(c);
    return true;
  }

  String? _montant(String? v, {bool required = false, int? min}) {
    if (v == null || v.trim().isEmpty) return required ? 'Champ obligatoire' : null;
    final m = Money.parse(v);
    if (m == null) return 'Montant invalide (ex. 1500 ou 1500,50)';
    if (min != null && m < min) return 'Minimum ${Money.format(min)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = AppScope.of(context);
    final regles = s.produit(_produitId) ?? s.produits.first;
    const gap = SizedBox(height: 14);
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Section('Identification'),
        TextFormField(
          controller: _ref,
          decoration: const InputDecoration(labelText: 'Référence du contrat', prefixIcon: Icon(Icons.tag)),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Champ obligatoire' : null,
        ),
        gap,
        DropdownButtonFormField<String>(
          initialValue: _produitId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Produit', prefixIcon: Icon(Icons.inventory_2_outlined)),
          items: [
            for (final p in s.produits.where((p) => p.actif || p.id == _produitId))
              DropdownMenuItem(value: p.id, child: Text(p.nom, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _produitId = v!),
        ),
        gap,
        Row(children: [
          Expanded(
            child: DateField(
              label: "Date d'effet",
              value: _dateEffet,
              format: Dates.day,
              lastDate: DateTime.now().add(const Duration(days: 365)),
              onChanged: (d) => setState(() => _dateEffet = d ?? _dateEffet),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DateField(
              label: 'Échéance (retraite)',
              value: _echeance,
              format: Dates.day,
              clearable: true,
              firstDate: _dateEffet,
              onChanged: (d) => setState(() => _echeance = d),
            ),
          ),
        ]),
        const SizedBox(height: 22),
        _Section('Cotisations'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextFormField(
              controller: _cotisation,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant', suffixText: 'DH'),
              validator: (v) => _montant(v, required: true, min: regles.cotisationMinimale),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<Periodicite>(
              initialValue: _periodicite,
              decoration: const InputDecoration(labelText: 'Périodicité'),
              items: [for (final p in Periodicite.values) DropdownMenuItem(value: p, child: Text(p.label))],
              onChanged: (v) => setState(() => _periodicite = v!),
            ),
          ),
        ]),
        gap,
        TextFormField(
          controller: _objectif,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Objectif d'épargne (facultatif)",
            suffixText: 'DH',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
          validator: (v) => _montant(v),
        ),
        if (widget.existing != null) ...[
          gap,
          Text('Statut', style: t.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<StatutContrat>(
            segments: const [
              ButtonSegment(value: StatutContrat.actif, label: Text('Actif')),
              ButtonSegment(value: StatutContrat.suspendu, label: Text('Suspendu')),
              ButtonSegment(value: StatutContrat.cloture, label: Text('Clôturé')),
            ],
            selected: {_statut},
            onSelectionChanged: (s) => setState(() => _statut = s.first),
          ),
        ],
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: _Section('Bénéficiaires')),
          TextButton.icon(
            onPressed: () => setState(() => _benefs.add(_BenefRow(newId(), '', '', _benefs.isEmpty ? 100 : 0))),
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: const Text('Ajouter'),
          ),
        ]),
        if (_benefs.isEmpty)
          Text('Aucun bénéficiaire désigné.', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        for (final b in _benefs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: b.nom,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 4, child: TextFormField(controller: b.lien, decoration: const InputDecoration(labelText: 'Lien'))),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: b.part,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Part', suffixText: '%'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n <= 0 || n > 100 ? '1–100' : null;
                  },
                ),
              ),
              IconButton(
                tooltip: 'Retirer',
                onPressed: () => setState(() => _benefs.remove(b)),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ]),
          ),
        if (_benefError != null) InfoBanner(text: _benefError!, icon: Icons.error_outline, color: Colors.red),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(),
          style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.primary, letterSpacing: 0.8, fontWeight: FontWeight.w700)),
    );
  }
}
