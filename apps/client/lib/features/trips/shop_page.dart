import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import '../shared/scheduled_date_time_field.dart';
import '../shared/sticker_chip.dart';
import 'shopping_amounts.dart';
import 'shopping_item_breakdown.dart';
import 'shopping_item_status.dart';
import 'trip_transition.dart';

final shopTripsProvider = FutureProvider<List<HouseholdCollectionItem>>(
  (ref) => ref.read(sessionRepositoryProvider).shoppingTrips(),
);
final tripDetailProvider =
    FutureProvider.family<HouseholdCollectionItem, String>(
      (ref, tripId) =>
          ref.read(sessionRepositoryProvider).shoppingTripDetail(tripId),
    );

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  String? _selectedTripId;

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(shopTripsProvider);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Shop', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 4),
              const Text('Keep the shared list clear while you shop.'),
              const SizedBox(height: 20),
              trips.when(
                loading: () => const _ShopLoading(),
                error: (_, _) => _ShopError(
                  onRetry: () => ref.invalidate(shopTripsProvider),
                ),
                data: _buildTrips,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrips(List<HouseholdCollectionItem> trips) {
    if (trips.isEmpty) return const _ShopEmpty();
    final active = trips.where((trip) {
      final status = trip.string('status');
      return status == 'CONFIRMED' || status == 'IN_PROGRESS';
    }).toList();
    final choices = active.isEmpty ? trips : active;
    final selected = choices.any((trip) => trip.string('id') == _selectedTripId)
        ? _selectedTripId!
        : choices.first.string('id')!;
    if (_selectedTripId != selected) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => mounted ? setState(() => _selectedTripId = selected) : null,
      );
    }
    final detail = ref.watch(tripDetailProvider(selected));
    return Column(
      children: [
        _TripSelector(
          trips: choices,
          selectedTripId: selected,
          onChanged: (id) => setState(() => _selectedTripId = id),
        ),
        const SizedBox(height: 16),
        detail.when(
          loading: () => const _ShopLoading(),
          error: (_, _) => _ShopError(
            onRetry: () => ref.invalidate(tripDetailProvider(selected)),
          ),
          data: (trip) => _TripShoppingView(
            trip: trip,
            onChanged: () {
              ref.invalidate(shopTripsProvider);
              ref.invalidate(tripDetailProvider(selected));
            },
          ),
        ),
      ],
    );
  }
}

class _TripSelector extends StatelessWidget {
  const _TripSelector({
    required this.trips,
    required this.selectedTripId,
    required this.onChanged,
  });
  final List<HouseholdCollectionItem> trips;
  final String selectedTripId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        initialValue: selectedTripId,
        decoration: const InputDecoration(
          labelText: 'Shopping trip',
          prefixIcon: Icon(Icons.shopping_bag_outlined),
        ),
        items: [
          for (final trip in trips)
            DropdownMenuItem(
              value: trip.string('id'),
              child: Text(_tripLabel(trip)),
            ),
        ],
        onChanged: (id) {
          if (id != null) onChanged(id);
        },
      ),
    ),
  );
}

