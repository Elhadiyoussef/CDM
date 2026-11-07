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
  static Future<bool> enregistrer(String contenu, String fileName, {String mimeType = 'application/json'}) async {
    // BOM UTF-8 pour les CSV : Excel affiche alors correctement les accents.
    final bytes = mimeType == 'text/csv' ? [0xEF, 0xBB, 0xBF, ...utf8.encode(contenu)] : utf8.encode(contenu);
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: mimeType,
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

  /// Sélectionne un fichier (.json par défaut) et retourne son contenu texte, ou null si annulé.
  static Future<String?> choisirFichier({List<String> extensions = const ['json']}) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choisir un fichier',
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes).replaceFirst('\uFEFF', '');
    } on FormatException {
      // Fichier CSV enregistré par Excel en Windows-1252 / Latin-1.
      return latin1.decode(bytes);
    }
  }
}
