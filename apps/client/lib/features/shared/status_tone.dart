import 'package:flutter/material.dart';

import '../../app.dart';

/// Semantic color role for a status. Never derive these from seeds; the
/// mapping below is the single source of truth (see DESIGN.md).
enum StatusColorRole { positive, attention, active, neutral }

Color statusToneColor(BuildContext context, StatusColorRole role) =>
    switch (role) {
      StatusColorRole.positive => PantryPalTheme.green,
      StatusColorRole.attention => PantryPalTheme.amber,
      StatusColorRole.active => PantryPalTheme.tomato,
      StatusColorRole.neutral => Theme.of(context).colorScheme.outline,
    };

/// Human wording for trip, cooking-instance, and recipe readiness statuses.
/// Never show the raw enum in the UI.
String humanStatusLabel(String status) => switch (status) {
  'SCHEDULED' => 'Planned',
  'PROPOSED' => 'Proposal',
  'CONFIRMED' => 'Confirmed',
  'IN_PROGRESS' => 'In progress',
  'COMPLETED' => 'Completed',
  'ARCHIVED' => 'Archived',
  'SHOPPING_READY' => 'Ready to shop',
  'COOK_READY' => 'Ready to cook',
  'NEEDS_REVIEW' => 'Needs review',
  'DRAFT' => 'Draft',
  _ => status.replaceAll('_', ' ').toLowerCase(),
};
