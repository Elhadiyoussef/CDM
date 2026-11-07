import 'storage_io.dart' if (dart.library.js_interop) 'storage_web.dart' as impl;

/// Stockage local du fichier JSON de l'application.
abstract class JsonStorage {
  /// Lit le contenu brut, ou null si aucune donnée n'existe encore.
  Future<String?> read();

  /// Écrit le contenu de façon sûre (sans corrompre l'existant en cas de coupure).
  Future<void> write(String content);

  /// Lit la sauvegarde précédente (avant la dernière écriture), si disponible.
  Future<String?> readBackup();

  /// Emplacement lisible par l'utilisateur.
  Future<String> location();

  static JsonStorage create() => impl.createStorage();
}
