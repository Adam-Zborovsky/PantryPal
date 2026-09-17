import 'package:flutter/material.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import 'recipe_actions.dart' show validateServings;

const _tabular = [FontFeature.tabularFigures()];

/// Expand/collapse timing for sections and rows; zero when the platform asks
/// for reduced motion.
Duration _disclosureDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 200);

Color _lineColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? PantryPalTheme.darkLine
    : PantryPalTheme.line;

/// "2 cups", "1–2 tbsp", "3", or "" when the ingredient has no amount.
String _ingredientAmountLabel(RecipeReviewIngredient ingredient) {
  final min = ingredient.quantityMin.trim();
  final max = ingredient.quantityMax.trim();
  final unit = ingredient.originalUnit.trim();
  final amount = min.isEmpty
      ? max
      : max.isEmpty || max == min
      ? min
      : '$min–$max';
  return [amount, unit].where((part) => part.isNotEmpty).join(' ');
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: expanded ? 0.5 : 0,
    duration: _disclosureDuration(context),
    curve: Curves.easeOutCubic,
    child: Icon(
      Icons.expand_more,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// Grows or shrinks to show [child] only while [expanded].
class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.expanded, required this.child});
  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: _disclosureDuration(context),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: expanded ? child : const SizedBox(width: double.infinity),
  );
}

/// A bordered card whose header toggles its hairline-separated [rows].
class CollapsibleSection extends StatelessWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.emptyText,
    required this.rows,
  });
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final String emptyText;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final line = _lineColor(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            button: true,
            expanded: expanded,
            label: '$title, $count',
            excludeSemantics: true,
            // excludeSemantics drops the InkWell's tap action; expose it here.
            onTap: onToggle,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 10),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w700,
                        fontFeatures: _tabular,
                      ),
                    ),
                    const Spacer(),
                    _Chevron(expanded: expanded),
                  ],
                ),
              ),
            ),
          ),
          _Disclosure(
            expanded: expanded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(height: 1, thickness: 1, color: line),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(emptyText, style: TextStyle(color: muted)),
                  )
                else
                  for (var i = 0; i < rows.length; i++) ...[
                    rows[i],
                    if (i != rows.length - 1)
                      Divider(height: 1, thickness: 1, color: line),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One ingredient: a compact amount/name summary that expands to its edit
/// fields.
class IngredientRow extends StatelessWidget {
  const IngredientRow({
    super.key,
    required this.ingredient,
    required this.fieldKey,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });
  final RecipeReviewIngredient ingredient;
  final String fieldKey;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final amount = _ingredientAmountLabel(ingredient);
    final name = ingredient.name.trim();
    final note = ingredient.preparationNote.trim();
    final summary = [
      amount,
      name.isEmpty ? 'Unnamed ingredient' : name,
    ].where((part) => part.isNotEmpty).join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          button: true,
          expanded: expanded,
          label: note.isEmpty ? summary : '$summary, $note',
          excludeSemantics: true,
          onTap: onToggle,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 72,
                      maxWidth: 128,
                    ),
                    child: Text(
                      amount,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Unnamed ingredient' : name,
                          style: textTheme.bodyLarge?.copyWith(
                            color: name.isEmpty ? muted : null,
                          ),
                        ),
                        if (note.isNotEmpty)
                          Text(
                            note,
                            style: textTheme.bodyMedium?.copyWith(color: muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Chevron(expanded: expanded),
                ],
              ),
            ),
          ),
        ),
        _Disclosure(
          expanded: expanded,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _IngredientFields(
              ingredient: ingredient,
              fieldKey: fieldKey,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _IngredientFields extends StatelessWidget {
  const _IngredientFields({
    required this.ingredient,
    required this.fieldKey,
    required this.onChanged,
  });
  final RecipeReviewIngredient ingredient;
  final String fieldKey;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    const amountKeyboard = TextInputType.numberWithOptions(decimal: true);
    const amountStyle = TextStyle(fontFeatures: _tabular);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('$fieldKey-min'),
                initialValue: ingredient.quantityMin,
                keyboardType: amountKeyboard,
                style: amountStyle,
                decoration: const InputDecoration(labelText: 'Amount'),
                onChanged: (value) {
                  ingredient.quantityMin = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: ValueKey('$fieldKey-max'),
                initialValue: ingredient.quantityMax,
                keyboardType: amountKeyboard,
                style: amountStyle,
                decoration: const InputDecoration(
                  labelText: 'Up to',
                  hintText: 'Optional',
                ),
                onChanged: (value) {
                  ingredient.quantityMax = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: ValueKey('$fieldKey-unit'),
                initialValue: ingredient.originalUnit,
                decoration: const InputDecoration(labelText: 'Unit'),
                onChanged: (value) {
                  ingredient.originalUnit = value;
                  onChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('$fieldKey-name'),
          initialValue: ingredient.name,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (value) {
            ingredient.name = value;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('$fieldKey-note'),
          initialValue: ingredient.preparationNote,
          decoration: const InputDecoration(
            labelText: 'Note',
            hintText: 'Chopped, softened, to taste',
          ),
          onChanged: (value) {
            ingredient.preparationNote = value;
            onChanged();
          },
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Add to shopping list'),
          value: ingredient.includeInShopping,
          onChanged: (value) {
            ingredient.includeInShopping = value;
            onChanged();
          },
        ),
      ],
    );
  }
}

/// One method step: its first line, expanding to full text and an edit field.
class StepRow extends StatelessWidget {
  const StepRow({
    super.key,
    required this.number,
    required this.text,
    required this.fieldKey,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });
  final int number;
  final String text;
  final String fieldKey;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final empty = text.trim().isEmpty;
    final firstLine = empty ? 'Empty step' : text.trim().split('\n').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          button: true,
          expanded: expanded,
          label: 'Step $number, $firstLine',
          excludeSemantics: true,
          onTap: onToggle,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$number',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      empty ? 'Empty step' : text,
                      maxLines: expanded ? null : 1,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: empty ? muted : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Chevron(expanded: expanded),
                ],
              ),
            ),
          ),
        ),
        _Disclosure(
          expanded: expanded,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: TextFormField(
              key: ValueKey('$fieldKey-text'),
              initialValue: text,
              minLines: 2,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(labelText: 'Step $number'),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// The recipe's original servings: "Serves N" (or "Servings not set") that
/// expands to a single decimal field. [trailing] sits beside the summary.
class ServingsRow extends StatelessWidget {
  const ServingsRow({
    super.key,
    required this.servings,
    required this.fieldKey,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
    this.trailing,
  });
  final String servings;
  final String fieldKey;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final value = servings.trim();
    final label = value.isEmpty ? 'Servings not set' : 'Serves $value';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              container: true,
              button: true,
              expanded: expanded,
              label: label,
              excludeSemantics: true,
              onTap: onToggle,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(13),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 4, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontFeatures: _tabular),
                      ),
                      const SizedBox(width: 4),
                      _Chevron(expanded: expanded),
                    ],
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        _Disclosure(
          expanded: expanded,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: TextFormField(
                  key: ValueKey('$fieldKey-servings'),
                  initialValue: servings,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontFeatures: _tabular),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (text) => (text ?? '').trim().isEmpty
                      ? null
                      : validateServings(text),
                  decoration: const InputDecoration(labelText: 'Servings'),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
