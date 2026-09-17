import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/session_repository.dart';
import '../home/app_shell.dart' show householdCollectionProvider;
import '../planning/plan_page.dart' show planProvider;
import '../shared/trip_picker.dart';
import '../trips/shop_page.dart' show shopTripsProvider, tripDetailProvider;

const _openTripStatuses = {'PROPOSED', 'CONFIRMED', 'IN_PROGRESS'};

/// How many days past today a meal can be planned; matches the Plan strip.
const _planHorizonDays = 20;

/// Opens the "Add to shopping trip" sheet for a saved recipe.
Future<void> showAddToTripSheet(
  BuildContext context, {
  required String recipeId,
  required String originalServings,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _AddToTripSheet(
    recipeId: recipeId,
    originalServings: originalServings.trim(),
  ),
);

/// Opens the "Plan a meal" sheet for a saved recipe.
Future<void> showPlanMealSheet(
  BuildContext context, {
  required String recipeId,
  required String originalServings,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _PlanMealSheet(
    recipeId: recipeId,
    originalServings: originalServings.trim(),
  ),
);

/// Null for a positive decimal such as "4" or "2.5", otherwise the fix.
String? validateServings(String? value) {
  final text = (value ?? '').trim();
  final valid =
      RegExp(r'^\d+(\.\d+)?$').hasMatch(text) && double.parse(text) > 0;
  return valid ? null : 'Use a number above 0, like 4 or 2.5.';
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _ServingsField extends StatelessWidget {
  const _ServingsField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    validator: validateServings,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: const InputDecoration(labelText: 'Servings'),
  );
}

class _AddToTripSheet extends ConsumerStatefulWidget {
  const _AddToTripSheet({
    required this.recipeId,
    required this.originalServings,
  });
  final String recipeId;
  final String originalServings;

  @override
  ConsumerState<_AddToTripSheet> createState() => _AddToTripSheetState();
}

class _AddToTripSheetState extends ConsumerState<_AddToTripSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _servings = TextEditingController(text: widget.originalServings);
  String? _tripId;
  bool _missingTrip = false;
  bool _submitting = false;

  @override
  void dispose() {
    _servings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Add to shopping trip';
    if (widget.originalServings.isEmpty) {
      return const _SheetFrame(
        title: title,
        children: [
          Text('Set the recipe’s servings before adding it to a trip.'),
        ],
      );
    }
    final trips = ref.watch(householdCollectionProvider('Shop'));
    return trips.when(
      loading: () => const _SheetFrame(
        title: title,
        children: [
          SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (_, _) => _SheetFrame(
        title: title,
        children: [
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
            .where((trip) => _openTripStatuses.contains(trip.string('status')))
            .toList();
        if (openTrips.isEmpty) {
          return const _SheetFrame(
            title: title,
            children: [Text('No open shopping trips. Create one in Shop.')],
          );
        }
        return _SheetFrame(
          title: title,
          children: [
            TripPicker(
              trips: openTrips,
              selectedTripId: _tripId,
              mealDate: null,
              onChanged: (value) => setState(() {
                _tripId = value;
                _missingTrip = false;
              }),
            ),
            if (_missingTrip)
              Text(
                'Choose a shopping trip.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: _ServingsField(controller: _servings),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Adding…' : 'Add to trip'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    final servingsValid = _formKey.currentState?.validate() ?? false;
    setState(() => _missingTrip = _tripId == null);
    final tripId = _tripId;
    if (!servingsValid || tripId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _submitting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .createCookingInstance(
            recipeId: widget.recipeId,
            targetServings: _servings.text,
            shoppingTripId: tripId,
          );
      ref.invalidate(householdCollectionProvider('Shop'));
      ref.invalidate(householdCollectionProvider('Plan'));
      ref.invalidate(planProvider);
      ref.invalidate(shopTripsProvider);
      ref.invalidate(tripDetailProvider);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Added to your shopping trip.')),
      );
    } catch (error) {
      if (error is! DioException && error is! StateError) rethrow;
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not add this recipe to the trip. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _PlanMealSheet extends ConsumerStatefulWidget {
  const _PlanMealSheet({
    required this.recipeId,
    required this.originalServings,
  });
  final String recipeId;
  final String originalServings;

  @override
  ConsumerState<_PlanMealSheet> createState() => _PlanMealSheetState();
}

class _PlanMealSheetState extends ConsumerState<_PlanMealSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _servings = TextEditingController(text: widget.originalServings);
  late final DateTime _today = _dateOnly(DateTime.now());
  late DateTime _day = _today;
  bool _submitting = false;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  void dispose() {
    _servings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Plan a meal';
    if (widget.originalServings.isEmpty) {
      return const _SheetFrame(
        title: title,
        children: [Text('Set the recipe’s servings before planning a meal.')],
      );
    }
    final dayLabel = DateFormat('EEEE, d MMMM').format(_day);
    return _SheetFrame(
      title: title,
      children: [
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: 'Day, $dayLabel',
          hint: 'Choose a different day',
          excludeSemantics: true,
          onTap: _pickDay,
          child: InkWell(
            onTap: _pickDay,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Day',
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              child: Text(dayLabel),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: _ServingsField(controller: _servings),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Adding meal…' : 'Add meal'),
        ),
      ],
    );
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: _planHorizonDays)),
    );
    if (picked != null && mounted) setState(() => _day = _dateOnly(picked));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final cookingAt = DateTime(_day.year, _day.month, _day.day, 18);
    setState(() => _submitting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .createCookingInstance(
            recipeId: widget.recipeId,
            targetServings: _servings.text,
            cookingDate: cookingAt.toUtc().toIso8601String(),
          );
      ref.invalidate(planProvider);
      ref.invalidate(householdCollectionProvider('Plan'));
      // A dated meal can be assigned to a confirmed trip automatically.
      ref.invalidate(shopTripsProvider);
      ref.invalidate(tripDetailProvider);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Meal added to your plan.')),
      );
    } catch (error) {
      if (error is! DioException && error is! StateError) rethrow;
      if (mounted) {
        messenger.showSnackBar(
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
