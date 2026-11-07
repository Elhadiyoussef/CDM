import '../models/enums.dart';

/// Lecture de données tabulaires collées depuis Excel / LibreOffice ou d'un fichier CSV.
class Tableur {
  Tableur._();

  /// Découpe un texte en lignes et cellules. Séparateur détecté : tabulation (copier-coller Excel),
  /// point-virgule (CSV français) ou virgule.
  static List<List<String>> lignes(String texte) {
    final rows = texte
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (rows.isEmpty) return [];
    final sample = rows.take(5).join('\n');
    final sep = sample.contains('\t') ? '\t' : (sample.contains(';') ? ';' : ',');
    return [
      for (final r in rows) [for (final c in r.split(sep)) c.trim().replaceAll(RegExp(r'^"|"$'), '')],
    ];
  }

  /// Date "05/01/2025", "5/1/2025", "2025-01-05" ou "05-01-2025".
  static DateTime? date(String s) {
    s = s.trim();
    var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    if (m != null) return _valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})$').firstMatch(s);
    if (m != null) {
      var y = int.parse(m[3]!);
      if (y < 100) y += 2000;
      return _valid(y, int.parse(m[2]!), int.parse(m[1]!));
    }
    return null;
  }

  static DateTime? _valid(int y, int mo, int d) {
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, mo, d);
    return dt.month == mo ? dt : null;
  }

  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static StatutOperation? statut(String s) {
    final v = _norm(s);
    if (v.isEmpty) return null;
    if (v.startsWith('exec') || v == 'ok' || v.startsWith('pay') || v.startsWith('valid')) return StatutOperation.executee;
    if (v.contains('attente') || v.startsWith('pend')) return StatutOperation.enAttente;
    if (v.startsWith('rej') || v.startsWith('impa')) return StatutOperation.rejetee;
    if (v.startsWith('annul')) return StatutOperation.annulee;
    return null;
  }

  static TypeOperation? type(String s) {
    final v = _norm(s);
    if (v.isEmpty) return null;
    if (v.startsWith('cotis') || v.startsWith('prel')) return TypeOperation.cotisation;
    if (v.startsWith('vers') || v.contains('libre')) return TypeOperation.versement;
    return null;
  }

  static String _norm(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâ]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u');

  /// Échappe une cellule pour un export CSV (séparateur « ; »).
  static String cellule(Object? v) {
    final s = '${v ?? ''}';
    return s.contains(';') || s.contains('"') || s.contains('\n') ? '"${s.replaceAll('"', '""')}"' : s;
  }
}
