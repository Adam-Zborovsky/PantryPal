import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../auth/session_repository.dart';

class RealtimeHouseholdEvent {
  const RealtimeHouseholdEvent({required this.name, required this.payload});

  final String name;
  final Map<String, Object?> payload;
}

class RealtimeHouseholdSync extends ConsumerStatefulWidget {
  const RealtimeHouseholdSync({
    super.key,
    required this.onEvent,
    required this.child,
  });

  final ValueChanged<RealtimeHouseholdEvent> onEvent;
  final Widget child;

  @override
  ConsumerState<RealtimeHouseholdSync> createState() =>
      _RealtimeHouseholdSyncState();
}

class _RealtimeHouseholdSyncState extends ConsumerState<RealtimeHouseholdSync> {
  io.Socket? _socket;

  static const _events = <String>{
    'cooking.changed',
    'cook_assignment.requested',
    'cook_assignment.resolved',
    'trip.changed',
    'shopping_item.changed',
    'pantry.recheck_required',
    'notification.created',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    final repository = ref.read(sessionRepositoryProvider);
    final token = await repository.accessToken();
    final householdId = await repository.householdId();
    if (!mounted || token == null || token.isEmpty || householdId == null) {
      return;
    }

    final socket = io.io(
      '$apiBaseUrl/realtime',
      io.OptionBuilder()
          .setAuth({'token': token})
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .enableForceNew()
          .build(),
    );
    _socket = socket;
    socket.onConnect((_) => socket.emit('household.subscribe', householdId));
    for (final event in _events) {
      socket.on(event, (payload) {
        final data = _objectMap(payload);
        if (data?['householdId'] != householdId) {
          return;
        }
        widget.onEvent(
          RealtimeHouseholdEvent(name: event, payload: data ?? const {}),
        );
      });
    }
    socket.connect();
  }

  Map<String, Object?>? _objectMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    return value.map((key, item) => MapEntry('$key', item as Object?));
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
