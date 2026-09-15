// Canonical local WR catalog.
//
// The JSON files are generated from the supplied SITUATIONS_v2.js source. They
// are the app's editorial authority: Supabase may contain stale rows, a
// partially applied migration, or historical rows that must remain readable,
// but it must not replace a canonical situation/story with different text or
// classification.

import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/wr_content.dart';

const String kWrSituationsAssetPath = 'assets/seed/wr_situations.json';
const String kWrStoriesAssetPath = 'assets/seed/wr_stories.json';

/// The normalized, immutable catalog used at the content repository boundary.
class WrCanonicalCatalog {
  const WrCanonicalCatalog({required this.situations, required this.stories});

  /// Builds a catalog from decoded JSON lists. This pure constructor is also
  /// useful for contract tests without a Flutter asset bundle.
  factory WrCanonicalCatalog.fromJson({
    required Object situationsJson,
    required Object storiesJson,
  }) {
    final situationRows = _rows(situationsJson, 'situations');
    final storyRows = _rows(storiesJson, 'stories');
    return WrCanonicalCatalog(
      situations: List.unmodifiable(situationRows.map(WrSituation.fromJson)),
      stories: List.unmodifiable(storyRows.map(WrStory.fromJson)),
    );
  }

  final List<WrSituation> situations;
  final List<WrStory> stories;

  List<WrSituation> get realSituations =>
      List.unmodifiable(situations.where((s) => !s.isCustom));

  Map<String, WrSituation> get situationsByCode => {
    for (final situation in situations) situation.code: situation,
  };

  Map<String, WrStory> get storiesById => {
    for (final story in stories) story.storyId: story,
  };

  WrSituation? situationFor(String code) => situationsByCode[code];

  WrStory? storyFor(String code) => storiesById[code];

  /// Merges remote rows without allowing them to override canonical codes.
  /// Unknown/retired remote rows are kept so history can still resolve labels,
  /// but are normalized to history-only compatibility rows at this boundary.
  /// A remote row must never become a new v2 catalog member merely by carrying
  /// plausible-looking axes.
  List<WrSituation> mergeSituations(Iterable<WrSituation> remote) {
    final merged = <String, WrSituation>{
      for (final situation in situations) situation.code: situation,
    };
    for (final situation in remote) {
      merged.putIfAbsent(situation.code, () => _historyOnly(situation));
    }
    final result = merged.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return List.unmodifiable(result);
  }

  /// Keeps remote labels and compatibility fields for old history links, but
  /// removes classification axes and marks the row retired. This protects
  /// every downstream consumer, including callers that only have the merged
  /// list and do not know the canonical catalog membership set.
  static WrSituation _historyOnly(WrSituation situation) {
    return WrSituation(
      code: situation.code,
      text: situation.textVi,
      textEn: situation.textEn,
      scaDimension: situation.scaDimension,
      humanNeed: situation.humanNeed,
      expectedOutcome: situation.expectedOutcome,
      scaPerspective: situation.scaPerspective,
      wave: situation.wave,
      custom: situation.custom,
      createdAt: situation.createdAt,
      retiredAt:
          situation.retiredAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// Same precedence rule as [mergeSituations], keyed by exact story id.
  List<WrStory> mergeStories(Iterable<WrStory> remote) {
    final merged = <String, WrStory>{
      for (final story in stories) story.storyId: story,
    };
    for (final story in remote) {
      merged.putIfAbsent(story.storyId, () => story);
    }
    final result = merged.values.toList()
      ..sort((a, b) => a.storyId.compareTo(b.storyId));
    return List.unmodifiable(result);
  }

  static List<Map<String, dynamic>> _rows(Object value, String label) {
    if (value is! List) {
      throw FormatException('Canonical $label asset must contain a JSON list');
    }
    return [
      for (final row in value)
        if (row is Map<String, dynamic>)
          row
        else if (row is Map)
          Map<String, dynamic>.from(row)
        else
          throw FormatException('Canonical $label row is not an object'),
    ];
  }
}

/// Loads the canonical assets through the supplied bundle, or the app bundle.
Future<WrCanonicalCatalog> loadWrCanonicalCatalog({AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final situations = jsonDecode(
    await assets.loadString(kWrSituationsAssetPath),
  );
  final stories = jsonDecode(await assets.loadString(kWrStoriesAssetPath));
  return WrCanonicalCatalog.fromJson(
    situationsJson: situations,
    storiesJson: stories,
  );
}
