import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ma_retraite/models/app_data.dart';
import 'package:ma_retraite/models/contrat.dart';
import 'package:ma_retraite/models/enums.dart';
import 'package:ma_retraite/models/operation.dart';
import 'package:ma_retraite/models/parametres.dart';
import 'package:ma_retraite/models/produit.dart';
import 'package:ma_retraite/models/taux_annuel.dart';
import 'package:ma_retraite/services/calcul_annuel.dart';
import 'package:ma_retraite/state/app_state.dart';
import 'package:ma_retraite/utils/money.dart';
import 'package:ma_retraite/utils/tableur.dart';

import 'app_state_test.dart' show MemoryStorage;

Contrat _c({String id = 'c1', String produitId = Produit.idIndividuelle}) => Contrat(
      id: id,
      reference: 'REF',
      produitId: produitId,
      dateEffet: DateTime(2025, 1, 1),
      cotisation: 150000,
      updatedAt: DateTime.utc(2026),
    );

Operation _op(TypeOperation t, int montant, DateTime d, {String contratId = 'c1'}) => Operation(
      id: newId(),
      contratId: contratId,
      type: t,
      montant: montant,
      date: d,
      updatedAt: DateTime.utc(2026),
    );

TauxEffectif Function(Contrat, int) _fixe(int? com, int? ren) => (c, y) => TauxEffectif(commission: com, rendement: ren);

