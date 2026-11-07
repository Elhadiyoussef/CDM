import 'contrat.dart';
import 'operation.dart';

/// Racine du fichier JSON stocké sur l'appareil et échangé par export/import.
class AppData {
  AppData({
    this.nomUtilisateur = '',
    this.themeMode = 'system',
    List<Contrat>? contrats,
    List<Operation>? operations,
    DateTime? updatedAt,
  })  : contrats = contrats ?? [],
        operations = operations ?? [],
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  /// Identifiant du format, vérifié à l'import.
  static const String appId = 'ma_retraite_cdm';

  /// Incrémenter à chaque changement de structure, et gérer la migration dans [fromJson].
  static const int schemaVersion = 1;

  String nomUtilisateur;
  String themeMode; // system | light | dark
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
        'contrats': contrats.map((c) => c.toJson()).toList(),
        'operations': operations.map((o) => o.toJson()).toList(),
      };

  /// Lève [FormatException] si le contenu n'est pas un fichier valide.
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
      return AppData(
        nomUtilisateur: (profil['nom'] ?? '') as String,
        themeMode: (profil['theme'] ?? 'system') as String,
        contrats: ((j['contrats'] as List?) ?? [])
            .map((e) => Contrat.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        operations: ((j['operations'] as List?) ?? [])
            .map((e) => Operation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '') as String),
      );
    } catch (e) {
      throw FormatException('Fichier corrompu ou incomplet ($e).');
    }
  }
}
