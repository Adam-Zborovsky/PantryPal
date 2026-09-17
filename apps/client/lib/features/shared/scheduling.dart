import 'package:intl/intl.dart';

/// Serializes a local date-time as a UTC ISO 8601 timestamp for the API.
String scheduledToApi(DateTime value) => value.toUtc().toIso8601String();

/// Parses a stored or user-entered timestamp into local time, so calendar
/// days and hours match the user's clock; blank and junk input are null.
DateTime? tryParseScheduled(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return DateTime.tryParse(trimmed)?.toLocal();
}

/// Human display for a scheduled moment, e.g. "Sat 22 Aug · 18:30".
String formatScheduledForDisplay(DateTime value) =>
    DateFormat('EEE d MMM · HH:mm').format(value);
