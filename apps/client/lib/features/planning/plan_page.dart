import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import '../home/app_shell.dart' show householdCollectionProvider;
import '../shared/scheduling.dart';
import '../shared/sticker_chip.dart';
import '../shared/trip_picker.dart';
import '../trips/shop_page.dart' show shopTripsProvider, tripDetailProvider;

final planProvider = FutureProvider<List<HouseholdCollectionItem>>(
  (ref) => ref.read(sessionRepositoryProvider).cookingInstances(),
);
const _openTripStatuses = {'PROPOSED', 'CONFIRMED', 'IN_PROGRESS'};

final _recipesProvider = FutureProvider<List<HouseholdCollectionItem>>(
  (ref) => ref.read(sessionRepositoryProvider).recipes(),
);

class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key});

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  late final List<DateTime> _days;
  var _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = List.generate(21, (index) => today.add(Duration(days: index)));
  }

  Future<void> _refresh() async {
    ref.invalidate(planProvider);
    ref.invalidate(shopTripsProvider);
    await ref.read(planProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(planProvider);
    final selected = _days[_selectedDay];
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
                Text('Plan', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 4),
                const Text('See what is cooking and who is responsible.'),
                const SizedBox(height: 20),
                _PlanStrip(
                  days: _days,
                  selectedIndex: _selectedDay,
                  onSelected: (index) => setState(() => _selectedDay = index),
                ),
                const SizedBox(height: 24),
                Text(
                  DateFormat('EEEE, d MMMM').format(selected),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                entries.when(
                  loading: () => const _PlanLoading(),
                  error: (_, _) =>
                      _PlanError(onRetry: () => ref.invalidate(planProvider)),
                  data: (items) {
                    final scheduled = _forDay(items, selected);
                    if (scheduled.isEmpty) return const _PlanEmpty();
                    return Column(
                      children: [
                        for (final item in scheduled) ...[
                          _MealCard(
                            item: item,
                            onOpen: () => _showMealDetail(context, item),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _showAddMeal(context, selected),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add meal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<HouseholdCollectionItem> _forDay(
    List<HouseholdCollectionItem> items,
    DateTime day,
  ) =>
      items.where((item) {
        if (item.string('status') != 'SCHEDULED') return false;
        final cookingDate = tryParseScheduled(item.string('cookingDate'));
        return cookingDate != null &&
            cookingDate.year == day.year &&
            cookingDate.month == day.month &&
            cookingDate.day == day.day;
      }).toList()..sort(
        (left, right) => (left.string('cookingDate') ?? '').compareTo(
          right.string('cookingDate') ?? '',
        ),
      );

  Future<void> _showMealDetail(
    BuildContext context,
    HouseholdCollectionItem item,
  ) async {
    final id = item.string('id');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _MealDetailSheet(
        item: item,
        onMarkCooked: id == null
            ? null
            : () async {
                final confirmed = await showDialog<bool>(
                  context: sheetContext,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Mark this meal cooked?'),
                    content: const Text(
                      'It will move to the archive as an immutable historical snapshot.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Mark cooked'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                try {
                  await ref.read(sessionRepositoryProvider).markCooked(id);
                  ref.invalidate(planProvider);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                } on DioException {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not archive this meal. Try again.',
                        ),
                      ),
                    );
                  }
                }
              },
      ),
    );
  }

  Future<void> _showAddMeal(BuildContext context, DateTime day) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _AddMealSheet(day: day),
      );
}

/// Three swipeable weeks of [_DateStrip] (7 days each) with a week label,
/// previous/next controls for non-swipe users, and page dots. Swiping never
/// changes the selected day; only tapping a cell does.
class _PlanStrip extends StatefulWidget {
  const _PlanStrip({
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<DateTime> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_PlanStrip> createState() => _PlanStripState();
}

class _PlanStripState extends State<_PlanStrip> {
  static const _weekLabels = ['This week', 'Next week', 'In 2 weeks'];
  late final PageController _controller;
  var _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _pageCount => (widget.days.length / 7).ceil();

  void _goToPage(int page) {
    final target = page.clamp(0, _pageCount - 1);
    if (target == _pageIndex) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(target);
    } else {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _weekLabels[_pageIndex.clamp(0, _weekLabels.length - 1)],
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Previous week',
              onPressed: _pageIndex == 0
                  ? null
                  : () => _goToPage(_pageIndex - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Next week',
              onPressed: _pageIndex >= pageCount - 1
                  ? null
                  : () => _goToPage(_pageIndex + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          // Grows with the user's text size so day cells never clip.
          height: MediaQuery.textScalerOf(context).scale(76),
          child: PageView.builder(
            controller: _controller,
            itemCount: pageCount,
            onPageChanged: (page) => setState(() => _pageIndex = page),
            itemBuilder: (context, page) {
              final start = page * 7;
              final end = (start + 7).clamp(0, widget.days.length);
              final pageDays = widget.days.sublist(start, end);
              final localSelected = widget.selectedIndex - start;
              return _DateStrip(
                days: pageDays,
                selectedIndex:
                    localSelected >= 0 && localSelected < pageDays.length
                    ? localSelected
                    : -1,
                onSelected: (index) => widget.onSelected(start + index),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Week ${_pageIndex + 1} of $pageCount',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pageCount; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _pageIndex
                          ? PantryPalTheme.tomato
                          : PantryPalTheme.line,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<DateTime> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Cooking date selector',
    child: Row(
      children: [
        for (var index = 0; index < days.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == days.length - 1 ? 0 : 4),
              child: _DateCell(
                day: days[index],
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
            ),
          ),
      ],
    ),
  );
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: DateFormat('EEEE, d MMMM').format(day),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: selected ? PantryPalTheme.tomato : Colors.transparent,
          border: Border.all(
            color: selected ? PantryPalTheme.tomato : PantryPalTheme.line,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(day).substring(0, 1),
              style: TextStyle(color: selected ? Colors.white : null),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.item, required this.onOpen});
  final HouseholdCollectionItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final snapshot = item.values['recipeSnapshot'];
    final title = snapshot is Map && snapshot['title'] is String
        ? snapshot['title'] as String
        : 'Planned meal';
    final date = tryParseScheduled(item.string('cookingDate'));
    final pending = item.string('pendingCookAccountId') != null;
    return Semantics(
      button: true,
      label: '$title, ${pending ? 'cook handoff pending' : 'cook confirmed'}',
      child: Card(
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(PantryPalTheme.radius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PantryPalTheme.tomato.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.soup_kitchen_outlined,
                    color: PantryPalTheme.tomato,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (date != null) DateFormat('h:mm a').format(date),
                          if (item.string('targetServings') != null)
                            'Serves ${item.string('targetServings')}',
                        ].join(' · '),
                      ),
                      const SizedBox(height: 8),
                      _ResponsibilityChip(pending: pending),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponsibilityChip extends StatelessWidget {
  const _ResponsibilityChip({required this.pending});
  final bool pending;

  @override
  Widget build(BuildContext context) => StickerChip(
    label: pending ? 'Handoff pending' : 'Cook confirmed',
    color: pending ? PantryPalTheme.amber : PantryPalTheme.green,
    icon: pending ? Icons.schedule_outlined : Icons.check_circle_outline,
  );
}

class _MealDetailSheet extends ConsumerWidget {
  const _MealDetailSheet({required this.item, required this.onMarkCooked});
  final HouseholdCollectionItem item;
  final Future<void> Function()? onMarkCooked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = item.values['recipeSnapshot'];
    final title = snapshot is Map && snapshot['title'] is String
        ? snapshot['title'] as String
        : 'Planned meal';
    final date = tryParseScheduled(item.string('cookingDate'));
    final tripId = item.string('shoppingTripId');
    final cookingInstanceId = item.string('id');
    final canChangeTrip =
        item.string('status') == 'SCHEDULED' && cookingInstanceId != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.people_outline,
            label: 'Servings',
            value: item.string('targetServings') ?? 'Not recorded',
          ),
          _DetailRow(
            icon: Icons.schedule_outlined,
            label: 'Cooking time',
            value: date == null
                ? 'Not scheduled'
                : DateFormat('EEE, d MMM · h:mm a').format(date),
          ),
          _TripDetailRow(tripId: tripId),
          if (canChangeTrip)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showChangeTripSheet(
                    context,
                    cookingInstanceId: cookingInstanceId,
                    currentTripId: tripId,
                    mealDate: date,
                  );
                },
                child: const Text('Change trip'),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Meal details are based on the saved recipe snapshot.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onMarkCooked == null ? null : () => onMarkCooked!(),
            style: FilledButton.styleFrom(
              backgroundColor: PantryPalTheme.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.done_outline),
            label: const Text('Mark cooked'),
          ),
        ],
      ),
    );
  }
}

/// Shows the meal's current shopping trip, formatted, or that it needs one.
class _TripDetailRow extends ConsumerWidget {
  const _TripDetailRow({required this.tripId});
  final String? tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(householdCollectionProvider('Shop'));
    final value = trips.when(
      loading: () =>
          tripId == null ? 'Needs a shopping trip' : 'Checking trip…',
      error: (_, _) =>
          tripId == null ? 'Needs a shopping trip' : 'Linked to this meal',
      data: (items) {
        final trip = items
            .where((candidate) => candidate.string('id') == tripId)
            .firstOrNull;
        // A cancelled, completed, or missing trip no longer shops for the meal.
        return trip == null ||
                !_openTripStatuses.contains(trip.string('status'))
            ? 'Needs a shopping trip'
            : tripPickerLabel(trip);
      },
    );
    return _DetailRow(
      icon: Icons.shopping_bag_outlined,
      label: 'Shopping trip',
      value: value,
    );
  }
}

void _showChangeTripSheet(
  BuildContext context, {
  required String cookingInstanceId,
  required String? currentTripId,
  required DateTime? mealDate,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ChangeTripSheet(
      cookingInstanceId: cookingInstanceId,
      currentTripId: currentTripId,
      mealDate: mealDate,
    ),
  );
}

class _ChangeTripSheet extends ConsumerStatefulWidget {
  const _ChangeTripSheet({
    required this.cookingInstanceId,
    required this.currentTripId,
    required this.mealDate,
  });
  final String cookingInstanceId;
  final String? currentTripId;
  final DateTime? mealDate;

  @override
  ConsumerState<_ChangeTripSheet> createState() => _ChangeTripSheetState();
}

class _ChangeTripSheetState extends ConsumerState<_ChangeTripSheet> {
  /// The member's pick; until they choose, the meal's trip if it is open.
  String? _chosenTripId;
  var _chosen = false;
  var _submitting = false;

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(householdCollectionProvider('Shop'));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: trips.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change trip',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Could not load your shopping trips.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(householdCollectionProvider('Shop')),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (items) {
          final openTrips = items
              .where(
                (trip) => _openTripStatuses.contains(trip.string('status')),
              )
              .toList();
          final currentIsOpen = openTrips.any(
            (trip) => trip.string('id') == widget.currentTripId,
          );
          final selectedTripId = _chosen
              ? _chosenTripId
              : currentIsOpen
              ? widget.currentTripId
              : null;
          final unchanged = selectedTripId == widget.currentTripId;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change trip',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                if (openTrips.isEmpty)
                  const Text('No open shopping trips. Create one in Shop.'),
                TripPicker(
                  trips: openTrips,
                  selectedTripId: selectedTripId,
                  mealDate: widget.mealDate,
                  allowNone: true,
                  onChanged: (value) => setState(() {
                    _chosen = true;
                    _chosenTripId = value;
                  }),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting || unchanged
                      ? null
                      : () => _save(selectedTripId),
                  child: Text(_submitting ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(String? shoppingTripId) async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .assignCookingTrip(
            cookingInstanceId: widget.cookingInstanceId,
            shoppingTripId: shoppingTripId,
          );
      ref.invalidate(planProvider);
      ref.invalidate(householdCollectionProvider('Shop'));
      // Both the old and the new trip's lists change.
      ref.invalidate(shopTripsProvider);
      ref.invalidate(tripDetailProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Shopping trip updated.')));
      }
    } catch (error) {
      if (error is! DioException && error is! StateError) rethrow;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update the shopping trip. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _AddMealSheet extends ConsumerStatefulWidget {
  const _AddMealSheet({required this.day});
  final DateTime day;

  @override
  ConsumerState<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<_AddMealSheet> {
  final _servings = TextEditingController(text: '2');
  String? _recipeId;
  var _submitting = false;

  @override
  void dispose() {
    _servings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(_recipesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: recipes.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add meal', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Could not load your recipes.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(_recipesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (recipes) {
          if (recipes.isEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add meal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Import and review a recipe before adding a meal.'),
              ],
            );
          }
          final selected =
              recipes.any((recipe) => recipe.string('id') == _recipeId)
              ? _recipeId
              : recipes.first.string('id');
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add meal',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Plan a meal for ${DateFormat('EEEE, d MMMM').format(widget.day)}.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Recipe',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
                items: [
                  for (final recipe in recipes)
                    DropdownMenuItem(
                      value: recipe.string('id'),
                      child: Text(recipe.string('title') ?? 'Untitled recipe'),
                    ),
                ],
                onChanged: (value) => setState(() => _recipeId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _servings,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Servings',
                  helperText:
                      'Use a positive number. You can adjust this later.',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : () => _save(selected),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(_submitting ? 'Adding meal…' : 'Add meal'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(String? selectedRecipeId) async {
    final recipeId = _recipeId ?? selectedRecipeId;
    if (recipeId == null || _servings.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final cookingAt = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      18,
    );
    try {
      await ref
          .read(sessionRepositoryProvider)
          .createCookingInstance(
            recipeId: recipeId,
            targetServings: _servings.text,
            cookingDate: cookingAt.toUtc().toIso8601String(),
          );
      ref.invalidate(planProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal added to your plan.')),
        );
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not add this meal. Check the servings and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, color: PantryPalTheme.tomato),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    ),
  );
}

class _PlanLoading extends StatelessWidget {
  const _PlanLoading();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _PlanError extends StatelessWidget {
  const _PlanError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Could not load your cooking plan.'),
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

class _PlanEmpty extends StatelessWidget {
  const _PlanEmpty();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            color: PantryPalTheme.tomato,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing planned for this day',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a reviewed recipe from Recipes to schedule the next meal.',
          ),
        ],
      ),
    ),
  );
}
