import 'package:workreflection_mobile/core/data/workshop_repository.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';

/// In-memory fake WorkshopRepository for widget/unit tests.
///
/// Pre-populate via the `seed*` methods before pumping widgets.
/// Inspect recorded calls via the `*Calls` fields.
///
/// Set [nextError] before a call to simulate an error; it is thrown once then
/// cleared automatically.
class FakeWorkshopRepository implements WorkshopRepository {
  // --- Internal state ---
  final List<WorkshopDetail> _workshops = [];
  final List<WorkshopRegistration> _registrations = [];
  final List<WorkshopAttachment> _attachments = [];
  WorkshopSurveySet? _surveySet;
  final Set<String> _submittedWorkshopIds = {};
  int _regCounter = 0;

  /// When set, the next repo call throws this error once, then clears it.
  Object? nextError;

  // --- Call recorders ---
  final List<String> registerFreeCalls = [];
  final List<String> checkInCalls = [];
  final List<(String, bool)> setImageConsentCalls = [];
  final List<Map<String, dynamic>> submitSurveyCalls = [];

  // --- Seed helpers ---

  void seedWorkshops(List<WorkshopDetail> workshops) {
    _workshops
      ..clear()
      ..addAll(workshops);
  }

  void seedRegistration(WorkshopRegistration reg) {
    _registrations.removeWhere((r) => r.id == reg.id);
    _registrations.add(reg);
  }

  void seedAttachments(List<WorkshopAttachment> attachments) {
    _attachments
      ..clear()
      ..addAll(attachments);
  }

  void seedSurveySet(WorkshopSurveySet surveySet) {
    _surveySet = surveySet;
  }

  void seedSubmittedSurvey(String workshopId) {
    _submittedWorkshopIds.add(workshopId);
  }

  // --- Helpers ---

  void _maybeThrow() {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      // ignore: only_throw_errors
      throw err;
    }
  }

  // --- WorkshopRepository impl ---

  @override
  Future<List<WorkshopDetail>> getActiveWorkshops() async {
    _maybeThrow();
    return List.unmodifiable(_workshops);
  }

  @override
  Future<WorkshopDetail?> getWorkshop(String id) async {
    _maybeThrow();
    try {
      return _workshops.firstWhere((w) => w.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<WorkshopRegistration?> getMyRegistration(String workshopId) async {
    _maybeThrow();
    try {
      return _registrations.firstWhere(
        (r) => r.workshopId == workshopId && r.status != 'cancelled',
      );
    } on StateError {
      return null;
    }
  }

  @override
  Future<List<WorkshopRegistration>> getMyRegistrations() async {
    _maybeThrow();
    final sorted = List.of(_registrations)
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
    return List.unmodifiable(sorted);
  }

  @override
  Future<void> registerFree(String workshopId) async {
    _maybeThrow();
    registerFreeCalls.add(workshopId);

    // Add a new registration.
    _regCounter++;
    final now = DateTime.now();
    _registrations.add(WorkshopRegistration(
      id: 'reg-$_regCounter',
      workshopId: workshopId,
      userId: 'fake-user',
      status: 'registered',
      attended: false,
      createdAt: now,
    ));

    // Increment the seeded workshop's currentParticipants.
    final idx = _workshops.indexWhere((w) => w.id == workshopId);
    if (idx != -1) {
      final w = _workshops[idx];
      _workshops[idx] = WorkshopDetail(
        id: w.id,
        title: w.title,
        description: w.description,
        category: w.category,
        date: w.date,
        startsAt: w.startsAt,
        endsAt: w.endsAt,
        location: w.location,
        price: w.price,
        currency: w.currency,
        maxParticipants: w.maxParticipants,
        currentParticipants: w.currentParticipants + 1,
        imageUrl: w.imageUrl,
        videoUrl: w.videoUrl,
        status: w.status,
        isActive: w.isActive,
        checkinCode: w.checkinCode,
        orgId: w.orgId,
      );
    }
  }

  @override
  Future<WorkshopDetail?> getWorkshopByCheckinCode(String code) async {
    _maybeThrow();
    try {
      return _workshops.firstWhere(
        (w) => w.checkinCode?.toUpperCase() == code.toUpperCase(),
      );
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> checkIn(String registrationId) async {
    _maybeThrow();
    checkInCalls.add(registrationId);

    final idx = _registrations.indexWhere((r) => r.id == registrationId);
    if (idx != -1) {
      final r = _registrations[idx];
      _registrations[idx] = WorkshopRegistration(
        id: r.id,
        workshopId: r.workshopId,
        userId: r.userId,
        status: r.status, // status NOT changed — matching web behaviour
        checkedInAt: DateTime.now(),
        attended: true,
        imageConsent: r.imageConsent,
        createdAt: r.createdAt,
      );
    }
  }

  @override
  Future<void> setImageConsent(String registrationId, bool consent) async {
    _maybeThrow();
    setImageConsentCalls.add((registrationId, consent));

    final idx = _registrations.indexWhere((r) => r.id == registrationId);
    if (idx != -1) {
      final r = _registrations[idx];
      _registrations[idx] = WorkshopRegistration(
        id: r.id,
        workshopId: r.workshopId,
        userId: r.userId,
        status: r.status,
        checkedInAt: r.checkedInAt,
        attended: r.attended,
        imageConsent: consent,
        createdAt: r.createdAt,
      );
    }
  }

  @override
  Future<List<WorkshopAttachment>> getAttachments(String workshopId) async {
    _maybeThrow();
    final filtered = _attachments
        .where((a) => a.workshopId == workshopId)
        .toList()
      ..sort((a, b) => (a.sortOrder).compareTo(b.sortOrder));
    return List.unmodifiable(filtered);
  }

  @override
  Future<WorkshopSurveySet?> getWorkshopSurveySet(String workshopId) async {
    _maybeThrow();
    return _surveySet;
  }

  @override
  Future<bool> hasSubmittedWorkshopSurvey(String workshopId) async {
    _maybeThrow();
    return _submittedWorkshopIds.contains(workshopId);
  }

  @override
  Future<void> submitWorkshopSurvey({
    required String workshopId,
    required String questionSetId,
    required Map<String, int> answers,
  }) async {
    _maybeThrow();
    submitSurveyCalls.add({
      'workshopId': workshopId,
      'questionSetId': questionSetId,
      'answers': Map.of(answers),
    });
    _submittedWorkshopIds.add(workshopId);
  }
}
