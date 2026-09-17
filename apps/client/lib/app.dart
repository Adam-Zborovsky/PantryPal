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

  // Primitive tokens — Direction A "Diner Board" (see DESIGN.md)
  static const cream = Color(0xFFFFF7E8);
  static const paper = Color(0xFFFFFFFF);
  static const tomato = Color(0xFFE23D28);
  static const butter = Color(0xFFFFD447);
  static const ink = Color(0xFF23283B);
  static const green = Color(0xFF3E8E4C);
  static const amber = Color(0xFFB45309);
  static const line = Color(0xFFF0E8D6);
  static const darkCanvas = Color(0xFF1D2029);
  static const darkSurface = Color(0xFF272B38);
  static const darkLine = Color(0x26FFF7E8);
  static const radius = 16.0;

  static ThemeData light() => _theme(
    brightness: Brightness.light,
    canvas: cream,
    surface: paper,
    content: ink,
    lineColor: line,
    cardBorder: ink,
  );

  static ThemeData dark() => _theme(
    brightness: Brightness.dark,
    canvas: darkCanvas,
    surface: darkSurface,
    content: const Color(0xFFF5EFE2),
    lineColor: darkLine,
    cardBorder: darkLine,
  );

  static ThemeData _theme({
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color content,
    required Color lineColor,
    required Color cardBorder,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: tomato,
      brightness: brightness,
      primary: tomato,
      secondary: butter,
      tertiary: amber,
      surface: surface,
      onSurface: content,
    );
    final body = GoogleFonts.workSansTextTheme().apply(
      bodyColor: content,
      displayColor: content,
    );
    final outlined = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: lineColor),
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
        displaySmall: GoogleFonts.fraunces(
          textStyle: body.displaySmall,
          fontWeight: FontWeight.w900,
        ),
        headlineSmall: GoogleFonts.fraunces(
          textStyle: body.headlineSmall,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: GoogleFonts.fraunces(
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
          side: BorderSide(color: cardBorder, width: 1.75),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: butter,
          foregroundColor: ink,
          elevation: 3,
          shadowColor: ink.withValues(alpha: 0.9),
          side: BorderSide(
            color: brightness == Brightness.light ? ink : lineColor,
            width: 2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius - 2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: content,
          side: BorderSide(color: lineColor),
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
          borderSide: BorderSide(color: tomato, width: 2),
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
        indicatorColor: butter.withValues(alpha: 0.65),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.workSans(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
