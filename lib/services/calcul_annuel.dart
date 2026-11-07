import '../models/contrat.dart';
import '../models/enums.dart';
import '../models/operation.dart';
import '../models/parametres.dart';

/// Taux applicable à un contrat pour une année.
class TauxEffectif {
  const TauxEffectif({this.commission, this.rendement, this.commissionEstimee = false, this.rendementEstime = false, this.source = ''});
  final int? commission; // points de base
  final int? rendement; // points de base
  final bool commissionEstimee;
  final bool rendementEstime;

  /// « contrat », « produit », « estimation » ou combinaison.
  final String source;
}

typedef ResolveurTaux = TauxEffectif Function(Contrat contrat, int annee);

/// Détail d'un calcul d'intérêts (une ligne par mouvement).
class LigneInteret {
  const LigneInteret({
    required this.date,
    required this.libelle,
    required this.base,
    required this.periodes,
    required this.periodesAnnee,
    required this.interets,
    this.commission = 0,
    this.brut = 0,
  });
  final DateTime date;
  final String libelle;

  /// Montant qui porte intérêt (négatif pour un retrait).
  final int base;
  final int periodes;
  final int periodesAnnee;
  final int interets;

  /// Pour un versement : montant brut et commission retenue.
  final int brut;
  final int commission;
}

class RecapAnnee {
  RecapAnnee(this.annee);
  final int annee;
  int capitalDebut = 0;
  int epargneBrute = 0;
  int commission = 0;
  int sorties = 0; // rachats + frais (hors commission)
  int rendement = 0;
  int? tauxCommission;
  int? tauxRendement;
  bool tauxEstime = false;
  bool commissionManquante = false;
  bool rendementManquant = false;
  bool enCours = false;
  bool cloture = false;
  String sourceTaux = '';
  final List<LigneInteret> details = [];

  int get epargneNette => epargneBrute - commission;
  int get capitalFin => capitalDebut + epargneNette - sorties + rendement;

  void ajouter(RecapAnnee o) {
    capitalDebut += o.capitalDebut;
    epargneBrute += o.epargneBrute;
    commission += o.commission;
    sorties += o.sorties;
    rendement += o.rendement;
    tauxEstime |= o.tauxEstime;
    commissionManquante |= o.commissionManquante;
    rendementManquant |= o.rendementManquant;
    enCours |= o.enCours;
    details.addAll(o.details);
  }
}

class Recap {
  Recap(this.annees);
  final List<RecapAnnee> annees;

  int get epargneBrute => annees.fold(0, (s, a) => s + a.epargneBrute);
  int get commission => annees.fold(0, (s, a) => s + a.commission);
  int get epargneNette => epargneBrute - commission;
  int get sorties => annees.fold(0, (s, a) => s + a.sorties);
  int get rendement => annees.fold(0, (s, a) => s + a.rendement);
  int get capitalFin => annees.isEmpty ? 0 : annees.last.capitalFin;

  /// Additionne plusieurs récapitulatifs (tous les contrats) année par année.
  static Recap somme(Iterable<Recap> recaps) {
    final map = <int, RecapAnnee>{};
    for (final r in recaps) {
      for (final a in r.annees) {
        map.putIfAbsent(a.annee, () => RecapAnnee(a.annee)).ajouter(a);
      }
    }
    final years = map.keys.toList()..sort();
    // Le capital de début d'année consolidé = capital de fin de l'année précédente consolidée.
    final out = <RecapAnnee>[];
    var prevFin = 0;
    for (final y in years) {
      final a = map[y]!;
      a.capitalDebut = prevFin;
      out.add(a);
      prevFin = a.capitalFin;
    }
    return Recap(out);
  }
}

/// Moteur de calcul du récapitulatif annuel.
class CalculAnnuel {
  CalculAnnuel(this.parametres, {DateTime? today}) : today = today ?? DateTime.now();
  final ParametresCalcul parametres;
  final DateTime today;

  /// Arrondi d'une division entière au plus proche (moitié vers l'extérieur).
  static int _div(int a, int b) {
    final q = a ~/ b;
    final r = a.remainder(b);
    if (r.abs() * 2 >= b.abs()) return q + (a.sign * b.sign);
    return q;
  }

  static int commissionSur(int montant, int? bp) => bp == null ? 0 : _div(montant * bp, 10000);

  static int _joursAnnee(int y) => DateTime.utc(y + 1, 1, 1).difference(DateTime.utc(y, 1, 1)).inDays;

  /// Index de quinzaine (0..23) d'une date.
  static int _quinzaine(DateTime d) => (d.month - 1) * 2 + (d.day >= 16 ? 1 : 0);

  /// Nombre de périodes rémunérées jusqu'au 31/12 pour un mouvement à la date [d].
  /// Versement : intérêts à partir de la quinzaine suivante (carnet) ou du jour même (prorata).
  /// Retrait : les intérêts s'arrêtent au début de la quinzaine du retrait.
  (int, int) periodesRestantes(DateTime d, {required bool retrait}) {
    final y = d.year;
    if (parametres.methode == MethodeInteret.quinzaines) {
      final q = _quinzaine(d);
      return (retrait ? 24 - q : 23 - q, 24);
    }
    final n = _joursAnnee(y);
    final restant = DateTime.utc(y + 1, 1, 1).difference(DateTime.utc(y, d.month, d.day)).inDays;
    return (restant, n);
  }

