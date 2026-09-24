import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import '../recipes/recipe_detail_page.dart';
import '../recipes/recipe_review_page.dart';
import '../shared/app_log.dart';
import '../shared/scheduled_date_time_field.dart';
import '../shared/staggered_entrance.dart';
import '../shared/sticker_chip.dart';
import '../shared/status_tone.dart' show humanStatusLabel;
import '../trips/trip_detail_page.dart';
import 'active_import_card.dart';
import '../trips/shop_page.dart';
import '../notifications/activity_inbox_page.dart';
import '../planning/plan_page.dart';
import '../archive/archive_page.dart';
import '../realtime/realtime_household_sync.dart';

final selectedDestinationProvider = StateProvider<int>((ref) => 0);
final householdCollectionProvider =
    FutureProvider.family<List<HouseholdCollectionItem>, String>((ref, kind) {
      final repository = ref.read(sessionRepositoryProvider);
      return switch (kind) {
        'Plan' => repository.cookingInstances(),
        'Shop' => repository.shoppingTrips(),
        'Archive' => repository.archive(),
        'Recipes' => repository.recipes(),
        _ => repository.notifications(),
      };
    });

class AppShell extends ConsumerWidget {
  const AppShell({super.key});
  static const destinations = <_Destination>[
    _Destination('Home', Icons.home_outlined, Icons.home),
    _Destination('Recipes', Icons.menu_book_outlined, Icons.menu_book),
    _Destination('Plan', Icons.calendar_month_outlined, Icons.calendar_month),
    _Destination('Shop', Icons.shopping_bag_outlined, Icons.shopping_bag),
    _Destination('Archive', Icons.auto_stories_outlined, Icons.auto_stories),
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDestinationProvider);
    final activeImport = ref.watch(activeImportProvider);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    void select(int index) =>
        ref.read(selectedDestinationProvider.notifier).state = index;
    return RealtimeHouseholdSync(
      onEvent: (event) => _refreshForRealtimeEvent(ref, event),
      child: Scaffold(
        appBar: AppBar(
          title: const _Brand(),
          actions: [
            IconButton(
              tooltip: 'Activity inbox',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ActivityInboxPage(),
                ),
              ),
              icon: const Badge(child: Icon(Icons.notifications_none)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: selected,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: select,
                destinations: [
                  for (final item in destinations)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    ),
                ],
              ),
            Expanded(
              child: _Body(
                destination: destinations[selected],
                activeImport: activeImport,
                onImport: () => _showImport(context),
                onCreateRecipe: () => _createRecipe(context, ref),
                onOpenImportReview: (recipeId) =>
                    _openImportReview(context, ref, recipeId),
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: select,
                destinations: [
                  for (final item in destinations)
                    NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label,
                    ),
                ],
              ),
        floatingActionButton: selected == 3
            ? FloatingActionButton.extended(
                onPressed: () => _showCreateTrip(context, ref),
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: const Text('New trip'),
              )
            : null,
      ),
    );
  }

  void _refreshForRealtimeEvent(WidgetRef ref, RealtimeHouseholdEvent event) {
    if ({
      'cooking.changed',
      'cook_assignment.requested',
      'cook_assignment.resolved',
    }.contains(event.name)) {
      ref.invalidate(planProvider);
      ref.invalidate(archiveProvider);
    }
    if (event.name == 'cooking.changed') {
      // A meal moving between trips changes both trips' shopping lists.
      ref.invalidate(shopTripsProvider);
      final summary = event.payload['summary'];
      final tripIds = summary is Map
          ? [summary['shoppingTripId'], summary['previousShoppingTripId']]
          : const [];
      for (final tripId in tripIds.whereType<String>().toSet()) {
        ref.invalidate(tripDetailProvider(tripId));
      }
    }
    if ({
      'trip.changed',
      'shopping_item.changed',
      'pantry.recheck_required',
    }.contains(event.name)) {
      ref.invalidate(shopTripsProvider);
      final summary = event.payload['summary'];
      final tripId = event.name == 'trip.changed'
          ? event.payload['entityId']
          : summary is Map
          ? summary['tripId']
          : null;
      if (tripId is String) ref.invalidate(tripDetailProvider(tripId));
    }
    if (event.name == 'notification.created') {
      ref.invalidate(notificationsProvider);
    }
  }

  Future<void> _showCreateTrip(BuildContext context, WidgetRef ref) async {
    var dateIso = '';
    var submitting = false;
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New shopping trip',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a proposal first. Confirm it once its date and recipe assignments are ready.',
                ),
                const SizedBox(height: 16),
                ScheduledDateTimeField(
                  label: 'Shopping date and time',
                  valueIso: dateIso,
                  helperText:
                      'Optional. Leave blank to propose without a date.',
                  onChanged: (value) => setSheetState(() => dateIso = value),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          setSheetState(() => submitting = true);
                          try {
                            await ref
                                .read(sessionRepositoryProvider)
                                .createShoppingTrip(dateIso);
                            ref.invalidate(householdCollectionProvider('Shop'));
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          } on DioException {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not create this trip. Try again.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (sheetContext.mounted) {
                              setSheetState(() => submitting = false);
                            }
                          }
                        },
                  icon: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_shopping_cart_outlined),
                  label: Text(
                    submitting ? 'Creating trip…' : 'Create proposal',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openImportReview(
    BuildContext context,
    WidgetRef ref,
    String recipeId,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecipeReviewPage(recipeId: recipeId)),
    );
    if (saved != true) return;
    if (ref.read(activeImportProvider)?.recipeId == recipeId) {
      ref.read(activeImportProvider.notifier).state = null;
    }
    ref.invalidate(householdCollectionProvider('Recipes'));
    ref.read(selectedDestinationProvider.notifier).state = destinations
        .indexWhere((destination) => destination.label == 'Recipes');
  }

  Future<void> _showImport(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ImportSheet(),
    );
  }

  Future<void> _createRecipe(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RecipeReviewPage.create()),
    );
    if (saved != true) return;
    ref.invalidate(householdCollectionProvider('Recipes'));
    ref.read(selectedDestinationProvider.notifier).state = destinations
        .indexWhere((destination) => destination.label == 'Recipes');
  }
}

