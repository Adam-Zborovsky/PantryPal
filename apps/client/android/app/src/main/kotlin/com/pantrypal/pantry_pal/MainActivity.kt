package com.pantrypal.pantry_pal

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Hands text/plain shares to Dart.
 *
 * Written by hand rather than taken from `receive_sharing_intent`, whose 1.9.0
 * release requires `compileSdk 37` while Flutter 3.44 pins the app at 36 and
 * AGP 9.0.1 supports no higher. Only the Android text share is needed, so the
 * bridge is two channels and an intent reader.
 *
 * A share reaches the app two ways, and both are covered here:
 *  - cold start, where the share created the activity: read in [onCreate] and
 *    collected once by the `consumeInitialSharedText` call;
 *  - warm start, where the activity already exists: delivered to [onNewIntent]
 *    because the manifest declares `launchMode="singleTop"`, and pushed
 *    straight down the event channel.
 */
class MainActivity : FlutterActivity() {
    private var pendingSharedText: String? = null
    private var sharedTextEvents: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super, which starts the engine: the initial payload has to be
        // readable by the time Dart asks for it.
        pendingSharedText = sharedTextOf(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeInitialSharedText" -> result.success(consumeInitialSharedText())
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sharedTextEvents = events
                }

                override fun onCancel(arguments: Any?) {
                    sharedTextEvents = null
                }
            },
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = sharedTextOf(intent) ?: return
        val events = sharedTextEvents
        if (events == null) pendingSharedText = text else events.success(text)
    }

    /**
     * Returns the share that started the app and forgets it, so a hot restart
     * or an activity recreation does not import the same link twice.
     */
    private fun consumeInitialSharedText(): String? {
        val text = pendingSharedText
        pendingSharedText = null
        // Replacing the activity's intent stops a process restart from finding
        // the share still attached.
        if (text != null) intent = Intent(Intent.ACTION_MAIN)
        return text
    }

    /**
     * The shared text, or null for any other intent. The manifest only routes
     * `ACTION_SEND` with `text/plain` here, so the MIME type needs no second
     * check; an empty payload is treated as no share at all.
     */
    private fun sharedTextOf(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_SEND) return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)?.takeIf { it.isNotBlank() }
    }

    private companion object {
        const val METHOD_CHANNEL = "pantrypal/shared_text"
        const val EVENT_CHANNEL = "pantrypal/shared_text_events"
    }
}
