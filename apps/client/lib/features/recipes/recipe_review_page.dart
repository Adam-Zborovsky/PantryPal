import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import '../shared/sticker_chip.dart';

class RecipeReviewPage extends ConsumerStatefulWidget {
  /// Pops with `true` once the review is saved.
  const RecipeReviewPage({super.key, required this.recipeId});
  final String recipeId;

  @override
  ConsumerState<RecipeReviewPage> createState() => _RecipeReviewPageState();
}

class _RecipeReviewPageState extends ConsumerState<RecipeReviewPage> {
  RecipeReview? _review;
  Object? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final review = await ref
          .read(sessionRepositoryProvider)
          .recipeReview(widget.recipeId);
      if (mounted) setState(() => _review = review);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final review = _review;
    if (review == null || _saving) return;
    if (review.title.trim().isEmpty ||
        review.ingredients.any((item) => item.name.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a title and a name for every ingredient before saving.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(sessionRepositoryProvider)
          .saveRecipeReview(review);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.readiness == 'SHOPPING_READY'
                ? 'Recipe is ready for shopping.'
                : 'Review saved.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Could not save this review.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    return Scaffold(
      appBar: AppBar(title: const Text('Review recipe')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : review == null
          ? _LoadFailure(error: _error, onRetry: _load)
          : _ReviewForm(
              review: review,
              saving: _saving,
              onChanged: () => setState(() {}),
              onSave: _save,
            ),
    );
  }
}

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.review,
    required this.saving,
    required this.onChanged,
    required this.onSave,
  });
  final RecipeReview review;
  final bool saving;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 880;
    final editor = _Editor(review: review, onChanged: onChanged);
    final evidence = _EvidencePanel(review: review);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Check the details',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep what was found, correct what is uncertain, then save a new recipe version.',
              ),
              const SizedBox(height: 20),
              _CompletenessMeter(completeness: review.completeness),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: editor),
                    const SizedBox(width: 24),
                    SizedBox(width: 300, child: evidence),
                  ],
                )
              else ...[
                editor,
                const SizedBox(height: 20),
                evidence,
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(saving ? 'Saving review…' : 'Save recipe review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletenessMeter extends StatelessWidget {
  const _CompletenessMeter({required this.completeness});
  final RecipeCompleteness completeness;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (completeness.extracted, PantryPalTheme.green, 'Extracted'),
      (completeness.manual, PantryPalTheme.tomato, 'You corrected'),
      (
        completeness.missing,
        Theme.of(context).colorScheme.error,
        'Still needed',
      ),
    ];
    return Semantics(
      label:
          '${completeness.extracted}% extracted, ${completeness.manual}% supplied by you, ${completeness.missing}% still needed',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recipe completeness',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      for (final part in parts)
                        if (part.$1 > 0)
                          Expanded(
                            flex: part.$1,
                            child: ColoredBox(color: part.$2),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final part in parts)
                    Text(
                      '${part.$3} ${part.$1}%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.review, required this.onChanged});
  final RecipeReview review;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Section(
        title: 'Recipe basics',
        child: Column(
          children: [
            TextFormField(
              initialValue: review.title,
              onChanged: (value) {
                review.title = value;
                onChanged();
              },
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Recipe title'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: review.originalServings,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      review.originalServings = value;
                      onChanged();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Original servings',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: review.yieldWording,
                    onChanged: (value) {
                      review.yieldWording = value;
                      onChanged();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Yield wording',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _Section(
        title: 'Ingredients',
        trailing: TextButton.icon(
          onPressed: () {
            review.ingredients.add(
              RecipeReviewIngredient(
                name: '',
                quantityMin: '',
                quantityMax: '',
                originalUnit: '',
                preparationNote: '',
                classification: 'REQUIRED',
                includeInShopping: true,
                originalText: '',
              ),
            );
            onChanged();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add ingredient'),
        ),
        child: Column(
          children: [
            for (var index = 0; index < review.ingredients.length; index++) ...[
              _IngredientEditor(
                ingredient: review.ingredients[index],
                number: index + 1,
                onDelete: review.ingredients.length == 1
                    ? null
                    : () {
                        review.ingredients.removeAt(index);
                        onChanged();
                      },
                onChanged: onChanged,
              ),
              if (index < review.ingredients.length - 1)
                const Divider(height: 32),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      _Section(
        title: 'Method',
        trailing: TextButton.icon(
          onPressed: () {
            review.instructions.add('');
            onChanged();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add step'),
        ),
        child: Column(
          children: [
            for (var index = 0; index < review.instructions.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: review.instructions[index],
                        maxLines: 3,
                        minLines: 2,
                        onChanged: (value) {
                          review.instructions[index] = value;
                          onChanged();
                        },
                        decoration: InputDecoration(
                          labelText: 'Step ${index + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove step ${index + 1}',
                      onPressed: review.instructions.length == 1
                          ? null
                          : () {
                              review.instructions.removeAt(index);
                              onChanged();
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _IngredientEditor extends StatelessWidget {
  const _IngredientEditor({
    required this.ingredient,
    required this.number,
    required this.onChanged,
    this.onDelete,
  });
  final RecipeReviewIngredient ingredient;
  final int number;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            'Ingredient $number',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Remove ingredient $number',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      TextFormField(
        initialValue: ingredient.name,
        onChanged: (value) {
          ingredient.name = value;
          onChanged();
        },
        decoration: const InputDecoration(labelText: 'Ingredient name'),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: ingredient.quantityMin,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) {
                ingredient.quantityMin = value;
                onChanged();
              },
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: ingredient.originalUnit,
              onChanged: (value) {
                ingredient.originalUnit = value;
                onChanged();
              },
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: ingredient.classification,
        decoration: const InputDecoration(labelText: 'Ingredient class'),
        items: const [
          DropdownMenuItem(value: 'REQUIRED', child: Text('Required')),
          DropdownMenuItem(value: 'FLEXIBLE', child: Text('Flexible')),
          DropdownMenuItem(
            value: 'PANTRY_STAPLE',
            child: Text('Pantry staple'),
          ),
          DropdownMenuItem(value: 'GARNISH', child: Text('Garnish')),
        ],
        onChanged: (value) {
          if (value == null) return;
          ingredient.classification = value;
          onChanged();
        },
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Include in shopping'),
        subtitle: const Text(
          'Required items need an amount and unit before shopping.',
        ),
        value: ingredient.includeInShopping,
        onChanged: (value) {
          ingredient.includeInShopping = value;
          onChanged();
        },
      ),
    ],
  );
}

class _EvidencePanel extends StatelessWidget {
  const _EvidencePanel({required this.review});
  final RecipeReview review;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Source and evidence',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (review.sourceUrl != null) ...[
          const Text('Imported from'),
          const SizedBox(height: 4),
          SelectableText(
            review.sourceUrl!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
        ],
        if (review.evidence.isEmpty)
          const Text('No source excerpts were saved for this draft.')
        else
          for (final item in review.evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StickerChip(
                    label: item.origin.replaceAll('-', ' '),
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  if (item.excerpt != null)
                    Text(
                      '“${item.excerpt}”',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          const Text('This recipe review is unavailable.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
