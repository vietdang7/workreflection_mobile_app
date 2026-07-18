// Workshop-phase models — Phase 3 / Phase 5.
// All classes are immutable. No Flutter dependencies.

// ---------------------------------------------------------------------------
// WorkshopDetail
// ---------------------------------------------------------------------------

/// Maps to the public.cc_workshops table (full detail view).
class WorkshopDetail {
  const WorkshopDetail({
    required this.id,
    required this.title,
    this.description,
    this.category,
    required this.date,
    this.startsAt,
    this.endsAt,
    this.location,
    required this.price,
    required this.currency,
    this.maxParticipants,
    required this.currentParticipants,
    this.imageUrl,
    this.videoUrl,
    required this.status,
    required this.isActive,
    this.checkinCode,
    this.orgId,
  });

  final String id;
  final String title;
  final String? description;
  final String? category;
  final DateTime date;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? location;

  /// Registration price; 0 means free. Stored as num to tolerate int or double
  /// from JSON.
  final num price;
  final String currency;
  final int? maxParticipants;
  final int currentParticipants;
  final String? imageUrl;
  final String? videoUrl;
  final String status;
  final bool isActive;
  final String? checkinCode;
  final String? orgId;

  bool get isFree => price == 0;

  bool get isFull =>
      maxParticipants != null && currentParticipants >= maxParticipants!;

  factory WorkshopDetail.fromJson(Map<String, dynamic> json) {
    return WorkshopDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      date: DateTime.parse(json['date'] as String),
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'] as String)
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      location: json['location'] as String?,
      price: (json['price'] as num?) ?? 0,
      currency: (json['currency'] as String?) ?? 'VND',
      maxParticipants: json['max_participants'] as int?,
      currentParticipants: (json['current_participants'] as int?) ?? 0,
      imageUrl: json['image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      status: json['status'] as String,
      isActive: json['is_active'] as bool,
      checkinCode: json['checkin_code'] as String?,
      orgId: json['org_id'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// WorkshopRegistration
// ---------------------------------------------------------------------------

/// Maps to the public.cc_workshop_registrations table.
class WorkshopRegistration {
  const WorkshopRegistration({
    required this.id,
    required this.workshopId,
    required this.userId,
    required this.status,
    this.checkedInAt,
    required this.attended,
    this.imageConsent,
    this.createdAt,
  });

  final String id;
  final String workshopId;
  final String userId;
  final String status;
  final DateTime? checkedInAt;
  final bool attended;
  final bool? imageConsent;
  final DateTime? createdAt;

  factory WorkshopRegistration.fromJson(Map<String, dynamic> json) {
    return WorkshopRegistration(
      id: json['id'] as String,
      workshopId: json['workshop_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'] as String)
          : null,
      attended: json['attended'] as bool? ?? false,
      imageConsent: json['image_consent'] as bool?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// WorkshopAttachment
// ---------------------------------------------------------------------------

/// Maps to the public.cc_workshop_attachments table.
class WorkshopAttachment {
  const WorkshopAttachment({
    required this.id,
    required this.workshopId,
    required this.fileName,
    required this.fileUrl,
    this.fileType,
    this.fileSize,
    required this.category,
    required this.sortOrder,
  });

  final String id;
  final String workshopId;
  final String fileName;
  final String fileUrl;
  final String? fileType;
  final int? fileSize;

  /// 'document' | 'image' | 'video'
  final String category;
  final int sortOrder;

  factory WorkshopAttachment.fromJson(Map<String, dynamic> json) {
    return WorkshopAttachment(
      id: json['id'] as String,
      workshopId: json['workshop_id'] as String,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      fileType: json['file_type'] as String?,
      fileSize: json['file_size'] as int?,
      category: json['category'] as String,
      sortOrder: (json['sort_order'] as int?) ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// WorkshopSurveyResults
// ---------------------------------------------------------------------------

/// Computed score summary for a completed workshop survey.
///
/// [layerScores] maps layer name (e.g. 'STRUCTURE') → average (1–5).
/// [total] is a weighted average over the SCA layers (same formula as web):
///   structure×0.5 + culture×0.3 + activity×0.2 when all three are present,
///   simple mean of active layers otherwise.
/// [responseCount] is the total number of responses used.
class WorkshopSurveyResults {
  const WorkshopSurveyResults({
    required this.layerScores,
    required this.total,
    required this.responseCount,
  });

  /// Layer name → average score (0.0 when no data).
  final Map<String, double> layerScores;

  /// Overall weighted total (0.0–5.0).
  final double total;

  /// Number of cc_workshop_responses rows used.
  final int responseCount;
}
