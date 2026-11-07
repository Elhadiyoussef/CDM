/// Produit d'assurance retraite (table de référence).
class Produit {
  Produit({
    required this.id,
    required this.code,
    required this.nom,
    this.assureur = '',
    this.multisupport = false,
    this.cotisationMinimale = 20000,
    this.rachatsPartielsMax = 4,
    this.plafondRachatPourcent = 50,
    this.actif = true,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String nom;
  final String assureur;

  /// true = unités de compte (rendement pouvant être négatif).
  final bool multisupport;

  /// Cotisation minimale en centimes.
  final int cotisationMinimale;
  final int rachatsPartielsMax;
  final int plafondRachatPourcent;
  final bool actif;
  final DateTime updatedAt;

  static const idIndividuelle = 'prod-ar-ind';
  static const idMultisupport = 'prod-ar-multi';
  static const idAutre = 'prod-autre';

  /// Référentiel initial (utilisé pour un nouveau fichier et pour migrer un fichier v1).
  static List<Produit> parDefaut() {
    final t = DateTime.utc(2026, 1, 1);
    return [
      Produit(id: idIndividuelle, code: 'AR-IND', nom: "Assur'Retraite individuelle", assureur: 'Sanlam Maroc', updatedAt: t),
      Produit(
          id: idMultisupport,
          code: 'AR-MULTI',
          nom: "Assur'Retraite Multisupport",
          assureur: 'Sanlam Maroc',
          multisupport: true,
          updatedAt: t),
      Produit(id: idAutre, code: 'AUTRE', nom: 'Autre produit retraite', updatedAt: t),
    ];
  }

  Produit copyWith({
    String? code,
    String? nom,
    String? assureur,
    bool? multisupport,
    int? cotisationMinimale,
    int? rachatsPartielsMax,
    int? plafondRachatPourcent,
    bool? actif,
  }) =>
      Produit(
        id: id,
        code: code ?? this.code,
        nom: nom ?? this.nom,
        assureur: assureur ?? this.assureur,
        multisupport: multisupport ?? this.multisupport,
        cotisationMinimale: cotisationMinimale ?? this.cotisationMinimale,
        rachatsPartielsMax: rachatsPartielsMax ?? this.rachatsPartielsMax,
        plafondRachatPourcent: plafondRachatPourcent ?? this.plafondRachatPourcent,
        actif: actif ?? this.actif,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'nom': nom,
        'assureur': assureur,
        'type': multisupport ? 'multisupport' : 'euro',
        'cotisationMinimale': cotisationMinimale,
        'rachatsPartielsMax': rachatsPartielsMax,
        'plafondRachatPourcent': plafondRachatPourcent,
        'actif': actif,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Produit.fromJson(Map<String, dynamic> j) => Produit(
        id: j['id'] as String,
        code: (j['code'] ?? '') as String,
        nom: (j['nom'] ?? '') as String,
        assureur: (j['assureur'] ?? '') as String,
        multisupport: j['type'] == 'multisupport',
        cotisationMinimale: (j['cotisationMinimale'] as num?)?.toInt() ?? 20000,
        rachatsPartielsMax: (j['rachatsPartielsMax'] as num?)?.toInt() ?? 4,
        plafondRachatPourcent: (j['plafondRachatPourcent'] as num?)?.toInt() ?? 50,
        actif: (j['actif'] ?? true) as bool,
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}
