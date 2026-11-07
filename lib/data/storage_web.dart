import 'package:web/web.dart' as web;

import 'storage.dart';

JsonStorage createStorage() => WebJsonStorage();

/// Version navigateur (démonstration) : même JSON, conservé dans le localStorage.
class WebJsonStorage implements JsonStorage {
  static const _key = 'ma_retraite.json';

  @override
  Future<String?> read() async => web.window.localStorage.getItem(_key);

  @override
  Future<String?> readBackup() async => web.window.localStorage.getItem('$_key.bak');

  @override
  Future<void> write(String content) async {
    final prev = web.window.localStorage.getItem(_key);
    if (prev != null) web.window.localStorage.setItem('$_key.bak', prev);
    web.window.localStorage.setItem(_key, content);
  }

  @override
  Future<String> location() async => 'Stockage local du navigateur';
}