class _TripShoppingView extends ConsumerWidget {
  const _TripShoppingView({required this.trip, required this.onChanged});
  final HouseholdCollectionItem trip;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = trip.string('id')!;
    final status = trip.string('status') ?? 'PROPOSED';
    final items = (trip.values['items'] as List? ?? const [])
        .whereType<Map>()
        .map(HouseholdCollectionItem.fromJson)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tripLabel(trip),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _TripStatus(status: status),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${items.length} items · shared household list'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showChangeDate(context, ref, id, onChanged),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Change date'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const _TripItemsEmpty()
        else
          Card(
            child: Column(
              children: [
                for (final item in items)
                  _ShoppingItemRow(
                    item: item,
                    tripId: id,
                    onChanged: onChanged,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (status == 'PROPOSED')
          FilledButton.icon(
            onPressed: () =>
                _transition(context, ref, id, 'confirm', onChanged),
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Confirm shopping date'),
          )
        else if (status == 'CONFIRMED')
          FilledButton.icon(
            onPressed: () => _transition(context, ref, id, 'start', onChanged),
            style: FilledButton.styleFrom(
              backgroundColor: PantryPalTheme.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Start shopping'),
          )
        else if (status == 'IN_PROGRESS')
          FilledButton.icon(
            onPressed: () =>
                _transition(context, ref, id, 'complete', onChanged),
            style: FilledButton.styleFrom(
              backgroundColor: PantryPalTheme.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.done_all_outlined),
            label: const Text('Complete shopping'),
          ),
      ],
    );
  }

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    String tripId,
    String action,
    VoidCallback changed,
  ) async {
    if (!await confirmShoppingTripTransition(context, action)) return;
    try {
      await ref
          .read(sessionRepositoryProvider)
          .transitionShoppingTrip(tripId: tripId, action: action);
      changed();
    } on DioException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this shopping trip.')),
        );
      }
    }
  }

  Future<void> _showChangeDate(
    BuildContext context,
    WidgetRef ref,
    String tripId,
    VoidCallback changed,
  ) async {
    var dateIso = trip.string('scheduledFor') ?? '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change shopping date',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Changing a confirmed date returns the trip to proposal.',
              ),
              const SizedBox(height: 16),
              ScheduledDateTimeField(
                label: 'Shopping date and time',
                valueIso: dateIso,
                onChanged: (value) => setSheetState(() => dateIso = value),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (dateIso.isEmpty) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('Choose a shopping date first.'),
                      ),
                    );
                    return;
                  }
                  try {
                    await ref
                        .read(sessionRepositoryProvider)
                        .updateShoppingTripDate(
                          tripId: tripId,
                          scheduledFor: dateIso,
                        );
                    changed();
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  } on DioException {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not change the date. Try again.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save date'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShoppingItemRow extends ConsumerWidget {
  const _ShoppingItemRow({
    required this.item,
    required this.tripId,
    required this.onChanged,
  });
  final HouseholdCollectionItem item;
  final String tripId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        tooltip: 'Change item state',
        onSelected: (next) async {
          try {
            await ref
                .read(sessionRepositoryProvider)
                .updateShoppingItem(
                  tripId: tripId,
                  itemId: item.string('id')!,
                  status: next,
                );
            onChanged();
          } on DioException {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not update this item.')),
              );
            }
          }
        },
        itemBuilder: (_) => [
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
          padding: const EdgeInsets.fromLTRB(56, 0, 24, 20),
          child: ShoppingItemBreakdown(item: item),
        ),
      ],
    );
  }
}

class _TripStatus extends StatelessWidget {
  const _TripStatus({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => StickerChip(
    label: humanStatusLabel(status),
    icon: status == 'CONFIRMED'
        ? Icons.event_available_outlined
        : Icons.shopping_bag_outlined,
    color: status == 'CONFIRMED' || status == 'IN_PROGRESS'
        ? PantryPalTheme.green
        : PantryPalTheme.tomato,
  );
}

class _ShopLoading extends StatelessWidget {
  const _ShopLoading();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _ShopError extends StatelessWidget {
  const _ShopError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Could not load this shopping trip.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _ShopEmpty extends StatelessWidget {
  const _ShopEmpty();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            color: PantryPalTheme.tomato,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'No shopping trips yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Create a trip once meals are assigned, then PantryPal combines compatible ingredients.',
          ),
        ],
      ),
    ),
  );
}

class _TripItemsEmpty extends StatelessWidget {
  const _TripItemsEmpty();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Assign scheduled meals to this trip, then confirm it to generate the shared list.',
      ),
    ),
  );
}

String _tripLabel(HouseholdCollectionItem trip) {
  final date = DateTime.tryParse(trip.string('scheduledFor') ?? '');
  return date == null
      ? 'Unscheduled shopping trip'
      : '${DateFormat('EEEE').format(date)} shop · ${DateFormat('d MMM').format(date)}';
}