  int _interets(int base, int bp, int periodes, int parAn) => _div(base * bp * periodes, 10000 * parAn);

  /// Récapitulatif « selon la table des taux » : recalcule commissions et rendements.
  Recap selonTaux(Contrat contrat, List<Operation> operations, ResolveurTaux taux) {
    final ops = operations
        .where((o) => o.contratId == contrat.id && o.estExecutee && !o.type.estCalculable)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final debut = ops.isEmpty
        ? contrat.dateEffet.year
        : (ops.first.date.year < contrat.dateEffet.year ? ops.first.date.year : contrat.dateEffet.year);
    final fin = today.year;
    if (debut > fin) return Recap([]);

    final annees = <RecapAnnee>[];
    var capital = 0;
    for (var y = debut; y <= fin; y++) {
      final r = RecapAnnee(y)..capitalDebut = capital;
      final t = taux(contrat, y);
      r.enCours = y == today.year;
      r.tauxCommission = t.commission;
      r.tauxRendement = t.rendement;
      r.tauxEstime = t.commissionEstimee || t.rendementEstime;
      r.sourceTaux = t.source;
      final rateR = t.rendement ?? 0;
      r.commissionManquante = t.commission == null;
      r.rendementManquant = t.rendement == null;

      if (capital != 0) {
        final parAn = parametres.methode == MethodeInteret.quinzaines ? 24 : _joursAnnee(y);
        final i = _interets(capital, rateR, parAn, parAn);
        r.details.add(LigneInteret(
            date: DateTime(y, 1, 1),
            libelle: 'Capital au 1er janvier',
            base: capital,
            periodes: parAn,
            periodesAnnee: parAn,
            interets: i));
      }

      var flux = capital; // capital « déposé » à date, hors intérêts de l'année
      for (final o in ops.where((o) => o.date.year == y)) {
        if (o.type.estApport) {
          final c = commissionSur(o.montant, t.commission);
          final net = o.montant - c;
          r.epargneBrute += o.montant;
          r.commission += c;
          flux += net;
          final (p, n) = periodesRestantes(o.date, retrait: false);
          r.details.add(LigneInteret(
              date: o.date,
              libelle: o.libelle.isEmpty ? o.type.label : o.libelle,
              base: net,
              brut: o.montant,
              commission: c,
              periodes: p,
              periodesAnnee: n,
              interets: _interets(net, rateR, p, n)));
        } else if (o.type == TypeOperation.rachatTotal) {
          // Retrait de tout le capital déposé ; les intérêts acquis jusqu'à cette date sont aussi versés.
          final (p, n) = periodesRestantes(o.date, retrait: true);
          r.details.add(LigneInteret(
              date: o.date,
              libelle: o.libelle.isEmpty ? o.type.label : o.libelle,
              base: -flux,
              periodes: p,
              periodesAnnee: n,
              interets: _interets(-flux, rateR, p, n)));
          final acquis = r.details.fold<int>(0, (s, l) => s + l.interets);
          r.sorties += flux + acquis;
          flux = 0;
          r.cloture = true;
        } else {
          // rachat partiel ou frais
          r.sorties += o.montant;
          flux -= o.montant;
          final (p, n) = periodesRestantes(o.date, retrait: true);
          r.details.add(LigneInteret(
              date: o.date,
              libelle: o.libelle.isEmpty ? o.type.label : o.libelle,
              base: -o.montant,
              periodes: p,
              periodesAnnee: n,
              interets: _interets(-o.montant, rateR, p, n)));
        }
      }
      r.rendement = r.details.fold(0, (s, l) => s + l.interets);
      if (r.enCours && t.rendement == null) r.rendement = 0;
      annees.add(r);
      capital = r.capitalFin;
      if (r.cloture) break;
    }
    return Recap(annees);
  }

  /// Récapitulatif « selon les opérations saisies » (commissions et revalorisations réellement enregistrées).
  Recap selonOperations(Contrat contrat, List<Operation> operations) {
    final ops = operations.where((o) => o.contratId == contrat.id && o.estExecutee).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (ops.isEmpty) return Recap([]);
    final annees = <RecapAnnee>[];
    var capital = 0;
    for (var y = ops.first.date.year; y <= today.year; y++) {
      final r = RecapAnnee(y)
        ..capitalDebut = capital
        ..enCours = y == today.year;
      for (final o in ops.where((o) => o.date.year == y)) {
        switch (o.type) {
          case TypeOperation.cotisation:
          case TypeOperation.versement:
            r.epargneBrute += o.montant;
          case TypeOperation.commission:
            r.commission += o.montant;
          case TypeOperation.revalorisation:
            r.rendement += o.montant;
          case TypeOperation.rachatTotal:
            r.sorties += o.montant;
            r.cloture = true;
          case TypeOperation.rachatPartiel:
          case TypeOperation.frais:
            r.sorties += o.montant;
        }
      }
      annees.add(r);
      capital = r.capitalFin;
      if (r.cloture) break;
    }
    return Recap(annees);
  }
}
