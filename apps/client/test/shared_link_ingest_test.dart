import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/auth/session_repository.dart';
import 'package:pantry_pal/features/home/active_import_card.dart';
import 'package:pantry_pal/features/home/app_shell.dart';
import 'package:pantry_pal/features/home/shared_link_ingest.dart';

class _FakeRepository extends SessionRepository {
  _FakeRepository({
    this.token = 'access-token',
    this.household = 'household-1',
    this.onImport,
  });

  final String? token;
  final String? household;
  final FutureOr<ImportJobSummary> Function(String url)? onImport;
  final imported = <String>[];

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<String?> householdId() async => household;

  @override
  Future<ImportJobSummary> importRecipe({
    required String sourceKind,
    required String sourceInput,
  }) async {
    expect(sourceKind, 'url');
    imported.add(sourceInput);
    final handler = onImport;
    if (handler != null) return handler(sourceInput);
    return const ImportJobSummary(
      id: 'job-1',
      status: 'QUEUED',
      progress: 0,
    );
  }
}

Future<ProviderContainer> _pumpIngest(
  WidgetTester tester,
  _FakeRepository repository,
  Stream<String> shares,
) async {
  final container = ProviderContainer(
    overrides: [
      sessionRepositoryProvider.overrideWithValue(repository),
      sharedTextStreamProvider.overrideWithValue(shares),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: SharedLinkIngest(
          child: Scaffold(body: Builder(builder: (_) => const Text('shell'))),
        ),
      ),
    ),
  );
  return container;
}

int get _homeIndex => AppShell.destinations.indexWhere(
  (destination) => destination.label == 'Home',
);

