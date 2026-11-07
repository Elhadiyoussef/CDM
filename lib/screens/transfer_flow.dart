import 'package:flutter/material.dart';

import '../data/transfer_service.dart';
import '../state/app_state.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';

/// Parcours d'export : enregistrer le fichier JSON où l'utilisateur le souhaite.
Future<void> exporterDonnees(BuildContext context) async {
  final state = AppScope.read(context);
  try {
    final ok = await TransferService.enregistrer(state.exporterJson(), state.nomFichierExport());
    if (context.mounted && ok) showMessage(context, 'Sauvegarde exportée.');
  } catch (e) {
    if (context.mounted) showMessage(context, 'Export impossible : $e', error: true);
  }
}

/// Parcours de partage (mobile) : feuille de partage du système.
Future<void> partagerDonnees(BuildContext context) async {
  final state = AppScope.read(context);
  try {
    await TransferService.partager(state.exporterJson(), state.nomFichierExport());
  } catch (e) {
    if (context.mounted) showMessage(context, 'Partage impossible : $e', error: true);
  }
}

/// Parcours d'import : choisir un fichier, prévisualiser, puis fusionner ou remplacer.
Future<void> importerDonnees(BuildContext context) async {
  final state = AppScope.read(context);
  final String? raw;
  try {
    raw = await TransferService.choisirFichier();
  } catch (e) {
    if (context.mounted) showMessage(context, 'Lecture du fichier impossible : $e', error: true);
    return;
  }
  if (raw == null || !context.mounted) return;

  final ResumeImport resume;
  try {
    resume = state.analyserImport(raw);
  } on FormatException catch (e) {
    showMessage(context, e.message, error: true);
    return;
  }

  final mode = await showDialog<ModeImport>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx);
      return AlertDialog(
        icon: const Icon(Icons.file_download_outlined),
        title: const Text('Importer cette sauvegarde ?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ligne(t, Icons.event, 'Dernière modification',
                resume.exporteLe == null ? 'Inconnue' : Dates.dateTime(resume.exporteLe!)),
            _ligne(t, Icons.description_outlined, 'Contrats', '${resume.nbContrats}'),
            _ligne(t, Icons.swap_vert, 'Opérations', '${resume.nbOperations}'),
            const SizedBox(height: 16),
            const InfoBanner(
              text: 'Fusionner : ajoute les nouveaux éléments et garde la version la plus récente de chacun.\n'
                  'Remplacer : efface les données de cet appareil et les remplace par celles du fichier.',
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          OutlinedButton(onPressed: () => Navigator.pop(ctx, ModeImport.remplacer), child: const Text('Remplacer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ModeImport.fusionner), child: const Text('Fusionner')),
        ],
      );
    },
  );
  if (mode == null || !context.mounted) return;
  if (mode == ModeImport.remplacer && !state.estVide) {
    final ok = await confirmer(context,
        titre: 'Remplacer toutes les données ?',
        message: 'Les contrats et opérations de cet appareil seront remplacés. '
            'Pensez à exporter une sauvegarde avant si nécessaire.',
        confirmer: 'Remplacer',
        destructive: true);
    if (!ok || !context.mounted) return;
  }
  final r = await state.importer(resume, mode);
  if (!context.mounted) return;
  showMessage(
      context,
      mode == ModeImport.remplacer
          ? 'Données remplacées (${resume.nbContrats} contrats, ${resume.nbOperations} opérations).'
          : 'Import terminé : ${r.ajoutes} ajoutés, ${r.misAJour} mis à jour, ${r.ignores} inchangés.');
}

Widget _ligne(ThemeData t, IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: t.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
