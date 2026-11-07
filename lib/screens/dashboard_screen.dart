import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../widgets/capital_chart.dart';
import '../widgets/common.dart';
import 'contrat_form.dart';
import 'operation_form.dart';
import 'transfer_flow.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.estVide) return const _Welcome();

    final t = Theme.of(context);
    final capital = s.capital();
    final verse = s.totalVerse();
    final ecart = s.ecart();
    final attente = s.montantEnAttente();
    final objectif = s.objectif();
    final actifs = s.contrats.where((c) => !c.estCloture).toList();
    final prochaines = actifs.map((c) => (c, c.prochaineCotisation)).where((e) => e.$2 != null).toList()
      ..sort((a, b) => a.$2!.compareTo(b.$2!));
    final echeances = actifs.where((c) => c.dateEcheance != null).map((c) => c.dateEcheance!).toList()..sort();
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final recentes = s.operations().take(6).toList();

    final chart = SectionCard(
      title: 'Évolution du capital',
      child: CapitalChart(points: s.evolutionCapital()),
    );
    final actions = SectionCard(
      title: 'Actions rapides',
      child: Column(children: [
        _QuickAction(
          icon: Icons.add_card,
          label: 'Effectuer un versement',
          onTap: actifs.isEmpty ? null : () => showOperationForm(context),
        ),
        _QuickAction(icon: Icons.insights, label: 'Simuler ma retraite', onTap: () => onNavigate(3)),
        _QuickAction(icon: Icons.description, label: 'Mes contrats', onTap: () => onNavigate(1)),
        _QuickAction(icon: Icons.ios_share, label: 'Exporter mes données', onTap: () => exporterDonnees(context)),
      ]),
    );

    return PageBody(children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.nomUtilisateur.isEmpty ? 'Bonjour' : 'Bonjour, ${s.nomUtilisateur}',
                style: t.textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(Dates.long(DateTime.now()),
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ]),
        ),
        if (actifs.isNotEmpty)
          FilledButton.icon(
            onPressed: () => showOperationForm(context),
            icon: const Icon(Icons.add),
            label: Text(wide ? 'Nouvelle opération' : 'Opération'),
          ),
      ]),
      const SizedBox(height: 20),
      _HeroCard(
        capital: capital,
        attente: attente,
        objectif: objectif,
        valorisation: s.derniereValorisation(),
        nbContrats: actifs.length,
      ),
      const SizedBox(height: 12),
      ResponsiveGrid(minItemWidth: 230, children: [
        StatCard(
          label: 'Total versé',
          value: Money.compact(verse),
          icon: Icons.account_balance_wallet_outlined,
          caption: 'Cotisations et versements exécutés',
        ),
        StatCard(
          label: 'Écart de valorisation',
          value: Money.compact(ecart, withSign: true),
          icon: ecart >= 0 ? Icons.trending_up : Icons.trending_down,
          valueColor: ecart >= 0 ? AppColors.positive : AppColors.negative,
          accent: ecart >= 0 ? AppColors.positive : AppColors.negative,
          caption: verse > 0 ? '${Money.percent(ecart, verse, withSign: true)} · hors fiscalité' : 'Hors frais et fiscalité',
        ),
        StatCard(
          label: 'Prochaine cotisation',
          value: prochaines.isEmpty ? '—' : Money.compact(prochaines.first.$1.cotisation),
          icon: Icons.event_repeat,
          accent: AppColors.gold,
          caption: prochaines.isEmpty ? 'Aucune échéance planifiée' : 'Le ${Dates.day(prochaines.first.$2!)}',
        ),
        StatCard(
          label: 'Départ à la retraite',
          value: echeances.isEmpty ? '—' : '${echeances.first.year}',
          icon: Icons.beach_access_outlined,
          accent: AppColors.info,
          caption: echeances.isEmpty ? 'Échéance non renseignée' : _restant(echeances.first),
        ),
      ]),
      const SizedBox(height: 12),
      if (wide)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 2, child: chart),
            const SizedBox(width: 12),
            Expanded(child: actions),
          ]),
        )
      else ...[
        chart,
        const SizedBox(height: 12),
        actions,
      ],
      const SizedBox(height: 12),
      SectionCard(
        title: 'Dernières opérations',
        trailing: TextButton(onPressed: () => onNavigate(2), child: const Text('Tout voir')),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: recentes.isEmpty
            ? const Padding(padding: EdgeInsets.all(16), child: Text('Aucune opération enregistrée.'))
            : Column(children: [for (final o in recentes) OperationTile(op: o)]),
      ),
      const SizedBox(height: 16),
      const InfoBanner(
        text: 'Les montants affichés proviennent de vos saisies et sont conservés uniquement sur cet appareil. '
            'Les opérations en attente ne sont pas incluses dans le capital. '
            "L'écart de valorisation n'est pas un rendement net de frais et d'impôts.",
      ),
    ]);
  }

  static String _restant(DateTime d) {
    final now = Dates.today();
    var mois = (d.year - now.year) * 12 + d.month - now.month;
    if (mois <= 0) return 'Échéance atteinte';
    final ans = mois ~/ 12;
    mois %= 12;
    return 'Dans ${ans > 0 ? '$ans an${ans > 1 ? 's' : ''}' : ''}${ans > 0 && mois > 0 ? ' et ' : ''}${mois > 0 ? '$mois mois' : ''}';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.capital,
    required this.attente,
    required this.objectif,
    required this.valorisation,
    required this.nbContrats,
  });
  final int capital;
  final int attente;
  final int objectif;
  final DateTime? valorisation;
  final int nbContrats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final progress = objectif > 0 ? (capital / objectif).clamp(0.0, 1.0) : null;
    const onHero = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.75);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandDark],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.brand.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Capital constitué', style: t.textTheme.titleSmall?.copyWith(color: muted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$nbContrats contrat${nbContrats > 1 ? 's' : ''} actif${nbContrats > 1 ? 's' : ''}',
                style: t.textTheme.labelMedium?.copyWith(color: onHero)),
          ),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Money.format(capital),
            style: t.textTheme.displaySmall?.copyWith(
              color: onHero,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 16, runSpacing: 4, children: [
          Text(
            valorisation == null ? 'Aucune valorisation saisie' : 'Dernière valorisation : ${Dates.day(valorisation!)}',
            style: t.textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (attente != 0)
            Text('${Money.compact(attente, withSign: true)} en attente (non comptés)',
                style: t.textTheme.bodySmall?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w600)),
        ]),
        if (progress != null) ...[
          const SizedBox(height: 20),
          Row(children: [
            Text('Objectif ${Money.compact(objectif)}', style: t.textTheme.labelLarge?.copyWith(color: muted)),
            const Spacer(),
            Text('${(progress * 100).toStringAsFixed(0)} %',
                style: t.textTheme.labelLarge?.copyWith(color: onHero, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
        ],
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListTile(
      enabled: onTap != null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: t.colorScheme.onPrimaryContainer),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return PageBody(maxWidth: 720, children: [
      const SizedBox(height: 24),
      EmptyState(
        icon: Icons.savings_outlined,
        title: 'Bienvenue dans Ma Retraite',
        message: 'Suivez votre épargne retraite, simulez votre capital futur et gardez l’historique de vos opérations. '
            'Vos données restent sur cet appareil, dans un fichier que vous pouvez exporter vers un autre appareil.',
        actions: [
          FilledButton.icon(
            onPressed: () => showContratForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter mon contrat'),
          ),
          OutlinedButton.icon(
            onPressed: () => importerDonnees(context),
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Importer un fichier'),
          ),
        ],
      ),
      Center(
        child: TextButton.icon(
          onPressed: () => AppScope.read(context).chargerDemo(),
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: const Text('Découvrir avec des données de démonstration'),
        ),
      ),
      const SizedBox(height: 24),
      ResponsiveGrid(minItemWidth: 200, children: [
        for (final (icon, title, text) in const [
          (Icons.lock_outline, '100 % local', 'Aucun compte, aucun serveur : le fichier JSON reste chez vous.'),
          (Icons.sync_alt, 'Multi-appareils', 'Exportez puis importez pour retrouver vos données ailleurs.'),
          (Icons.insights, 'Projections', 'Comparez des scénarios prudent, central et favorable.'),
        ])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: t.colorScheme.primary),
                const SizedBox(height: 10),
                Text(title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(text, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
      ]),
    ]);
  }
}
