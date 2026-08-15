import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pantry_pal/app.dart';
import 'package:pantry_pal/features/auth/auth_page.dart';

void main() {
  testWidgets('shows the PantryPal sign-in screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: PantryPalTheme.light(),
          home: const AuthPage(),
        ),
      ),
    );

    expect(find.text('PantryPal'), findsOneWidget);
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