class _ImportSheet extends ConsumerStatefulWidget {
  const _ImportSheet();

  @override
  ConsumerState<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<_ImportSheet> {
  final source = TextEditingController();
  var sourceKind = 'url';
  _SelectedImage? selectedImage;
  var uploadProgress = 0.0;
  var isUploading = false;
  var importError = '';

  @override
  void dispose() {
    // Disposing here (at real unmount) instead of after
    // showModalBottomSheet resolves: that future returns before the pop
    // animation finishes, and tearing down the controller mid-animation
    // crashed the still-live TextField subtree ("used after being disposed",
    // cascading into the _dependents.isEmpty red screen).
    source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import a recipe',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Bring a public recipe link, recipe text, or a screenshot. PantryPal creates a review draft before saving it.',
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'url',
                  icon: Icon(Icons.link),
                  label: Text('Link'),
                ),
                ButtonSegment(
                  value: 'text',
                  icon: Icon(Icons.notes),
                  label: Text('Text'),
                ),
                ButtonSegment(
                  value: 'image',
                  icon: Icon(Icons.photo_outlined),
                  label: Text('Screenshot'),
                ),
              ],
              selected: {sourceKind},
              onSelectionChanged: (selection) => setState(() {
                sourceKind = selection.first;
                source.clear();
                selectedImage = null;
                uploadProgress = 0;
                importError = '';
              }),
            ),
            const SizedBox(height: 16),
            if (sourceKind != 'image')
              TextField(
                controller: source,
                keyboardType: sourceKind == 'url'
                    ? TextInputType.url
                    : TextInputType.multiline,
                maxLines: sourceKind == 'url' ? 1 : 7,
                minLines: sourceKind == 'url' ? 1 : 4,
                decoration: InputDecoration(
                  labelText: sourceKind == 'url' ? 'Recipe URL' : 'Recipe text',
                  hintText: sourceKind == 'url'
                      ? 'https://example.com/recipe'
                      : 'Title, ingredients, and method',
                ),
              )
            else
              _ScreenshotPicker(
                selectedImage: selectedImage,
                isUploading: isUploading,
                progress: uploadProgress,
                onPick: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final file = await FilePicker.pickFile(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
                  );
                  if (file == null) return;
                  final bytes = await file.readAsBytes();
                  if (bytes.lengthInBytes > 10 * 1024 * 1024) {
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Choose a screenshot smaller than 10 MB, or paste the recipe text.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  setState(
                    () => selectedImage = _SelectedImage(
                      name: file.name,
                      bytes: bytes,
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (sourceKind != 'image' && source.text.trim().isEmpty) {
                        setState(
                          () => importError = sourceKind == 'url'
                              ? 'Enter a recipe URL.'
                              : 'Paste the recipe text first.',
                        );
                        return;
                      }
                      if (sourceKind == 'image' && selectedImage == null) {
                        setState(
                          () =>
                              importError = 'Choose a recipe screenshot first.',
                        );
                        return;
                      }
                      try {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        setState(() {
                          importError = '';
                          isUploading = sourceKind == 'image';
                          uploadProgress = 0;
                        });
                        final job = sourceKind == 'image'
                            ? await ref
                                  .read(sessionRepositoryProvider)
                                  .importRecipeImage(
                                    bytes: selectedImage!.bytes,
                                    mimeType: _imageMimeType(selectedImage!),
                                    onUploadProgress: (sent, total) {
                                      if (total > 0 && mounted) {
                                        setState(
                                          () => uploadProgress = sent / total,
                                        );
                                      }
                                    },
                                  )
                            : await ref
                                  .read(sessionRepositoryProvider)
                                  .importRecipe(
                                    sourceKind: sourceKind,
                                    sourceInput: source.text,
                                  );
                        ref.read(activeImportProvider.notifier).state = job;
                        if (mounted) {
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Recipe import started.'),
                            ),
                          );
                        }
                      } on DioException catch (error) {
                        appLog(
                          'import',
                          'Import request failed: '
                              '${error.response?.statusCode ?? error.type.name} '
                              '${error.requestOptions.path}',
                        );
                        final data = error.response?.data;
                        final message = data is Map && data['message'] is String
                            ? data['message'] as String
                            : 'Could not start the import.';
                        if (mounted) {
                          setState(() => importError = message);
                        }
                      } on StateError catch (error) {
                        appLog('import', 'Import blocked: ${error.message}');
                        if (mounted) {
                          setState(() => importError = error.message);
                        }
                      } catch (error) {
                        appLog('import', 'Unexpected import failure: $error');
                        if (mounted) {
                          setState(
                            () => importError =
                                'Unexpected error. Check your connection and try again.',
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => isUploading = false);
                        }
                      }
                    },
              child: Text(
                isUploading
                    ? 'Uploading screenshot…'
                    : sourceKind == 'image'
                    ? 'Analyze screenshot'
                    : 'Start import',
              ),
            ),
            if (importError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      importError,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _imageMimeType(_SelectedImage file) {
  final extension = file.name.split('.').last.toLowerCase();
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    default:
      throw StateError('Choose a JPEG, PNG, WebP, or HEIC screenshot.');
  }
}

