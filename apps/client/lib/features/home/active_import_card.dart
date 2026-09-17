import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import '../shared/app_log.dart';

final activeImportProvider = StateProvider<ImportJobSummary?>((ref) => null);

const _terminalImportStatuses = {'READY_FOR_REVIEW', 'FAILED', 'CANCELLED'};

/// Plain wording for an import that is still running. Never show the raw enum.
String importProgressLabel(String status) => switch (status) {
  'QUEUED' => 'Waiting to start',
  'VALIDATING_SOURCE' => 'Checking the link',
  'FETCHING_METADATA' => 'Getting details',
  'FETCHING_CONTENT' => 'Reading the page',
  'ANALYZING_TEXT' => 'Reading the recipe',
  'ACQUIRING_MEDIA' => 'Getting the media',
  'ANALYZING_AUDIO' => 'Listening to the video',
  'ANALYZING_VISUALS' => 'Looking at the images',
  'STRUCTURING_RECIPE' => 'Organizing the recipe',
  _ => status.replaceAll('_', ' ').toLowerCase(),
};

/// What went wrong and what to do next, keyed by the API's import error code.
String importFailureMessage(String? errorCode) => switch (errorCode) {
  'SOURCE_BLOCKED' =>
    'This site blocks automatic imports. Copy the recipe and import it as Text, or use a Screenshot.',
  'SOURCE_PRIVATE_OR_LOGIN_REQUIRED' =>
    'This page needs a login, so PantryPal can’t read it. Import the recipe as Text or a Screenshot.',
  'SOURCE_REMOVED' =>
    'This page no longer exists. Check the link, or import the recipe as Text.',
  'SOURCE_UNSUPPORTED' =>
    'PantryPal can’t read this link. Use the full recipe page address rather than a short or redirecting link, or import it as Text.',
  'SOURCE_UNAVAILABLE' =>
    'We couldn’t reach this page. Try again in a moment, or import the recipe as Text.',
  'SOURCE_METADATA_ONLY' =>
    'We found the video but not its ingredients. Import the recipe as Text or a Screenshot.',
  'PROVIDER_RATE_LIMITED' =>
    'Recipe reading is busy right now. Try again in a few minutes.',
  'MEDIA_TOO_LARGE_OR_LONG' =>
    'This video is too large or too long to read. Try a shorter clip or a Screenshot.',
  'MEDIA_DOWNLOAD_DISABLED' =>
    'Video imports are turned off. Import the recipe as Text or a Screenshot.',
  'MEDIA_PROCESSING_FAILED' =>
    'We couldn’t process this media. Try again, or import the recipe as Text.',
  'RECIPE_NOT_FOUND' =>
    'We couldn’t find a recipe on this page. Import it as Text or a Screenshot.',
  'INGREDIENTS_NOT_FOUND' =>
    'We couldn’t find the ingredients. Import the recipe as Text or a Screenshot.',
  'SCALABLE_AMOUNTS_NOT_FOUND' =>
    'We couldn’t read the ingredient amounts. Import the recipe as Text so you can check them.',
  'SERVING_YIELD_MISSING' =>
    'The recipe doesn’t say how many it serves. Import it as Text and add the servings.',
  _ =>
    'Something went wrong while reading this recipe. Try again, or import it as Text.',
};

/// Home card for the most recent import. Checks progress on its own until the
/// import finishes, so a failure is never left looking queued.
class ActiveImportCard extends ConsumerStatefulWidget {
  const ActiveImportCard({
    super.key,
    required this.job,
    required this.onOpenReview,
  });

  static const pollInterval = Duration(seconds: 2);
  static const maxFailedChecks = 5;

  final ImportJobSummary job;

  /// Opens the review for the imported recipe once the import is ready.
  final ValueChanged<String>? onOpenReview;

  @override
  ConsumerState<ActiveImportCard> createState() => _ActiveImportCardState();
}

class _ActiveImportCardState extends ConsumerState<ActiveImportCard> {
  Timer? _timer;
  bool _checking = false;
  int _failedChecks = 0;

  bool get _finished => _terminalImportStatuses.contains(widget.job.status);
  bool get _gaveUp => _failedChecks >= ActiveImportCard.maxFailedChecks;

  @override
  void initState() {
    super.initState();
    _syncPolling();
  }

  @override
  void didUpdateWidget(ActiveImportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job.id != widget.job.id) _failedChecks = 0;
    _syncPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncPolling() {
    if (_finished || _gaveUp) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(ActiveImportCard.pollInterval, (_) => _check());
  }

  Future<void> _check({bool manual = false}) async {
    if (_checking) return;
    _checking = true;
    final jobId = widget.job.id;
    try {
      final job = await ref.read(sessionRepositoryProvider).importStatus(jobId);
      if (!mounted) return;
      _failedChecks = 0;
      final active = ref.read(activeImportProvider.notifier);
      if (active.state?.id == jobId) active.state = job;
    } on DioException catch (error) {
      _recordFailedCheck(
        '${error.response?.statusCode ?? error.type.name}',
        manual: manual,
      );
    } on StateError catch (error) {
      _recordFailedCheck(error.message, manual: manual);
    } finally {
      _checking = false;
      if (mounted) _syncPolling();
    }
  }

  void _recordFailedCheck(String reason, {required bool manual}) {
    appLog('import', 'Import status check failed: $reason');
    if (!mounted) return;
    setState(() => _failedChecks++);
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not refresh import status.')),
      );
    }
  }

  void _refresh() {
    setState(() => _failedChecks = 0);
    unawaited(_check(manual: true));
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final failed = job.status == 'FAILED';
    final recipeId = job.recipeId;
    final openReview = widget.onOpenReview;
    final reviewable =
        job.status == 'READY_FOR_REVIEW' &&
        recipeId != null &&
        openReview != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: reviewable ? () => openReview(recipeId) : null,
        leading: Icon(
          failed ? Icons.error_outline : Icons.sync,
          color: failed
              ? Theme.of(context).colorScheme.error
              : PantryPalTheme.green,
        ),
        title: Text(switch (job.status) {
          'READY_FOR_REVIEW' => 'Recipe ready to review',
          'FAILED' => 'Couldn’t import this recipe',
          'CANCELLED' => 'Import cancelled',
          _ => 'Importing recipe',
        }),
        subtitle: Text(switch (job.status) {
          'FAILED' => importFailureMessage(job.errorCode),
          'READY_FOR_REVIEW' => 'Check the details before saving.',
          'CANCELLED' => 'This import was stopped.',
          _ when _gaveUp =>
            'Couldn’t check progress. Tap refresh to try again.',
          _ => '${importProgressLabel(job.status)} • ${job.progress}%',
        }),
        trailing: reviewable
            ? const Icon(Icons.chevron_right)
            : _finished
            ? null
            : IconButton(
                tooltip: 'Refresh import status',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
      ),
    );
  }
}
