/// Taux d'une année pour un produit, ou pour un contrat précis (qui remplace alors le taux du produit).
///
/// Les taux sont en points de base (entiers) : 300 = 3,00 %.
class TauxAnnuel {
  TauxAnnuel({
    required this.id,
    this.produitId,
    this.contratId,
    required this.annee,
    this.tauxCommission,
    this.tauxRendement,
    this.commentaire = '',
    required this.updatedAt,
  }) : assert(produitId != null || contratId != null);

  final String id;
  final String? produitId;
  final String? contratId;
  final int annee;

  /// Commission prélevée sur chaque versement (null = non renseigné).
  final int? tauxCommission;

  /// Taux de rendement servi par l'assureur (null = non renseigné ; peut être négatif en multisupport).
  final int? tauxRendement;
  final String commentaire;
  final DateTime updatedAt;

  /// Clé fonctionnelle : une seule ligne par cible et par année.
  String get cle => '${contratId != null ? 'c:$contratId' : 'p:$produitId'}:$annee';

  TauxAnnuel copyWith({int? tauxCommission, int? tauxRendement, String? commentaire, bool clearCommission = false, bool clearRendement = false}) =>
      TauxAnnuel(
        id: id,
        produitId: produitId,
        contratId: contratId,
        annee: annee,
        tauxCommission: clearCommission ? null : (tauxCommission ?? this.tauxCommission),
        tauxRendement: clearRendement ? null : (tauxRendement ?? this.tauxRendement),
        commentaire: commentaire ?? this.commentaire,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (produitId != null) 'produitId': produitId,
        if (contratId != null) 'contratId': contratId,
        'annee': annee,
        'tauxCommission': tauxCommission,
        'tauxRendement': tauxRendement,
        'commentaire': commentaire,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory TauxAnnuel.fromJson(Map<String, dynamic> j) => TauxAnnuel(
        id: j['id'] as String,
        produitId: j['produitId'] as String?,
        contratId: j['contratId'] as String?,
        annee: (j['annee'] as num).toInt(),
        tauxCommission: (j['tauxCommission'] as num?)?.toInt(),
        tauxRendement: (j['tauxRendement'] as num?)?.toInt(),
        commentaire: (j['commentaire'] ?? '') as String,
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// Formatage et saisie des taux en points de base.
class Taux {
  Taux._();

  /// 320 -> "3,20 %"
  static String format(int? bp) {
    if (bp == null) return '—';
    final neg = bp < 0;
    final a = bp.abs();
    return '${neg ? '−' : ''}${a ~/ 100},${(a % 100).toString().padLeft(2, '0')} %';
  }

  /// 320 -> "3,20" (pour un champ de saisie)
  static String toInput(int? bp) {
    if (bp == null) return '';
    final neg = bp < 0;
    final a = bp.abs();
    return '${neg ? '-' : ''}${a ~/ 100},${(a % 100).toString().padLeft(2, '0')}';
  }

  /// "3,2" / "3.20" / "-4,5 %" -> points de base ; null si vide ; lève FormatException si invalide.
  static int? parse(String input) {
    var s = input.trim().replaceAll('%', '').replaceAll(' ', '').replaceAll(',', '.');
    if (s.isEmpty) return null;
    final m = RegExp(r'^([-+−]?)(\d+)(?:\.(\d{0,2}))?$').firstMatch(s);
    if (m == null) throw const FormatException('Taux invalide (ex. 3,20)');
    final v = int.parse(m.group(2)!) * 100 + int.parse((m.group(3) ?? '').padRight(2, '0'));
    return (m.group(1) == '-' || m.group(1) == '−') ? -v : v;
  }
}
