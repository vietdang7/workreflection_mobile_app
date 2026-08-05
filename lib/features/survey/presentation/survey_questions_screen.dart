import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/logic/stt_service.dart';
import '../../../core/logic/voice_answer_matcher.dart';
import '../../../core/models/survey_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/progress_track.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/profile_providers.dart';
import '../survey_providers.dart';

// ---------------------------------------------------------------------------
// TTS playback provider (per-screen, auto-disposed)
// ---------------------------------------------------------------------------

final _ttsPlaybackProvider =
    StateNotifierProvider.autoDispose<TtsPlaybackNotifier, TtsPlaybackState>(
        (ref) => TtsPlaybackNotifier(ref));

class TtsPlaybackState {
  const TtsPlaybackState({
    this.isPlaying = false,
    this.isLoading = false,
    this.audioUrl,
    this.durationMs = 0,
    this.positionMs = 0,
    this.questionId,
  });
  final bool isPlaying;
  final bool isLoading;
  final String? audioUrl;
  final int durationMs;
  final int positionMs;
  final String? questionId;

  /// Active word index estimated from positionMs / durationMs * wordCount.
  int activeWordIndex(int wordCount) {
    if (durationMs <= 0 || wordCount == 0) return -1;
    return ((positionMs / durationMs) * wordCount).floor().clamp(0, wordCount - 1);
  }
}

class TtsPlaybackNotifier extends StateNotifier<TtsPlaybackState> {
  TtsPlaybackNotifier(this._ref) : super(const TtsPlaybackState()) {
    _player = AudioPlayer();
    _ref.onDispose(() => _player.dispose());
  }

  final Ref _ref;
  late final AudioPlayer _player;
  StreamSubscription<Duration>? _posSub;

  Future<void> toggle(String text, String language, {String? questionId}) async {
    if (state.isPlaying) {
      await _player.pause();
      state = TtsPlaybackState(
        isPlaying: false,
        audioUrl: state.audioUrl,
        durationMs: state.durationMs,
        positionMs: state.positionMs,
        questionId: state.questionId,
      );
      return;
    }

    // Resume only if same question.
    if (state.audioUrl != null && !state.isLoading && state.questionId == questionId) {
      await _player.play();
      state = TtsPlaybackState(
        isPlaying: true,
        audioUrl: state.audioUrl,
        durationMs: state.durationMs,
        positionMs: state.positionMs,
        questionId: state.questionId,
      );
      return;
    }

    // New question — stop any existing playback first.
    if (state.isPlaying || state.audioUrl != null) {
      await _player.stop();
    }
    state = TtsPlaybackState(isLoading: true, questionId: questionId);
    try {
      final repo = _ref.read(surveyRepositoryProvider);
      final result = await repo.tts(text, language);
      await _player.setUrl(result.audioUrl);
      await _player.play();

      await _posSub?.cancel();
      _posSub = _player.positionStream.listen((pos) {
        state = TtsPlaybackState(
          isPlaying: _player.playing,
          audioUrl: result.audioUrl,
          durationMs: result.durationMs,
          positionMs: pos.inMilliseconds,
          questionId: questionId,
        );
      });

      state = TtsPlaybackState(
        isPlaying: true,
        audioUrl: result.audioUrl,
        durationMs: result.durationMs,
        questionId: questionId,
      );
    } catch (_) {
      state = const TtsPlaybackState();
    }
  }

  Future<void> stopForQuestionChange() async {
    if (state.isPlaying) {
      await _player.stop();
    }
    state = const TtsPlaybackState();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// STT (voice input) provider (per-screen, auto-disposed)
// ---------------------------------------------------------------------------

class SttState {
  const SttState({
    this.isListening = false,
    this.isAvailable = false,
    this.transcript = '',
  });
  final bool isListening;
  final bool isAvailable;
  final String transcript;

  SttState copyWith({bool? isListening, bool? isAvailable, String? transcript}) =>
      SttState(
        isListening: isListening ?? this.isListening,
        isAvailable: isAvailable ?? this.isAvailable,
        transcript: transcript ?? this.transcript,
      );
}

class SttNotifier extends StateNotifier<SttState> {
  SttNotifier(this._stt) : super(const SttState()) {
    _init();
  }

  final SttService _stt;
  Timer? _timeout;

  Future<void> _init() async {
    final available = await _stt.isAvailable;
    if (mounted) state = state.copyWith(isAvailable: available);
  }

  Future<void> toggle({
    required String localeId,
    required int maxValue,
    required void Function(int value) onAnswer,
    required void Function() onNoMatch,
  }) async {
    if (state.isListening) {
      _stopAll();
      return;
    }
    if (!state.isAvailable) return;
    _timeout?.cancel();
    state = state.copyWith(isListening: true, transcript: '');

    await _stt.startListening(
      localeId: localeId,
      listenFor: const Duration(seconds: 10),
      onResult: (transcript, {required bool isFinal}) {
        if (!mounted) return;
        state = state.copyWith(transcript: transcript);
        if (isFinal || transcript.isNotEmpty) {
          final matched = matchVoiceAnswer(transcript, maxValue, locale: localeId);
          if (matched != null) {
            _stopAll();
            onAnswer(matched);
          } else if (isFinal && transcript.isNotEmpty) {
            _stopAll();
            onNoMatch();
          }
        }
      },
    );

    // Overall timeout — mirror the web 10s listen window.
    _timeout = Timer(const Duration(seconds: 10), () {
      if (mounted && state.isListening) {
        _stopAll();
        onNoMatch();
      }
    });
  }

  void _stopAll() {
    _timeout?.cancel();
    _stt.stopListening();
    if (mounted) state = state.copyWith(isListening: false);
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _stt.stopListening();
    super.dispose();
  }
}

final _sttProvider =
    StateNotifierProvider.autoDispose<SttNotifier, SttState>((ref) {
  return SttNotifier(ref.watch(sttServiceProvider));
});

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class SurveyQuestionsScreen extends ConsumerWidget {
  const SurveyQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeAsync = ref.watch(surveyTypeProvider);

    return typeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text(AppLocalizations.of(context)!.surveyProcessingError)),
      ),
      data: (type) => _QuestionsBody(surveyType: type),
    );
  }
}

