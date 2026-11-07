/// Règles produit paramétrables.
///
/// Valeurs indicatives issues des informations publiques Assur'Retraite :
/// elles doivent être confirmées selon la version exacte du contrat.
class ReglesProduit {
  const ReglesProduit({
    this.cotisationMinimale = 20000, // 200 DH
    this.rachatsPartielsMax = 4,
    this.plafondRachatPourcent = 50,
  });

  final int cotisationMinimale;
  final int rachatsPartielsMax;
  final int plafondRachatPourcent;

  static const standard = ReglesProduit();

  static const produits = <String>[
    "Assur'Retraite individuelle",
    "Assur'Retraite Multisupport",
    'Autre produit retraite',
  ];
}
