import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/auth/session_repository.dart';
import 'package:pantry_pal/features/home/active_import_card.dart';

class _ScriptedRepository extends SessionRepository {
  _ScriptedRepository(this.responses);

  final List<FutureOr<ImportJobSummary> Function()> responses;
  int calls = 0;

  @override
  Future<ImportJobSummary> importStatus(String jobId) async {
    final next =
        responses[calls < responses.length ? calls : responses.length - 1];
    calls++;
    return next();
  }
}

ImportJobSummary _job(
  String status, {
  int progress = 0,
  String? errorCode,
  String? recipeId,
}) => ImportJobSummary(
  id: 'job-1',
  status: status,
  progress: progress,
  errorCode: errorCode,
  recipeId: recipeId,
);

Future<ProviderContainer> _pumpCard(
  WidgetTester tester,
  _ScriptedRepository repository,
  ImportJobSummary initial, {
  ValueChanged<String>? onOpenReview,
}) async {
  final container = ProviderContainer(
    overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  container.read(activeImportProvider.notifier).state = initial;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final job = ref.watch(activeImportProvider);
              return job == null
                  ? const SizedBox.shrink()
                  : ActiveImportCard(job: job, onOpenReview: onOpenReview);
            },
          ),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  group('importFailureMessage', () {
    test('explains a blocked site and offers another way in', () {
      final message = importFailureMessage('SOURCE_BLOCKED');
      expect(message, contains('blocks automatic imports'));
      expect(message, contains('Text'));
    });

    test('never shows the raw error code', () {
      for (final code in [
        'SOURCE_UNAVAILABLE',
        'SOURCE_PRIVATE_OR_LOGIN_REQUIRED',
        'SOURCE_REMOVED',
        'SOURCE_UNSUPPORTED',
        'SOURCE_BLOCKED',
        'SOURCE_METADATA_ONLY',
        'PROVIDER_RATE_LIMITED',
        'MEDIA_TOO_LARGE_OR_LONG',
        'MEDIA_DOWNLOAD_DISABLED',
        'MEDIA_PROCESSING_FAILED',
        'RECIPE_NOT_FOUND',
        'INGREDIENTS_NOT_FOUND',
        'SCALABLE_AMOUNTS_NOT_FOUND',
        'SERVING_YIELD_MISSING',
        'EXTRACTION_SCHEMA_INVALID',
        'ANALYSIS_FAILED',
        'SOMETHING_NEW',
        null,
      ]) {
        final message = importFailureMessage(code);
        expect(message, isNot(contains('_')), reason: '$code');
        expect(message.trim(), isNotEmpty, reason: '$code');
      }
    });
  });

  group('importProgressLabel', () {
    test('describes in-flight work in plain words', () {
      expect(importProgressLabel('QUEUED'), 'Waiting to start');
      expect(importProgressLabel('FETCHING_CONTENT'), 'Reading the page');
      expect(importProgressLabel('SOMETHING_NEW'), 'something new');
    });
  });

  group('ActiveImportCard', () {
    testWidgets('checks status by itself and shows why an import failed', (
      tester,
    ) async {
      final repository = _ScriptedRepository([
        () => _job('FETCHING_CONTENT', progress: 20),
        () => _job('FAILED', progress: 100, errorCode: 'SOURCE_BLOCKED'),
      ]);
      await _pumpCard(tester, repository, _job('QUEUED'));
      expect(find.textContaining('Waiting to start'), findsOneWidget);

      await tester.pump(ActiveImportCard.pollInterval);
      await tester.pump();
      expect(find.textContaining('Reading the page'), findsOneWidget);

      await tester.pump(ActiveImportCard.pollInterval);
      await tester.pump();
      expect(find.text('Couldn’t import this recipe'), findsOneWidget);
      expect(find.textContaining('blocks automatic imports'), findsOneWidget);

      await tester.pump(ActiveImportCard.pollInterval * 3);
      expect(repository.calls, 2, reason: 'polling stops once the job ends');
    });

    testWidgets('a ready import opens review from anywhere on the card', (
      tester,
    ) async {
      final opened = <String>[];
      await _pumpCard(
        tester,
        _ScriptedRepository([]),
        _job('READY_FOR_REVIEW', progress: 100, recipeId: 'recipe-1'),
        onOpenReview: opened.add,
      );

      expect(find.byTooltip('Review imported recipe'), findsNothing);
      expect(find.byTooltip('Refresh import status'), findsNothing);
      await tester.tap(find.text('Check the details before saving.'));
      expect(opened, ['recipe-1']);
    });

    testWidgets('stops checking after repeated network errors and says so', (
      tester,
    ) async {
      final repository = _ScriptedRepository([
        () => throw DioException(
          requestOptions: RequestOptions(path: '/imports/job-1'),
          type: DioExceptionType.connectionError,
        ),
      ]);
      await _pumpCard(tester, repository, _job('QUEUED'));

      for (var i = 0; i < ActiveImportCard.maxFailedChecks + 2; i++) {
        await tester.pump(ActiveImportCard.pollInterval);
        await tester.pump();
      }
      expect(repository.calls, ActiveImportCard.maxFailedChecks);
      expect(find.textContaining('Couldn’t check progress'), findsOneWidget);
    });
  });
}
