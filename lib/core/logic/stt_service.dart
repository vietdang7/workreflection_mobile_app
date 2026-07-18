// Abstract STT service + real implementation backed by the speech_to_text
// package. Tests inject a FakeSttService so the mic is never touched.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// Callback invoked each time a (partial or final) transcript arrives.
typedef SttResultCallback = void Function(String transcript, {required bool isFinal});

/// Minimal STT contract used by the survey questions screen.
abstract class SttService {
  /// Returns true if speech recognition is available on this device.
  Future<bool> get isAvailable;

  /// Start listening. [localeId] is e.g. 'vi-VN' or 'en-US'.
  /// [onResult] is called with every partial / final transcript.
  /// [listenFor] is the maximum listen window; the service may stop earlier.
  Future<void> startListening({
    required String localeId,
    required SttResultCallback onResult,
    Duration listenFor = const Duration(seconds: 10),
  });

  /// Stop listening (user-initiated or timeout).
  Future<void> stopListening();

  /// Current listening state.
  bool get isListening;
}

// ---------------------------------------------------------------------------
// Real implementation
// ---------------------------------------------------------------------------

class RealSttService implements SttService {
  final _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _listening = false;

  @override
  Future<bool> get isAvailable async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (e) {},
      onStatus: (_) {},
    );
    return _initialized;
  }

  @override
  Future<void> startListening({
    required String localeId,
    required SttResultCallback onResult,
    Duration listenFor = const Duration(seconds: 10),
  }) async {
    final available = await isAvailable;
    if (!available) return;
    _listening = true;
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenFor: listenFor,
        partialResults: true,
      ),
      onResult: (result) {
        onResult(result.recognizedWords, isFinal: result.finalResult);
      },
    );
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
    await _speech.stop();
  }

  @override
  bool get isListening => _listening && _speech.isListening;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final sttServiceProvider = Provider<SttService>((ref) => RealSttService());
