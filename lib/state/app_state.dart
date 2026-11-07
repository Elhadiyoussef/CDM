import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/storage.dart';
import '../models/app_data.dart';
import '../models/contrat.dart';
import '../models/enums.dart';
import '../models/operation.dart';
import '../models/parametres.dart';
import '../models/produit.dart';
import '../models/taux_annuel.dart';
import '../services/calcul_annuel.dart';
import '../utils/dates.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

enum ModeImport { fusionner, remplacer }

class ResumeImport {
  ResumeImport({required this.data, required this.exporteLe});
  final AppData data;
  final DateTime? exporteLe;
  int get nbContrats => data.contrats.length;
  int get nbOperations => data.operations.length;
}

class ResultatImport {
  ResultatImport(this.ajoutes, this.misAJour, this.ignores);
  final int ajoutes;
  final int misAJour;
  final int ignores;
}

/// Point d'accès aux données. Toute modification est enregistrée immédiatement dans le JSON.
class AppState extends ChangeNotifier {
  AppState({JsonStorage? storage, DateTime? today})
      : _storage = storage ?? JsonStorage.create(),
        _today = today; // ignore: prefer_initializing_formals

  final JsonStorage _storage;
  final DateTime? _today;
  DateTime get today => _today ?? DateTime.now();

  AppData _data = AppData();
  bool _loaded = false;
  String? loadWarning;

  bool get isLoaded => _loaded;
  AppData get data => _data;
  String get nomUtilisateur => _data.nomUtilisateur;
  List<Contrat> get contrats => List.unmodifiable(_data.contrats);
  bool get estVide => _data.contrats.isEmpty;

