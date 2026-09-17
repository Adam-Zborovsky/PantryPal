import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import '../shared/status_tone.dart' show humanStatusLabel;
import '../shared/sticker_chip.dart';
import 'recipe_actions.dart';
import 'recipe_detail_sections.dart';
import 'recipe_review_page.dart';

/// Read-first view of a saved recipe with in-place editing and meal actions.
/// Pops with `true` when changes were saved at least once, otherwise `false`.
class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipeId});
  final String recipeId;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  /// The recipe as last loaded or saved; the baseline for unsaved changes.
  RecipeReview? _loaded;

  /// The working copy that edit fields mutate.
  RecipeReview? _draft;
  String _loadedFingerprint = '';
  Object? _error;
  bool _loading = true;
  bool _saving = false;
  bool _savedOnce = false;

  /// Bumped whenever the draft is replaced so edit fields rebuild with the
  /// new values instead of keeping their old text.
  int _generation = 0;
  bool _servingsOpen = false;
  bool _ingredientsOpen = true;
  bool _stepsOpen = true;
  final _openIngredients = <int>{};
  final _openSteps = <int>{};

  bool get _dirty {
    final draft = _draft;
    return draft != null && _fingerprint(draft) != _loadedFingerprint;
  }

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
      final recipe = await ref
          .read(sessionRepositoryProvider)
          .recipeReview(widget.recipeId);
      if (mounted) setState(() => _adopt(recipe));
    } catch (error) {
      if (!mounted) return;
      if (_loaded == null) {
        setState(() => _error = error);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not refresh this recipe. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _adopt(RecipeReview recipe) {
    _loaded = recipe;
    _loadedFingerprint = _fingerprint(recipe);
    _draft = _copy(recipe);
    _generation++;
  }

  void _discard() {
    final loaded = _loaded;
    if (loaded == null) return;
    setState(() {
      _draft = _copy(loaded);
      _generation++;
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final servings = draft.originalServings.trim();
    if (servings.isNotEmpty && validateServings(servings) != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Use a number above 0 for servings, like 4 or 2.5.'),
        ),
      );
      return;
    }
    if (draft.ingredients.any((item) => item.name.trim().isEmpty)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Give every ingredient a name before saving.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(sessionRepositoryProvider)
          .saveRecipeReview(draft);
      if (!mounted) return;
      setState(() {
        _adopt(saved);
        _savedOnce = true;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Recipe saved.')));
    } on DioException catch (error) {
      if (!mounted) return;
      if (error.response?.statusCode == 409) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'This recipe changed elsewhere. Refresh to see the latest version.',
            ),
            action: SnackBarAction(label: 'Refresh', onPressed: _loadLatest),
          ),
        );
        return;
      }
      final data = error.response?.data;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            data is Map && data['message'] is String
                ? data['message'] as String
                : 'Could not save this recipe. Check your connection and try again.',
          ),
        ),
      );
    } on StateError catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Asks before throwing away unsaved edits; true when the member agrees.
  Future<bool> _confirmDiscard(String title) async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: const Text('Your edits to this recipe haven’t been saved.'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: PantryPalTheme.tomato),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
        ],
      ),
    );
    return discard == true && mounted;
  }

  Future<void> _handlePop() async {
    if (!await _confirmDiscard('Discard your changes?')) return;
    if (mounted) Navigator.of(context).pop(_savedOnce);
  }

  /// Replaces the draft with the version saved elsewhere, after a conflict.
  Future<void> _loadLatest() async {
    if (!await _confirmDiscard(
      'Discard your changes and load the latest version?',
    )) {
      return;
    }
    await _load();
  }

  /// Title, classification, and adding or removing lines live in the full
  /// review form; reload afterwards so this view shows the new version.
  Future<void> _editFullRecipe() async {
    if (!_readyForAction()) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeReviewPage(recipeId: widget.recipeId),
      ),
    );
    if (saved != true || !mounted) return;
    setState(() => _savedOnce = true);
    await _load();
  }

  /// Actions use the saved recipe, so unsaved edits must be resolved first.
  bool _readyForAction() {
    if (!_dirty) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save or discard your changes first.')),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _loaded;
    final draft = _draft;
    final dirty = _dirty;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recipe'),
          actions: [
            if (loaded != null)
              PopupMenuButton<_RecipeMenuAction>(
                tooltip: 'More options',
                onSelected: (action) => switch (action) {
                  _RecipeMenuAction.editFullRecipe => _editFullRecipe(),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _RecipeMenuAction.editFullRecipe,
                    child: Text('Edit full recipe'),
                  ),
                ],
              ),
          ],
        ),
        bottomNavigationBar: dirty
            ? _UnsavedChangesBar(
                saving: _saving,
                onDiscard: _discard,
                onSave: _save,
              )
            : null,
        body: _loading && draft == null
            ? const Center(child: CircularProgressIndicator())
            : loaded == null || draft == null
            ? _LoadFailure(error: _error, onRetry: _load)
            : _buildContent(context, loaded, draft),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    RecipeReview loaded,
    RecipeReview draft,
  ) {
    final generation = _generation;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Header(
                title: loaded.title,
                servings: ServingsRow(
                  servings: draft.originalServings,
                  fieldKey: '$generation',
                  expanded: _servingsOpen,
                  onToggle: () =>
                      setState(() => _servingsOpen = !_servingsOpen),
                  onChanged: (value) =>
                      setState(() => draft.originalServings = value),
                  trailing: _ReadinessSticker(readiness: loaded.readiness),
                ),
              ),
              const SizedBox(height: 20),
              _ActionZone(
                onAddToTrip: () {
                  if (!_readyForAction()) return;
                  showAddToTripSheet(
                    context,
                    recipeId: loaded.id,
                    originalServings: loaded.originalServings,
                  );
                },
                onPlanMeal: () {
                  if (!_readyForAction()) return;
                  showPlanMealSheet(
                    context,
                    recipeId: loaded.id,
                    originalServings: loaded.originalServings,
                  );
                },
              ),
              const SizedBox(height: 28),
              CollapsibleSection(
                title: 'Ingredients',
                count: draft.ingredients.length,
                expanded: _ingredientsOpen,
                onToggle: () =>
                    setState(() => _ingredientsOpen = !_ingredientsOpen),
                emptyText: 'No ingredients yet.',
                rows: [
                  for (var i = 0; i < draft.ingredients.length; i++)
                    IngredientRow(
                      key: ValueKey('ingredient-$i'),
                      ingredient: draft.ingredients[i],
                      fieldKey: '$generation-ingredient-$i',
                      expanded: _openIngredients.contains(i),
                      onToggle: () => setState(() {
                        if (!_openIngredients.remove(i)) {
                          _openIngredients.add(i);
                        }
                      }),
                      onChanged: () => setState(() {}),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              CollapsibleSection(
                title: 'Steps',
                count: draft.instructions.length,
                expanded: _stepsOpen,
                onToggle: () => setState(() => _stepsOpen = !_stepsOpen),
                emptyText: 'No steps yet.',
                rows: [
                  for (var i = 0; i < draft.instructions.length; i++)
                    StepRow(
                      key: ValueKey('step-$i'),
                      number: i + 1,
                      text: draft.instructions[i],
                      fieldKey: '$generation-step-$i',
                      expanded: _openSteps.contains(i),
                      onToggle: () => setState(() {
                        if (!_openSteps.remove(i)) {
                          _openSteps.add(i);
                        }
                      }),
                      onChanged: (value) =>
                          setState(() => draft.instructions[i] = value),
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

enum _RecipeMenuAction { editFullRecipe }

RecipeReview _copy(RecipeReview recipe) => RecipeReview(
  id: recipe.id,
  title: recipe.title,
  readiness: recipe.readiness,
  revision: recipe.revision,
  originalServings: recipe.originalServings,
  yieldWording: recipe.yieldWording,
  ingredients: [
    for (final item in recipe.ingredients)
      RecipeReviewIngredient(
        name: item.name,
        quantityMin: item.quantityMin,
        quantityMax: item.quantityMax,
        originalUnit: item.originalUnit,
        preparationNote: item.preparationNote,
        classification: item.classification,
        includeInShopping: item.includeInShopping,
        originalText: item.originalText,
      ),
  ],
  instructions: [...recipe.instructions],
  completeness: recipe.completeness,
  evidence: recipe.evidence,
  sourceUrl: recipe.sourceUrl,
);

/// Every value this page can edit, raw (untrimmed), so any keystroke that
/// changes a field counts as an unsaved change.
String _fingerprint(RecipeReview recipe) => jsonEncode([
  recipe.originalServings,
  for (final item in recipe.ingredients)
    [
      item.quantityMin,
      item.quantityMax,
      item.originalUnit,
      item.name,
      item.preparationNote,
      item.includeInShopping,
    ],
  recipe.instructions,
]);

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.servings});
  final String title;
  final Widget servings;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title.trim().isEmpty ? 'Untitled recipe' : title,
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: 6),
      servings,
    ],
  );
}

class _ReadinessSticker extends StatelessWidget {
  const _ReadinessSticker({required this.readiness});
  final String readiness;

  @override
  Widget build(BuildContext context) => StickerChip(
    label: humanStatusLabel(readiness),
    color: readiness == 'SHOPPING_READY' || readiness == 'COOK_READY'
        ? PantryPalTheme.green
        : PantryPalTheme.amber,
  );
}

class _ActionZone extends StatelessWidget {
  const _ActionZone({required this.onAddToTrip, required this.onPlanMeal});
  final VoidCallback onAddToTrip;
  final VoidCallback onPlanMeal;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 12.0;
      final sideBySide = constraints.maxWidth >= 440;
      final width = sideBySide
          ? (constraints.maxWidth - gap) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          SizedBox(
            width: width,
            child: FilledButton.icon(
              onPressed: onAddToTrip,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add to shopping trip'),
            ),
          ),
          SizedBox(
            width: width,
            child: OutlinedButton.icon(
              onPressed: onPlanMeal,
              icon: const Icon(Icons.event_outlined),
              label: const Text('Plan a meal'),
            ),
          ),
        ],
      );
    },
  );
}

class _UnsavedChangesBar extends StatelessWidget {
  const _UnsavedChangesBar({
    required this.saving,
    required this.onDiscard,
    required this.onSave,
  });
  final bool saving;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: dark ? PantryPalTheme.darkLine : PantryPalTheme.ink,
            width: 2,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Unsaved changes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: saving ? null : onDiscard,
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 48),
                  ),
                  onPressed: saving ? null : onSave,
                  child: Text(saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: PantryPalTheme.tomato,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load this recipe.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              error is StateError
                  ? error.message
                  : 'Check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 52)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