class _QuestionsBody extends ConsumerWidget {
  const _QuestionsBody({required this.surveyType});
  final SurveyType surveyType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(surveyQuestionsProvider(surveyType));
    final optionsAsync = ref.watch(likertOptionsProvider);

    return questionsAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(AppLocalizations.of(context)!.surveyProcessingError))),
      data: (questions) => optionsAsync.when(
        loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(body: Center(child: Text(AppLocalizations.of(context)!.surveyProcessingError))),
        data: (options) => _QuestionView(
          questions: questions,
          options: options,
          surveyType: surveyType,
        ),
      ),
    );
  }
}

class _QuestionView extends ConsumerStatefulWidget {
  const _QuestionView({
    required this.questions,
    required this.options,
    required this.surveyType,
  });
  final List<CcQuestion> questions;
  final Map<ScaleType, List<CcLikertOption>> options;
  final SurveyType surveyType;

  @override
  ConsumerState<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends ConsumerState<_QuestionView> {
  Timer? _advanceTimer;
  int? _lastIndex;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  void _onAnswer(int index, String questionId, int value) {
    ref.read(surveyAnswersProvider.notifier).setAnswer(questionId, value);
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (index < widget.questions.length - 1) {
        ref.read(currentQuestionIndexProvider.notifier).state = index + 1;
      }
      // Last question — user taps "Hoàn thành" CTA manually
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = ref.watch(currentQuestionIndexProvider);
    final answers = ref.watch(surveyAnswersProvider);
    final questions = widget.questions;

    if (questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Stop TTS when question changes
    if (_lastIndex != null && _lastIndex != currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(_ttsPlaybackProvider.notifier).stopForQuestionChange();
        }
      });
    }
    _lastIndex = currentIndex;

    final safeIndex = currentIndex.clamp(0, questions.length - 1);
    final question = questions[safeIndex];
    final isLast = safeIndex == questions.length - 1;
    final currentAnswer = answers[question.id];

    final localeCode = ref.watch(appLocaleProvider);
    final displayText = localeCode == 'en' && question.questionTextEn != null
        ? question.questionTextEn!
        : question.questionText;
    final ttsLanguage = localeCode == 'en' ? 'en' : 'vi';

    // Determine layer label
    final layerLabel = _layerLabel(question.layer, l10n);