  ThemeMode get themeMode => switch (_data.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<String> emplacement() => _storage.location();

  // ---------------------------------------------------------------- chargement

  Future<void> load() async {
    try {
      final raw = await _storage.read();
      if (raw != null) _data = _decode(raw);
    } catch (_) {
      // Fichier principal illisible : tentative sur la sauvegarde.
      try {
        final bak = await _storage.readBackup();
        if (bak != null) {
          _data = _decode(bak);
          loadWarning = 'Le fichier de données était endommagé : la sauvegarde précédente a été restaurée.';
        }
      } catch (_) {
        loadWarning = 'Impossible de lire les données enregistrées.';
      }
    }
    _loaded = true;
    notifyListeners();
  }

  AppData _decode(String raw) =>
      AppData.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));

  Future<void> _commit() async {
    _data.updatedAt = DateTime.now().toUtc();
    notifyListeners();
    await _storage.write(_encode(_data));
  }

  String _encode(AppData d) => const JsonEncoder.withIndent('  ').convert(d.toJson());

  // ---------------------------------------------------------------- profil

  Future<void> setNom(String nom) async {
    _data.nomUtilisateur = nom.trim();
    await _commit();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _data.themeMode = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await _commit();
  }

  // ---------------------------------------------------------------- contrats

  Contrat? contrat(String id) {
    for (final c in _data.contrats) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> saveContrat(Contrat c) async {
    final i = _data.contrats.indexWhere((e) => e.id == c.id);
    if (i >= 0) {
      _data.contrats[i] = c;
    } else {
      _data.contrats.add(c);
    }
    await _commit();
  }

  Future<void> deleteContrat(String id) async {
    _data.contrats.removeWhere((c) => c.id == id);
    _data.operations.removeWhere((o) => o.contratId == id);
    await _commit();
  }

  // ---------------------------------------------------------------- opérations

  /// Opérations triées de la plus récente à la plus ancienne.
  List<Operation> operations({String? contratId}) {
    final list = _data.operations
        .where((o) => contratId == null || o.contratId == contratId)
        .toList()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
      });
    return list;
  }

  /// Capital constitué = somme des opérations exécutées uniquement.
  int capital({String? contratId}) =>
      operations(contratId: contratId).fold(0, (s, o) => s + o.impact);

  int totalVerse({String? contratId}) => operations(contratId: contratId)
      .where((o) => o.estExecutee && o.type.estApport)
      .fold(0, (s, o) => s + o.montant);

  int totalRachats({String? contratId}) => operations(contratId: contratId)
      .where((o) => o.estExecutee && o.type.estRachat)
      .fold(0, (s, o) => s + o.montant);

  /// Écart de valorisation = capital − (versé − rachats).
  int ecart({String? contratId}) =>
      capital(contratId: contratId) - (totalVerse(contratId: contratId) - totalRachats(contratId: contratId));

  int montantEnAttente({String? contratId}) => operations(contratId: contratId)
      .where((o) => o.statut == StatutOperation.enAttente)
      .fold(0, (s, o) => s + (o.type.credit ? o.montant : -o.montant));

  int objectif({String? contratId}) => contratId != null
      ? (contrat(contratId)?.objectif ?? 0)
      : _data.contrats.where((c) => !c.estCloture).fold(0, (s, c) => s + c.objectif);

  DateTime? derniereValorisation({String? contratId}) {
    final reval = operations(contratId: contratId)
        .where((o) => o.estExecutee && o.type == TypeOperation.revalorisation);
    return reval.isEmpty ? null : reval.first.date;
  }

  int nbRachatsPartiels(String contratId) => operations(contratId: contratId)
      .where((o) =>
          o.type == TypeOperation.rachatPartiel &&
          (o.statut == StatutOperation.executee || o.statut == StatutOperation.enAttente))
      .length;

  /// Courbe du capital (point par date d'opération exécutée), ordre chronologique.
  List<MapEntry<DateTime, int>> evolutionCapital({String? contratId}) {
    final ops = operations(contratId: contratId).where((o) => o.estExecutee).toList().reversed;
    final points = <MapEntry<DateTime, int>>[];
    var cumul = 0;
    for (final o in ops) {
      cumul += o.impact;
      if (points.isNotEmpty && points.last.key == o.date) {
        points[points.length - 1] = MapEntry(o.date, cumul);
      } else {
        points.add(MapEntry(o.date, cumul));
      }
    }
    return points;
  }

  /// Contrôles métier avant enregistrement. Retourne la liste des erreurs bloquantes.
  List<String> verifierOperation({
    required String contratId,
    required TypeOperation type,
    required int montant,
    required StatutOperation statut,
  }) {
    final errors = <String>[];
    final c = contrat(contratId);
    if (c == null) return ['Contrat introuvable.'];
    if (c.estCloture) {
      errors.add('Ce contrat est clôturé : aucune nouvelle opération financière n’est possible.');
    }
    if (montant <= 0) errors.add('Le montant doit être supérieur à zéro.');
    final cap = capital(contratId: contratId);
    final regles = produitDe(c);
    if (type == TypeOperation.rachatPartiel && statut != StatutOperation.annulee && statut != StatutOperation.rejetee) {
      if (nbRachatsPartiels(contratId) >= regles.rachatsPartielsMax) {
        errors.add('Nombre maximal de rachats partiels atteint (${regles.rachatsPartielsMax}).');
      }
      final plafond = cap * regles.plafondRachatPourcent ~/ 100;
      if (montant > plafond) {
        errors.add('Le rachat partiel est limité à ${regles.plafondRachatPourcent} % de l’épargne constituée.');
      }
    }
    if ((type == TypeOperation.rachatTotal || type == TypeOperation.frais) && montant > cap) {
      errors.add('Le montant dépasse le capital constitué.');
    }
    final doublon = type.estRachat &&
        operations(contratId: contratId)
            .any((o) => o.type.estRachat && o.statut == StatutOperation.enAttente);
    if (doublon && statut == StatutOperation.enAttente) {
      errors.add('Une demande de rachat est déjà en attente sur ce contrat.');
    }
    return errors;
  }

  Future<void> addOperation(Operation op) async {
    _data.operations.add(op);
    _appliquerEffets(op);
    await _commit();
  }

  Future<void> setStatutOperation(String id, StatutOperation statut) async {
    final i = _data.operations.indexWhere((o) => o.id == id);
    if (i < 0) return;
    final op = _data.operations[i].copyWith(statut: statut);
    _data.operations[i] = op;
    _appliquerEffets(op);
    await _commit();
  }

  Future<void> deleteOperation(String id) async {
    _data.operations.removeWhere((o) => o.id == id);
    await _commit();
  }

  /// Un rachat total exécuté clôture le contrat.
  void _appliquerEffets(Operation op) {
    if (op.type == TypeOperation.rachatTotal && op.estExecutee) {
      final i = _data.contrats.indexWhere((c) => c.id == op.contratId);
      if (i >= 0) _data.contrats[i] = _data.contrats[i].copyWith(statut: StatutContrat.cloture);
    }
  }


  // ---------------------------------------------------------------- produits

  List<Produit> get produits => List.unmodifiable(_data.produits);

  Produit? produit(String id) {
    for (final p in _data.produits) {
      if (p.id == id) return p;
    }
    return null;
  }

  Produit produitDe(Contrat c) =>
      produit(c.produitId) ?? _data.produits.firstWhere((p) => p.id == Produit.idAutre, orElse: () => Produit.parDefaut().last);

  String nomProduit(Contrat c) => produitDe(c).nom;

  Future<void> saveProduit(Produit p) async {
    final i = _data.produits.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      _data.produits[i] = p;
    } else {
      _data.produits.add(p);
    }
    await _commit();
  }

  bool produitUtilise(String id) => _data.contrats.any((c) => c.produitId == id);

  Future<void> deleteProduit(String id) async {
    if (produitUtilise(id)) throw StateError('Produit utilisé par un contrat.');
    _data.produits.removeWhere((p) => p.id == id);
    _data.tauxAnnuels.removeWhere((t) => t.produitId == id);
    await _commit();
  }

  // ---------------------------------------------------------------- taux annuels

  ParametresCalcul get parametres => _data.parametres;

  Future<void> setParametres(ParametresCalcul p) async {
    _data.parametres = p;
    await _commit();
  }

  /// Lignes de taux d'une cible (produit ou contrat), triées par année décroissante.
  List<TauxAnnuel> tauxDe({String? produitId, String? contratId}) => _data.tauxAnnuels
      .where((t) => contratId != null ? t.contratId == contratId : (t.produitId == produitId && t.contratId == null))
      .toList()
    ..sort((a, b) => b.annee.compareTo(a.annee));

  /// Enregistre l'ensemble des lignes d'une cible (remplace les précédentes).
  Future<void> saveTaux({String? produitId, String? contratId, required List<TauxAnnuel> lignes}) async {
    _data.tauxAnnuels.removeWhere(
        (t) => contratId != null ? t.contratId == contratId : (t.produitId == produitId && t.contratId == null));
    _data.tauxAnnuels.addAll(lignes);
    await _commit();
  }

  /// Taux applicables à un contrat pour une année :
  /// taux du contrat s'il existe, sinon taux du produit, sinon estimation (année en cours, si paramétré).
  TauxEffectif tauxEffectif(Contrat c, int annee) {
    TauxAnnuel? ligne(bool contrat, int y) {
      for (final t in _data.tauxAnnuels) {
        if (t.annee != y) continue;
        if (contrat ? t.contratId == c.id : (t.contratId == null && t.produitId == c.produitId)) return t;
      }
      return null;
    }

    final lc = ligne(true, annee);
    final lp = ligne(false, annee);
    int? com = lc?.tauxCommission ?? lp?.tauxCommission;
    int? ren = lc?.tauxRendement ?? lp?.tauxRendement;
    final sources = <String>{
      if (lc?.tauxCommission != null || lc?.tauxRendement != null) 'contrat',
      if ((lc?.tauxCommission == null && lp?.tauxCommission != null) || (lc?.tauxRendement == null && lp?.tauxRendement != null)) 'produit',
    };
    var comEst = false, renEst = false;
    final p = _data.parametres;
    if (annee >= today.year && p.estimerAnneeEnCours) {
      int? dernier(int? Function(TauxAnnuel) f) {
        for (var y = annee - 1; y >= annee - 30; y--) {
          final v = (ligne(true, y) != null ? f(ligne(true, y)!) : null) ?? (ligne(false, y) != null ? f(ligne(false, y)!) : null);
          if (v != null) return v;
        }
        return null;
      }

      if (ren == null) {
        ren = p.tauxEstimation ?? dernier((t) => t.tauxRendement);
        renEst = ren != null;
      }
      if (com == null) {
        com = dernier((t) => t.tauxCommission);
        comEst = com != null;
      }
      if (renEst || comEst) sources.add('estimation');
    }
    return TauxEffectif(
      commission: com,
      rendement: ren,
      commissionEstimee: comEst,
      rendementEstime: renEst,
      source: sources.join(' + '),
    );
  }

  // ---------------------------------------------------------------- récapitulatif annuel

  CalculAnnuel get _moteur => CalculAnnuel(_data.parametres, today: today);

  /// Récapitulatif d'un contrat, ou de tous les contrats si [contratId] est null.
  Recap recap({String? contratId, bool selonTaux = true}) {
    final cibles = contratId == null ? _data.contrats : _data.contrats.where((c) => c.id == contratId);
    final recaps = [
      for (final c in cibles)
        selonTaux ? _moteur.selonTaux(c, _data.operations, tauxEffectif) : _moteur.selonOperations(c, _data.operations),
    ];
    if (contratId != null) return recaps.isEmpty ? Recap([]) : recaps.first;
    return Recap.somme(recaps);
  }

  /// Génère, pour les années terminées, les opérations « Commission » et « Revalorisation »
  /// calculées depuis la table des taux. Les années contenant déjà des revalorisations ou
  /// commissions saisies à la main sont ignorées. Retourne le nombre d'années traitées.
  Future<({int traitees, List<int> ignorees})> genererOperationsAnnuelles(String contratId) async {
    final c = contrat(contratId);
    if (c == null) return (traitees: 0, ignorees: <int>[]);
    final r = _moteur.selonTaux(c, _data.operations, tauxEffectif);
    final lot = newId();
    var traitees = 0;
    final ignorees = <int>[];
    final now = DateTime.now().toUtc();
    final p = _data.parametres;
    for (final a in r.annees) {
      if (a.enCours || a.cloture) continue;
      final manuelles = _data.operations.any((o) =>
          o.contratId == contratId &&
          o.date.year == a.annee &&
          o.type.estCalculable &&
          o.origine != OrigineOperation.calculAnnuel);
      if (manuelles) {
        ignorees.add(a.annee);
        continue;
      }
      _data.operations.removeWhere((o) =>
          o.contratId == contratId && o.date.year == a.annee && o.origine == OrigineOperation.calculAnnuel);
      final dateReval = DateTime(a.annee, p.moisRevalorisation, p.jourRevalorisation);
      if (a.commission > 0) {
        _data.operations.add(Operation(
          id: newId(),
          contratId: contratId,
          type: TypeOperation.commission,
          montant: a.commission,
          date: dateReval,
          libelle: 'Commissions ${a.annee} (${Taux.format(a.tauxCommission)} des versements)',
          origine: OrigineOperation.calculAnnuel,
          lotId: lot,
          updatedAt: now,
        ));
      }
      if (a.rendement != 0) {
        _data.operations.add(Operation(
          id: newId(),
          contratId: contratId,
          type: a.rendement > 0 ? TypeOperation.revalorisation : TypeOperation.frais,
          montant: a.rendement.abs(),
          date: dateReval,
          libelle: 'Rendement ${a.annee} (${Taux.format(a.tauxRendement)})',
          origine: OrigineOperation.calculAnnuel,
          lotId: lot,
          updatedAt: now,
        ));
      }
      traitees++;
    }
    await _commit();
    return (traitees: traitees, ignorees: ignorees);
  }

  // ---------------------------------------------------------------- saisie de masse

  /// Une cotisation existe-t-elle déjà à cette date pour ce contrat ?
  bool existeOperation(String contratId, DateTime date, TypeOperation type) => _data.operations.any((o) =>
      o.contratId == contratId &&
      o.type == type &&
      o.date == date &&
      o.statut != StatutOperation.annulee);

  /// Enregistre un lot d'opérations en une fois. Retourne l'identifiant du lot.
  Future<String> enregistrerLot(List<Operation> ops) async {
    final lot = newId();
    final now = DateTime.now().toUtc();
    for (final o in ops) {
      _data.operations.add(Operation(
        id: newId(),
        contratId: o.contratId,
        type: o.type,
        montant: o.montant,
        date: o.date,
        statut: o.statut,
        libelle: o.libelle,
        origine: o.origine,
        lotId: lot,
        updatedAt: now,
      ));
    }
    await _commit();
    return lot;
  }

  /// Lots de saisie d'un contrat (le plus récent d'abord).
  List<({String lotId, OrigineOperation origine, int nb, int total, DateTime creeLe, DateTime du, DateTime au})> lots(
      String contratId) {
    final map = <String, List<Operation>>{};
    for (final o in _data.operations) {
      if (o.contratId == contratId && o.lotId != null) map.putIfAbsent(o.lotId!, () => []).add(o);
    }
    final out = [
      for (final e in map.entries)
        (
          lotId: e.key,
          origine: e.value.first.origine,
          nb: e.value.length,
          total: e.value.fold(0, (s, o) => s + o.montant),
          creeLe: e.value.map((o) => o.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b),
          du: e.value.map((o) => o.date).reduce((a, b) => a.isBefore(b) ? a : b),
          au: e.value.map((o) => o.date).reduce((a, b) => a.isAfter(b) ? a : b),
        ),
    ]..sort((a, b) => b.creeLe.compareTo(a.creeLe));
    return out;
  }

  Future<int> annulerLot(String lotId) async {
    final n = _data.operations.where((o) => o.lotId == lotId).length;
    _data.operations.removeWhere((o) => o.lotId == lotId);
    await _commit();
    return n;
  }

  // ---------------------------------------------------------------- export / import

  String exporterJson() => _encode(_data);

  String nomFichierExport() {
    final d = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'ma_retraite_${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}.json';
  }

  /// Analyse un fichier sans rien modifier. Lève [FormatException] si invalide.
  ResumeImport analyserImport(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException("Le fichier n'est pas un JSON valide.");
    }
    if (decoded is! Map) throw const FormatException('Structure de fichier inattendue.');
    final data = AppData.fromJson(Map<String, dynamic>.from(decoded));
    return ResumeImport(data: data, exporteLe: DateTime.tryParse('${decoded['updatedAt']}'));
  }

  Future<ResultatImport> importer(ResumeImport resume, ModeImport mode) async {
    final incoming = resume.data;
    if (mode == ModeImport.remplacer) {
      _data = incoming;
      await _commit();
      return ResultatImport(incoming.contrats.length + incoming.operations.length, 0, 0);
    }
    // Fusion par identifiant : la version modifiée le plus récemment l'emporte.
    var added = 0, updated = 0, skipped = 0;
    void merge<T>(List<T> target, List<T> source, String Function(T) id, DateTime Function(T) at) {
      for (final item in source) {
        final i = target.indexWhere((e) => id(e) == id(item));
        if (i < 0) {
          target.add(item);
          added++;
        } else if (at(item).isAfter(at(target[i]))) {
          target[i] = item;
          updated++;
        } else {
          skipped++;
        }
      }
    }

    merge<Produit>(_data.produits, incoming.produits, (p) => p.id, (p) => p.updatedAt);
    // Les taux sont fusionnés par cible et par année (une seule ligne par produit/contrat et par an).
    merge<TauxAnnuel>(_data.tauxAnnuels, incoming.tauxAnnuels, (t) => t.cle, (t) => t.updatedAt);
    merge<Contrat>(_data.contrats, incoming.contrats, (c) => c.id, (c) => c.updatedAt);
    merge<Operation>(_data.operations, incoming.operations, (o) => o.id, (o) => o.updatedAt);
    if (_data.nomUtilisateur.isEmpty) _data.nomUtilisateur = incoming.nomUtilisateur;
    await _commit();
    return ResultatImport(added, updated, skipped);
  }

  Future<void> toutEffacer() async {
    // Les référentiels (produits, taux, paramètres) sont conservés.
    _data = AppData(
      themeMode: _data.themeMode,
      produits: _data.produits,
      tauxAnnuels: _data.tauxAnnuels,
      parametres: _data.parametres,
    );
    await _commit();
  }

  // ---------------------------------------------------------------- démo

  Future<void> chargerDemo() async {
    final now = DateTime.now().toUtc();
    final today = Dates.today();
    final debut = Dates.addMonths(DateTime(today.year, today.month, 5), -84);
    final c = Contrat(
      id: newId(),
      reference: 'AR-2019-004587',
      produitId: Produit.idIndividuelle,
      dateEffet: debut,
      dateEcheance: DateTime(today.year + 18, 6, 30),
      cotisation: 150000,
      objectif: 50000000,
      beneficiaires: [
        Beneficiaire(id: newId(), nom: 'Salma El Amrani', lien: 'Conjointe', quotePart: 60),
        Beneficiaire(id: newId(), nom: 'Yanis El Amrani', lien: 'Enfant', quotePart: 40),
      ],
      updatedAt: now,
    );
    final ops = <Operation>[];
    var cap = 0;
    for (var m = 0; m < 84; m++) {
      final d = Dates.addMonths(debut, m);
      if (!d.isBefore(today)) break;
      ops.add(Operation(
          id: newId(),
          contratId: c.id,
          type: TypeOperation.cotisation,
          montant: c.cotisation,
          date: d,
          statut: m == 41 ? StatutOperation.rejetee : StatutOperation.executee,
          libelle: m == 41 ? 'Prélèvement rejeté — provision insuffisante' : 'Prélèvement mensuel',
          updatedAt: now));
      if (m != 41) cap += c.cotisation;
      if (d.month == 12 && DateTime(d.year, 12, 31).isBefore(today)) {
        final reval = cap * 3 ~/ 100;
        cap += reval;
        ops.add(Operation(
            id: newId(),
            contratId: c.id,
            type: TypeOperation.revalorisation,
            montant: reval,
            date: DateTime(d.year, 12, 31),
            libelle: 'Participation aux bénéfices ${d.year}',
            updatedAt: now));
      }
      if (m == 30 || m == 66) {
        ops.add(Operation(
            id: newId(),
            contratId: c.id,
            type: TypeOperation.versement,
            montant: 1000000,
            date: d.add(const Duration(days: 12)),
            libelle: 'Versement libre',
            updatedAt: now));
        cap += 1000000;
      }
    }
    ops.add(Operation(
        id: newId(),
        contratId: c.id,
        type: TypeOperation.versement,
        montant: 500000,
        date: today,
        statut: StatutOperation.enAttente,
        libelle: 'Versement complémentaire',
        updatedAt: now));
    _data.contrats.add(c);
    _data.operations.addAll(ops);
    for (var y = debut.year; y <= today.year; y++) {
      final i = _data.tauxAnnuels.indexWhere((t) => t.produitId == Produit.idIndividuelle && t.contratId == null && t.annee == y);
      if (i >= 0) continue;
      _data.tauxAnnuels.add(TauxAnnuel(
        id: newId(),
        produitId: Produit.idIndividuelle,
        annee: y,
        tauxCommission: 300,
        tauxRendement: y == today.year ? null : const [240, 250, 290, 330, 340, 320, 300][(y - debut.year) % 7],
        commentaire: y == today.year ? 'Taux non encore publié' : 'Données de démonstration',
        updatedAt: now,
      ));
    }
    if (_data.nomUtilisateur.isEmpty) _data.nomUtilisateur = 'Karim';
    await _commit();
  }
}

/// Accès à [AppState] depuis l'arbre de widgets.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
