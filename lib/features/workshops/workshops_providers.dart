// Riverpod providers for the workshops feature — Phase 3.
//
// All providers are autoDispose so resources are freed when the screen is
// popped. Family variants accept a workshopId (String) parameter.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/workshop_repository.dart';
import '../../core/models/workshop_models.dart';

// ---------------------------------------------------------------------------
// Task 9 — Workshops list
// ---------------------------------------------------------------------------

/// All active public workshops, ordered by date asc.
final activeWorkshopsProvider =
    FutureProvider.autoDispose<List<WorkshopDetail>>((ref) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getActiveWorkshops();
});

// ---------------------------------------------------------------------------
// Task 10 — Workshop detail
// ---------------------------------------------------------------------------

/// Single workshop detail by id.
final workshopDetailProvider =
    FutureProvider.autoDispose.family<WorkshopDetail?, String>((ref, id) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getWorkshop(id);
});

/// Current user's registration for a workshop.
final myRegistrationProvider =
    FutureProvider.autoDispose.family<WorkshopRegistration?, String>(
        (ref, workshopId) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getMyRegistration(workshopId);
});

/// Attachments for a workshop.
final workshopAttachmentsProvider =
    FutureProvider.autoDispose.family<List<WorkshopAttachment>, String>(
        (ref, workshopId) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getAttachments(workshopId);
});

/// Whether the current user has already submitted a survey for a workshop.
final hasSubmittedSurveyProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, workshopId) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.hasSubmittedWorkshopSurvey(workshopId);
});

// ---------------------------------------------------------------------------
// Task 11 — My Workshops
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Task 12 — Check-in
// ---------------------------------------------------------------------------

/// Controls whether the real QR scanner is shown (set to false in tests).
final checkinScannerEnabledProvider = Provider<bool>((_) => true);

// ---------------------------------------------------------------------------
// Task 13 — Post-workshop survey
// ---------------------------------------------------------------------------

/// The active survey question set for a workshop, or null when none assigned.
final workshopSurveySetProvider =
    FutureProvider.autoDispose.family<WorkshopSurveySet?, String>(
        (ref, workshopId) {
  final repo = ref.watch(workshopRepositoryProvider);
  return repo.getWorkshopSurveySet(workshopId);
});

// ---------------------------------------------------------------------------
// Task 11 — My Workshops
// ---------------------------------------------------------------------------

/// All registrations for the current user, paired with their workshop detail.
/// Fetches workshop details in parallel; tolerates null (shows fallback title).
final myWorkshopsProvider = FutureProvider.autoDispose<
    List<(WorkshopRegistration, WorkshopDetail?)>>((ref) async {
  final repo = ref.watch(workshopRepositoryProvider);
  final registrations = await repo.getMyRegistrations();
  final details = await Future.wait(
    registrations.map((r) => repo.getWorkshop(r.workshopId)),
  );
  return [
    for (var i = 0; i < registrations.length; i++) (registrations[i], details[i]),
  ];
});
