import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../auth/session_repository.dart';

final selectedDestinationProvider = StateProvider<int>((ref) => 0);
final activeImportProvider = StateProvider<ImportJobSummary?>((ref) => null);

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
    final activeImport = ref.watch(activeImportProvider);
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
          Expanded(
            child: _Body(
              destination: destinations[selected],
              activeImport: activeImport,
              onImport: () => _showImport(context, ref),
              onRefreshImport: activeImport == null
                  ? null
                  : () => _refreshImport(context, ref, activeImport),
            ),
          ),
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

  Future<void> _refreshImport(
    BuildContext context,
    WidgetRef ref,
    ImportJobSummary job,
  ) async {
    try {
      ref.read(activeImportProvider.notifier).state = await ref
          .read(sessionRepositoryProvider)
          .importStatus(job.id);
    } on DioException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh import status.')),
        );
      }
    }
  }

  Future<void> _showImport(BuildContext context, WidgetRef ref) async {
    final source = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import a recipe',
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste a public recipe page. PantryPal will create a review draft before saving it.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: source,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Recipe URL',
                hintText: 'https://example.com/recipe',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                try {
                  final job = await ref
                      .read(sessionRepositoryProvider)
                      .importRecipe(source.text);
                  ref.read(activeImportProvider.notifier).state = job;
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recipe import started.')),
                    );
                } on DioException catch (error) {
                  final data = error.response?.data;
                  final message = data is Map && data['message'] is String
                      ? data['message'] as String
                      : 'Could not start the import.';
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                } on StateError catch (error) {
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                }
              },
              child: const Text('Start import'),
            ),
          ],
        ),
      ),
    );
    source.dispose();
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
  const _Body({
    required this.destination,
    required this.activeImport,
    required this.onImport,
    required this.onRefreshImport,
  });
  final _Destination destination;
  final ImportJobSummary? activeImport;
  final VoidCallback onImport;
  final VoidCallback? onRefreshImport;

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
                          onPressed: onImport,
                          icon: const Icon(Icons.add_link),
                          label: const Text('Import a recipe'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (home && activeImport != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Icon(
                      activeImport!.status == 'FAILED'
                          ? Icons.error_outline
                          : Icons.sync,
                      color: activeImport!.status == 'FAILED'
                          ? Theme.of(context).colorScheme.error
                          : PantryPalTheme.green,
                    ),
                    title: Text(
                      activeImport!.status == 'READY_FOR_REVIEW'
                          ? 'Recipe ready to review'
                          : activeImport!.status == 'FAILED'
                          ? 'Import needs attention'
                          : 'Importing recipe',
                    ),
                    subtitle: Text(
                      activeImport!.status == 'FAILED'
                          ? (activeImport!.errorCode ??
                                'Could not complete the source.')
                          : '${activeImport!.status.replaceAll('_', ' ').toLowerCase()} • ${activeImport!.progress}%',
                    ),
                    trailing: IconButton(
                      tooltip: 'Refresh import status',
                      onPressed: onRefreshImport,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              ],
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
