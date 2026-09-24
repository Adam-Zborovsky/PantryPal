import 'package:flutter/material.dart';

import '../shared/status_tone.dart';

export '../shared/status_tone.dart';

class ShoppingItemStatusPresentation {
  const ShoppingItemStatusPresentation({
    required this.label,
    required this.icon,
    required this.colorRole,
  });

  final String label;
  final IconData icon;
  final StatusColorRole colorRole;
}

/// Maps a raw shopping-item status to the words, glyph, and color role a
/// person should see. Never surface the enum itself in the UI.
ShoppingItemStatusPresentation shoppingItemStatus(String status) =>
    switch (status) {
      'CONFIRMED_AT_HOME' => const ShoppingItemStatusPresentation(
        label: 'Already have it',
        icon: Icons.inventory_2_outlined,
        colorRole: StatusColorRole.positive,
      ),
      'CHECK_AGAIN' => const ShoppingItemStatusPresentation(
        label: 'Check pantry',
        icon: Icons.help_outline,
        colorRole: StatusColorRole.attention,
      ),
      'PARTIALLY_AVAILABLE' => const ShoppingItemStatusPresentation(
        label: 'Got some',
        icon: Icons.pie_chart_outline,
        colorRole: StatusColorRole.attention,
      ),
      _ => const ShoppingItemStatusPresentation(
        label: 'Buy',
        icon: Icons.add_shopping_cart_outlined,
        colorRole: StatusColorRole.active,
      ),
    };

const shoppingItemStatuses = <String>[
  'NEED_TO_BUY',
  'CONFIRMED_AT_HOME',
  'CHECK_AGAIN',
  'PARTIALLY_AVAILABLE',
];
