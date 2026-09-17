import 'package:flutter/material.dart';

import '../auth/session_repository.dart';
import 'shopping_amounts.dart';

const _tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

/// Expanded content for a shopping item: exact totals, each recipe's original
/// amount, and a note when the estimate relies on typical conversions.
class ShoppingItemBreakdown extends StatelessWidget {
  const ShoppingItemBreakdown({super.key, required this.item});

  final HouseholdCollectionItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final exact = exactSummary(
      demandFrom(item.values),
      unmeasured: item.values['unmeasured'] == true,
    );
    final rawContributions = item.values['contributions'];
    final contributions = rawContributions is List
        ? rawContributions.whereType<Map>().toList()
        : const <Map>[];
    final estimate = estimateFrom(item.values);
    final note = estimate == null
        ? null
        : crossDimensionNote(
            estimate,
            item.string('displayName') ?? 'this item',
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exact.isNotEmpty) ...[
          Text('Exact amounts', style: textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(exact, style: _tabular),
          const SizedBox(height: 12),
        ],
        if (contributions.isEmpty)
          const Text('No recipe contribution recorded.')
        else
          for (final contribution in contributions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${contribution['recipeTitle'] ?? 'Recipe'}'),
                  ),
                  const SizedBox(width: 12),
                  Text(contributionAmount(contribution), style: _tabular),
                ],
              ),
            ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note, style: textTheme.bodySmall),
        ],
      ],
    );
  }
}
