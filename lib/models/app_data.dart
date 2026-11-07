import 'contrat.dart';
import 'operation.dart';
import 'parametres.dart';
import 'produit.dart';
import 'taux_annuel.dart';

/// Racine du fichier JSON stocké sur l'appareil et échangé par export/import.
class AppData {
  AppData({
    this.nomUtilisateur = '',
    this.themeMode = 'system',
    List<Produit>? produits,
    List<TauxAnnuel>? tauxAnnuels,
    this.parametres = const ParametresCalcul(),
    List<Contrat>? contrats,
    List<Operation>? operations,
    DateTime? updatedAt,
  })  : produits = produits ?? Produit.parDefaut(),
        tauxAnnuels = tauxAnnuels ?? [],
        contrats = contrats ?? [],
        operations = operations ?? [],
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  /// Identifiant du format, vérifié à l'import.
  static const String appId = 'ma_retraite_cdm';

  /// v1 : contrats + opérations.
  /// v2 : + produits, tauxAnnuels, parametres ; contrat.produitId ; opération.origine / lotId.
  static const int schemaVersion = 2;

  String nomUtilisateur;
  String themeMode; // system | light | dark
  List<Produit> produits;
  List<TauxAnnuel> tauxAnnuels;
  ParametresCalcul parametres;
  List<Contrat> contrats;
  List<Operation> operations;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'app': appId,
        'schemaVersion': schemaVersion,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'profil': {
          'nom': nomUtilisateur,
          'theme': themeMode,
        },
        'parametres': parametres.toJson(),
        'produits': produits.map((p) => p.toJson()).toList(),
        'tauxAnnuels': tauxAnnuels.map((t) => t.toJson()).toList(),
        'contrats': contrats.map((c) => c.toJson()).toList(),
        'operations': operations.map((o) => o.toJson()).toList(),
      };

  /// Lève [FormatException] si le contenu n'est pas un fichier valide.
  /// Un fichier v1 est migré automatiquement en v2.
  factory AppData.fromJson(Map<String, dynamic> j) {
    if (j['app'] != appId) {
      throw const FormatException("Ce fichier n'a pas été créé par Ma Retraite.");
    }
    final version = (j['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version < 1 || version > schemaVersion) {
      throw FormatException(
          'Version de fichier $version non prise en charge (version attendue : $schemaVersion). '
          "Mettez l'application à jour.");
    }
    try {
      final profil = Map<String, dynamic>.from((j['profil'] ?? {}) as Map);
      List<Map<String, dynamic>> list(String k) =>
          ((j[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final produits = j['produits'] == null
          ? Produit.parDefaut()
          : list('produits').map(Produit.fromJson).toList();
      var contrats = list('contrats').map(Contrat.fromJson).toList();

      // Migration v1 -> v2 : le champ « produit » contenait le nom ; on le relie au référentiel.
      contrats = [
        for (final c in contrats)
          if (produits.any((p) => p.id == c.produitId))
            c
          else
            c.migrerProduit(_produitPourNom(produits, c.produitId).id),
      ];

      return AppData(
        nomUtilisateur: (profil['nom'] ?? '') as String,
        themeMode: (profil['theme'] ?? 'system') as String,
        produits: produits,
        tauxAnnuels: list('tauxAnnuels').map(TauxAnnuel.fromJson).toList(),
        parametres: ParametresCalcul.fromJson(
            j['parametres'] == null ? null : Map<String, dynamic>.from(j['parametres'] as Map)),
        contrats: contrats,
        operations: list('operations').map(Operation.fromJson).toList(),
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String),
      );
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Fichier corrompu ou incomplet ($e).');
    }
  }

  static Produit _produitPourNom(List<Produit> produits, String nom) {
    final n = nom.trim().toLowerCase();
    for (final p in produits) {
      if (p.nom.toLowerCase() == n || p.code.toLowerCase() == n) return p;
    }
    return produits.firstWhere((p) => p.id == Produit.idAutre, orElse: () => produits.last);
  }
}
