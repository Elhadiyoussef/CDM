import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/operation.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/adaptive_form.dart';
import '../widgets/common.dart';

/// Saisie d'une opération (versement, cotisation, revalorisation, frais, rachat).
Future<void> showOperationForm(BuildContext context, {String? contratId, TypeOperation? type}) async {
  final state = AppScope.read(context);
  final ouverts = state.contrats.where((c) => !c.estCloture).toList();
  if (ouverts.isEmpty) {
    showMessage(context, 'Aucun contrat ouvert : ajoutez un contrat pour saisir une opération.', error: true);
    return;
  }
  final key = GlobalKey<_OperationFormState>();
  await showAdaptiveForm<void>(
    context,
    title: 'Nouvelle opération',
    body: (_) => _OperationForm(key: key, contratId: contratId ?? ouverts.first.id, type: type),
    actions: (ctx) => Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler'))),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: () async {
            final msg = await key.currentState?.save();
            if (msg != null && ctx.mounted) {
              Navigator.pop(ctx);
              showMessage(context, msg);
            }
          },
          child: const Text('Enregistrer'),
        ),
      ),
    ]),
  );
}

class _OperationForm extends StatefulWidget {
  const _OperationForm({super.key, required this.contratId, this.type});
  final String contratId;
  final TypeOperation? type;

  @override
  State<_OperationForm> createState() => _OperationFormState();
}

class _OperationFormState extends State<_OperationForm> {
  final _form = GlobalKey<FormState>();
  final _montant = TextEditingController();
  final _libelle = TextEditingController();
  late String _contratId = widget.contratId;
  late TypeOperation _type = widget.type ?? TypeOperation.versement;
  StatutOperation _statut = StatutOperation.executee;
  DateTime _date = Dates.today();
  List<String> _errors = const [];

  @override
  void initState() {
    super.initState();
    _montant.addListener(() => setState(() => _errors = const []));
    _applyTypeDefaults();
  }

  void _applyTypeDefaults() {
    final s = AppScope.read(context);
    if (_type == TypeOperation.rachatTotal) {
      _montant.text = Money.toInput(s.capital(contratId: _contratId));
      _statut = StatutOperation.enAttente;
    } else if (_type == TypeOperation.cotisation) {
      final c = s.contrat(_contratId);
      if (c != null && _montant.text.isEmpty) _montant.text = Money.toInput(c.cotisation);
    }
  }

  /// Retourne un message de succès, ou null si l'enregistrement est bloqué.
  Future<String?> save() async {
    final s = AppScope.read(context);
    if (!_form.currentState!.validate()) return null;
    final montant = Money.parse(_montant.text)!;
    final errors = s.verifierOperation(contratId: _contratId, type: _type, montant: montant, statut: _statut);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return null;
    }
    if (_type == TypeOperation.rachatTotal) {
      final ok = await confirmer(
        context,
        titre: 'Confirmer le rachat total',
        message: 'Une fois exécuté, le rachat total met fin au contrat et à ses garanties. '
            'Aucune nouvelle opération ne pourra être enregistrée sur ce contrat.',
        confirmer: 'Confirmer le rachat',
        destructive: true,
      );
      if (!ok) return null;
    }
    await s.addOperation(Operation(
      id: newId(),
      contratId: _contratId,
      type: _type,
      montant: montant,
      date: _date,
      statut: _statut,
      libelle: _libelle.text.trim(),
      updatedAt: DateTime.now().toUtc(),
    ));
    return '${_type.label} de ${Money.format(montant)} enregistré${_statut == StatutOperation.enAttente ? ' (en attente)' : ''}.';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context);
    final ouverts = s.contrats.where((c) => !c.estCloture).toList();
    final capital = s.capital(contratId: _contratId);
    final regles = s.regles;
    const gap = SizedBox(height: 14);

    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (ouverts.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: _contratId,
            decoration: const InputDecoration(labelText: 'Contrat', prefixIcon: Icon(Icons.description_outlined)),
            items: [
              for (final c in ouverts) DropdownMenuItem(value: c.id, child: Text('${c.reference} · ${c.produit}')),
            ],
            onChanged: (v) => setState(() {
              _contratId = v!;
              _errors = const [];
              _applyTypeDefaults();
            }),
          ),
          gap,
        ],
        Text("Type d'opération", style: t.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final ty in TypeOperation.values)
            ChoiceChip(
              avatar: Icon(iconForType(ty), size: 18),
              label: Text(ty.label),
              selected: _type == ty,
              onSelected: (_) => setState(() {
                _type = ty;
                _errors = const [];
                _applyTypeDefaults();
              }),
            ),
        ]),
        gap,
        if (_type.estRachat)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InfoBanner(
              icon: Icons.policy_outlined,
              color: AppColors.warning,
              text: _type == TypeOperation.rachatPartiel
                  ? 'Capital disponible : ${Money.format(capital)}. Plafond par rachat : ${regles.plafondRachatPourcent} % '
                      '(${Money.format(capital * regles.plafondRachatPourcent ~/ 100)}). '
                      'Rachats partiels utilisés : ${s.nbRachatsPartiels(_contratId)} / ${regles.rachatsPartielsMax}. '
                      'Règles indicatives, à confirmer selon votre contrat.'
                  : 'Valeur de rachat à ce jour : ${Money.format(capital)}. '
                      'Le montant réellement versé dépendra des frais et de la fiscalité applicables.',
            ),
          ),
        TextFormField(
          controller: _montant,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: t.textTheme.titleLarge,
          decoration: const InputDecoration(labelText: 'Montant', suffixText: 'DH', prefixIcon: Icon(Icons.payments_outlined)),
          validator: (v) {
            final m = Money.parse(v ?? '');
            if (m == null) return 'Montant invalide (ex. 1500 ou 1500,50)';
            if (m <= 0) return 'Le montant doit être positif';
            return null;
          },
        ),
        gap,
        Row(children: [
          Expanded(
            child: DateField(
              label: 'Date',
              value: _date,
              format: Dates.day,
              onChanged: (d) => setState(() => _date = d ?? _date),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<StatutOperation>(
              initialValue: _statut,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: [for (final st in StatutOperation.values) DropdownMenuItem(value: st, child: Text(st.label))],
              onChanged: (v) => setState(() {
                _statut = v!;
                _errors = const [];
              }),
            ),
          ),
        ]),
        gap,
        TextFormField(
          controller: _libelle,
          decoration: const InputDecoration(labelText: 'Libellé (facultatif)', prefixIcon: Icon(Icons.notes)),
        ),
        if (_statut == StatutOperation.enAttente) ...[
          gap,
          const InfoBanner(
            text: 'Une opération en attente n’est pas comptée dans le capital tant que vous ne la marquez pas « Exécutée ».',
          ),
        ],
        for (final e in _errors) ...[
          gap,
          InfoBanner(text: e, icon: Icons.block, color: AppColors.negative),
        ],
      ]),
    );
  }
}
