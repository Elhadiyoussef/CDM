import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/transfer_service.dart';
import '../models/enums.dart';
import '../models/operation.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../utils/tableur.dart';
import '../widgets/common.dart';

class _Ligne {
  _Ligne({required DateTime date, required int montant, this.type = TypeOperation.cotisation, this.statut = StatutOperation.executee, String libelle = ''})
      : date = TextEditingController(text: Tableur.formatDate(date)),
        montant = TextEditingController(text: Money.toInput(montant)),
        libelle = TextEditingController(text: libelle);
  bool coche = true;
  TypeOperation type;
  StatutOperation statut;
  final TextEditingController date;
  final TextEditingController montant;
  final TextEditingController libelle;

  DateTime? get dateValue => Tableur.date(date.text);
  int? get montantValue => Money.parse(montant.text);
}

/// Saisie de masse des cotisations : génération par année, grille modifiable comme un tableur,
/// copier-coller depuis Excel et import CSV.
class SaisieMasseScreen extends StatefulWidget {
  const SaisieMasseScreen({super.key, this.contratId});
  final String? contratId;

  @override
  State<SaisieMasseScreen> createState() => _SaisieMasseScreenState();
}

class _SaisieMasseScreenState extends State<SaisieMasseScreen> {
  String? _contratId;
  late int _du;
  late int _au;
  final _montant = TextEditingController();
  int _jour = 5;
  StatutOperation _statut = StatutOperation.executee;
  final List<_Ligne> _lignes = [];
  bool _calculerFinAnnee = false;
  OrigineOperation _origine = OrigineOperation.saisieMasse;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    final ouverts = s.contrats.where((c) => !c.estCloture).toList();
    _contratId = widget.contratId ?? (ouverts.isEmpty ? null : ouverts.first.id);
    _du = _au = DateTime.now().year;
    _syncContrat();
  }

  void _syncContrat() {
    final c = _contratId == null ? null : AppScope.read(context).contrat(_contratId!);
    if (c == null) return;
    _montant.text = Money.toInput(c.cotisation);
    _jour = c.dateEffet.day.clamp(1, 28);
  }

  /// Génère les échéances de la période selon la périodicité du contrat.
  void _generer() {
    final s = AppScope.read(context);
    final c = s.contrat(_contratId!)!;
    final m = Money.parse(_montant.text);
    if (m == null || m <= 0) {
      showMessage(context, 'Montant de cotisation invalide.', error: true);
      return;
    }
    final pas = c.periodicite.mois;
    var n = 0;
    final today = Dates.today();
    for (var y = _du; y <= _au; y++) {
      // Les mois d'échéance suivent le mois de la date d'effet.
      for (var mo = 1; mo <= 12; mo++) {
        if ((mo - c.dateEffet.month) % pas != 0) continue;
        final d = DateTime(y, mo, _jour);
        if (d.isBefore(c.dateEffet) || d.isAfter(today)) continue;
        if (c.dateEcheance != null && d.isAfter(c.dateEcheance!)) continue;
        if (_lignes.any((l) => l.dateValue == d && l.type == TypeOperation.cotisation)) continue;
        _lignes.add(_Ligne(date: d, montant: m, statut: _statut, libelle: 'Prélèvement ${c.periodicite.label.toLowerCase()}'));
        n++;
      }
    }
    _trier();
    _decocherDoublons();
    setState(() {});
    showMessage(context, n == 0 ? 'Aucune nouvelle échéance sur cette période.' : '$n échéance(s) générée(s).');
  }

  /// Les lignes déjà présentes dans le contrat sont décochées par défaut.
  void _decocherDoublons() {
    final s = AppScope.read(context);
    for (final l in _lignes) {
      final d = l.dateValue;
      if (d != null && _contratId != null && s.existeOperation(_contratId!, d, l.type)) l.coche = false;
    }
  }

  void _trier() => _lignes.sort((a, b) => (a.dateValue ?? DateTime(9999)).compareTo(b.dateValue ?? DateTime(9999)));

  /// Intègre des lignes « date ; montant ; statut ; type ; libellé ».
  void _integrer(String texte, OrigineOperation origine) {
    final rows = Tableur.lignes(texte);
    var n = 0;
    final rejets = <int>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final d = Tableur.date(r.first);
      final m = r.length > 1 ? Money.parse(r[1]) : null;
      if (d == null || m == null || m <= 0) {
        if (i > 0 || (d != null)) rejets.add(i + 1); // 1re ligne : peut être un en-tête
        continue;
      }
      _lignes.add(_Ligne(
        date: d,
        montant: m,
        statut: (r.length > 2 ? Tableur.statut(r[2]) : null) ?? _statut,
        type: (r.length > 3 ? Tableur.type(r[3]) : null) ?? TypeOperation.cotisation,
        libelle: r.length > 4 ? r[4] : '',
      ));
      n++;
    }
    _origine = origine;
    _trier();
    _decocherDoublons();
    setState(() {});
    showMessage(context,
        '$n ligne(s) ajoutée(s)${rejets.isEmpty ? '' : ' · lignes ignorées : ${rejets.take(10).join(', ')}${rejets.length > 10 ? '…' : ''}'}.',
        error: n == 0);
  }

  Future<void> _coller() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.trim().isEmpty) {
      if (mounted) showMessage(context, 'Le presse-papiers est vide.', error: true);
      return;
    }
    _integrer(data.text!, OrigineOperation.saisieMasse);
  }

  Future<void> _importer() async {
    try {
      final txt = await TransferService.choisirFichier(extensions: const ['csv', 'txt']);
      if (txt != null) _integrer(txt, OrigineOperation.importCsv);
    } catch (e) {
      if (mounted) showMessage(context, 'Lecture impossible : $e', error: true);
    }
  }

  Future<void> _enregistrer() async {
    final s = AppScope.read(context);
    final c = s.contrat(_contratId!)!;
    final retenues = _lignes.where((l) => l.coche).toList();
    for (final l in retenues) {
      if (l.dateValue == null || l.montantValue == null || l.montantValue! <= 0) {
        showMessage(context, 'Ligne invalide : « ${l.date.text} / ${l.montant.text} ». Corrigez-la ou décochez-la.', error: true);
        return;
      }
    }
    if (retenues.isEmpty) {
      showMessage(context, 'Aucune ligne cochée.', error: true);
      return;
    }
    final total = retenues.fold<int>(0, (a, l) => a + l.montantValue!);
    final ok = await confirmer(context,
        titre: 'Enregistrer ${retenues.length} opération(s) ?',
        message: 'Contrat ${c.reference} · total ${Money.format(total)}.\n'
            'Le lot pourra être annulé en une fois depuis la fiche du contrat.',
        confirmer: 'Enregistrer');
    if (!ok) return;
    final now = DateTime.now().toUtc();
    final lot = await s.enregistrerLot([
      for (final l in retenues)
        Operation(
          id: '',
          contratId: c.id,
          type: l.type,
          montant: l.montantValue!,
          date: l.dateValue!,
          statut: l.statut,
          libelle: l.libelle.text.trim(),
          origine: _origine,
          updatedAt: now,
        ),
    ]);
    String extra = '';
    if (_calculerFinAnnee) {
      final r = await s.genererOperationsAnnuelles(c.id);
      extra = ' · commissions et rendements calculés pour ${r.traitees} année(s)';
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text('${retenues.length} opération(s) enregistrée(s)$extra.'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(label: 'Annuler', onPressed: () => s.annulerLot(lot)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context);
    final ouverts = s.contrats.where((c) => !c.estCloture).toList();
    final c = _contratId == null ? null : s.contrat(_contratId!);
    final cochees = _lignes.where((l) => l.coche).toList();
    final total = cochees.fold<int>(0, (a, l) => a + (l.montantValue ?? 0));
    final annees = [for (var y = DateTime.now().year; y >= (c?.dateEffet.year ?? DateTime.now().year); y--) y];

    return Scaffold(
      appBar: AppBar(title: const Text('Saisie de masse')),
      bottomNavigationBar: _lignes.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: t.cardTheme.color,
                  border: Border(top: BorderSide(color: t.colorScheme.outlineVariant)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${cochees.length} / ${_lignes.length} ligne(s)', style: t.textTheme.labelMedium),
                      Text(Money.format(total), style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  FilledButton.icon(onPressed: _enregistrer, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
                ]),
              ),
            ),
      body: ouverts.isEmpty
          ? const EmptyState(icon: Icons.description_outlined, title: 'Aucun contrat ouvert', message: 'Ajoutez un contrat actif.')
          : PageBody(maxWidth: 1000, children: [
              SectionCard(
                title: '1. Générer les cotisations d’une période',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  DropdownButtonFormField<String>(
                    initialValue: _contratId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Contrat', prefixIcon: Icon(Icons.description_outlined)),
                    items: [
                      for (final o in ouverts)
                        DropdownMenuItem(value: o.id, child: Text('${o.reference} · ${s.nomProduit(o)}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() {
                      _contratId = v;
                      _lignes.clear();
                      _syncContrat();
                    }),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<int>(
                        initialValue: annees.contains(_du) ? _du : annees.first,
                        decoration: const InputDecoration(labelText: 'Du'),
                        items: [for (final y in annees) DropdownMenuItem(value: y, child: Text('$y'))],
                        onChanged: (v) => setState(() {
                          _du = v!;
                          if (_au < _du) _au = _du;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('au$_du'),
                        initialValue: annees.contains(_au) ? _au : annees.first,
                        decoration: const InputDecoration(labelText: 'Au'),
                        items: [for (final y in annees.where((y) => y >= _du)) DropdownMenuItem(value: y, child: Text('$y'))],
                        onChanged: (v) => setState(() => _au = v!),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: _montant,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Montant', suffixText: 'DH'),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<int>(
                        initialValue: _jour,
                        decoration: const InputDecoration(labelText: 'Jour'),
                        items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text('$d'))],
                        onChanged: (v) => setState(() => _jour = v!),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<StatutOperation>(
                        initialValue: _statut,
                        decoration: const InputDecoration(labelText: 'Statut'),
                        items: [for (final st in StatutOperation.values) DropdownMenuItem(value: st, child: Text(st.label))],
                        onChanged: (v) => setState(() => _statut = v!),
                      ),
                    ),
                    FilledButton.tonalIcon(onPressed: _generer, icon: const Icon(Icons.auto_awesome), label: const Text('Générer')),
                  ]),
                  if (c != null) ...[
                    const SizedBox(height: 8),
                    Text('Périodicité du contrat : ${c.periodicite.label.toLowerCase()} · depuis ${Dates.day(c.dateEffet)}',
                        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '2. Ou saisir comme dans un tableur',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        final last = _lignes.isEmpty ? null : _lignes.last;
                        final d = last?.dateValue != null && c != null
                            ? Dates.addMonths(last!.dateValue!, c.periodicite.mois)
                            : Dates.today();
                        _lignes.add(_Ligne(date: d, montant: last?.montantValue ?? (Money.parse(_montant.text) ?? 0), statut: _statut));
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une ligne'),
                    ),
                    OutlinedButton.icon(onPressed: _coller, icon: const Icon(Icons.content_paste), label: const Text('Coller depuis Excel')),
                    OutlinedButton.icon(onPressed: _importer, icon: const Icon(Icons.upload_file), label: const Text('Importer CSV')),
                    if (_lignes.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setState(_lignes.clear),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Vider'),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  Text('Colonnes : Date ; Montant ; Statut ; Type ; Libellé  (ex. 05/01/2025;1500;exécutée;cotisation)',
                      style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ]),
              ),
              const SizedBox(height: 12),
              if (_lignes.isNotEmpty) ...[
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _enTete(t),
                        for (final l in _lignes) _ligne(l, s),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _calculerFinAnnee,
                  onChanged: (v) => setState(() => _calculerFinAnnee = v ?? false),
                  title: const Text('Calculer ensuite les commissions et rendements des années terminées'),
                  subtitle: const Text('À partir de la table des taux annuels (les années déjà saisies à la main sont conservées).'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
              const SizedBox(height: 40),
            ]),
    );
  }

  Widget _enTete(ThemeData t) {
    final st = t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700);
    return Row(children: [
      const SizedBox(width: 48),
      SizedBox(width: 130, child: Text('Date', style: st)),
      const SizedBox(width: 8),
      SizedBox(width: 150, child: Text('Type', style: st)),
      const SizedBox(width: 8),
      SizedBox(width: 130, child: Text('Montant (DH)', style: st)),
      const SizedBox(width: 8),
      SizedBox(width: 140, child: Text('Statut', style: st)),
      const SizedBox(width: 8),
      SizedBox(width: 220, child: Text('Libellé', style: st)),
    ]);
  }

  Widget _ligne(_Ligne l, AppState s) {
    final d = l.dateValue;
    final doublon = d != null && _contratId != null && s.existeOperation(_contratId!, d, l.type);
    final invalide = d == null || l.montantValue == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 48,
          child: Checkbox(value: l.coche, onChanged: (v) => setState(() => l.coche = v ?? false)),
        ),
        SizedBox(
          width: 130,
          child: TextField(
            controller: l.date,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'jj/mm/aaaa',
              errorText: d == null ? 'Date ?' : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<TypeOperation>(
            initialValue: l.type,
            isDense: true,
            decoration: const InputDecoration(isDense: true),
            items: const [
              DropdownMenuItem(value: TypeOperation.cotisation, child: Text('Cotisation')),
              DropdownMenuItem(value: TypeOperation.versement, child: Text('Versement libre')),
            ],
            onChanged: (v) => setState(() => l.type = v!),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 130,
          child: TextField(
            controller: l.montant,
            textAlign: TextAlign.end,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(isDense: true, errorText: l.montantValue == null ? 'Montant ?' : null),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: DropdownButtonFormField<StatutOperation>(
            initialValue: l.statut,
            isDense: true,
            decoration: const InputDecoration(isDense: true),
            items: [for (final st in StatutOperation.values) DropdownMenuItem(value: st, child: Text(st.label))],
            onChanged: (v) => setState(() => l.statut = v!),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 220,
          child: TextField(controller: l.libelle, decoration: const InputDecoration(isDense: true, hintText: 'Libellé')),
        ),
        const SizedBox(width: 4),
        if (doublon)
          const Tooltip(
            message: 'Une opération de ce type existe déjà à cette date',
            child: Icon(Icons.warning_amber, color: AppColors.warning),
          )
        else if (invalide)
          const Icon(Icons.error_outline, color: AppColors.negative)
        else
          const SizedBox(width: 24),
        IconButton(
          tooltip: 'Supprimer la ligne',
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => setState(() => _lignes.remove(l)),
        ),
      ]),
    );
  }
}
