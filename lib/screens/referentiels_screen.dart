import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/transfer_service.dart';
import '../models/produit.dart';
import '../models/taux_annuel.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../utils/tableur.dart';
import '../widgets/adaptive_form.dart';
import '../widgets/common.dart';

// ============================================================================ Produits

/// Table de référence des produits d'assurance.
class ProduitsScreen extends StatelessWidget {
  const ProduitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Produits d’assurance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showProduitForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Produit'),
      ),
      body: PageBody(maxWidth: 900, children: [
        const InfoBanner(
          text: 'Chaque produit porte ses propres règles (cotisation minimale, rachats). '
              'Les taux de commission et de rendement se saisissent par produit et par année dans « Taux annuels ».',
        ),
        const SizedBox(height: 12),
        for (final p in s.produits) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              leading: CircleAvatar(
                backgroundColor: (p.multisupport ? AppColors.gold : t.colorScheme.primary).withValues(alpha: 0.15),
                child: Icon(p.multisupport ? Icons.stacked_line_chart : Icons.shield_outlined,
                    color: p.multisupport ? AppColors.gold : t.colorScheme.primary),
              ),
              title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('${p.code}${p.assureur.isEmpty ? '' : ' · ${p.assureur}'} · ${p.multisupport ? 'Multisupport' : 'Fonds euro'}'),
                  Text('min. ${Money.compact(p.cotisationMinimale)} · ${p.rachatsPartielsMax} rachats ≤ ${p.plafondRachatPourcent} %',
                      style: t.textTheme.bodySmall),
                  Text('${s.contrats.where((c) => c.produitId == p.id).length} contrat(s)', style: t.textTheme.bodySmall),
                  if (!p.actif) const StatusChip(label: 'Inactif', color: Colors.blueGrey, icon: Icons.block),
                ]),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Taux annuels',
                  icon: const Icon(Icons.percent),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => TauxAnnuelsScreen(produitId: p.id))),
                ),
                IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined), onPressed: () => showProduitForm(context, existing: p)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 60),
      ]),
    );
  }
}

Future<void> showProduitForm(BuildContext context, {Produit? existing}) {
  final form = GlobalKey<FormState>();
  final code = TextEditingController(text: existing?.code ?? '');
  final nom = TextEditingController(text: existing?.nom ?? '');
  final assureur = TextEditingController(text: existing?.assureur ?? '');
  final min = TextEditingController(text: Money.toInput(existing?.cotisationMinimale ?? 20000));
  final nb = TextEditingController(text: '${existing?.rachatsPartielsMax ?? 4}');
  final plafond = TextEditingController(text: '${existing?.plafondRachatPourcent ?? 50}');
  var multi = existing?.multisupport ?? false;
  var actif = existing?.actif ?? true;

  String? entier(String? v, int max) {
    final n = int.tryParse(v ?? '');
    return n == null || n < 0 || n > max ? 'Entre 0 et $max' : null;
  }

  return showAdaptiveForm<void>(
    context,
    title: existing == null ? 'Nouveau produit' : 'Modifier le produit',
    body: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Form(
        key: form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox(
              width: 130,
              child: TextFormField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Code'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requis' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: nom,
                decoration: const InputDecoration(labelText: 'Nom du produit'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Requis' : null,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextFormField(controller: assureur, decoration: const InputDecoration(labelText: 'Assureur')),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Fonds euro'), icon: Icon(Icons.shield_outlined)),
              ButtonSegment(value: true, label: Text('Multisupport'), icon: Icon(Icons.stacked_line_chart)),
            ],
            selected: {multi},
            onSelectionChanged: (v) => setState(() => multi = v.first),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: min,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cotisation minimale', suffixText: 'DH'),
            validator: (v) => Money.parse(v ?? '') == null ? 'Montant invalide' : null,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: nb,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rachats partiels max'),
                validator: (v) => entier(v, 100),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: plafond,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Plafond par rachat', suffixText: '%'),
                validator: (v) => entier(v, 100),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Produit actif'),
            subtitle: const Text('Un produit inactif n’est plus proposé pour un nouveau contrat.'),
            value: actif,
            onChanged: (v) => setState(() => actif = v),
          ),
        ]),
      ),
    ),
    actions: (ctx) {
      final s = AppScope.read(ctx);
      return Row(children: [
        if (existing != null && !s.produitUtilise(existing.id))
          IconButton(
            tooltip: 'Supprimer',
            color: AppColors.negative,
            onPressed: () async {
              await s.deleteProduit(existing.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            icon: const Icon(Icons.delete_outline),
          ),
        const Spacer(),
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: () async {
            if (!form.currentState!.validate()) return;
            final base = existing ?? Produit(id: newId(), code: '', nom: '', updatedAt: DateTime.now().toUtc());
            await s.saveProduit(base.copyWith(
              code: code.text.trim(),
              nom: nom.text.trim(),
              assureur: assureur.text.trim(),
              multisupport: multi,
              cotisationMinimale: Money.parse(min.text),
              rachatsPartielsMax: int.parse(nb.text),
              plafondRachatPourcent: int.parse(plafond.text),
              actif: actif,
            ));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Enregistrer'),
        ),
      ]);
    },
  );
}

