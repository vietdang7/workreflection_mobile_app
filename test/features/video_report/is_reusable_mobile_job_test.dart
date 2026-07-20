import 'package:flutter_test/flutter_test.dart';

import 'package:workreflection_mobile/features/video_report/data/video_report_repository.dart';

void main() {
  group('isReusableMobileJob', () {
    test('completed + audio_url + mobile_v1 source → true', () {
      final row = <String, dynamic>{
        'status': 'completed',
        'audio_url': 'https://example.com/audio.mp3',
        'narration_script': {'source': kMobileNarrationSource},
      };
      expect(isReusableMobileJob(row), isTrue);
    });

    test('completed + audio_url + gemini source → false', () {
      final row = <String, dynamic>{
        'status': 'completed',
        'audio_url': 'https://example.com/audio.mp3',
        'narration_script': {'source': 'gemini'},
      };
      expect(isReusableMobileJob(row), isFalse);
    });

    test('completed + audio_url + missing source → false', () {
      final row = <String, dynamic>{
        'status': 'completed',
        'audio_url': 'https://example.com/audio.mp3',
        'narration_script': {'scenes': <dynamic>[]},
      };
      expect(isReusableMobileJob(row), isFalse);
    });

    test('completed + audio_url + narration_script null → false', () {
      final row = <String, dynamic>{
        'status': 'completed',
        'audio_url': 'https://example.com/audio.mp3',
        'narration_script': null,
      };
      expect(isReusableMobileJob(row), isFalse);
    });

    test('status processing → false', () {
      final row = <String, dynamic>{
        'status': 'processing',
        'audio_url': 'https://example.com/audio.mp3',
        'narration_script': {'source': kMobileNarrationSource},
      };
      expect(isReusableMobileJob(row), isFalse);
    });

    test('completed + audio_url null → false', () {
      final row = <String, dynamic>{
        'status': 'completed',
        'audio_url': null,
        'narration_script': {'source': kMobileNarrationSource},
      };
      expect(isReusableMobileJob(row), isFalse);
    });
  });
}
