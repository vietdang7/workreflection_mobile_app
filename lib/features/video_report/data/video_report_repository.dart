// Video Report — data repository.
//
// Owns all Supabase access for the video report feature: the cc_video_jobs
// cache lookup and the tts-proxy edge function (create + poll). Screens and
// providers consume this via [videoReportRepositoryProvider] only.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';

// ---------------------------------------------------------------------------
// Raw job model — the pieces we reuse from a completed TTS job.
// ---------------------------------------------------------------------------

class RawVideoJob {
  const RawVideoJob({required this.audioUrl, this.srt, this.durationMs});
  final String audioUrl;
  final String? srt;
  final int? durationMs;
}

// ---------------------------------------------------------------------------
// Poll-response interpretation (pure, testable)
// ---------------------------------------------------------------------------

// subtitle_data.duration is in SECONDS (num|null) → milliseconds (int|null).
int? _durationMsFromSubtitle(Map<String, dynamic>? sub) {
  final d = sub?['duration'];
  if (d == null) return null;
  return ((d as num) * 1000).round();
}

/// Interprets one tts-proxy poll response.
/// Returns a completed RawVideoJob, null if still pending/processing,
/// or throws if the job failed or the payload is malformed on a completed job.
RawVideoJob? interpretPollResponse(Map<String, dynamic> data) {
  final status = data['status'] as String?;

  if (status == 'completed') {
    final audioUrl = data['audio_url'];
    if (audioUrl is! String) {
      throw Exception('Video job completed but audio_url missing');
    }
    final sub = data['subtitle_data'] as Map<String, dynamic>?;
    return RawVideoJob(
      audioUrl: audioUrl,
      srt: sub?['srt'] as String?,
      durationMs: _durationMsFromSubtitle(sub),
    );
  }
  if (status == 'failed') {
    throw Exception(data['error_message'] as String? ?? 'TTS generation failed');
  }
  return null;
}

// ---------------------------------------------------------------------------
// Abstract interface (overridable in tests)
// ---------------------------------------------------------------------------

abstract class VideoReportRepository {
  /// Latest completed job's audio + srt + duration for [reportId], or null.
  Future<RawVideoJob?> findCompletedJob(String reportId);

  /// Create a TTS job then poll until completed/failed/timeout.
  Future<RawVideoJob> createAndWait({
    required String reportId,
    required String userId,
    required String text,
    required Map<String, dynamic> narrationScript,
    required String language,
  });

  /// Wrap a raw audio URL in the authenticated GET proxy URL.
  String proxiedAudioUrl(String rawAudioUrl);

  /// Auth headers required to GET the proxied audio URL.
  Map<String, String> audioHeaders();
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final videoReportRepositoryProvider = Provider<VideoReportRepository>(
  (ref) => SupabaseVideoReportRepository(Supabase.instance.client),
);

// ---------------------------------------------------------------------------
// Live Supabase implementation
// ---------------------------------------------------------------------------

class SupabaseVideoReportRepository implements VideoReportRepository {
  SupabaseVideoReportRepository(this._client);

  final SupabaseClient _client;

  // Voice IDs per language (integers per tts-proxy contract).
  static const int _viVoiceId = 1619321;
  static const int _enVoiceId = 1914576;

  // Polling: up to 60 attempts spaced 3s apart (~3 minutes max).
  static const int _maxPollAttempts = 60;
  static const Duration _pollInterval = Duration(seconds: 3);

  @override
  Future<RawVideoJob?> findCompletedJob(String reportId) async {
    final row = await _client
        .from('cc_video_jobs')
        .select()
        .eq('report_id', reportId)
        .eq('status', 'completed')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    final audioUrl = row['audio_url'] as String?;
    if (audioUrl == null) return null;

    final sub = row['subtitle_data'] as Map<String, dynamic>?;
    return RawVideoJob(
      audioUrl: audioUrl,
      srt: sub?['srt'] as String?,
      durationMs: _durationMsFromSubtitle(sub),
    );
  }

  @override
  Future<RawVideoJob> createAndWait({
    required String reportId,
    required String userId,
    required String text,
    required Map<String, dynamic> narrationScript,
    required String language,
  }) async {
    final voiceId = language == 'en' ? _enVoiceId : _viVoiceId;

    final createResp = await _client.functions.invoke('tts-proxy', body: {
      'action': 'create',
      'report_id': reportId,
      'user_id': userId,
      'text': text,
      'voice_id': voiceId,
      'narration_script': narrationScript,
      'language': language,
      'speed': 1.0,
    });
    final rawCreate = createResp.data;
    if (rawCreate is! Map) {
      throw Exception('Video job creation failed: unexpected response');
    }
    final createData = Map<String, dynamic>.from(rawCreate);
    final jobId = createData['job_id'];
    if (jobId == null) {
      throw Exception('Video job creation failed: no job_id returned');
    }

    for (var attempt = 0; attempt < _maxPollAttempts; attempt++) {
      await Future.delayed(_pollInterval);

      final pollResp = await _client.functions.invoke('tts-proxy', body: {
        'action': 'poll',
        'job_id': jobId,
      });
      final data = Map<String, dynamic>.from(pollResp.data as Map);

      final job = interpretPollResponse(data);
      if (job != null) return job;
    }

    throw Exception('TTS timed out');
  }

  @override
  String proxiedAudioUrl(String rawAudioUrl) {
    final encoded = Uri.encodeComponent(rawAudioUrl);
    return '${SupabaseConfig.url}/functions/v1/tts-proxy?audio_url=$encoded';
  }

  @override
  Map<String, String> audioHeaders() => {
        'Authorization':
            'Bearer ${_client.auth.currentSession?.accessToken ?? ''}',
        'apikey': SupabaseConfig.anonKey,
      };
}