class _ScreenshotPicker extends StatelessWidget {
  const _ScreenshotPicker({
    required this.selectedImage,
    required this.isUploading,
    required this.progress,
    required this.onPick,
  });

  final _SelectedImage? selectedImage;
  final bool isUploading;
  final double progress;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: selectedImage == null
        ? 'No recipe screenshot selected'
        : 'Selected screenshot ${selectedImage!.name}',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedImage?.name ?? 'Choose a recipe screenshot',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            selectedImage == null
                ? 'JPEG, PNG, WebP, or HEIC. Up to 10 MB.'
                : '${(selectedImage!.bytes.lengthInBytes / 1024).ceil()} KB • ready to analyze',
          ),
          const SizedBox(height: 12),
          if (isUploading) ...[
            LinearProgressIndicator(value: progress == 0 ? null : progress),
            const SizedBox(height: 8),
            Text('Uploading ${(progress * 100).round()}%'),
          ] else
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                selectedImage == null ? 'Choose screenshot' : 'Choose another',
              ),
            ),
        ],
      ),
    ),
  );
}

class _SelectedImage {
  const _SelectedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.kitchen_outlined, color: PantryPalTheme.tomato),
      const SizedBox(width: 8),
      Text('PantryPal', style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.destination,
    required this.activeImport,
    required this.onImport,
    required this.onCreateRecipe,
    required this.onOpenImportReview,
  });
  final _Destination destination;
  final ImportJobSummary? activeImport;
  final VoidCallback onImport;
  final VoidCallback onCreateRecipe;
  final ValueChanged<String> onOpenImportReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = destination.label == 'Home';
    if (destination.label == 'Plan') return const PlanPage();
    if (destination.label == 'Shop') return const ShopPage();
    if (destination.label == 'Archive') return const ArchivePage();
    Future<void> refresh() async {
      if (!home) {
        ref.invalidate(householdCollectionProvider(destination.label));
        await ref.read(householdCollectionProvider(destination.label).future);
      }
    }

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  home ? 'Good food, clearly planned.' : destination.label,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  home
                      ? 'Bring a recipe. Choose the servings. Know exactly what the household needs.'
                      : '${destination.label} is ready for your household data.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          home ? Icons.kitchen_outlined : destination.icon,
                          size: 40,
                          color: PantryPalTheme.tomato,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          home
                              ? 'Your kitchen is clear'
                              : '${destination.label}, at a glance',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          home
                              ? 'Import a recipe to review it, save a Quick Cook, or plan your next meal.'
                              : _destinationDescription(destination.label),
                        ),
                        if (home) ...[
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: onImport,
                                icon: const Icon(Icons.add_link),
                                label: const Text('Import a recipe'),
                              ),
                              OutlinedButton.icon(
                                onPressed: onCreateRecipe,
                                icon: const Icon(Icons.edit_note_outlined),
                                label: const Text('Create recipe'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!home) ...[
                  const SizedBox(height: 16),
                  _CollectionSection(kind: destination.label),
                ],
                if (home && activeImport != null) ...[
                  const SizedBox(height: 16),
                  ActiveImportCard(
                    job: activeImport!,
                    onOpenReview: onOpenImportReview,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _destinationDescription(String destination) => switch (destination) {
  'Recipes' => 'Every recipe your household has reviewed and saved.',
  'Plan' => 'See who is cooking next and whether a handoff is waiting.',
  'Shop' => 'Track proposed and active shopping trips with clear state.',
  'Archive' => 'Keep past meals intact and return to a recipe when it helps.',
  _ => 'This area will keep your household in sync.',
};

class _CollectionSection extends ConsumerWidget {
  const _CollectionSection({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(householdCollectionProvider(kind));
    return items.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Could not load this household view.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(householdCollectionProvider(kind)),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (entries) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        child: entries.isEmpty
            ? _CollectionEmpty(
                key: ValueKey('collection-empty-$kind'),
                kind: kind,
              )
            : Card(
                key: ValueKey('collection-$kind-${entries.length}'),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        StaggeredIn(
                          key: ValueKey(
                            '${entries[i].string('id') ?? 'row'}-$i',
                          ),
                          index: i,
                          child: _CollectionTile(kind: kind, entry: entries[i]),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _CollectionEmpty extends StatelessWidget {
  const _CollectionEmpty({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_emptyIcon(kind), color: PantryPalTheme.tomato, size: 36),
            const SizedBox(height: 12),
            Text(
              _emptyTitle(kind),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(_emptyBody(kind)),
          ],
        ),
      ),
    ),
  );
}

class _CollectionTile extends ConsumerWidget {
  const _CollectionTile({required this.kind, required this.entry});
  final String kind;
  final HouseholdCollectionItem entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = _entryTitle(kind, entry);
    final status = entry.string(kind == 'Recipes' ? 'readiness' : 'status');
    final cookingId = entry.string('id');
    final recipeId = kind == 'Recipes' ? entry.string('id') : null;
    return Semantics(
      label: [title, if (status != null) humanStatusLabel(status)].join(', '),
      child: ListTile(
        onTap: kind == 'Shop' && entry.string('id') != null
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TripDetailPage(tripId: entry.string('id')!),
                ),
              )
            : recipeId != null
            ? () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailPage(recipeId: recipeId),
                  ),
                );
                if (saved == true) {
                  ref.invalidate(householdCollectionProvider('Recipes'));
                }
              }
            : null,
        minVerticalPadding: 12,
        leading: kind == 'Shop' && entry.string('id') != null
            ? Hero(
                tag: 'trip-icon-${entry.string('id')}',
                child: CircleAvatar(
                  backgroundColor: _statusColor(
                    context,
                    status,
                  ).withValues(alpha: 0.14),
                  foregroundColor: _statusColor(context, status),
                  child: Icon(_entryIcon(kind, status)),
                ),
              )
            : CircleAvatar(
                backgroundColor: _statusColor(
                  context,
                  status,
                ).withValues(alpha: 0.14),
                foregroundColor: _statusColor(context, status),
                child: Icon(_entryIcon(kind, status)),
              ),
        title: Text(title),
        subtitle: Text(_entryDetail(kind, entry)),
        trailing: kind == 'Plan' && cookingId != null && status == 'SCHEDULED'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusChip(status: status!),
                  IconButton(
                    tooltip: 'Mark meal cooked',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Mark this meal cooked?'),
                          content: const Text(
                            'The meal will move into your archive and stay as a historical snapshot.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Mark cooked'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      try {
                        await ref
                            .read(sessionRepositoryProvider)
                            .markCooked(cookingId);
                        ref.invalidate(householdCollectionProvider('Plan'));
                        ref.invalidate(householdCollectionProvider('Archive'));
                      } on DioException {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not archive this meal. Try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.done_outline),
                  ),
                ],
              )
            : kind == 'Archive' && cookingId != null
            ? IconButton(
                tooltip: 'Cook this meal again',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _CookAgainSheet(cookingInstanceId: cookingId),
                ),
                icon: const Icon(Icons.replay_outlined),
              )
            : status == null
            ? null
            : _StatusChip(status: status),
      ),
    );
  }
}

