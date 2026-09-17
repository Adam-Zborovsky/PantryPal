import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import '../home/app_shell.dart' show householdCollectionProvider;
import '../shared/scheduling.dart';
import 'shopping_amounts.dart';
import 'shopping_item_breakdown.dart';
import 'shopping_item_status.dart';
import 'trip_transition.dart';

class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  late Future<HouseholdCollectionItem> _trip;

  @override
  void initState() {
    super.initState();
    _trip = _load();
  }

  Future<HouseholdCollectionItem> _load() =>
      ref.read(sessionRepositoryProvider).shoppingTripDetail(widget.tripId);

  Future<void> _updateItem(String itemId, String status) async {
    try {
      await ref
          .read(sessionRepositoryProvider)
          .updateShoppingItem(
            tripId: widget.tripId,
            itemId: itemId,
            status: status,
          );
      ref.invalidate(householdCollectionProvider('Shop'));
      setState(() => _trip = _load());
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this shopping item. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _transition(String action) async {
    if (!await confirmShoppingTripTransition(context, action)) return;
    try {
      await ref
          .read(sessionRepositoryProvider)
          .transitionShoppingTrip(tripId: widget.tripId, action: action);
      ref.invalidate(householdCollectionProvider('Shop'));
      setState(() => _trip = _load());
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this trip. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shopping trip')),
    body: FutureBuilder<HouseholdCollectionItem>(
      future: _trip,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load this shopping trip.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() => _trip = _load()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        final trip = snapshot.data!;
        final rawItems = trip.values['items'];
        final items = rawItems is List
            ? rawItems.whereType<Map>().map(HouseholdCollectionItem.fromJson)
            : const <HouseholdCollectionItem>[];
        return SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _TripSummary(trip: trip, onTransition: _transition),
              const SizedBox(height: 24),
              Text(
                'Shopping list',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const _TripEmpty()
              else
                Card(
                  child: Column(
                    children: [
                      for (final item in items)
                        _ShoppingItemTile(
                          item: item,
                          onChanged: (status) =>
                              _updateItem(item.string('id')!, status),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.trip, required this.onTransition});
  final HouseholdCollectionItem trip;
  final ValueChanged<String> onTransition;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'trip-icon-${trip.string('id')}',
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: PantryPalTheme.tomato.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip status',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  (trip.string('status') ?? 'PROPOSED')
                      .replaceAll('_', ' ')
                      .toLowerCase(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final parsed = tryParseScheduled(
                      trip.string('scheduledFor'),
                    );
                    return Text(
                      parsed == null
                          ? 'No shopping date chosen yet'
                          : formatScheduledForDisplay(parsed),
                    );
                  },
                ),
                if (_nextAction(trip.string('status')) case final action?) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => onTransition(action),
                    icon: Icon(_nextActionIcon(action)),
                    label: Text(_nextActionLabel(action)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String? _nextAction(String? status) => switch (status) {
  'PROPOSED' => 'confirm',
  'CONFIRMED' => 'start',
  'IN_PROGRESS' => 'complete',
  _ => null,
};

String _nextActionLabel(String action) => switch (action) {
  'confirm' => 'Confirm shopping date',
  'start' => 'Start shopping',
  _ => 'Complete shopping',
};

IconData _nextActionIcon(String action) => switch (action) {
  'confirm' => Icons.event_available_outlined,
  'start' => Icons.shopping_cart_checkout_outlined,
  _ => Icons.check_circle_outline,
};

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({required this.item, required this.onChanged});
  final HouseholdCollectionItem item;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final status = item.string('status') ?? 'NEED_TO_BUY';
    final presentation = shoppingItemStatus(status);
    return ExpansionTile(
      leading: Icon(
        presentation.icon,
        color: statusToneColor(context, presentation.colorRole),
      ),
      title: Text(item.string('displayName') ?? 'Shopping item'),
      subtitle: Text(
        [
          shoppingItemSummary(item.values),
          if (status != 'NEED_TO_BUY') presentation.label,
        ].where((part) => part.isNotEmpty).join(' · '),
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Change shopping item state',
        onSelected: onChanged,
        itemBuilder: (context) => [
          for (final choice in shoppingItemStatuses)
            CheckedPopupMenuItem(
              value: choice,
              checked: choice == status,
              child: Row(
                children: [
                  Icon(
                    shoppingItemStatus(choice).icon,
                    size: 18,
                    color: statusToneColor(
                      context,
                      shoppingItemStatus(choice).colorRole,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(shoppingItemStatus(choice).label),
                ],
              ),
            ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: ShoppingItemBreakdown(item: item),
        ),
      ],
    );
  }
}

class _TripEmpty extends StatelessWidget {
  const _TripEmpty();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Assign a scheduled recipe to this trip, then confirm it to generate a shared shopping list.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}