// ============================================================================ Taux annuels

class _LigneTaux {
  _LigneTaux({required this.annee, String commission = '', String rendement = '', String commentaire = '', this.id})
      : commission = TextEditingController(text: commission),
        rendement = TextEditingController(text: rendement),
        commentaire = TextEditingController(text: commentaire);
  final String? id;
  int annee;
  final TextEditingController commission;
  final TextEditingController rendement;
  final TextEditingController commentaire;
}

/// Tableau des taux de commission et de rendement par année, pour un produit ou pour un contrat.
class TauxAnnuelsScreen extends StatefulWidget {
  const TauxAnnuelsScreen({super.key, this.produitId, this.contratId});
  final String? produitId;
  final String? contratId;

  @override
  State<TauxAnnuelsScreen> createState() => _TauxAnnuelsScreenState();
}

class _TauxAnnuelsScreenState extends State<TauxAnnuelsScreen> {
  late bool _parContrat = widget.contratId != null;
  String? _produitId;
  String? _contratId;
  List<_LigneTaux> _lignes = [];
  bool _modifie = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    _produitId = widget.produitId ?? (s.produits.isEmpty ? null : s.produits.first.id);
    _contratId = widget.contratId ?? (s.contrats.isEmpty ? null : s.contrats.first.id);
    _charger();
  }

  void _charger() {
    final s = AppScope.read(context);
    final rows = _parContrat
        ? (_contratId == null ? <TauxAnnuel>[] : s.tauxDe(contratId: _contratId))
        : (_produitId == null ? <TauxAnnuel>[] : s.tauxDe(produitId: _produitId));
    _lignes = [
      for (final t in rows)
        _LigneTaux(
          id: t.id,
          annee: t.annee,
          commission: Taux.toInput(t.tauxCommission),
          rendement: Taux.toInput(t.tauxRendement),
          commentaire: t.commentaire,
        ),
    ];
    _modifie = false;
    _erreur = null;
  }

  Future<bool> _confirmerAbandon() async {
    if (!_modifie) return true;
    return confirmer(context,
        titre: 'Modifications non enregistrées',
        message: 'Abandonner les modifications du tableau ?',
        confirmer: 'Abandonner',
        destructive: true);
  }

  void _ajouter({required bool suivante}) {
    setState(() {
      final annees = _lignes.map((l) => l.annee).toList();
      final y = annees.isEmpty
          ? DateTime.now().year
          : (suivante ? annees.reduce((a, b) => a > b ? a : b) + 1 : annees.reduce((a, b) => a < b ? a : b) - 1);
      final ref = _lignes.where((l) => l.annee == (suivante ? y - 1 : y + 1)).firstOrNull;
      _lignes.add(_LigneTaux(annee: y, commission: ref?.commission.text ?? '', rendement: suivante ? '' : (ref?.rendement.text ?? '')));
      _lignes.sort((a, b) => b.annee.compareTo(a.annee));
      _modifie = true;
    });
  }

  /// Colle ou importe des lignes « année ; commission ; rendement ; commentaire ».
  void _integrer(String texte) {
    final rows = Tableur.lignes(texte);
    var n = 0;
    final rejets = <int>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final y = int.tryParse(r.first.trim());
      if (y == null || y < 1950 || y > 2100) {
        if (i > 0) rejets.add(i + 1); // la 1re ligne peut être un en-tête
        continue;
      }
      try {
        final com = r.length > 1 ? Taux.parse(r[1]) : null;
        final ren = r.length > 2 ? Taux.parse(r[2]) : null;
        final ex = _lignes.where((l) => l.annee == y).firstOrNull;
        final l = ex ?? _LigneTaux(annee: y);
        l.commission.text = Taux.toInput(com);
        l.rendement.text = Taux.toInput(ren);
        if (r.length > 3) l.commentaire.text = r[3];
        if (ex == null) _lignes.add(l);
        n++;
      } on FormatException {
        rejets.add(i + 1);
      }
    }
    setState(() {
      _lignes.sort((a, b) => b.annee.compareTo(a.annee));
      _modifie = _modifie || n > 0;
    });
    showMessage(context,
        '$n ligne(s) intégrée(s)${rejets.isEmpty ? '' : ' · lignes ignorées : ${rejets.join(', ')}'}. Pensez à enregistrer.',
        error: n == 0);
  }

  Future<void> _coller() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.trim().isEmpty) {
      if (mounted) showMessage(context, 'Le presse-papiers est vide.', error: true);
      return;
    }
    _integrer(data.text!);
  }

  Future<void> _importer() async {
    try {
      final txt = await TransferService.choisirFichier(extensions: const ['csv', 'txt']);
      if (txt != null) _integrer(txt);
    } catch (e) {
      if (mounted) showMessage(context, 'Lecture impossible : $e', error: true);
    }
  }

  Future<void> _enregistrer() async {
    final s = AppScope.read(context);
    final out = <TauxAnnuel>[];
    final vues = <int>{};
    for (final l in _lignes) {
      if (!vues.add(l.annee)) {
        setState(() => _erreur = 'L’année ${l.annee} apparaît deux fois.');
        return;
      }
      final int? com, ren;
      try {
        com = Taux.parse(l.commission.text);
        ren = Taux.parse(l.rendement.text);
      } on FormatException {
        setState(() => _erreur = 'Taux invalide pour ${l.annee} (exemple : 3,20).');
        return;
      }
      if (com != null && (com < 0 || com > 1000)) {
        setState(() => _erreur = 'Commission ${l.annee} : entre 0 et 10 %.');
        return;
      }
      if (ren != null && (ren < -3000 || ren > 3000)) {
        setState(() => _erreur = 'Rendement ${l.annee} : entre −30 % et +30 %.');
        return;
      }
      if (com == null && ren == null && l.commentaire.text.trim().isEmpty) continue;
      out.add(TauxAnnuel(
        id: l.id ?? newId(),
        produitId: _parContrat ? null : _produitId,
        contratId: _parContrat ? _contratId : null,
        annee: l.annee,
        tauxCommission: com,
        tauxRendement: ren,
        commentaire: l.commentaire.text.trim(),
        updatedAt: DateTime.now().toUtc(),
      ));
    }
    await s.saveTaux(produitId: _parContrat ? null : _produitId, contratId: _parContrat ? _contratId : null, lignes: out);
    if (!mounted) return;
    setState(() {
      _modifie = false;
      _erreur = null;
    });
    showMessage(context, '${out.length} année(s) enregistrée(s).');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context);
    final contrat = _contratId == null ? null : s.contrat(_contratId!);
    final produitRef = _parContrat && contrat != null ? s.produitDe(contrat) : null;
    String? hint(int annee, bool commission) {
      if (produitRef == null) return null;
      final l = s.tauxDe(produitId: produitRef.id).where((e) => e.annee == annee).firstOrNull;
      final v = commission ? l?.tauxCommission : l?.tauxRendement;
      return v == null ? null : Taux.toInput(v);
    }

    return PopScope(
      canPop: !_modifie,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmerAbandon() && context.mounted) {
          _modifie = false;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Taux annuels'),
          actions: [
            if (_modifie)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(onPressed: _enregistrer, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
              ),
          ],
        ),
        body: PageBody(maxWidth: 980, children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Par produit'), icon: Icon(Icons.inventory_2_outlined)),
              ButtonSegment(value: true, label: Text('Par contrat'), icon: Icon(Icons.description_outlined)),
            ],
            selected: {_parContrat},
            onSelectionChanged: (v) async {
              if (!await _confirmerAbandon()) return;
              setState(() {
                _parContrat = v.first;
                _charger();
              });
            },
          ),
          const SizedBox(height: 12),
          if (!_parContrat)
            DropdownButtonFormField<String>(
              initialValue: _produitId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Produit', prefixIcon: Icon(Icons.inventory_2_outlined)),
              items: [for (final p in s.produits) DropdownMenuItem(value: p.id, child: Text(p.nom, overflow: TextOverflow.ellipsis))],
              onChanged: (v) async {
                if (!await _confirmerAbandon()) return;
                setState(() {
                  _produitId = v;
                  _charger();
                });
              },
            )
          else if (s.contrats.isEmpty)
            const InfoBanner(text: 'Aucun contrat.')
          else
            DropdownButtonFormField<String>(
              initialValue: _contratId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Contrat', prefixIcon: Icon(Icons.description_outlined)),
              items: [
                for (final c in s.contrats)
                  DropdownMenuItem(value: c.id, child: Text('${c.reference} · ${s.nomProduit(c)}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) async {
                if (!await _confirmerAbandon()) return;
                setState(() {
                  _contratId = v;
                  _charger();
                });
              },
            ),
          const SizedBox(height: 12),
          InfoBanner(
            text: _parContrat
                ? 'Taux propres à ce contrat : ils remplacent ceux du produit « ${produitRef?.nom ?? ''} ». '
                    'Laissez une case vide pour garder le taux du produit (affiché en gris).'
                : 'Commission : % retenu sur chaque versement (cotisation ou versement libre). '
                    'Rendement : taux servi par l’assureur pour l’année, appliqué comme sur un compte sur carnet.',
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _ajouter(suivante: true), icon: const Icon(Icons.add), label: const Text('Année suivante')),
            OutlinedButton.icon(
                onPressed: () => _ajouter(suivante: false), icon: const Icon(Icons.history), label: const Text('Année antérieure')),
            OutlinedButton.icon(onPressed: _coller, icon: const Icon(Icons.content_paste), label: const Text('Coller depuis Excel')),
            OutlinedButton.icon(onPressed: _importer, icon: const Icon(Icons.upload_file), label: const Text('Importer CSV')),
          ]),
          const SizedBox(height: 6),
          Text('Format attendu : Année ; Commission % ; Rendement % ; Commentaire  (ex. 2025;3,00;3,20;Courrier du 15/01)',
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          if (_erreur != null) ...[
            const SizedBox(height: 12),
            InfoBanner(text: _erreur!, icon: Icons.error_outline, color: AppColors.negative),
          ],
          const SizedBox(height: 12),
          Card(
            child: _lignes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aucun taux saisi. Ajoutez une année, collez depuis Excel ou importez un fichier CSV.'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 640),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          _enTete(t),
                          for (final l in _lignes)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                SizedBox(
                                  width: 70,
                                  child: Text('${l.annee}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                _celluleTaux(l.commission, hint(l.annee, true)),
                                const SizedBox(width: 8),
                                _celluleTaux(l.rendement, hint(l.annee, false)),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 260,
                                  child: TextField(
                                    controller: l.commentaire,
                                    onChanged: (_) => setState(() => _modifie = true),
                                    decoration: const InputDecoration(isDense: true, hintText: 'Commentaire'),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Supprimer la ligne',
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() {
                                    _lignes.remove(l);
                                    _modifie = true;
                                  }),
                                ),
                              ]),
                            ),
                        ]),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (_modifie)
            FilledButton.icon(onPressed: _enregistrer, icon: const Icon(Icons.save), label: const Text('Enregistrer le tableau')),
        ]),
      ),
    );
  }

  Widget _enTete(ThemeData t) {
    final st = t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 70, child: Text('Année', style: st)),
        SizedBox(width: 120, child: Text('Commission %', style: st)),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: Text('Rendement %', style: st)),
        const SizedBox(width: 8),
        SizedBox(width: 260, child: Text('Commentaire', style: st)),
      ]),
    );
  }

  Widget _celluleTaux(TextEditingController c, String? hint) => SizedBox(
        width: 120,
        child: TextField(
          controller: c,
          textAlign: TextAlign.end,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onChanged: (_) => setState(() => _modifie = true),
          decoration: InputDecoration(isDense: true, suffixText: '%', hintText: hint ?? '—'),
        ),
      );
}