class _CookAgainSheet extends ConsumerStatefulWidget {
  const _CookAgainSheet({required this.cookingInstanceId});
  final String cookingInstanceId;

  @override
  ConsumerState<_CookAgainSheet> createState() => _CookAgainSheetState();
}

class _CookAgainSheetState extends ConsumerState<_CookAgainSheet> {
  final servings = TextEditingController();
  var cookingDateIso = '';
  var submitting = false;

  @override
  void dispose() {
    servings.dispose();
    super.dispose();
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cook again', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'This creates a new planned meal and leaves the archive unchanged.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: servings,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Servings',
              helperText: 'Leave blank to reuse the archived serving count.',
            ),
          ),
          const SizedBox(height: 12),
          ScheduledDateTimeField(
            label: 'Cooking date and time',
            valueIso: cookingDateIso,
            helperText: 'Optional. Leave blank for Quick Cook.',
            onChanged: (value) => setState(() => cookingDateIso = value),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: submitting
                ? null
                : () async {
                    setState(() => submitting = true);
                    try {
                      await ref
                          .read(sessionRepositoryProvider)
                          .cookAgain(
                            cookingInstanceId: widget.cookingInstanceId,
                            targetServings: servings.text,
                            cookingDate: cookingDateIso,
                          );
                      ref.invalidate(householdCollectionProvider('Plan'));
                      ref.invalidate(householdCollectionProvider('Archive'));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('A new cooking plan was created.'),
                          ),
                        );
                      }
                    } on DioException {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not create the new cooking plan. Check the values and try again.',
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => submitting = false);
                    }
                  },
            icon: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.replay_outlined),
            label: Text(submitting ? 'Creating plan…' : 'Create cooking plan'),
          ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => StickerChip(
    label: humanStatusLabel(status),
    icon: _entryIcon('', status),
    color: _statusColor(context, status),
  );
}

