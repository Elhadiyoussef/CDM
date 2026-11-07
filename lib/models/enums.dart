enum Periodicite {
  mensuelle('Mensuelle', 1),
  trimestrielle('Trimestrielle', 3),
  semestrielle('Semestrielle', 6),
  annuelle('Annuelle', 12);

  const Periodicite(this.label, this.mois);
  final String label;
  final int mois;

  static Periodicite fromName(String? n) =>
      values.firstWhere((e) => e.name == n, orElse: () => mensuelle);
}

enum StatutContrat {
  actif('Actif'),
  suspendu('Cotisations suspendues'),
  cloture('Clôturé');

  const StatutContrat(this.label);
  final String label;

  static StatutContrat fromName(String? n) =>
      values.firstWhere((e) => e.name == n, orElse: () => actif);
}

enum TypeOperation {
  cotisation('Cotisation', true),
  versement('Versement libre', true),
  revalorisation('Revalorisation', true),
  frais('Frais', false),
  commission('Commission', false),
  rachatPartiel('Rachat partiel', false),
  rachatTotal('Rachat total', false);

  const TypeOperation(this.label, this.credit);
  final String label;

  /// true si l'opération augmente le capital.
  final bool credit;

  /// Opérations calculées depuis la table des taux (ignorées par le moteur de recalcul).
  bool get estCalculable => this == revalorisation || this == commission;

  bool get estRachat => this == rachatPartiel || this == rachatTotal;

  /// Compte dans le « total versé » par le client.
  bool get estApport => this == cotisation || this == versement;

  static TypeOperation fromName(String? n) =>
      values.firstWhere((e) => e.name == n, orElse: () => versement);
}

/// Une opération initiée n'est jamais comptée comme réalisée avant exécution.
enum StatutOperation {
  enAttente('En attente'),
  executee('Exécutée'),
  rejetee('Rejetée'),
  annulee('Annulée');

  const StatutOperation(this.label);
  final String label;

  static StatutOperation fromName(String? n) =>
      values.firstWhere((e) => e.name == n, orElse: () => enAttente);
}

/// Provenance d'une opération.
enum OrigineOperation {
  manuelle('Saisie manuelle'),
  saisieMasse('Saisie de masse'),
  importCsv('Import CSV'),
  calculAnnuel('Calcul annuel');

  const OrigineOperation(this.label);
  final String label;

  static OrigineOperation fromName(String? n) =>
      values.firstWhere((e) => e.name == n, orElse: () => manuelle);
}
