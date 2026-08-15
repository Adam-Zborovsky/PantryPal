import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const PantryPalApp());
}

class PantryPalApp extends StatelessWidget {
  const PantryPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'PantryPal',
        debugShowCheckedModeBanner: false,
        theme: PantryPalTheme.light(),
        darkTheme: PantryPalTheme.dark(),
        themeMode: ThemeMode.system,
        home: const AppShell(),
      ),
    );
  }
}

final selectedDestinationProvider = StateProvider<int>((ref) => 0);

class PantryPalTheme {
  static const cream = Color(0xFFFFFBEB);
  static const terracotta = Color(0xFF9A3412);
  static const green = Color(0xFF059669);
  static const ink = Color(0xFF0F172A);
  static const darkCanvas = Color(0xFF17221F);

  static ThemeData light() => _theme(
    brightness: Brightness.light,
    canvas: cream,
    raised: Colors.white,
    content: ink,
  );

  static ThemeData dark() => _theme(
    brightness: Brightness.dark,
    canvas: darkCanvas,
    raised: const Color(0xFF22312D),
    content: const Color(0xFFF8FAFC),
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color canvas,
    required Color raised,
    required Color content,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: terracotta,
      brightness: brightness,
      primary: green,
      secondary: terracotta,
      surface: raised,
    );
    final baseText = GoogleFonts.nunitoSansTextTheme().apply(
      bodyColor: content,
      displayColor: content,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: baseText.copyWith(
        displaySmall: GoogleFonts.baloo2(
          textStyle: baseText.displaySmall,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.baloo2(
          textStyle: baseText.headlineSmall,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: raised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        indicatorColor: terracotta.withValues(alpha: 0.16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: content.withValues(alpha: 0.24)),
        ),
      ),
    );
  }
}

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
    final body = _ScreenBody(destination: destinations[selected]);
    void onSelect(int value) {
      ref.read(selectedDestinationProvider.notifier).state = value;
    }

    return Scaffold(
      appBar: AppBar(
        title: const _BrandMark(),
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
              onDestinationSelected: onSelect,
              destinations: [
                for (final item in destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: onSelect,
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PantryPal',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: PantryPalTheme.terracotta,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.soup_kitchen_outlined, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text('PantryPal', style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _ScreenBody extends StatelessWidget {
  const _ScreenBody({required this.destination});

  final _Destination destination;

  @override
  Widget build(BuildContext context) {
    final isHome = destination.label == 'Home';
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
                isHome ? 'Good food, clearly planned.' : destination.label,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                isHome
                    ? 'Bring a recipe. Choose the servings. Know exactly what the household needs.'
                    : '${destination.label} is ready for your household data.',
              ),
              const SizedBox(height: 24),
              if (isHome)
                const _HomePreview()
              else
                _FeaturePlaceholder(destination: destination),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePreview extends StatelessWidget {
  const _HomePreview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'No upcoming cooking plans',
              child: const Icon(
                Icons.kitchen_outlined,
                size: 40,
                color: PantryPalTheme.terracotta,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your kitchen is clear',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Import a recipe to review it, save a Quick Cook, or plan your next meal.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_link),
              label: const Text('Import a recipe'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  const _FeaturePlaceholder({required this.destination});
  final _Destination destination;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Semantics(
        label: 'No ${destination.label.toLowerCase()} items yet',
        child: Column(
          children: [
            Icon(destination.icon, size: 44, color: PantryPalTheme.terracotta),
            const SizedBox(height: 12),
            Text(
              'Nothing here yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            const Text('This area will keep your household in sync.'),
          ],
        ),
      ),
    ),
  );
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