String _entryTitle(String kind, HouseholdCollectionItem entry) {
  if (kind == 'Shop') {
    return entry.string('scheduledFor') ?? 'Unscheduled shopping trip';
  }
  if (kind == 'Recipes') return entry.string('title') ?? 'Untitled recipe';
  final snapshot = entry.values['recipeSnapshot'];
  if (snapshot is Map && snapshot['title'] is String) {
    return snapshot['title'] as String;
  }
  return kind == 'Archive' ? 'Archived meal' : 'Planned meal';
}

String _entryDetail(String kind, HouseholdCollectionItem entry) {
  if (kind == 'Shop') {
    return 'Revision ${entry.integer('revision') ?? 1} • tap a trip to view its list';
  }
  if (kind == 'Recipes') return 'Tap to view or edit';
  final servings = entry.string('targetServings');
  final date = entry.string(kind == 'Archive' ? 'archivedAt' : 'cookingDate');
  return [
    servings == null ? null : '$servings servings',
    date,
  ].whereType<String>().join(' • ');
}

IconData _entryIcon(String kind, String? status) {
  if (kind == 'Shop') return Icons.shopping_bag_outlined;
  if (kind == 'Recipes') return Icons.menu_book_outlined;
  if (kind == 'Archive') return Icons.auto_stories_outlined;
  return status == 'ARCHIVED'
      ? Icons.check_circle_outline
      : Icons.restaurant_outlined;
}

