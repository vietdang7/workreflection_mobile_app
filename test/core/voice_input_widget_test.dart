import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/stt_service.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/survey/presentation/survey_questions_screen.dart';
import 'package:workreflection_mobile/features/survey/survey_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_survey_repository.dart';

// ---------------------------------------------------------------------------
// Fake STT service — never touches the real mic
// ---------------------------------------------------------------------------

class FakeSttService implements SttService {
  final bool available;
  bool _listening = false;
  SttResultCallback? _onResult;

  /// If set, fires immediately when startListening is called.
  String? pendingTranscript;
  bool pendingIsFinal = true;

  FakeSttService({this.available = true});

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<void> startListening({
    required String localeId,
    required SttResultCallback onResult,
    Duration listenFor = const Duration(seconds: 10),
  }) async {
    _listening = true;
    _onResult = onResult;
    if (pendingTranscript != null) {
      onResult(pendingTranscript!, isFinal: pendingIsFinal);
    }
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
  }

  @override
  bool get isListening => _listening;

  /// Push a transcript result mid-session from a test.
  void emit(String transcript, {bool isFinal = true}) {
    _onResult?.call(transcript, isFinal: isFinal);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CcQuestion _q(String id, SurveyLayer layer, ScaleType scale, int order) =>
    CcQuestion(
      id: id,
      layer: layer,
      scaleType: scale,
      questionText: 'Câu hỏi $id',
      questionOrder: order,
      isActive: true,
    );

CcLikertOption _opt(ScaleType scale, int value, String label) =>
    CcLikertOption(
        scaleType: scale, value: value, label: label, displayOrder: value);

FakeSurveyRepository _repo() {
  final repo = FakeSurveyRepository();
  repo.seedRole('user'); // FREE survey type
  repo.seedQuestions([_q('q1', SurveyLayer.structure, ScaleType.likert5, 1)]);
  repo.seedLikertOptions({
    ScaleType.likert5: List.generate(
      5,
      (i) => _opt(ScaleType.likert5, i + 1, 'Lựa chọn ${i + 1}'),
    ),
  });
  return repo;
}

Widget _wrap({
  required FakeSurveyRepository repo,
  required FakeSttService stt,
}) {
  return ProviderScope(
    overrides: [
      surveyRepositoryProvider.overrideWithValue(repo),
      sttServiceProvider.overrideWithValue(stt),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('vi')],
      home: SurveyQuestionsScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('_MicButton — STT unavailable', () {
    testWidgets('mic button hidden when STT not available', (tester) async {
      final stt = FakeSttService(available: false);
      await tester.pumpWidget(_wrap(repo: _repo(), stt: stt));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
    });
  });

  group('_MicButton — STT available', () {
    testWidgets('idle mic icon shown when STT available', (tester) async {
      final stt = FakeSttService(available: true);
      await tester.pumpWidget(_wrap(repo: _repo(), stt: stt));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    });

    testWidgets('tap mic → listening state (pulsing icon visible)', (tester) async {
      final stt = FakeSttService(available: true);
      // No pending transcript — stays listening.
      await tester.pumpWidget(_wrap(repo: _repo(), stt: stt));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none_outlined));
      await tester.pump();

      // Pulsing mic icon shown while listening.
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('matched transcript → listening stops, idle icon returns', (tester) async {
      final stt = FakeSttService(available: true);
      // "ba" → 3 in Vietnamese
      stt.pendingTranscript = 'ba';
      stt.pendingIsFinal = true;

      await tester.pumpWidget(_wrap(repo: _repo(), stt: stt));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none_outlined));
      await tester.pumpAndSettle();

      // After match, listening stops → idle icon returns.
      expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('no-match final transcript → snackbar, idle icon returns', (tester) async {
      final stt = FakeSttService(available: true);
      stt.pendingTranscript = 'xin chào thế giới'; // no number
      stt.pendingIsFinal = true;

      await tester.pumpWidget(_wrap(repo: _repo(), stt: stt));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none_outlined));
      await tester.pumpAndSettle();

      // Snackbar with no-match message.
      expect(find.byType(SnackBar), findsOneWidget);
      // Mic back to idle.
      expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    });

    testWidgets('tap mic while listening → stops listening', (tester) async {
      final stt = FakeSttService(available: true);
      // No transcript — stays listening indefinitely.
      await tester.pumpWidget(_wrap(repo: _repo(), stt: stt));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Tap again to stop.
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    });
  });
}
