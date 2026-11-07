import 'package:intl/intl.dart';

class Dates {
  Dates._();

  static final _day = DateFormat('d MMM yyyy', 'fr_FR');
  static final _long = DateFormat('d MMMM yyyy', 'fr_FR');
  static final _month = DateFormat('MMM yy', 'fr_FR');
  static final _dateTime = DateFormat("d MMM yyyy 'à' HH:mm", 'fr_FR');

  static String day(DateTime d) => _day.format(d);
  static String long(DateTime d) => _long.format(d);
  static String month(DateTime d) => _month.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d.toLocal());

  /// Date sans heure (stockée en ISO "yyyy-MM-dd").
  static String toIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime fromIsoDate(String s) {
    final d = DateTime.parse(s);
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Ajoute [months] mois en restant sur un jour valide (31 janv. + 1 mois = 28/29 févr.).
  static DateTime addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
  }
}
