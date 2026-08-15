import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/auth/auth_page.dart';
import 'features/auth/session_repository.dart';
import 'features/home/app_shell.dart';

final authenticatedProvider = StateProvider<bool>((ref) => false);
final sessionRestoreProvider = FutureProvider<bool>(
  (ref) => ref.read(sessionRepositoryProvider).restore(),
);

class PantryPalApp extends StatelessWidget {
  const PantryPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _PantryPalMaterialApp());
  }
}

class _PantryPalMaterialApp extends ConsumerWidget {
  const _PantryPalMaterialApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restored = ref.watch(sessionRestoreProvider);
    final authenticated = ref.watch(authenticatedProvider);
    return MaterialApp(
      title: 'PantryPal',
      debugShowCheckedModeBanner: false,
      theme: PantryPalTheme.light(),
      darkTheme: PantryPalTheme.dark(),
      themeMode: ThemeMode.system,
      home: restored.when(
        loading: () => const _SessionRestoring(),
        error: (_, _) => const AuthPage(),
        data: (hasSession) =>
            authenticated || hasSession ? const AppShell() : const AuthPage(),
      ),
    );
  }
}

class _SessionRestoring extends StatelessWidget {
  const _SessionRestoring();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class PantryPalTheme {
  PantryPalTheme._();

  // Primitive tokens
  static const cream = Color(0xFFFFFBEB);
  static const paper = Color(0xFFFFFFFF);
  static const terracotta = Color(0xFF9A3412);
  static const green = Color(0xFF059669);
  static const ink = Color(0xFF0F172A);
  static const line = Color(0xFFE7E5E4);
  static const darkCanvas = Color(0xFF17221F);
  static const darkSurface = Color(0xFF22312D);
  static const radius = 14.0;

  static ThemeData light() => _theme(
    brightness: Brightness.light,
    canvas: cream,
    surface: paper,
    content: ink,
  );

  static ThemeData dark() => _theme(
    brightness: Brightness.dark,
    canvas: darkCanvas,
    surface: darkSurface,
    content: const Color(0xFFF8FAFC),
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color content,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: terracotta,
      brightness: brightness,
      primary: terracotta,
      secondary: green,
      surface: surface,
      onSurface: content,
    );
    final body = GoogleFonts.nunitoSansTextTheme().apply(
      bodyColor: content,
      displayColor: content,
    );
    final outlined = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: line),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: content,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: body.copyWith(
        displaySmall: GoogleFonts.baloo2(
          textStyle: body.displaySmall,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.baloo2(
          textStyle: body.headlineSmall,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.baloo2(
          textStyle: body.titleLarge,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: terracotta,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: content,
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: outlined,
        enabledBorder: outlined,
        focusedBorder: outlined.copyWith(
          borderSide: const BorderSide(color: terracotta, width: 2),
        ),
        errorBorder: outlined.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: outlined.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: surface,
        indicatorColor: terracotta.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