void main() {
  group('extractSharedUrl', () {
    test('takes a bare link handed over by the share sheet', () {
      expect(
        extractSharedUrl('https://www.instagram.com/reel/Cx9abcdef/'),
        'https://www.instagram.com/reel/Cx9abcdef/',
      );
    });

    test('finds the link inside the caption TikTok shares alongside it', () {
      expect(
        extractSharedUrl(
          '15-minute garlic pasta 🍝 https://vm.tiktok.com/ZMhabcdefg/ '
          'Check this out on TikTok',
        ),
        'https://vm.tiktok.com/ZMhabcdefg/',
      );
    });

    test('finds a link that sits on its own line', () {
      expect(
        extractSharedUrl(
          'Look at this reel\n\nhttps://www.instagram.com/reel/Cx9abcdef/\n',
        ),
        'https://www.instagram.com/reel/Cx9abcdef/',
      );
    });

    test('keeps the query string share links carry', () {
      expect(
        extractSharedUrl(
          'https://www.instagram.com/reel/Cx9abcdef/?igsh=MXBtcWRlaWs',
        ),
        'https://www.instagram.com/reel/Cx9abcdef/?igsh=MXBtcWRlaWs',
      );
    });

    test('drops sentence punctuation that trails the link', () {
      expect(
        extractSharedUrl('Try this https://vm.tiktok.com/ZMhabcdefg/.'),
        'https://vm.tiktok.com/ZMhabcdefg/',
      );
      expect(
        extractSharedUrl('(https://www.tiktok.com/@cook/video/7123456789)'),
        'https://www.tiktok.com/@cook/video/7123456789',
      );
    });

    test('keeps a trailing slash, which is part of the path', () {
      expect(
        extractSharedUrl('https://www.instagram.com/p/Cx9abcdef/'),
        'https://www.instagram.com/p/Cx9abcdef/',
      );
    });

    test('accepts a plain http link', () {
      expect(
        extractSharedUrl('http://example.com/recipe'),
        'http://example.com/recipe',
      );
    });

    test('takes the first link when the share carries several', () {
      expect(
        extractSharedUrl(
          'https://vm.tiktok.com/ZMfirst/ and https://vm.tiktok.com/ZMsecond/',
        ),
        'https://vm.tiktok.com/ZMfirst/',
      );
    });

    test('returns null for a share with no link in it', () {
      expect(extractSharedUrl('Garlic pasta, 15 minutes, so good'), isNull);
      expect(extractSharedUrl('   '), isNull);
      expect(extractSharedUrl(''), isNull);
    });

    test('returns null for a schemeless host it cannot import', () {
      expect(extractSharedUrl('www.instagram.com/reel/Cx9abcdef/'), isNull);
    });

    test('returns null when a scheme has no host behind it', () {
      expect(extractSharedUrl('shared this: https://'), isNull);
      expect(extractSharedUrl('https://.'), isNull);
    });

    test('rejects a scheme the import pipeline cannot fetch', () {
      expect(extractSharedUrl('ftp://example.com/recipe.txt'), isNull);
      expect(
        extractSharedUrl('intent://instagram.com/reel/Cx9abcdef/#Intent;end'),
        isNull,
      );
    });
  });

  group('SharedLinkIngest', () {
    testWidgets('a shared reel starts an import and shows it on Home', (
      tester,
    ) async {
      final shares = StreamController<String>();
      addTearDown(shares.close);
      final repository = _FakeRepository();
      final container = await _pumpIngest(tester, repository, shares.stream);
      container.read(selectedDestinationProvider.notifier).state = 3;

      shares.add(
        'Garlic pasta 🍝 https://www.instagram.com/reel/Cx9abcdef/ on Instagram',
      );
      await tester.pumpAndSettle();

      expect(repository.imported, ['https://www.instagram.com/reel/Cx9abcdef/']);
      expect(container.read(activeImportProvider)?.id, 'job-1');
      expect(container.read(selectedDestinationProvider), _homeIndex);
      expect(find.text(sharedLinkStartedMessage), findsOneWidget);
    });

    testWidgets('a share while signed out asks for sign-in and imports nothing', (
      tester,
    ) async {
      final shares = StreamController<String>();
      addTearDown(shares.close);
      final repository = _FakeRepository(token: null, household: null);
      final container = await _pumpIngest(tester, repository, shares.stream);

      shares.add('https://vm.tiktok.com/ZMhabcdefg/');
      await tester.pumpAndSettle();

      expect(repository.imported, isEmpty);
      expect(container.read(activeImportProvider), isNull);
      expect(find.text(sharedLinkSignInMessage), findsOneWidget);
    });

    testWidgets('a share with no household resolved still asks for sign-in', (
      tester,
    ) async {
      final shares = StreamController<String>();
      addTearDown(shares.close);
      final repository = _FakeRepository(household: null);
      await _pumpIngest(tester, repository, shares.stream);

      shares.add('https://vm.tiktok.com/ZMhabcdefg/');
      await tester.pumpAndSettle();

      expect(repository.imported, isEmpty);
      expect(find.text(sharedLinkSignInMessage), findsOneWidget);
    });

    testWidgets('a share with no link points the user at Text import', (
      tester,
    ) async {
      final shares = StreamController<String>();
      addTearDown(shares.close);
      final repository = _FakeRepository();
      await _pumpIngest(tester, repository, shares.stream);

      shares.add('Garlic pasta, 15 minutes, so good');
      await tester.pumpAndSettle();

      expect(repository.imported, isEmpty);
      expect(find.text(sharedLinkNoLinkMessage), findsOneWidget);
    });

    testWidgets('a rejected import surfaces the reason the API gave', (
      tester,
    ) async {
      final shares = StreamController<String>();
      addTearDown(shares.close);
      final repository = _FakeRepository(
        onImport: (_) => throw DioException(
          requestOptions: RequestOptions(path: '/imports'),
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/imports'),
            statusCode: 400,
            data: const {'message': 'SOURCE_UNSUPPORTED: Enter a valid link.'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      final container = await _pumpIngest(tester, repository, shares.stream);

      shares.add('https://vm.tiktok.com/ZMhabcdefg/');
      await tester.pumpAndSettle();

      expect(container.read(activeImportProvider), isNull);
      expect(
        find.text('SOURCE_UNSUPPORTED: Enter a valid link.'),
        findsOneWidget,
      );
    });

    testWidgets('a platform error does not stop later shares arriving', (
      tester,
    ) async {
      final shares = StreamController<String>();
      addTearDown(shares.close);
      final repository = _FakeRepository();
      await _pumpIngest(tester, repository, shares.stream);

      shares.addError(
        PlatformException(code: 'channel-error', message: 'no implementation'),
      );
      await tester.pumpAndSettle();
      shares.add('https://vm.tiktok.com/ZMhabcdefg/');
      await tester.pumpAndSettle();

      expect(repository.imported, ['https://vm.tiktok.com/ZMhabcdefg/']);
    });

    testWidgets('a second share replaces the first as the active import', (
      tester,
    ) async {
      final shares = StreamController<String>();
      addTearDown(shares.close);
      var next = 1;
      final repository = _FakeRepository(
        onImport: (_) =>
            ImportJobSummary(id: 'job-${next++}', status: 'QUEUED', progress: 0),
      );
      final container = await _pumpIngest(tester, repository, shares.stream);

      shares.add('https://vm.tiktok.com/ZMfirst/');
      await tester.pumpAndSettle();
      shares.add('https://vm.tiktok.com/ZMsecond/');
      await tester.pumpAndSettle();

      expect(repository.imported, [
        'https://vm.tiktok.com/ZMfirst/',
        'https://vm.tiktok.com/ZMsecond/',
      ]);
      expect(container.read(activeImportProvider)?.id, 'job-2');
    });
  });
}
