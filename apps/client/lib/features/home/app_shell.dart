import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

final selectedDestinationProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});
  static const destinations = <_Destination>[
    _Destination('Home', Icons.home_outlined, Icons.home),
    _Destination('Recipes', Icons.menu_book_outlined, Icons.menu_book),
    _Destination('Plan', Icons.calendar_month_outlined, Icons.calendar_month),
    _Destination('Shop', Icons.shopping_bag_outlined, Icons.shopping_bag),
    _Destination('Archive', Icons.auto_stories_outlined, Icons.auto_stories),
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDestinationProvider);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    void select(int index) =>
        ref.read(selectedDestinationProvider.notifier).state = index;
    return Scaffold(
      appBar: AppBar(
        title: const _Brand(),
        actions: [
          IconButton(
            tooltip: 'Activity inbox',
            onPressed: () {},
            icon: const Badge(child: Icon(Icons.notifications_none)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: selected,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: select,
              destinations: [
                for (final item in destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
          Expanded(child: _Body(destination: destinations[selected])),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: select,
              destinations: [
                for (final item in destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.kitchen_outlined, color: PantryPalTheme.terracotta),
      const SizedBox(width: 8),
      Text('PantryPal', style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.destination});
  final _Destination destination;

  @override
  Widget build(BuildContext context) {
    final home = destination.label == 'Home';
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                home ? 'Good food, clearly planned.' : destination.label,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                home
                    ? 'Bring a recipe. Choose the servings. Know exactly what the household needs.'
                    : '${destination.label} is ready for your household data.',
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        home ? Icons.kitchen_outlined : destination.icon,
                        size: 40,
                        color: PantryPalTheme.terracotta,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        home ? 'Your kitchen is clear' : 'Nothing here yet',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        home
                            ? 'Import a recipe to review it, save a Quick Cook, or plan your next meal.'
                            : 'This area will keep your household in sync.',
                      ),
                      if (home) ...[
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add_link),
                          label: const Text('Import a recipe'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
