/// Maps to the public.cc_workshops table.
/// Columns: id, title, category (nullable), date, starts_at (nullable timestamptz).
class Workshop {
  const Workshop({
    required this.id,
    required this.title,
    this.category,
    required this.date,
    this.startsAt,
  });

  final String id;
  final String title;
  final String? category;

  /// The workshop date (calendar date, time stripped).
  final DateTime date;

  /// Full timestamp when the workshop starts — nullable.
  final DateTime? startsAt;

  factory Workshop.fromJson(Map<String, dynamic> json) {
    return Workshop(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String?,
      date: DateTime.parse(json['date'] as String),
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'] as String)
          : null,
    );
  }
}
