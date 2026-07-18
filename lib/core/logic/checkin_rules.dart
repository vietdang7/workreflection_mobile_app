// Check-in rules — Phase 3.
// Pure functions, no Flutter/Supabase dependencies.

// ---------------------------------------------------------------------------
// parseCheckinCode
// ---------------------------------------------------------------------------

/// Extracts an 8-char uppercase alphanumeric check-in code from [raw].
///
/// Accepts:
/// - Bare code: "AB12CD34" (any case, surrounding whitespace trimmed).
/// - URL: any string whose last non-empty path segment is a valid code,
///   e.g. "https://app.example.com/workshop/checkin/AB12CD34[/]".
///
/// Returns null when no valid 8-char alphanumeric code is found.
String? parseCheckinCode(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // Try to extract the candidate from the last non-empty path segment when
  // the input looks like a URL (contains '/').
  String candidate;
  if (trimmed.contains('/')) {
    final segments = trimmed.split('/').where((s) => s.isNotEmpty).toList();
    candidate = segments.isEmpty ? '' : segments.last;
  } else {
    candidate = trimmed;
  }

  // Validate: exactly 8 alphanumeric characters (A-Z, a-z, 0-9).
  final codeRegex = RegExp(r'^[A-Za-z0-9]{8}$');
  if (!codeRegex.hasMatch(candidate)) return null;

  return candidate.toUpperCase();
}

// ---------------------------------------------------------------------------
// CheckinWindow + checkinWindow
// ---------------------------------------------------------------------------

enum CheckinWindow {
  /// [now] is before the check-in opens (startsAt − 2h).
  tooEarly,

  /// [now] is within the check-in window [startsAt−2h, startsAt+4h].
  open,

  /// [now] is after the check-in window closes (startsAt + 4h).
  closed,

  /// [startsAt] is null — treat as open to avoid blocking attendees.
  unknown,
}

/// Returns the [CheckinWindow] for the given [now] relative to [startsAt].
///
/// Window: **open** from `startsAt − 2h` to `startsAt + 4h` inclusive at
/// both bounds. A null [startsAt] returns [CheckinWindow.unknown]; callers
/// should treat unknown as open so incomplete server data never blocks
/// attendees.
CheckinWindow checkinWindow(DateTime? startsAt, DateTime now) {
  if (startsAt == null) return CheckinWindow.unknown;

  final open = startsAt.subtract(const Duration(hours: 2));
  final close = startsAt.add(const Duration(hours: 4));

  if (now.isBefore(open)) return CheckinWindow.tooEarly;
  if (now.isAfter(close)) return CheckinWindow.closed;
  return CheckinWindow.open;
}
