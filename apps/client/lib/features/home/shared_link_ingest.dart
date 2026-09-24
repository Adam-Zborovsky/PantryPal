import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_repository.dart';
import '../shared/app_log.dart';
import 'active_import_card.dart';
import 'app_shell.dart';
import 'shared_text_source.dart';

/// Matches the first http(s) link in a share payload. Stops at whitespace and
/// at the bracket characters that wrap a link in prose.
final _linkPattern = RegExp(r'''https?://[^\s<>"'\]]+''');

/// Sentence punctuation that trails a pasted link. A trailing `/` is part of
/// the path on both Instagram and TikTok, so it is deliberately absent here.
const _trailingPunctuation = {
  '.',
  ',',
  '!',
  '?',
  ';',
  ':',
  ')',
  ']',
  '}',
  '"',
  "'",
};

/// Pulls the importable link out of text handed over by the Android share
/// sheet.
///
/// Instagram and TikTok both share a caption with the link embedded in it
/// rather than a bare URL, so this scans for the link instead of trusting the
/// whole payload. Returns null when the share carries nothing the import
/// pipeline could fetch — the caller then tells the user to import as Text.
String? extractSharedUrl(String raw) {
  final match = _linkPattern.stringMatch(raw);
  if (match == null) return null;
  var candidate = match;
  while (candidate.isNotEmpty &&
      _trailingPunctuation.contains(candidate[candidate.length - 1])) {
    candidate = candidate.substring(0, candidate.length - 1);
  }
  final parsed = Uri.tryParse(candidate);
  if (parsed == null || parsed.host.isEmpty) return null;
  return candidate;
}

/// Wording for every outcome of a share. Kept as constants so the tests assert
/// the same strings the user reads.
const sharedLinkStartedMessage = 'Recipe import started.';
const sharedLinkSignInMessage =
    'Sign in to PantryPal, then share the link again.';
const sharedLinkNoLinkMessage =
    'That share didn’t include a link. Copy the recipe and import it as Text.';
const sharedLinkGenericFailureMessage = 'Could not start the import.';

/// Raw share payloads handed over by the host platform.
///
/// Only Android registers a share target, so every other surface — the PWA
/// build included — gets an inert stream. Widget tests override this provider
/// with a stream they drive themselves.
final sharedTextStreamProvider = Provider<Stream<String>>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const Stream<String>.empty();
  }
  return androidSharedTextStream();
});

/// Turns an Android share into a recipe import.
///
/// Sits above the auth branch so a share is answered whether the user is
/// looking at sign-in or at the shell. Renders [child] untouched; all it adds
/// is the subscription.
class SharedLinkIngest extends ConsumerStatefulWidget {
  const SharedLinkIngest({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SharedLinkIngest> createState() => _SharedLinkIngestState();
}

class _SharedLinkIngestState extends ConsumerState<SharedLinkIngest> {
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    // A failing share channel must not take the subscription down with it, or
    // every later share is lost for the life of the process. Log and stay live.
    _subscription = ref.read(sharedTextStreamProvider).listen(
      _handle,
      onError: (Object error) =>
          appLog('import', 'Share channel error: $error'),
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String message) =>
        messenger.showSnackBar(SnackBar(content: Text(message)));

    final url = extractSharedUrl(raw);
    if (url == null) {
      appLog('import', 'Shared payload carried no importable link');
      say(sharedLinkNoLinkMessage);
      return;
    }

    // Read the stored credentials rather than the restore provider: a cold
    // start from the share sheet can deliver the payload before the session
    // restore future resolves, and storage is authoritative either way.
    final repository = ref.read(sessionRepositoryProvider);
    final token = await repository.accessToken();
    final household = await repository.householdId();
    if (!mounted) return;
    if (token == null ||
        token.isEmpty ||
        household == null ||
        household.isEmpty) {
      appLog('import', 'Shared link arrived without a signed-in household');
      say(sharedLinkSignInMessage);
      return;
    }

    try {
      final job = await repository.importRecipe(
        sourceKind: 'url',
        sourceInput: url,
      );
      if (!mounted) return;
      ref.read(activeImportProvider.notifier).state = job;
      ref.read(selectedDestinationProvider.notifier).state = _homeIndex;
      say(sharedLinkStartedMessage);
    } on DioException catch (error) {
      appLog(
        'import',
        'Shared link import failed: '
            '${error.response?.statusCode ?? error.type.name}',
      );
      final data = error.response?.data;
      if (!mounted) return;
      say(
        data is Map && data['message'] is String
            ? data['message'] as String
            : sharedLinkGenericFailureMessage,
      );
    } on StateError catch (error) {
      appLog('import', 'Shared link import blocked: ${error.message}');
      if (!mounted) return;
      say(error.message);
    } catch (error) {
      appLog('import', 'Unexpected shared link failure: $error');
      if (!mounted) return;
      say(sharedLinkGenericFailureMessage);
    }
  }

  int get _homeIndex => AppShell.destinations.indexWhere(
    (destination) => destination.label == 'Home',
  );

  @override
  Widget build(BuildContext context) => widget.child;
}