    // Options for this question's scale
    final scaleOptions = widget.options[question.scaleType] ?? [];

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: safeIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: WrColors.navy),
                onPressed: () {
                  ref.read(currentQuestionIndexProvider.notifier).state =
                      safeIndex - 1;
                },
              )
            : IconButton(
                icon: const Icon(Icons.close, color: WrColors.navy),
                onPressed: () => context.pop(),
              ),
        actions: [
          _TtsButton(
            questionText: displayText,
            language: ttsLanguage,
            questionId: question.id,
          ),
          _MicButton(
            localeId: localeCode == 'en' ? 'en-US' : 'vi-VN',
            maxValue: question.scaleType == ScaleType.enps10 ? 10 : 5,
            onAnswer: (v) => _onAnswer(safeIndex, question.id, v),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: WrProgressTrack(
                      value: questions.isEmpty
                          ? 0
                          : (safeIndex + 1) / questions.length,
                      color: WrColors.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.surveyProgress(safeIndex + 1, questions.length),
                    style: WrTextStyles.greeting,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WrEyebrow(layerLabel),
                    const SizedBox(height: 16),
                    _TtsQuestionText(questionText: displayText),
                    const SizedBox(height: 28),

                    // Answer options
                    if (question.scaleType == ScaleType.enps10)
                      _EnpsGrid(
                        currentAnswer: currentAnswer,
                        onAnswer: (v) =>
                            _onAnswer(safeIndex, question.id, v),
                      )
                    else
                      _LikertPills(
                        options: scaleOptions,
                        currentAnswer: currentAnswer,
                        onAnswer: (v) =>
                            _onAnswer(safeIndex, question.id, v),
                      ),

                    const SizedBox(height: 32),

                    // Last question CTA
                    if (isLast && currentAnswer != null)
                      WrPillButton(
                        label: l10n.surveyCompleteCta,
                        onPressed: () {
                          ref
                              .read(currentQuestionIndexProvider.notifier)
                              .state = 0;
                          context.pushReplacement('/survey/processing');
                        },
                        variant: WrPillVariant.coral,
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _layerLabel(SurveyLayer layer, AppLocalizations l10n) {
    return switch (layer) {
      SurveyLayer.structure => l10n.surveyLayerStructure,
      SurveyLayer.culture => l10n.surveyLayerCulture,
      SurveyLayer.activity => l10n.surveyLayerActivity,
      SurveyLayer.esi => l10n.surveyLayerEsi,
      SurveyLayer.enps => l10n.surveyLayerEnps,
    };
  }
}

// ---------------------------------------------------------------------------
// TTS button
// ---------------------------------------------------------------------------

class _TtsButton extends ConsumerWidget {
  const _TtsButton({required this.questionText, required this.language, required this.questionId});
  final String questionText;
  final String language;
  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_ttsPlaybackProvider);
    return IconButton(
      icon: state.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              state.isPlaying ? Icons.pause_circle_outline : Icons.volume_up_outlined,
              color: state.isPlaying ? WrColors.coral : WrColors.navy,
            ),
      onPressed: () {
        ref
            .read(_ttsPlaybackProvider.notifier)
            .toggle(questionText, language, questionId: questionId);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Mic button (voice input)
// ---------------------------------------------------------------------------

class _MicButton extends ConsumerWidget {
  const _MicButton({
    required this.localeId,
    required this.maxValue,
    required this.onAnswer,
  });
  final String localeId;
  final int maxValue;
  final void Function(int) onAnswer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sttState = ref.watch(_sttProvider);

    // Hide if STT is unavailable on this device (emulator without mic, etc.)
    if (!sttState.isAvailable) return const SizedBox.shrink();

    final isListening = sttState.isListening;

    return IconButton(
      tooltip: isListening ? l10n.voiceInputStopListening : l10n.voiceInputTapToSpeak,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isListening
            ? _PulsingMicIcon(key: const ValueKey('listening'))
            : Icon(
                Icons.mic_none_outlined,
                key: const ValueKey('idle'),
                color: WrColors.navy,
              ),
      ),
      onPressed: () {
        ref.read(_sttProvider.notifier).toggle(
          localeId: localeId,
          maxValue: maxValue,
          onAnswer: onAnswer,
          onNoMatch: () {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.voiceInputNoMatch),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      },
    );
  }
}

/// Simple pulsing mic icon shown while STT is actively listening.
class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon({super.key});

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Icon(Icons.mic, color: WrColors.coral),
    );
  }
}

// ---------------------------------------------------------------------------
// Question text with karaoke highlight
// ---------------------------------------------------------------------------

class _TtsQuestionText extends ConsumerWidget {
  const _TtsQuestionText({required this.questionText});
  final String questionText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(_ttsPlaybackProvider);
    final words = questionText.split(' ');
    final activeIdx = tts.activeWordIndex(words.length);

    return RichText(
      text: TextSpan(
        children: words.asMap().entries.map((e) {
          final isActive = tts.isPlaying && e.key == activeIdx;
          return TextSpan(
            text: '${e.value} ',
            style: WrTextStyles.hLarge.copyWith(
              backgroundColor: isActive
                  ? WrColors.coral.withValues(alpha: 0.2)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Likert pill options (LIKERT_5 / ESI_5)
// ---------------------------------------------------------------------------

class _LikertPills extends StatelessWidget {
  const _LikertPills({
    required this.options,
    required this.currentAnswer,
    required this.onAnswer,
  });
  final List<CcLikertOption> options;
  final int? currentAnswer;
  final void Function(int) onAnswer;

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(options)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return Column(
      children: sorted.map((opt) {
        final selected = currentAnswer == opt.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => onAnswer(opt.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: selected
                    ? WrColors.coral
                    : WrColors.navy.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: selected
                      ? WrColors.coral
                      : WrColors.navy.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                opt.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? WrColors.navy : WrColors.dark,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// eNPS 0–10 grid chips
// ---------------------------------------------------------------------------

class _EnpsGrid extends StatelessWidget {
  const _EnpsGrid({required this.currentAnswer, required this.onAnswer});
  final int? currentAnswer;
  final void Function(int) onAnswer;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(11, (i) {
        final selected = currentAnswer == i;
        return GestureDetector(
          onTap: () => onAnswer(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: selected
                  ? WrColors.coral
                  : WrColors.navy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? WrColors.coral
                    : WrColors.navy.withValues(alpha: 0.15),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$i',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: selected ? WrColors.navy : WrColors.dark,
              ),
            ),
          ),
        );
      }),
    );
  }
}
