import '../utils/dates.dart';
import 'enums.dart';

class Beneficiaire {
  Beneficiaire({
    required this.id,
    required this.nom,
    this.lien = '',
    required this.quotePart,
  });

  final String id;
  final String nom;
  final String lien;

  /// Quote-part en pourcentage entier (0–100).
  final int quotePart;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'lien': lien,
        'quotePart': quotePart,
      };

  factory Beneficiaire.fromJson(Map<String, dynamic> j) => Beneficiaire(
        id: j['id'] as String,
        nom: (j['nom'] ?? '') as String,
        lien: (j['lien'] ?? '') as String,
        quotePart: (j['quotePart'] as num?)?.toInt() ?? 0,
      );
}

class Contrat {
  Contrat({
    required this.id,
    required this.reference,
    required this.produitId,
    required this.dateEffet,
    this.dateEcheance,
    required this.cotisation,
    this.periodicite = Periodicite.mensuelle,
    this.objectif = 0,
    this.statut = StatutContrat.actif,
    this.beneficiaires = const [],
    required this.updatedAt,
  });

  final String id;
  final String reference;
  /// Référence vers la table des produits.
  final String produitId;
  final DateTime dateEffet;
  final DateTime? dateEcheance;

  /// Cotisation périodique en centimes.
  final int cotisation;
  final Periodicite periodicite;

  /// Objectif d'épargne en centimes (0 = non défini).
  final int objectif;
  final StatutContrat statut;
  final List<Beneficiaire> beneficiaires;
  final DateTime updatedAt;

  bool get estCloture => statut == StatutContrat.cloture;

  /// Prochaine échéance de cotisation à partir d'aujourd'hui.
  DateTime? get prochaineCotisation {
    if (statut != StatutContrat.actif || cotisation <= 0) return null;
    final today = Dates.today();
    var d = dateEffet;
    var i = 0;
    while (d.isBefore(today)) {
      i++;
      d = Dates.addMonths(dateEffet, i * periodicite.mois);
    }
    if (dateEcheance != null && d.isAfter(dateEcheance!)) return null;
    return d;
  }

  Contrat copyWith({
    String? reference,
    String? produitId,
    DateTime? dateEffet,
    DateTime? dateEcheance,
    bool clearEcheance = false,
    int? cotisation,
    Periodicite? periodicite,
    int? objectif,
    StatutContrat? statut,
    List<Beneficiaire>? beneficiaires,
  }) =>
      Contrat(
        id: id,
        reference: reference ?? this.reference,
        produitId: produitId ?? this.produitId,
        dateEffet: dateEffet ?? this.dateEffet,
        dateEcheance: clearEcheance ? null : (dateEcheance ?? this.dateEcheance),
        cotisation: cotisation ?? this.cotisation,
        periodicite: periodicite ?? this.periodicite,
        objectif: objectif ?? this.objectif,
        statut: statut ?? this.statut,
        beneficiaires: beneficiaires ?? this.beneficiaires,
        updatedAt: DateTime.now().toUtc(),
      );

  /// Migration : change le produit sans modifier la date de mise à jour.
  Contrat migrerProduit(String id) => Contrat(
        id: this.id,
        reference: reference,
        produitId: id,
        dateEffet: dateEffet,
        dateEcheance: dateEcheance,
        cotisation: cotisation,
        periodicite: periodicite,
        objectif: objectif,
        statut: statut,
        beneficiaires: beneficiaires,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'produitId': produitId,
        'dateEffet': Dates.toIsoDate(dateEffet),
        'dateEcheance': dateEcheance == null ? null : Dates.toIsoDate(dateEcheance!),
        'cotisation': cotisation,
        'periodicite': periodicite.name,
        'objectif': objectif,
        'statut': statut.name,
        'beneficiaires': beneficiaires.map((b) => b.toJson()).toList(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Contrat.fromJson(Map<String, dynamic> j) => Contrat(
        id: j['id'] as String,
        reference: (j['reference'] ?? '') as String,
        // En v1, seul le nom du produit existait : la migration le convertit (voir AppData).
        produitId: (j['produitId'] ?? j['produit'] ?? '') as String,
        dateEffet: Dates.fromIsoDate(j['dateEffet'] as String),
        dateEcheance:
            j['dateEcheance'] == null ? null : Dates.fromIsoDate(j['dateEcheance'] as String),
        cotisation: (j['cotisation'] as num?)?.toInt() ?? 0,
        periodicite: Periodicite.fromName(j['periodicite'] as String?),
        objectif: (j['objectif'] as num?)?.toInt() ?? 0,
        statut: StatutContrat.fromName(j['statut'] as String?),
        beneficiaires: ((j['beneficiaires'] as List?) ?? [])
            .map((e) => Beneficiaire.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}
