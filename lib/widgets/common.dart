import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/operation.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../utils/money.dart';

/// Largeur maximale du contenu, centré sur grand écran.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1180});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16, vertical: wide ? 24 : 12),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Grille adaptative : nombre de colonnes selon la largeur disponible.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 220, this.spacing = 12});
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minItemWidth).floor().clamp(1, children.length);
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    });
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(20)});
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(children: [
                Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium)),
                ?trailing,
              ]),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.valueColor,
    this.accent,
  });
  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final Color? valueColor;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = accent ?? t.colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: t.textTheme.titleLarge?.copyWith(color: valueColor, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(caption!,
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actions = const []});
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: t.colorScheme.primaryContainer, shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: t.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(height: 20),
        Text(title, style: t.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(message,
              textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: actions),
        ],
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  factory StatusChip.operation(StatutOperation s) => switch (s) {
        StatutOperation.executee => StatusChip(label: s.label, color: AppColors.positive, icon: Icons.check_circle),
        StatutOperation.enAttente => StatusChip(label: s.label, color: AppColors.warning, icon: Icons.schedule),
        StatutOperation.rejetee => StatusChip(label: s.label, color: AppColors.negative, icon: Icons.error),
        StatutOperation.annulee => StatusChip(label: s.label, color: Colors.blueGrey, icon: Icons.block),
      };

  factory StatusChip.contrat(StatutContrat s) => switch (s) {
        StatutContrat.actif => StatusChip(label: s.label, color: AppColors.positive, icon: Icons.verified),
        StatutContrat.suspendu => StatusChip(label: s.label, color: AppColors.warning, icon: Icons.pause_circle),
        StatutContrat.cloture => StatusChip(label: s.label, color: Colors.blueGrey, icon: Icons.lock),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

IconData iconForType(TypeOperation t) => switch (t) {
      TypeOperation.cotisation => Icons.event_repeat,
      TypeOperation.versement => Icons.add_card,
      TypeOperation.revalorisation => Icons.trending_up,
      TypeOperation.frais => Icons.receipt_long,
      TypeOperation.rachatPartiel => Icons.call_made,
      TypeOperation.rachatTotal => Icons.logout,
    };

class OperationTile extends StatelessWidget {
  const OperationTile({super.key, required this.op, this.onTap, this.subtitlePrefix});
  final Operation op;
  final VoidCallback? onTap;
  final String? subtitlePrefix;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = !op.estExecutee;
    final color = muted
        ? t.colorScheme.onSurfaceVariant
        : (op.type.credit ? AppColors.positive : t.colorScheme.onSurface);
    final amount = Money.format(op.type.credit ? op.montant : -op.montant, withSign: true);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: (op.type.credit ? AppColors.positive : AppColors.gold).withValues(alpha: 0.14),
        child: Icon(iconForType(op.type), size: 20, color: op.type.credit ? AppColors.positive : AppColors.gold),
      ),
      title: Text(op.libelle.isNotEmpty ? op.libelle : op.type.label,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${subtitlePrefix ?? ''}${op.type.label} · ${Dates.day(op.date)}'),
          if (op.statut != StatutOperation.executee) StatusChip.operation(op.statut),
        ]),
      ),
      trailing: Text(
        amount,
        style: t.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          decoration: op.statut == StatutOperation.rejetee || op.statut == StatutOperation.annulee
              ? TextDecoration.lineThrough
              : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Bandeau d'information (hypothèses, avertissements).
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text, this.icon = Icons.info_outline, this.color});
  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.info;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4))),
      ]),
    );
  }
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.negative : null,
    ));
}

Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String message,
  String confirmer = 'Confirmer',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.negative) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmer),
        ),
      ],
    ),
  );
  return r ?? false;
}
