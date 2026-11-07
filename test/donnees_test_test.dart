import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ma_retraite/models/enums.dart';
import 'package:ma_retraite/state/app_state.dart';
import 'package:ma_retraite/utils/money.dart';

import 'app_state_test.dart' show MemoryStorage;

void main() {
  test('le fichier de données de test est importable et cohérent', () async {
    final raw = File('docs/donnees-test/ma_retraite_test.json').readAsStringSync();
    final s = AppState(storage: MemoryStorage());
    await s.load();
    final resume = s.analyserImport(raw);
    await s.importer(resume, ModeImport.remplacer);
    expect(s.contrats.length, greaterThanOrEqualTo(8));

    for (final c in s.contrats) {
      final ops = s.operations(contratId: c.id);
      // Le capital ne devient jamais négatif au fil du temps.
      for (final p in s.evolutionCapital(contratId: c.id)) {
        expect(p.value, greaterThanOrEqualTo(0), reason: '${c.reference} au ${p.key}');
      }
      final partiels = ops.where((o) =>
          o.type == TypeOperation.rachatPartiel &&
          (o.statut == StatutOperation.executee || o.statut == StatutOperation.enAttente));
      expect(partiels.length, lessThanOrEqualTo(4), reason: c.reference);
      expect(ops.where((o) => o.type.estRachat && o.statut == StatutOperation.enAttente).length, lessThanOrEqualTo(1));
      if (c.estCloture) expect(s.capital(contratId: c.id), 0, reason: c.reference);
      // ignore: avoid_print
      print('${c.reference.padRight(15)} ${c.statut.label.padRight(22)} ${ops.length.toString().padLeft(4)} op. '
          'capital ${Money.format(s.capital(contratId: c.id))}');
    }
  });
}
