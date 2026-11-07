import 'package:flutter/material.dart';

import '../data/transfer_service.dart';
import '../models/app_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import 'transfer_flow.dart';

class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  late final TextEditingController _nom;
  String? _emplacement;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    _nom = TextEditingController(text: s.nomUtilisateur);
    s.emplacement().then((v) {
      if (mounted) setState(() => _emplacement = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context);
    final nbOps = s.operations().length;

    return PageBody(maxWidth: 820, children: [
      Text('Paramètres', style: t.textTheme.headlineSmall),
      const SizedBox(height: 20),

      // ------------------------------------------------ Données
      SectionCard(
        title: 'Mes données',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.data_object, color: t.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s.contrats.length} contrat${s.contrats.length > 1 ? 's' : ''} · $nbOps opération${nbOps > 1 ? 's' : ''}',
                      style: t.textTheme.titleSmall),
                  Text('Modifié le ${Dates.dateTime(s.data.updatedAt)} · format v${AppData.schemaVersion}',
                      style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton.icon(
              onPressed: () => exporterDonnees(context),
              icon: const Icon(Icons.save_alt),
              label: const Text('Exporter (.json)'),
            ),
            if (TransferService.estMobile)
              FilledButton.tonalIcon(
                onPressed: () => partagerDonnees(context),
                icon: const Icon(Icons.share),
                label: const Text('Partager'),
              ),
            OutlinedButton.icon(
              onPressed: () => importerDonnees(context),
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Importer'),
            ),
          ]),
          const SizedBox(height: 16),
          const InfoBanner(
            icon: Icons.sync_alt,
            text: 'Pour utiliser vos données sur un autre appareil : exportez le fichier, transférez-le '
                '(e-mail, clé USB, cloud, messagerie…), puis choisissez « Importer » sur l’autre appareil. '
                'La fusion conserve la version la plus récente de chaque élément.',
          ),
          if (_emplacement != null) ...[
            const SizedBox(height: 12),
            SelectableText('Fichier local : $_emplacement',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ],
        ]),
      ),
      const SizedBox(height: 12),

      // ------------------------------------------------ Profil & apparence
      SectionCard(
        title: 'Profil et apparence',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _nom,
            decoration: const InputDecoration(labelText: 'Prénom affiché', prefixIcon: Icon(Icons.person_outline)),
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => s.setNom(v),
            onTapOutside: (_) {
              if (_nom.text.trim() != s.nomUtilisateur) s.setNom(_nom.text);
              FocusScope.of(context).unfocus();
            },
          ),
          const SizedBox(height: 16),
          Text('Thème', style: t.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Système')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Clair')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Sombre')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.setThemeMode(v.first),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ------------------------------------------------ Règles produit
      SectionCard(
        title: 'Règles produit appliquées',
        child: Column(children: [
          _Rule('Cotisation minimale', '${s.regles.cotisationMinimale ~/ 100} DH'),
          _Rule('Rachats partiels maximum', '${s.regles.rachatsPartielsMax}'),
          _Rule('Plafond par rachat partiel', '${s.regles.plafondRachatPourcent} % de l’épargne'),
          const SizedBox(height: 8),
          const InfoBanner(
            text: "Valeurs indicatives tirées des informations publiques du produit Assur'Retraite, "
                'à confirmer selon les conditions de votre contrat.',
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ------------------------------------------------ Zone sensible
      SectionCard(
        title: 'Zone sensible',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (s.estVide)
            OutlinedButton.icon(
              onPressed: () => s.chargerDemo(),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Charger des données de démonstration'),
            ),
          if (!s.estVide)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.negative,
                side: const BorderSide(color: AppColors.negative),
              ),
              onPressed: () async {
                final ok = await confirmer(context,
                    titre: 'Effacer toutes les données ?',
                    message: 'Tous les contrats et opérations seront supprimés de cet appareil. '
                        'Exportez une sauvegarde avant si vous souhaitez les conserver.',
                    confirmer: 'Tout effacer',
                    destructive: true);
                if (ok) {
                  await s.toutEffacer();
                  if (context.mounted) showMessage(context, 'Données effacées.');
                }
              },
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Effacer toutes les données'),
            ),
        ]),
      ),
      const SizedBox(height: 20),
      Center(
        child: Text('Ma Retraite · application locale · aucune donnée transmise',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
      ),
    ]);
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