IconData _emptyIcon(String kind) => switch (kind) {
  'Recipes' => Icons.menu_book_outlined,
  'Plan' => Icons.calendar_month_outlined,
  'Shop' => Icons.shopping_bag_outlined,
  _ => Icons.auto_stories_outlined,
};

String _emptyTitle(String kind) => switch (kind) {
  'Recipes' => 'No saved recipes yet',
  'Plan' => 'Nothing planned yet',
  'Shop' => 'No shopping trips yet',
  _ => 'Your cooking history will appear here',
};

String _emptyBody(String kind) => switch (kind) {
  'Recipes' =>
    'Import a recipe from Home and save its review. It will appear here.',
  'Plan' =>
    'Schedule a reviewed recipe to give your household a clear next meal.',
  'Shop' =>
    'Create a trip once meals are assigned, then PantryPal combines compatible ingredients.',
  _ =>
    'When a scheduled cooking date passes, PantryPal preserves a stable meal snapshot here.',
};

Color _statusColor(BuildContext context, String? status) {
  if (status == 'CONFIRMED' ||
      status == 'COMPLETED' ||
      status == 'ARCHIVED' ||
      status == 'SHOPPING_READY' ||
      status == 'COOK_READY') {
    return PantryPalTheme.green;
  }
  if (status == 'CHECK_AGAIN' ||
      status == 'PARTIALLY_AVAILABLE' ||
      status == 'NEEDS_REVIEW' ||
      status == 'DRAFT') {
    return PantryPalTheme.amber;
  }
  return PantryPalTheme.tomato;
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
