import 'package:flutter/services.dart';

/// Channels into `MainActivity.kt`, which reads `ACTION_SEND` intents.
const _methodChannel = MethodChannel('pantrypal/shared_text');
const _eventChannel = EventChannel('pantrypal/shared_text_events');

/// Text handed to the app by the Android share sheet, oldest first.
///
/// Merges the two ways a share arrives: the one that cold-started the process,
/// collected once through the method channel, and the ones delivered to the
/// already-running activity through `onNewIntent`, which come down the event
/// channel. Collecting the initial payload also clears it on the Android side,
/// so a hot restart never replays a link that was already imported.
Stream<String> androidSharedTextStream() async* {
  final initial = await _methodChannel.invokeMethod<String>(
    'consumeInitialSharedText',
  );
  if (initial != null && initial.trim().isNotEmpty) yield initial;
  yield* _eventChannel
      .receiveBroadcastStream()
      .where((event) => event is String && event.trim().isNotEmpty)
      .cast<String>();
}
