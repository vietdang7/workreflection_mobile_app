// WorkReflection entitlement logic — WR Two-Layer Architecture v1.2.
// Pure Dart, no Flutter dependencies.
// Implements 3-level content gating per spec v1.2.
//
// GATING LEVELS:
//   Level 1 — Feature gating: premium features unavailable to free users
//   Level 2 — Content gating: premium practice steps locked for free users
//   Level 3 — Quota gating: limits on active themes & context docs for free users
//
// IMPORTANT — NEVER GATE:
//   • WrStory access (Story Library is ALWAYS free)
//   • SCA Self-Check question access (self-check is ALWAYS free)
//   These are core free-tier value props per v1.2 decision.

import 'package:workreflection_mobile/core/models/wr_intelligence.dart';

// ---------------------------------------------------------------------------
// NEVER GATE: Story Library & SCA Self-Check question access
// Per v1.2 architecture decision: these are always available to free users
// as core value propositions. UI MUST NOT call canUseFeature() for stories
// or self-check questions.
// ---------------------------------------------------------------------------

/// Premium features that are unavailable to free-tier users.
/// See Level 1 gating below.
enum WrPremiumFeature {
  aiInsight,
  careerBenchmark,
  patternAdvanced,
  selfCheckDeepDive,
  selfCheckTrend,
  growthJourney,
  careerMemoryFullHistory,
  contextDocAnalysis,
  deepReport,
}

/// Encapsulates a user's entitlement state and enforces all 3 gating levels.
class WrEntitlement {
  final WrPlan plan;
  final DateTime? validUntil;

  WrEntitlement({required this.plan, this.validUntil});

  factory WrEntitlement.fromRecord(WrEntitlementRecord record) =>
      WrEntitlement(plan: record.plan, validUntil: record.validUntil);

  /// True when the user has an active premium subscription.
  /// A premium plan with an expired [validUntil] is treated as free.
  bool get isPremium =>
      plan == WrPlan.premium &&
      (validUntil == null || validUntil!.isAfter(DateTime.now()));

  // -------------------------------------------------------------------------
  // Level 1 — Feature gating
  // -------------------------------------------------------------------------

  /// Returns true if this entitlement can use [feature].
  /// Free users: blocked from ALL WrPremiumFeature values.
  /// Premium users (active): can use all features.
  bool canUseFeature(WrPremiumFeature f) => isPremium;

  // -------------------------------------------------------------------------
  // Level 2 — Content gating
  // -------------------------------------------------------------------------

  /// Returns true if this entitlement can access a practice step.
  /// [isPremiumStep] = PracticeStep.isPremium from DB.
  /// Free users: only non-premium steps (isPremiumStep == false).
  /// Premium users: all steps.
  bool canAccessPracticeStep({required bool isPremiumStep}) {
    if (!isPremiumStep) return true;
    return isPremium;
  }

  // -------------------------------------------------------------------------
  // Level 3 — Quota gating
  // -------------------------------------------------------------------------

  /// Max active (non-completed) practice theme enrollments.
  /// Free: 2 — yêu cầu khách 2026-07-27 ("free chỉ được chọn thực hành tối đa
  /// 2 chủ đề cùng lúc"). Premium: null (unlimited).
  int? get maxActivePracticeThemes => isPremium ? null : 2;

  /// Returns true if user can enroll in another practice theme.
  /// [activeCount] = count of enrollments where completedAt == null.
  bool canEnrollPracticeTheme(int activeCount) {
    final max = maxActivePracticeThemes;
    if (max == null) return true;
    return activeCount < max;
  }

  /// Max uploaded context documents.
  /// Free: 1. Premium: null (unlimited).
  int? get maxContextDocuments => isPremium ? null : 1;

  /// Returns true if user can upload another context document.
  /// [currentCount] = count of existing documents.
  bool canUploadContextDocument(int currentCount) {
    final max = maxContextDocuments;
    if (max == null) return true;
    return currentCount < max;
  }
}
