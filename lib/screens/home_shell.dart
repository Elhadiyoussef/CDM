import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'contrats_screen.dart';
import 'dashboard_screen.dart';
import 'operations_screen.dart';
import 'parametres_screen.dart';
import 'recap_screen.dart';
import 'simulateur_screen.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Dest('Accueil', Icons.dashboard_outlined, Icons.dashboard),
  _Dest('Contrats', Icons.description_outlined, Icons.description),
  _Dest('Opérations', Icons.swap_vert_outlined, Icons.swap_vert),
  _Dest('Récap', Icons.table_chart_outlined, Icons.table_chart),
  _Dest('Simulateur', Icons.insights_outlined, Icons.insights),
  _Dest('Paramètres', Icons.settings_outlined, Icons.settings),
];

/// Navigation adaptative : barre du bas sur mobile, rail latéral sur tablette / desktop.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final w = AppScope.read(context).loadWarning;
      if (w != null && mounted) showMessage(context, w, error: true);
    });
  }

  void go(int i) => setState(() => _index = i);

  Widget _page() => switch (_index) {
        0 => DashboardScreen(onNavigate: go),
        1 => const ContratsScreen(),
        2 => const OperationsScreen(),
        3 => const RecapScreen(),
        4 => const SimulateurScreen(),
        _ => const ParametresScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final t = Theme.of(context);
    final page = KeyedSubtree(key: ValueKey(_index), child: _page());
    final body = AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: page);

    if (width < 760) {
      return Scaffold(
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: go,
          labelBehavior: width < 420 ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          ],
        ),
      );
    }

    final extended = width >= 1100;
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          extended: extended,
          minExtendedWidth: 232,
          selectedIndex: _index,
          onDestinationSelected: go,
          labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 24),
            child: _Brand(extended: extended),
          ),
          destinations: [
            for (final d in _destinations)
              NavigationRailDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: Text(d.label),
                padding: const EdgeInsets.symmetric(vertical: 2),
              ),
          ],
        ),
        VerticalDivider(width: 1, color: t.dividerTheme.color),
        Expanded(child: SafeArea(child: body)),
      ]),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.extended});
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final logo = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.brand, AppColors.brandDark]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.savings, color: AppColors.gold, size: 22),
    );
    if (!extended) return logo;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      logo,
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ma Retraite', style: t.textTheme.titleMedium),
        Text('Épargne retraite', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
      ]),
    ]);
  }
}
