import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Échange du fichier JSON avec d'autres appareils.
class TransferService {
  TransferService._();

  static bool get estMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Ouvre la boîte « Enregistrer sous » (desktop) ou le sélecteur de dossier (mobile).
  /// Retourne false si l'utilisateur a annulé.
  static Future<bool> enregistrer(String json, String fileName) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
    );
    return uri != null || kIsWeb;
  }

  /// Ouvre la feuille de partage du système (e-mail, messagerie, Drive, AirDrop, Bluetooth…).
  static Future<void> partager(String json, String fileName) async {
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
      name: fileName,
    );
    await SharePlus.instance.share(ShareParams(
      files: [file],
      fileNameOverrides: [fileName],
      subject: 'Sauvegarde Ma Retraite',
    ));
  }

  /// Sélectionne un fichier .json et retourne son contenu, ou null si annulé.
  static Future<String?> choisirFichier() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Importer une sauvegarde Ma Retraite',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes, allowMalformed: false);
  }
}
