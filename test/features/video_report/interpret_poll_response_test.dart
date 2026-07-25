import 'package:flutter_test/flutter_test.dart';

import 'package:workreflection_mobile/features/video_report/data/video_report_repository.dart';

void main() {
  group('interpretPollResponse', () {
    test('completed with audio_url + subtitle_data returns RawVideoJob', () {
      final job = interpretPollResponse({
        'status': 'completed',
        'audio_url': 'https://example.com/audio.mp3',
        'subtitle_data': {'srt': 'x', 'duration': 5},
      });

      expect(job, isNotNull);
      expect(job!.audioUrl, 'https://example.com/audio.mp3');
      expect(job.srt, 'x');
      expect(job.durationMs, 5000);
    });

    test('completed without audio_url throws', () {
      expect(
        () => interpretPollResponse({
          'status': 'completed',
          'subtitle_data': {'srt': 'x', 'duration': 5},
        }),
        throwsException,
      );
    });

    test('failed with error_message throws with that message', () {
      expect(
        () => interpretPollResponse({
          'status': 'failed',
          'error_message': 'boom went the TTS',
        }),
        throwsA(predicate(
          (e) => e is Exception && e.toString().contains('boom went the TTS'),
        )),
      );
    });

    test('pending returns null', () {
      final job = interpretPollResponse({'status': 'pending'});
      expect(job, isNull);
    });

    test('completed with subtitle_data null returns srt null, durationMs null',
        () {
      final job = interpretPollResponse({
        'status': 'completed',
        'audio_url': 'https://example.com/audio.mp3',
        'subtitle_data': null,
      });

      expect(job, isNotNull);
      expect(job!.audioUrl, 'https://example.com/audio.mp3');
      expect(job.srt, isNull);
      expect(job.durationMs, isNull);
    });
  });
}
