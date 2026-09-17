import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import '../shared/scheduled_date_time_field.dart';
import '../shared/sticker_chip.dart';

final archiveProvider = FutureProvider<List<HouseholdCollectionItem>>(
  (ref) => ref.read(sessionRepositoryProvider).archive(),
);

class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key});
  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  late DateTime _month;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _month = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final archive = ref.watch(archiveProvider);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Archive', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 4),
              const Text(
                'Your cooked meals stay intact, ready when you need them.',
              ),
              const SizedBox(height: 20),
              archive.when(
                loading: () => const _ArchiveLoading(),
                error: (_, _) => _ArchiveError(
                  onRetry: () => ref.invalidate(archiveProvider),
                ),
                data: _buildArchive,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchive(List<HouseholdCollectionItem> entries) {
    final byDate = _archiveByDate(entries);
    final dated = byDate.keys.toList()..sort();
    if (dated.isNotEmpty && _selectedDay == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => mounted
            ? setState(() => _selectedDay = DateTime.parse(dated.last))
            : null,
      );
    }
    final selected = _selectedDay;
    final dayEntries = selected == null
        ? const <HouseholdCollectionItem>[]
        : byDate[_dateKey(selected)] ?? const [];
    return Column(
      children: [
        _MonthHeader(
          month: _month,
          onPrevious: () =>
              setState(() => _month = DateTime(_month.year, _month.month - 1)),
          onNext: () =>
              setState(() => _month = DateTime(_month.year, _month.month + 1)),
        ),
        const SizedBox(height: 12),
        _ArchiveCalendar(
          month: _month,
          archiveByDate: byDate,
          selected: _selectedDay,
          onSelected: (day) => setState(() => _selectedDay = day),
        ),
        const SizedBox(height: 24),
        if (dayEntries.isEmpty)
          const _ArchiveEmpty()
        else
          _ArchiveDayDetail(day: selected!, entries: dayEntries),
      ],
    );
  }

  Map<String, List<HouseholdCollectionItem>> _archiveByDate(
    List<HouseholdCollectionItem> entries,
  ) {
    final result = <String, List<HouseholdCollectionItem>>{};
    for (final entry in entries) {
      final date = DateTime.tryParse(entry.string('archivedAt') ?? '');
      if (date == null) continue;
      result.putIfAbsent(_dateKey(date), () => []).add(entry);
    }
    return result;
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Previous month',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Text(
          DateFormat('MMMM y').format(month),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      IconButton(
        tooltip: 'Next month',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _ArchiveCalendar extends StatelessWidget {
  const _ArchiveCalendar({
    required this.month,
    required this.archiveByDate,
    required this.selected,
    required this.onSelected,
  });
  final DateTime month;
  final Map<String, List<HouseholdCollectionItem>> archiveByDate;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final leading = (first.weekday - DateTime.monday) % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: const [
                _Weekday('M'),
                _Weekday('T'),
                _Weekday('W'),
                _Weekday('T'),
                _Weekday('F'),
                _Weekday('S'),
                _Weekday('S'),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leading + days,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, index) {
                if (index < leading) return const SizedBox.shrink();
                final day = DateTime(
                  month.year,
                  month.month,
                  index - leading + 1,
                );
                final archived = archiveByDate[_dateKey(day)] ?? const [];
                return _ArchiveDateCell(
                  day: day,
                  count: archived.length,
                  selected:
                      selected != null && DateUtils.isSameDay(selected, day),
                  onTap: () => onSelected(day),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelMedium,
    ),
  );
}

class _ArchiveDateCell extends StatelessWidget {
  const _ArchiveDateCell({
    required this.day,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final DateTime day;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${DateFormat('d MMMM').format(day)}, $count archived meals',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? PantryPalTheme.tomato
              : count > 0
              ? PantryPalTheme.green.withValues(alpha: 0.13)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? PantryPalTheme.tomato
                : count > 0
                ? PantryPalTheme.green
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (count > 1)
              Positioned(
                right: 2,
                bottom: 1,
                child: Text(
                  '+$count',
                  style: TextStyle(
                    fontSize: 9,
                    color: selected ? Colors.white : PantryPalTheme.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ArchiveDayDetail extends StatelessWidget {
  const _ArchiveDayDetail({required this.day, required this.entries});
  final DateTime day;
  final List<HouseholdCollectionItem> entries;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, d MMMM').format(day),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final entry in entries) _ArchivedMeal(entry: entry),
        ],
      ),
    ),
  );
}

class _ArchivedMeal extends ConsumerStatefulWidget {
  const _ArchivedMeal({required this.entry});
  final HouseholdCollectionItem entry;

  @override
  ConsumerState<_ArchivedMeal> createState() => _ArchivedMealState();
}

class _ArchivedMealState extends ConsumerState<_ArchivedMeal> {
  var _uploading = false;

  bool get _hasCover => widget.entry.string('archiveCoverKey') != null;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.entry.values['recipeSnapshot'];
    final title = snapshot is Map && snapshot['title'] is String
        ? snapshot['title'] as String
        : 'Archived meal';
    final id = widget.entry.string('id');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PantryPalTheme.tomato.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.restaurant_outlined,
                  color: PantryPalTheme.tomato,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'Served ${widget.entry.string('targetServings') ?? '—'} · Cooked',
                    ),
                  ],
                ),
              ),
              const StickerChip(
                label: 'Cooked',
                color: PantryPalTheme.green,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MealCover(id: id, hasCover: _hasCover),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: id == null || _uploading
                ? null
                : () => _pickAndUploadCover(id),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: Text(
              _uploading
                  ? 'Adding photo…'
                  : _hasCover
                  ? 'Replace with a new photo'
                  : 'Add the real photo',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: id == null
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) => _CookAgainSheet(id: id),
                  ),
            icon: const Icon(Icons.replay_outlined),
            label: const Text('Cook this again'),
          ),
          const SizedBox(height: 4),
          const Text('Creates a new meal plan; history stays unchanged.'),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadCover(String id) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a photo smaller than 10 MB.')),
        );
      }
      return;
    }
    setState(() => _uploading = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .uploadArchiveCover(
            cookingInstanceId: id,
            bytes: bytes,
            mimeType: _mimeTypeFor(file.name),
          );
      ref.invalidate(archiveProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo added to the archive.')),
        );
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add the photo. Try again.')),
        );
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mimeTypeFor(String name) =>
      switch (name.split('.').last.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => throw StateError('Choose a JPEG, PNG, WebP, or HEIC photo.'),
      };
}

