/// Méthode de calcul des intérêts (rendement) dans l'année.
enum MethodeInteret {
  /// Prorata au jour près (jours restants / jours de l'année).
  jours('Prorata au jour'),

  /// Comme un compte sur carnet : par quinzaine (1er et 16 du mois), 24 quinzaines par an.
  quinzaines('Par quinzaine (compte sur carnet)');

  const MethodeInteret(this.label);
  final String label;

  static MethodeInteret fromName(String? n) => values.firstWhere((e) => e.name == n, orElse: () => quinzaines);
}

/// Paramètres de calcul enregistrés dans le fichier JSON.
class ParametresCalcul {
  const ParametresCalcul({
    this.methode = MethodeInteret.quinzaines,
    this.estimerAnneeEnCours = true,
    this.tauxEstimation,
    this.jourRevalorisation = 31,
    this.moisRevalorisation = 12,
  });

  final MethodeInteret methode;

  /// Si le taux de l'année en cours n'est pas publié : l'estimer (sinon l'année reste « à venir »).
  final bool estimerAnneeEnCours;

  /// Taux d'estimation imposé (points de base). null = reprendre le dernier taux connu.
  final int? tauxEstimation;

  /// Date à laquelle l'assureur verse la revalorisation (information affichée).
  final int jourRevalorisation;
  final int moisRevalorisation;

  ParametresCalcul copyWith({
    MethodeInteret? methode,
    bool? estimerAnneeEnCours,
    int? tauxEstimation,
    bool clearTauxEstimation = false,
    int? jourRevalorisation,
    int? moisRevalorisation,
  }) =>
      ParametresCalcul(
        methode: methode ?? this.methode,
        estimerAnneeEnCours: estimerAnneeEnCours ?? this.estimerAnneeEnCours,
        tauxEstimation: clearTauxEstimation ? null : (tauxEstimation ?? this.tauxEstimation),
        jourRevalorisation: jourRevalorisation ?? this.jourRevalorisation,
        moisRevalorisation: moisRevalorisation ?? this.moisRevalorisation,
      );

  Map<String, dynamic> toJson() => {
        'methodeInteret': methode.name,
        'estimerAnneeEnCours': estimerAnneeEnCours,
        'tauxEstimation': tauxEstimation,
        'dateRevalorisation': '${moisRevalorisation.toString().padLeft(2, '0')}-${jourRevalorisation.toString().padLeft(2, '0')}',
      };

  factory ParametresCalcul.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ParametresCalcul();
    final d = ((j['dateRevalorisation'] ?? '12-31') as String).split('-');
    return ParametresCalcul(
      methode: MethodeInteret.fromName(j['methodeInteret'] as String?),
      estimerAnneeEnCours: (j['estimerAnneeEnCours'] ?? true) as bool,
      tauxEstimation: (j['tauxEstimation'] as num?)?.toInt(),
      moisRevalorisation: int.tryParse(d.first) ?? 12,
      jourRevalorisation: int.tryParse(d.length > 1 ? d[1] : '') ?? 31,
    );
  }
}
