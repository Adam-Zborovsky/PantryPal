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

  Future<void> _refresh() async {
    final selected = _selectedTripId;
    ref.invalidate(shopTripsProvider);
    if (selected != null) ref.invalidate(tripDetailProvider(selected));
    await ref.read(shopTripsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(shopTripsProvider);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
    final activeItems = items
        .where((item) => item.string('archivedAt') == null)
        .toList();
    final archivedItems = items
        .where((item) => item.string('archivedAt') != null)
        .toList();
    final pickedUp = activeItems
        .where((item) => item.string('pickedUpAt') != null)
        .length;
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
                    IconButton(
                      tooltip: 'Shopping item guide',
                      onPressed: () => _showShoppingGuide(context),
                      icon: const Icon(Icons.info_outline),
                    ),
                    _TripStatus(status: status),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${activeItems.length} to manage · $pickedUp picked up'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showChangeDate(context, ref, id, onChanged),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Change date'),
                ),
                if (status == 'PROPOSED' ||
                    status == 'CONFIRMED' ||
                    status == 'IN_PROGRESS') ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final added = await showAddShoppingItemSheet(
                        context,
                        tripId: id,
                      );
                      if (added) onChanged();
                    },
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Add item'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (activeItems.isEmpty)
          const _TripItemsEmpty()
        else
          Card(
            child: Column(
              children: [
                for (final item in activeItems)
                  _ShoppingItemRow(
                    item: item,
                    tripId: id,
                    onChanged: onChanged,
                  ),
              ],
            ),
          ),
        if (archivedItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              title: Text('Archived from this trip (${archivedItems.length})'),
              subtitle: const Text('Bought elsewhere or removed'),
              children: [
                for (final item in archivedItems)
                  ListTile(
                    title: Text(item.string('displayName') ?? 'Shopping item'),
                    subtitle: Text(
                      item.string('archivedReason') == 'BOUGHT_ELSEWHERE'
                          ? 'Bought elsewhere'
                          : 'Removed from trip',
                    ),
                  ),
              ],
            ),
          ),
        ],
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
        if (status == 'PROPOSED' || status == 'CONFIRMED') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _transition(context, ref, id, 'cancel', onChanged),
            style: OutlinedButton.styleFrom(
              foregroundColor: PantryPalTheme.tomato,
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel trip'),
          ),
        ],
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

Future<bool> showAddShoppingItemSheet(
  BuildContext context, {
  required String tripId,
}) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddShoppingItemSheet(tripId: tripId),
  );
  return added ?? false;
}

class _AddShoppingItemSheet extends ConsumerStatefulWidget {
  const _AddShoppingItemSheet({required this.tripId});
  final String tripId;

  @override
  ConsumerState<_AddShoppingItemSheet> createState() =>
      _AddShoppingItemSheetState();
}

class _AddShoppingItemSheetState extends ConsumerState<_AddShoppingItemSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _unit = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter an item to add.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .addShoppingItem(
            tripId: widget.tripId,
            displayName: _name.text,
            amount: _amount.text,
            unit: _unit.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add this item. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add to the shared list',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Add anything your household needs, even when it is not part of a recipe.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Item',
            hintText: 'Dish soap',
          ),
          onSubmitted: (_) => _saving ? null : _save(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '2',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  hintText: 'packs',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_shopping_cart_outlined),
          label: Text(_saving ? 'Adding item…' : 'Add item'),
        ),
      ],
    ),
  );
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
    final pickedUp = item.string('pickedUpAt') != null;
    final presentation = shoppingItemStatus(status);
    return ExpansionTile(
      leading: Checkbox(
        value: pickedUp,
        semanticLabel: pickedUp
            ? 'Mark as still needed'
            : 'Mark as picked up on this trip',
        onChanged: (_) async {
          await ref
              .read(sessionRepositoryProvider)
              .toggleShoppingItemPickedUp(
                tripId: tripId,
                itemId: item.string('id')!,
              );
          onChanged();
        },
      ),
      title: Text(
        item.string('displayName') ?? 'Shopping item',
        style: pickedUp
            ? const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
              )
            : null,
      ),
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
            if (next == 'EDIT_AMOUNT') {
              if (await _editAmount(context, ref, tripId, item, status)) {
                onChanged();
              }
              return;
            }
            if (next == 'BOUGHT_ELSEWHERE' || next == 'REMOVE') {
              if (next == 'REMOVE' && !await _confirmRemoval(context)) return;
              await ref
                  .read(sessionRepositoryProvider)
                  .archiveShoppingItem(
                    tripId: tripId,
                    itemId: item.string('id')!,
                    reason: next == 'REMOVE' ? 'REMOVED' : 'BOUGHT_ELSEWHERE',
                  );
              onChanged();
              return;
            }
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
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'EDIT_AMOUNT', child: Text('Edit amount')),
          const PopupMenuItem(
            value: 'BOUGHT_ELSEWHERE',
            child: Text('Bought elsewhere'),
          ),
          const PopupMenuItem(value: 'REMOVE', child: Text('Remove from trip')),
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

Future<bool> _editAmount(
  BuildContext context,
  WidgetRef ref,
  String tripId,
  HouseholdCollectionItem item,
  String status,
) async {
  final amount = TextEditingController(
    text: item.string('manualQuantity') ?? '',
  );
  final unit = TextEditingController(text: item.string('manualUnit') ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Edit ${item.string('displayName') ?? 'item'}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: unit,
            decoration: const InputDecoration(labelText: 'Unit'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (amount.text.trim().isEmpty) return;
            await ref
                .read(sessionRepositoryProvider)
                .updateShoppingItem(
                  tripId: tripId,
                  itemId: item.string('id')!,
                  status: status,
                  amount: amount.text,
                  unit: unit.text,
                );
            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
          },
          child: const Text('Save amount'),
        ),
      ],
    ),
  );
  amount.dispose();
  unit.dispose();
  return saved ?? false;
}

Future<bool> _confirmRemoval(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this item from the trip?'),
        content: const Text(
          'It will leave the active list and remain in this trip’s history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep item'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove item'),
          ),
        ],
      ),
    ) ??
    false;

void _showShoppingGuide(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your shopping-list key',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Each choice says what happened, so everyone stays on the same page.',
            ),
            const SizedBox(height: 20),
            const _ShoppingGuideRow(
              icon: Icons.add_shopping_cart_outlined,
              title: 'Buy',
              detail: 'Still needed for this trip.',
              color: PantryPalTheme.tomato,
            ),
            const _ShoppingGuideRow(
              icon: Icons.inventory_2_outlined,
              title: 'Already have it',
              detail: 'The household has enough at home.',
              color: PantryPalTheme.green,
            ),
            const _ShoppingGuideRow(
              icon: Icons.pie_chart_outline,
              title: 'Got some',
              detail: 'Edit the amount that is still needed.',
              color: PantryPalTheme.amber,
            ),
            const _ShoppingGuideRow(
              icon: Icons.check_box_outlined,
              title: 'Picked up on this trip',
              detail:
                  'Check the box. The item stays visible and can be unchecked.',
              color: PantryPalTheme.ink,
            ),
            const _ShoppingGuideRow(
              icon: Icons.archive_outlined,
              title: 'Bought elsewhere',
              detail: 'Archives one item because it is no longer needed here.',
              color: PantryPalTheme.green,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShoppingGuideRow extends StatelessWidget {
  const _ShoppingGuideRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(detail),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