class _MealCover extends ConsumerWidget {
  const _MealCover({required this.id, required this.hasCover});

  final String? id;
  final bool hasCover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverId = hasCover ? id : null;
    final Widget child;
    if (coverId == null) {
      child = Container(
        height: 132,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PantryPalTheme.line, width: 1.5),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_outlined,
                size: 20,
                color: PantryPalTheme.tomato.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'No live photo yet',
                style: TextStyle(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ),
      );
    } else {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: FutureBuilder<Uint8List>(
          future: ref
              .read(sessionRepositoryProvider)
              .archiveCoverBytes(coverId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Container(
                height: 132,
                color: PantryPalTheme.line.withValues(alpha: 0.5),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Container(
                height: 132,
                color: PantryPalTheme.line.withValues(alpha: 0.5),
                child: const Center(child: Text('Photo unavailable')),
              );
            }
            return Image.memory(
              snapshot.data!,
              height: 132,
              width: double.infinity,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          },
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: child,
    );
  }
}

class _CookAgainSheet extends ConsumerStatefulWidget {
  const _CookAgainSheet({required this.id});
  final String id;
  @override
  ConsumerState<_CookAgainSheet> createState() => _CookAgainSheetState();
}

class _CookAgainSheetState extends ConsumerState<_CookAgainSheet> {
  final _servings = TextEditingController();
  var _cookingDateIso = '';
  var _submitting = false;
  @override
  void dispose() {
    _servings.dispose();
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
          controller: _servings,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Servings',
            helperText: 'Leave blank to reuse the archived servings.',
          ),
        ),
        const SizedBox(height: 12),
        ScheduledDateTimeField(
          label: 'Cooking date and time',
          valueIso: _cookingDateIso,
          helperText: 'Optional. Leave blank for Quick Cook.',
          onChanged: (value) => setState(() => _cookingDateIso = value),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: const Icon(Icons.replay_outlined),
          label: Text(_submitting ? 'Creating plan…' : 'Create cooking plan'),
        ),
      ],
    ),
  );
  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .cookAgain(
            cookingInstanceId: widget.id,
            targetServings: _servings.text,
            cookingDate: _cookingDateIso,
          );
      ref.invalidate(archiveProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not create the new cooking plan. Check the values and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _ArchiveLoading extends StatelessWidget {
  const _ArchiveLoading();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _ArchiveError extends StatelessWidget {
  const _ArchiveError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Could not load the archive.'),
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

class _ArchiveEmpty extends StatelessWidget {
  const _ArchiveEmpty();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            color: PantryPalTheme.tomato,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'No meals on this day',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text('Cooked meals will appear here as stable snapshots.'),
        ],
      ),
    ),
  );
}

String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
