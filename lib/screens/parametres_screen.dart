import 'package:flutter/material.dart';

import '../data/transfer_service.dart';
import '../models/app_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import '../models/parametres.dart';
import '../models/taux_annuel.dart';
import 'referentiels_screen.dart';
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

      // ------------------------------------------------ Référentiels
      SectionCard(
        title: 'Référentiels',
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
        child: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Produits d’assurance'),
            subtitle: Text('${s.produits.length} produit(s) · règles de cotisation et de rachat'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProduitsScreen())),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.percent),
            title: const Text('Taux annuels'),
            subtitle: Text('${s.data.tauxAnnuels.length} ligne(s) · commission et rendement par année'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TauxAnnuelsScreen())),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ------------------------------------------------ Calcul
      _CalculCard(),
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


/// Paramètres du calcul des rendements.
class _CalculCard extends StatefulWidget {
  @override
  State<_CalculCard> createState() => _CalculCardState();
}

class _CalculCardState extends State<_CalculCard> {
  late final TextEditingController _taux;

  @override
  void initState() {
    super.initState();
    _taux = TextEditingController(text: Taux.toInput(AppScope.read(context).parametres.tauxEstimation));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.parametres;
    final t = Theme.of(context);
    const mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    return SectionCard(
      title: 'Calcul des rendements',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Méthode de calcul des intérêts', style: t.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<MethodeInteret>(
          segments: const [
            ButtonSegment(value: MethodeInteret.quinzaines, label: Text('Quinzaines (carnet)')),
            ButtonSegment(value: MethodeInteret.jours, label: Text('Prorata au jour')),
          ],
          selected: {p.methode},
          onSelectionChanged: (v) => s.setParametres(p.copyWith(methode: v.first)),
        ),
        const SizedBox(height: 6),
        Text(
          p.methode == MethodeInteret.quinzaines
              ? 'Comme un compte sur carnet : un versement rapporte à partir de la quinzaine suivante (1er ou 16 du mois).'
              : 'Chaque versement rapporte à partir de sa date, au jour près.',
          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
        const Divider(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Estimer l’année en cours'),
          subtitle: const Text('Si le taux de l’année n’est pas encore publié par l’assureur.'),
          value: p.estimerAnneeEnCours,
          onChanged: (v) => s.setParametres(p.copyWith(estimerAnneeEnCours: v)),
        ),
        if (p.estimerAnneeEnCours)
          TextField(
            controller: _taux,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: 'Taux d’estimation (facultatif)',
              helperText: 'Vide = dernier taux connu du produit ou du contrat',
              suffixText: '%',
            ),
            onSubmitted: (v) => _saveTaux(s, p, v),
            onTapOutside: (_) {
              _saveTaux(s, p, _taux.text);
              FocusScope.of(context).unfocus();
            },
          ),
        const Divider(height: 28),
        Row(children: [
          const Expanded(child: Text('Date de versement de la revalorisation')),
          DropdownButton<int>(
            value: p.jourRevalorisation,
            items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))],
            onChanged: (v) => s.setParametres(p.copyWith(jourRevalorisation: v)),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: p.moisRevalorisation,
            items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(mois[m - 1]))],
            onChanged: (v) => s.setParametres(p.copyWith(moisRevalorisation: v)),
          ),
        ]),
        Text('Information affichée dans le récapitulatif et date des opérations de rendement générées.',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
      ]),
    );
  }

  void _saveTaux(AppState s, ParametresCalcul p, String v) {
    try {
      final bp = Taux.parse(v);
      if (bp != p.tauxEstimation) s.setParametres(bp == null ? p.copyWith(clearTauxEstimation: true) : p.copyWith(tauxEstimation: bp));
    } on FormatException {
      showMessage(context, 'Taux d’estimation invalide (ex. 3,00).', error: true);
    }
  }
}
