/// Montants manipulés en centimes entiers (jamais en virgule flottante).
///
/// 152 450,50 DH  <=>  15245050
class Money {
  Money._();

  static const String devise = 'DH';

  /// Formate des centimes : 15245050 -> "152 450,50 DH".
  static String format(int cents, {bool withSign = false, bool decimals = true}) {
    final negative = cents < 0;
    final abs = cents.abs();
    final units = abs ~/ 100;
    final rest = abs % 100;
    final grouped = _group(units.toString());
    final body = decimals ? '$grouped,${rest.toString().padLeft(2, '0')}' : grouped;
    final sign = negative ? '−' : (withSign && cents > 0 ? '+' : '');
    return '$sign$body $devise';
  }

  /// Formate sans décimales (pour les gros chiffres d'en-tête).
  static String compact(int cents, {bool withSign = false}) {
    // Arrondi au dirham le plus proche.
    final rounded = ((cents.abs() + 50) ~/ 100) * 100 * (cents < 0 ? -1 : 1);
    return format(rounded, withSign: withSign, decimals: false);
  }

  /// Convertit une saisie utilisateur ("1 500,50", "1500.5", "1500") en centimes.
  /// Retourne null si la saisie est invalide.
  static int? parse(String input) {
    var s = input.trim().replaceAll(RegExp(r'[\s  ]'), '');
    s = s.replaceAll(RegExp(r'(DH|MAD)$', caseSensitive: false), '');
    if (s.isEmpty) return null;
    s = s.replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$').firstMatch(s);
    if (match == null) return null;
    final units = int.parse(match.group(1)!);
    final dec = (match.group(2) ?? '').padRight(2, '0');
    return units * 100 + int.parse(dec);
  }

  /// Représentation éditable : 150050 -> "1500,50" ; 150000 -> "1500".
  static String toInput(int cents) {
    final units = cents ~/ 100;
    final rest = cents % 100;
    return rest == 0 ? '$units' : '$units,${rest.toString().padLeft(2, '0')}';
  }

  /// Pourcentage à une décimale : percent(890, 10000) -> "8,9 %".
  static String percent(int numerator, int denominator, {bool withSign = false}) {
    if (denominator == 0) return '—';
    final tenths = (numerator * 1000 / denominator).round();
    final sign = tenths < 0 ? '−' : (withSign && tenths > 0 ? '+' : '');
    final a = tenths.abs();
    return '$sign${a ~/ 10},${a % 10} %';
  }

  static String _group(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}
