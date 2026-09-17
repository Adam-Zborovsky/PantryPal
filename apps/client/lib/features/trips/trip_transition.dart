import 'package:flutter/material.dart';

/// Asks for explicit confirmation before an irreversible shopping-trip
/// transition (confirm / start / complete). Returns true only when the user
/// accepted.
Future<bool> confirmShoppingTripTransition(
  BuildContext context,
  String action,
) async {
  final spec = switch (action) {
    'confirm' => (
      'Confirm this shopping date?',
      'The trip moves from proposal to confirmed so the household can rely on it.',
      'Confirm date',
    ),
    'start' => (
      'Start this shopping trip?',
      'The shared list becomes the active shopping run.',
      'Start shopping',
    ),
    _ => (
      'Complete this shopping trip?',
      'The trip closes as completed.',
      'Complete',
    ),
  };
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(spec.$1),
      content: Text(spec.$2),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(spec.$3),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
