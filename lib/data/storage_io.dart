import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'storage.dart';

JsonStorage createStorage() => FileJsonStorage();

/// Stockage dans le dossier privé de l'application :
/// - Android/iOS : dossier de support de l'application
/// - Windows : %APPDATA%\ma.cdm\ma_retraite
/// - macOS : ~/Library/Application Support/...
/// - Linux : ~/.local/share/...
class FileJsonStorage implements JsonStorage {
  static const fileName = 'ma_retraite.json';

  Directory? _dir;

  Future<Directory> _directory() async {
    if (_dir != null) return _dir!;
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  Future<File> _file([String suffix = '']) async =>
      File('${(await _directory()).path}${Platform.pathSeparator}$fileName$suffix');

  @override
  Future<String?> read() async {
    final f = await _file();
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<String?> readBackup() async {
    final f = await _file('.bak');
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> write(String content) async {
    final main = await _file();
    final tmp = await _file('.tmp');
    final bak = await _file('.bak');
    // 1. écrire dans un fichier temporaire
    await tmp.writeAsString(content, flush: true);
    // 2. conserver la version précédente
    if (await main.exists()) await main.copy(bak.path);
    // 3. remplacer atomiquement
    await tmp.rename(main.path);
  }

  @override
  Future<String> location() async => (await _file()).path;
}