void main() {
  group('Taux et tableur', () {
    test('parse et format des taux en points de base', () {
      expect(Taux.parse('3,2'), 320);
      expect(Taux.parse('3.20 %'), 320);
      expect(Taux.parse('-4,5'), -450);
      expect(Taux.parse(''), isNull);
      expect(() => Taux.parse('abc'), throwsFormatException);
      expect(Taux.format(320), '3,20 %');
      expect(Taux.format(-650), '−6,50 %');
    });

    test('lecture d’un copier-coller Excel et d’un CSV', () {
      final xl = Tableur.lignes('Date\tMontant\n05/01/2025\t1 500,00\n05/02/2025\t1500\n');
      expect(xl.length, 3);
      expect(xl[1], ['05/01/2025', '1 500,00']);
      final csv = Tableur.lignes('2025-03-05;1500;rejetée;cotisation');
      expect(Tableur.date(csv[0][0]), DateTime(2025, 3, 5));
      expect(Tableur.statut(csv[0][2]), StatutOperation.rejetee);
      expect(Tableur.type('Versement libre'), TypeOperation.versement);
      expect(Tableur.date('31/02/2025'), isNull);
    });

    test('fichiers CSV d’exemple', () {
      final cot = Tableur.lignes(File('docs/donnees-test/cotisations_exemple.csv').readAsStringSync());
      final lignes = cot.skip(1).toList();
      expect(lignes.length, 14);
      expect(lignes.every((r) => Tableur.date(r[0]) != null && Money.parse(r[1]) != null), isTrue);
      expect(Tableur.statut(lignes[2][2]), StatutOperation.rejetee);
      expect(Tableur.statut(lignes.last[2]), StatutOperation.enAttente);
      final taux = Tableur.lignes(File('docs/donnees-test/taux_exemple.csv').readAsStringSync());
      expect(Taux.parse(taux[1][2]), 240);
      expect(Taux.parse(taux.last[2]), isNull);
    });
  });

  group('Calcul annuel', () {
    final today = DateTime(2026, 6, 1);

    test('commission sur chaque versement, épargne nette', () {
      final m = CalculAnnuel(const ParametresCalcul(methode: MethodeInteret.quinzaines), today: today);
      final ops = [
        _op(TypeOperation.cotisation, 150000, DateTime(2025, 1, 5)),
        _op(TypeOperation.versement, 1000000, DateTime(2025, 6, 20)),
      ];
      final r = m.selonTaux(_c(), ops, _fixe(300, 0));
      final a = r.annees.first;
      expect(a.epargneBrute, 1150000);
      expect(a.commission, 4500 + 30000);
      expect(a.epargneNette, 1150000 - 34500);
      expect(a.rendement, 0);
    });

    test('quinzaines : versement le 1er janvier = 23 quinzaines, le 16 décembre = 0', () {
      final m = CalculAnnuel(const ParametresCalcul(methode: MethodeInteret.quinzaines), today: today);
      final ops = [
        _op(TypeOperation.versement, 2400000, DateTime(2025, 1, 1)),
        _op(TypeOperation.versement, 1000000, DateTime(2025, 12, 16)),
      ];
      final a = m.selonTaux(_c(), ops, _fixe(0, 300)).annees.first;
      // 24 000 DH × 3 % × 23/24 = 690 DH ; dernier versement : 0
      expect(a.details[0].periodes, 23);
      expect(a.details[0].interets, 69000);
      expect(a.details[1].periodes, 0);
      expect(a.rendement, 69000);
      // Année suivante : capital complet sur 24 quinzaines.
      final b = m.selonTaux(_c(), ops, _fixe(0, 300)).annees[1];
      expect(b.capitalDebut, 3400000 + 69000);
      expect(b.rendement, (3469000 * 300 / 10000).round());
    });

    test('prorata au jour : 1er janvier = année pleine', () {
      final m = CalculAnnuel(const ParametresCalcul(methode: MethodeInteret.jours), today: today);
      final ops = [_op(TypeOperation.versement, 1000000, DateTime(2025, 1, 1))];
      final a = m.selonTaux(_c(), ops, _fixe(0, 365)).annees.first;
      expect(a.details.first.periodes, 365);
      expect(a.rendement, 36500);
    });

    test('exemple du document : 1 500 DH/mois, 3 % de commission, 3,2 %', () {
      final m = CalculAnnuel(const ParametresCalcul(methode: MethodeInteret.jours), today: today);
      final ops = [
        _op(TypeOperation.versement, 10000000, DateTime(2024, 1, 1)),
        for (var mo = 1; mo <= 12; mo++) _op(TypeOperation.cotisation, 150000, DateTime(2025, mo, 5)),
      ];
      // 2024 : 100 000 DH sans commission ni rendement pour isoler 2025
      final r = m.selonTaux(_c(), ops, (c, y) => y == 2024 ? const TauxEffectif(commission: 0, rendement: 0) : const TauxEffectif(commission: 300, rendement: 320));
      final a = r.annees.firstWhere((a) => a.annee == 2025);
      expect(a.capitalDebut, 10000000);
      expect(a.epargneBrute, 1800000);
      expect(a.commission, 54000);
      expect(a.epargneNette, 1746000);
      expect(a.details.first.interets, 320000);
      expect(a.rendement, 320000 + 29773); // 3 200 DH + 297,73 DH au prorata
    });

    test('rendement négatif (multisupport) et taux manquant', () {
      final m = CalculAnnuel(const ParametresCalcul(), today: today);
      final ops = [_op(TypeOperation.versement, 1000000, DateTime(2024, 1, 1))];
      final r = m.selonTaux(_c(), ops, (c, y) => TauxEffectif(commission: 0, rendement: y == 2024 ? -650 : null));
      expect(r.annees[0].rendement, lessThan(0));
      expect(r.annees[1].rendementManquant, isTrue);
      expect(r.annees[1].rendement, 0);
    });

    test('rachat total : capital à zéro et arrêt du calcul', () {
      final m = CalculAnnuel(const ParametresCalcul(), today: today);
      final ops = [
        _op(TypeOperation.versement, 1000000, DateTime(2024, 1, 1)),
        _op(TypeOperation.rachatTotal, 1000000, DateTime(2025, 7, 1)),
      ];
      final r = m.selonTaux(_c(), ops, _fixe(0, 300));
      expect(r.annees.length, 2);
      expect(r.annees.last.cloture, isTrue);
      expect(r.annees.last.capitalFin, 0);
      expect(r.annees.last.rendement, greaterThan(0));
    });

    test('la somme des années est égale aux totaux', () {
      final m = CalculAnnuel(const ParametresCalcul(), today: today);
      final ops = [
        for (var y = 2020; y <= 2026; y++)
          for (var mo = 1; mo <= 12; mo += 3) _op(TypeOperation.cotisation, 300000, DateTime(y, mo, 10)),
        _op(TypeOperation.rachatPartiel, 200000, DateTime(2023, 8, 2)),
      ];
      final c = Contrat(id: 'c1', reference: 'R', produitId: 'p', dateEffet: DateTime(2020, 1, 10), cotisation: 300000, updatedAt: DateTime.utc(2026));
      final r = m.selonTaux(c, ops, _fixe(250, 310));
      expect(r.capitalFin, r.epargneNette - r.sorties + r.rendement);
    });
  });

  group('AppState v2', () {
    late AppState s;
    setUp(() async {
      s = AppState(storage: MemoryStorage(), today: DateTime(2026, 6, 1));
      await s.load();
      await s.saveContrat(_c());
    });

    test('taux du contrat prioritaire sur le produit, estimation de l’année en cours', () async {
      await s.saveTaux(produitId: Produit.idIndividuelle, lignes: [
        TauxAnnuel(id: 'a', produitId: Produit.idIndividuelle, annee: 2025, tauxCommission: 300, tauxRendement: 320, updatedAt: DateTime.utc(2026)),
      ]);
      await s.saveTaux(contratId: 'c1', lignes: [
        TauxAnnuel(id: 'b', contratId: 'c1', annee: 2025, tauxCommission: 150, updatedAt: DateTime.utc(2026)),
      ]);
      final c = s.contrat('c1')!;
      final t25 = s.tauxEffectif(c, 2025);
      expect(t25.commission, 150); // contrat
      expect(t25.rendement, 320); // produit
      final t26 = s.tauxEffectif(c, 2026);
      expect(t26.rendement, 320);
      expect(t26.rendementEstime, isTrue);

      await s.setParametres(s.parametres.copyWith(tauxEstimation: 250));
      expect(s.tauxEffectif(c, 2026).rendement, 250);
      await s.setParametres(s.parametres.copyWith(estimerAnneeEnCours: false));
      expect(s.tauxEffectif(c, 2026).rendement, isNull);
    });

    test('saisie de masse en lot, puis annulation du lot', () async {
      final lot = await s.enregistrerLot([
        for (var mo = 1; mo <= 12; mo++)
          Operation(
              id: '',
              contratId: 'c1',
              type: TypeOperation.cotisation,
              montant: 150000,
              date: DateTime(2025, mo, 5),
              origine: OrigineOperation.saisieMasse,
              updatedAt: DateTime.utc(2026)),
      ]);
      expect(s.operations(contratId: 'c1').length, 12);
      expect(s.existeOperation('c1', DateTime(2025, 3, 5), TypeOperation.cotisation), isTrue);
      expect(s.lots('c1').single.nb, 12);
      expect(await s.annulerLot(lot), 12);
      expect(s.operations(contratId: 'c1'), isEmpty);
    });

    test('génération des opérations de commission et de rendement', () async {
      await s.saveTaux(produitId: Produit.idIndividuelle, lignes: [
        TauxAnnuel(id: 'a', produitId: Produit.idIndividuelle, annee: 2025, tauxCommission: 300, tauxRendement: 300, updatedAt: DateTime.utc(2026)),
      ]);
      await s.addOperation(_op(TypeOperation.versement, 1000000, DateTime(2025, 1, 1)));
      final r = await s.genererOperationsAnnuelles('c1');
      expect(r.traitees, 1);
      final recapOps = s.recap(contratId: 'c1', selonTaux: false).annees.first;
      final recapTaux = s.recap(contratId: 'c1').annees.first;
      expect(recapOps.commission, recapTaux.commission);
      expect(recapOps.rendement, recapTaux.rendement);
      // Relancer ne duplique pas.
      await s.genererOperationsAnnuelles('c1');
      expect(s.operations(contratId: 'c1').where((o) => o.origine == OrigineOperation.calculAnnuel).length, 2);
    });

    test('migration d’un fichier v1 et fusion des taux', () async {
      final v1 = jsonEncode({
        'app': 'ma_retraite_cdm',
        'schemaVersion': 1,
        'contrats': [
          {'id': 'x', 'reference': 'R1', 'produit': "Assur'Retraite Multisupport", 'dateEffet': '2020-01-01', 'cotisation': 100, 'updatedAt': '2020-01-01T00:00:00Z'},
          {'id': 'y', 'reference': 'R2', 'produit': 'Inconnu', 'dateEffet': '2020-01-01', 'cotisation': 100, 'updatedAt': '2020-01-01T00:00:00Z'},
        ],
        'operations': [],
      });
      final data = s.analyserImport(v1).data;
      expect(data.contrats[0].produitId, Produit.idMultisupport);
      expect(data.contrats[1].produitId, Produit.idAutre);
      expect(data.contrats[0].updatedAt, DateTime.utc(2020));
      expect(AppData.schemaVersion, 2);

      // Deux appareils saisissent le taux 2025 du même produit : la ligne la plus récente gagne, sans doublon.
      await s.saveTaux(produitId: Produit.idIndividuelle, lignes: [
        TauxAnnuel(id: 'local', produitId: Produit.idIndividuelle, annee: 2025, tauxRendement: 300, updatedAt: DateTime.utc(2026, 1, 1)),
      ]);
      final autre = AppData(tauxAnnuels: [
        TauxAnnuel(id: 'distant', produitId: Produit.idIndividuelle, annee: 2025, tauxRendement: 320, updatedAt: DateTime.utc(2026, 2, 1)),
      ]);
      await s.importer(s.analyserImport(jsonEncode(autre.toJson())), ModeImport.fusionner);
      final t = s.tauxDe(produitId: Produit.idIndividuelle);
      expect(t.length, 1);
      expect(t.single.tauxRendement, 320);
    });
  });
}
