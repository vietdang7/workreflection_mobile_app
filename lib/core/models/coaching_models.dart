// Coaching-phase models — Phase 3.
// All classes are immutable. No Flutter dependencies.

// ---------------------------------------------------------------------------
// CoachingPackage
// ---------------------------------------------------------------------------

/// Maps to the public.cc_coaching_packages table.
class CoachingPackage {
  const CoachingPackage({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    required this.sessionsCount,
    this.durationMinutes,
    required this.features,
    this.targetAudience,
    required this.isActive,
    required this.displayOrder,
  });

  final String id;
  final String name;
  final String? description;

  /// Package price; 0 means free. Stored as num to tolerate int or double.
  final num price;
  final String currency;
  final int sessionsCount;
  final int? durationMinutes;
  final List<String> features;
  final String? targetAudience;
  final bool isActive;
  final int displayOrder;

  bool get isFree => price == 0;

  factory CoachingPackage.fromJson(Map<String, dynamic> json) {
    final featuresRaw = json['features'];
    final List<String> parsedFeatures;
    if (featuresRaw == null) {
      parsedFeatures = const [];
    } else {
      parsedFeatures = (featuresRaw as List).cast<String>();
    }
    return CoachingPackage(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num?) ?? 0,
      currency: (json['currency'] as String?) ?? 'VND',
      sessionsCount: (json['sessions_count'] as int?) ?? 1,
      durationMinutes: json['duration_minutes'] as int?,
      features: parsedFeatures,
      targetAudience: json['target_audience'] as String?,
      isActive: json['is_active'] as bool,
      displayOrder: (json['display_order'] as int?) ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Coach
// ---------------------------------------------------------------------------

/// Maps to the public.cc_coaches table.
class Coach {
  const Coach({
    required this.id,
    required this.fullName,
    this.title,
    this.bio,
    this.avatarUrl,
    required this.specializations,
    this.experienceYears,
    required this.isActive,
    required this.displayOrder,
  });

  final String id;
  final String fullName;
  final String? title;
  final String? bio;
  final String? avatarUrl;
  final List<String> specializations;
  final int? experienceYears;
  final bool isActive;
  final int displayOrder;

  /// Initials: first letter of the first word + first letter of the last word,
  /// uppercased. For single-word names both letters come from the same word.
  String get initials {
    final words = fullName.trim().split(RegExp(r'\s+'));
    final first = words.first;
    final last = words.last;
    return '${first[0]}${last[0]}'.toUpperCase();
  }

  factory Coach.fromJson(Map<String, dynamic> json) {
    final specsRaw = json['specializations'];
    final List<String> parsedSpecs;
    if (specsRaw == null) {
      parsedSpecs = const [];
    } else {
      parsedSpecs = (specsRaw as List).cast<String>();
    }
    return Coach(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      title: json['title'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      specializations: parsedSpecs,
      experienceYears: json['experience_years'] as int?,
      isActive: json['is_active'] as bool,
      displayOrder: (json['display_order'] as int?) ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// CoachingBooking
// ---------------------------------------------------------------------------

/// Maps to the public.cc_coaching_bookings table.
class CoachingBooking {
  const CoachingBooking({
    required this.id,
    required this.packageId,
    this.coachId,
    this.orderId,
    required this.status,
    this.sessionNumber,
    this.totalSessions,
    this.scheduledAt,
    this.durationMinutes,
    this.meetingLink,
  });

  final String id;
  final String packageId;
  final String? coachId;
  final String? orderId;
  final String status;
  final int? sessionNumber;
  final int? totalSessions;
  final DateTime? scheduledAt;
  final int? durationMinutes;
  final String? meetingLink;

  factory CoachingBooking.fromJson(Map<String, dynamic> json) {
    return CoachingBooking(
      id: json['id'] as String,
      packageId: json['package_id'] as String,
      coachId: json['coach_id'] as String?,
      orderId: json['order_id'] as String?,
      status: json['status'] as String,
      sessionNumber: json['session_number'] as int?,
      totalSessions: json['total_sessions'] as int?,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      durationMinutes: json['duration_minutes'] as int?,
      meetingLink: json['meeting_link'] as String?,
    );
  }
}
