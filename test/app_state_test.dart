import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ma_retraite/data/storage.dart';
import 'package:ma_retraite/models/contrat.dart';
import 'package:ma_retraite/models/enums.dart';
import 'package:ma_retraite/models/operation.dart';
import 'package:ma_retraite/state/app_state.dart';
import 'package:ma_retraite/utils/money.dart';

class MemoryStorage implements JsonStorage {
  String? content;
  String? backup;

  @override
  Future<String?> read() async => content;
  @override
  Future<String?> readBackup() async => backup;
  @override
  Future<void> write(String c) async {
    backup = content;
    content = c;
  }

  @override
  Future<String> location() async => 'mémoire';
}

Contrat _contrat(String id) => Contrat(
      id: id,
      reference: 'REF-$id',
      produit: 'Test',
      dateEffet: DateTime(2020, 1, 1),
      cotisation: 150000,
      updatedAt: DateTime.utc(2026),
    );

Operation _op(String contratId, TypeOperation type, int montant,
        {StatutOperation statut = StatutOperation.executee, String? id}) =>
    Operation(
      id: id ?? newId(),
      contratId: contratId,
      type: type,
      montant: montant,
      date: DateTime(2026, 1, 1),
      statut: statut,
      updatedAt: DateTime.now().toUtc(),
    );

void main() {
  group('Money', () {
    test('parse sans virgule flottante', () {
      expect(Money.parse('1 500,50'), 150050);
      expect(Money.parse('1500.5'), 150050);
      expect(Money.parse('200'), 20000);
      expect(Money.parse('0,1'), 10);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('1,234'), isNull);
    });

    test('format', () {
      expect(Money.format(15245050), '152 450,50 DH');
      expect(Money.format(-500, withSign: true), '−5,00 DH');
      expect(Money.percent(890, 10000), '8,9 %');
    });
  });

  group('AppState', () {
    late MemoryStorage storage;
    late AppState s;

    setUp(() async {
      storage = MemoryStorage();
      s = AppState(storage: storage);
      await s.load();
      await s.saveContrat(_contrat('a'));
    });

    test('une opération en attente n’est pas comptée dans le capital', () async {
      await s.addOperation(_op('a', TypeOperation.versement, 100000));
      await s.addOperation(_op('a', TypeOperation.versement, 50000, statut: StatutOperation.enAttente));
      await s.addOperation(_op('a', TypeOperation.cotisation, 150000, statut: StatutOperation.rejetee));
      expect(s.capital(contratId: 'a'), 100000);
      expect(s.montantEnAttente(contratId: 'a'), 50000);
    });

    test('rachat partiel limité à 50 % et à 4 rachats', () async {
      await s.addOperation(_op('a', TypeOperation.versement, 1000000));
      expect(
        s.verifierOperation(contratId: 'a', type: TypeOperation.rachatPartiel, montant: 600000, statut: StatutOperation.executee),
        isNotEmpty,
      );
      for (var i = 0; i < 4; i++) {
        final err = s.verifierOperation(
            contratId: 'a', type: TypeOperation.rachatPartiel, montant: 10000, statut: StatutOperation.executee);
        expect(err, isEmpty);
        await s.addOperation(_op('a', TypeOperation.rachatPartiel, 10000));
      }
      expect(
        s.verifierOperation(contratId: 'a', type: TypeOperation.rachatPartiel, montant: 10000, statut: StatutOperation.executee),
        contains(contains('maximal')),
      );
    });

    test('un rachat total exécuté clôture le contrat et bloque les opérations', () async {
      await s.addOperation(_op('a', TypeOperation.versement, 100000));
      final rachat = _op('a', TypeOperation.rachatTotal, 100000, statut: StatutOperation.enAttente);
      await s.addOperation(rachat);
      expect(s.contrat('a')!.statut, StatutContrat.actif);
      await s.setStatutOperation(rachat.id, StatutOperation.executee);
      expect(s.contrat('a')!.statut, StatutContrat.cloture);
      expect(s.capital(contratId: 'a'), 0);
      expect(
        s.verifierOperation(contratId: 'a', type: TypeOperation.versement, montant: 1000, statut: StatutOperation.executee),
        isNotEmpty,
      );
    });

    test('export puis import (fusion) sur un autre appareil', () async {
      await s.addOperation(_op('a', TypeOperation.versement, 100000, id: 'op1'));
      final exported = s.exporterJson();
      expect(jsonDecode(exported)['app'], 'ma_retraite_cdm');

      final other = AppState(storage: MemoryStorage());
      await other.load();
      await other.saveContrat(_contrat('b'));
      final r1 = await other.importer(other.analyserImport(exported), ModeImport.fusionner);
      expect(r1.ajoutes, 2);
      expect(other.contrats.length, 2);
      expect(other.capital(contratId: 'a'), 100000);

      // Réimporter le même fichier ne crée pas de doublons.
      final r2 = await other.importer(other.analyserImport(exported), ModeImport.fusionner);
      expect(r2.ajoutes, 0);
      expect(other.operations().length, 1);
    });

    test('import en mode remplacer', () async {
      final other = AppState(storage: MemoryStorage());
      await other.load();
      await other.saveContrat(_contrat('b'));
      await other.importer(other.analyserImport(s.exporterJson()), ModeImport.remplacer);
      expect(other.contrats.map((c) => c.id), ['a']);
    });

    test('fichier invalide refusé', () {
      expect(() => s.analyserImport('pas du json'), throwsFormatException);
      expect(() => s.analyserImport('{"app":"autre"}'), throwsFormatException);
      expect(() => s.analyserImport('{"app":"ma_retraite_cdm","schemaVersion":99}'), throwsFormatException);
    });

    test('rechargement depuis le stockage et récupération de la sauvegarde', () async {
      await s.addOperation(_op('a', TypeOperation.versement, 100000));
      final reloaded = AppState(storage: storage);
      await reloaded.load();
      expect(reloaded.capital(), 100000);

      storage.content = '{corrompu';
      final recovered = AppState(storage: storage);
      await recovered.load();
      expect(recovered.loadWarning, isNotNull);
      expect(recovered.contrats, isNotEmpty);
    });

    test('données de démonstration cohérentes', () async {
      final demo = AppState(storage: MemoryStorage());
      await demo.load();
      await demo.chargerDemo();
      expect(demo.capital(), greaterThan(0));
      expect(demo.ecart(), greaterThan(0));
      expect(demo.montantEnAttente(), 500000);
    });
  });
}
