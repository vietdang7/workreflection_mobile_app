import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_canonical_catalog.dart';
import 'package:workreflection_mobile/core/logic/wr_situation_picker.dart';
import 'package:workreflection_mobile/core/models/checkin.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('QA malformed persisted recent IDs do not crash the picker', () async {
    final catalog = await loadWrCanonicalCatalog();
    final profile = MobileProfile.fromJson({
      'user_id': 'qa',
      'reminder_enabled': false,
      'language': 'vi',
      'created_at': '2026-09-14T00:00:00Z',
      'updated_at': '2026-09-14T00:00:00Z',
      'recent_situation_ids': ['A1-01', null, 42, {}, 'qa-unknown'],
    });
    expect(
      () => pickSituationChoices(
        all: catalog.situations,
        mood: Mood.foggy,
        recentIds: profile.recentSituationIds,
      ),
      returnsNormally,
    );
  });
}
