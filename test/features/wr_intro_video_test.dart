// Video hướng dẫn tự dựng (đợt E2, chốt 03/10): cảnh hình động trong Flutter +
// giọng đọc AI sinh sẵn một lần, đóng gói trong app.
//
// Khoá:
//   1. Onboarding (mockup v47): video mở SAU bước Riêng tư, không tự bật ở
//      bước đầu; cờ đã xem được ghi lúc mở.
//   2. Không bao giờ treo Onboarding: audio lỗi hoặc quá 8 giây thì hiện câu
//      "Chưa tải được video..." kèm nút đóng; nút đóng bấm được cả lúc đang
//      tải; đóng xong sang bước chọn cảm xúc.
//   3. Web bắt đầu tắt tiếng (trình duyệt chặn tự phát có tiếng), có nút
//      "Bật tiếng".
//   4. Không có giọng đọc (chưa sinh được, hoặc lời đọc đã sửa mà chưa sinh
//      lại) thì vẫn chạy: cảnh tự chuyển theo thời lượng ước tính, có phụ đề.
//   5. File JSON đã đóng gói phải khớp lời đọc hiện tại.
//   6. Màn Hướng dẫn có dòng "Xem lại video hướng dẫn".
//
// Không bài nào gọi mạng hay just_audio thật: audio là controller giả.
//
// Run: flutter test test/features/wr_intro_video_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/onboarding/intro_video_providers.dart';
import 'package:workreflection_mobile/features/onboarding/intro_video_script.dart';
import 'package:workreflection_mobile/features/onboarding/intro_video_timeline.dart';
import 'package:workreflection_mobile/features/onboarding/presentation/intro_scene_view.dart';
import 'package:workreflection_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:workreflection_mobile/features/onboarding/presentation/wr_intro_video_sheet.dart';
import 'package:workreflection_mobile/features/profile/presentation/guide_screen.dart';
import 'package:workreflection_mobile/features/video_report/data/video_audio_controller.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Giả
// ---------------------------------------------------------------------------

class FakeIntroAudio implements VideoAudioController {
  FakeIntroAudio({this.failLoad = false, this.hangLoad = false});

  final bool failLoad;
  final bool hangLoad;
  final _pos = StreamController<Duration>.broadcast();
  final _playingCtl = StreamController<bool>.broadcast();
  bool _playing = false;

  final List<String> loadedUrls = [];
  int playCalls = 0;
  int pauseCalls = 0;
  final List<Duration> seeks = [];

  @override
  Stream<Duration> get positionStream => _pos.stream;
  @override
  Stream<bool> get playingStream => _playingCtl.stream;
  @override
  bool get playing => _playing;

  @override
  Future<void> load(String url, Map<String, String> headers) async {
    loadedUrls.add(url);
    if (failLoad) throw Exception('không đọc được file');
    if (hangLoad) await Completer<void>().future;
  }

  @override
  Future<void> play() async {
    playCalls++;
    _playing = true;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _playing = false;
  }

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<void> dispose() async {}
}

/// JSON giống hệt file mà `tool/gen_intro_narration.dart` ghi, khớp lời đọc
/// hiện tại, mỗi cảnh 6 giây.
String recordedJson({String lang = 'vi', String? overrideFirstText}) {
  final scenes = introNarrationScenes;
  var t = 0;
  final list = [
    for (var i = 0; i < scenes.length; i++)
      {
        'id': scenes[i].id.name,
        'text': i == 0 && overrideFirstText != null
            ? overrideFirstText
            : scenes[i].text,
        'startMs': t,
        'endMs': t += 6000,
      },
  ];
  return jsonEncode({
    'lang': lang,
    'audio': 'assets/intro/intro_$lang.mp3',
    'durationMs': t,
    'scenes': list,
  });
}

Widget _app(
  Widget home, {
  IntroTimingSource? source,
  VideoAudioController? audio,
}) {
  return ProviderScope(
    overrides: [
      introTimingSourceProvider.overrideWithValue(source ?? (_) async => null),
      if (audio != null) videoAudioControllerProvider.overrideWithValue(audio),
    ],
    child: MaterialApp(
      builder: wrTextScaleBuilder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: home,
    ),
  );
}

/// Bấm "Tiếp tục" qua ba bước có hero, tới bước Riêng tư rồi bấm tiếp —
/// đúng chỗ video hướng dẫn mở.
Future<void> _toPrivacyAndContinue(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.tap(find.byKey(const Key('onboarding_next')));
    // Qua hết hiệu ứng chuyển bước (220ms) để không còn hai nút cùng khoá:
    // khung đầu khởi động hiệu ứng, khung giữa chạy hết, khung cuối gỡ màn cũ.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }
  await _settleOpen(tester);
}

Future<void> _settleOpen(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String get _errorText =>
    'Chưa tải được video. Bạn có thể xem lại trong phần Hướng dẫn.';

void main() {
  setUp(() {
    wrEnglish = false;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => wrEnglish = false);

  // -------------------------------------------------------------------------
  // Lời đọc và thời lượng
  // -------------------------------------------------------------------------

  group('lời đọc', () {
    for (final en in [false, true]) {
      test('${en ? 'EN' : 'VI'}: 6 cảnh, giọng app, không dấu gạch dài', () {
        wrEnglish = en;
        final scenes = introNarrationScenes;
        expect(scenes.map((s) => s.id), IntroSceneId.values);
        final emoji = RegExp(
          r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
          unicode: true,
        );
        for (final s in scenes) {
          expect(s.text.trim(), isNotEmpty);
          expect(s.text.contains('—'), isFalse, reason: s.id.name);
          expect(s.text.contains('–'), isFalse, reason: s.id.name);
          expect(emoji.hasMatch(s.text), isFalse, reason: s.id.name);
        }
        if (!en) {
          expect(scenes.first.text, contains('bạn'));
        }
      });

      test('${en ? 'EN' : 'VI'}: cảnh nhìn lại kể đủ BỐN bước của HDSD v4', () {
        wrEnglish = en;
        final reflect = introNarrationScenes
            .firstWhere((s) => s.id == IntroSceneId.reflect)
            .text
            .toLowerCase();
        expect(kIntroReflectSteps, hasLength(4));
        for (final step in kIntroReflectSteps) {
          expect(reflect, contains(step.toLowerCase()));
        }
        expect(reflect, contains(en ? 'four steps' : 'bốn bước'));
      });

      test(
        '${en ? 'EN' : 'VI'}: không có giọng đọc → ước tính 45 đến 60 giây',
        () {
          wrEnglish = en;
          final t = buildIntroTimeline(introNarrationScenes);
          expect(t.audioAsset, isNull);
          expect(t.durationMs, inInclusiveRange(45000, 60000));
        },
      );
    }
  });

  group('dòng thời gian', () {
    test('cảnh nối liền nhau từ 0 tới hết, phụ đề phủ đủ câu', () {
      final t = buildIntroTimeline(introNarrationScenes);
      expect(t.scenes.first.startMs, 0);
      expect(t.scenes.last.endMs, t.durationMs);
      for (var i = 1; i < t.scenes.length; i++) {
        expect(t.scenes[i].startMs, t.scenes[i - 1].endMs);
      }
      final joined = t.cues.map((c) => c.text).join(' ');
      for (final s in introNarrationScenes) {
        expect(joined, contains(s.text.split(' ').first));
      }
      for (final c in t.cues) {
        expect(c.endMs, greaterThan(c.startMs));
      }
      expect(t.sceneAt(0)!.id, IntroSceneId.welcome);
      expect(t.sceneAt(t.durationMs + 10)!.id, IntroSceneId.closing);
    });

    test('JSON khớp lời đọc → dùng giọng đọc và thời điểm đã ghi', () {
      final rec = jsonDecode(recordedJson()) as Map<String, dynamic>;
      final t = buildIntroTimeline(introNarrationScenes, recorded: rec);
      expect(t.audioAsset, 'assets/intro/intro_vi.mp3');
      expect(t.durationMs, 36000);
      expect(t.scenes[1].startMs, 6000);
    });

    test('lời đọc đã sửa mà chưa sinh lại → bỏ tiếng, không phát câu cũ', () {
      final rec =
          jsonDecode(recordedJson(overrideFirstText: 'Câu cũ.'))
              as Map<String, dynamic>;
      expect(introRecordingMatches(introNarrationScenes, rec), isFalse);
      final t = buildIntroTimeline(introNarrationScenes, recorded: rec);
      expect(t.audioAsset, isNull);
    });

    test('file JSON đã đóng gói khớp lời đọc hiện tại', () {
      // Thư mục giọng đọc phải được khai báo sẵn, để lần sinh sau chỉ cần
      // chạy script là app nhận file, không phải nhớ sửa pubspec.
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/intro/'),
      );
      for (final lang in ['vi', 'en']) {
        final f = File('assets/intro/intro_$lang.json');
        if (!f.existsSync()) continue; // chưa sinh được giọng đọc
        wrEnglish = lang == 'en';
        final rec = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        expect(
          introRecordingMatches(introNarrationScenes, rec),
          isTrue,
          reason:
              'Lời đọc $lang đã sửa mà chưa sinh lại giọng đọc. Chạy: '
              'dart run tool/gen_intro_narration.dart $lang',
        );
        expect(File(rec['audio'] as String).existsSync(), isTrue);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Cờ theo thiết bị
  // -------------------------------------------------------------------------

  test(
    'cờ: chưa đọc xong là null, máy mới là false, đánh dấu thì lưu',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(introVideoShownProvider), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(introVideoShownProvider), isFalse);

      await container.read(introVideoShownProvider.notifier).markShown();
      expect(container.read(introVideoShownProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kIntroVideoShownKey), isTrue);
    },
  );

  // -------------------------------------------------------------------------
  // Onboarding (mockup v47): video phát SAU bước Riêng tư
  // -------------------------------------------------------------------------

  testWidgets(
    'bước đầu không tự bật video; hết bước Riêng tư thì mở, cờ = true',
    (tester) async {
      await tester.pumpWidget(_app(const OnboardingScreen()));
      await _settleOpen(tester);
      expect(find.byType(WrIntroVideoSheet), findsNothing);

      await _toPrivacyAndContinue(tester);
      expect(find.byType(WrIntroVideoSheet), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kIntroVideoShownKey), isTrue);
    },
  );

  testWidgets(
    'controller lỗi → hiện câu chưa tải được + nút đóng; đóng xong sang bước '
    'chọn cảm xúc',
    (tester) async {
      final audio = FakeIntroAudio(failLoad: true);
      await tester.pumpWidget(
        _app(
          const OnboardingScreen(),
          source: (lang) async => recordedJson(lang: lang),
          audio: audio,
        ),
      );
      await _settleOpen(tester);
      await _toPrivacyAndContinue(tester);

      expect(audio.loadedUrls, ['asset:///assets/intro/intro_vi.mp3']);
      expect(find.text(_errorText), findsOneWidget);
      await tester.tap(find.byKey(const Key('intro_video_close')));
      await _settleOpen(tester);
      expect(find.byType(WrIntroVideoSheet), findsNothing);
      expect(find.byKey(const Key('onboarding_mood_ok')), findsOneWidget);
    },
  );

  testWidgets('tải quá 8 giây → câu chưa tải được, không treo', (tester) async {
    final audio = FakeIntroAudio(hangLoad: true);
    await tester.pumpWidget(
      _app(
        const WrIntroVideoSheet(),
        source: (lang) async => recordedJson(lang: lang),
        audio: audio,
      ),
    );
    await _settleOpen(tester);
    expect(find.text(_errorText), findsNothing);

    await tester.pump(const Duration(seconds: 9));
    expect(find.text(_errorText), findsOneWidget);
  });

  testWidgets('nút đóng bấm được ngay cả khi video đang tải', (tester) async {
    final audio = FakeIntroAudio(hangLoad: true);
    await tester.pumpWidget(
      _app(
        const OnboardingScreen(),
        source: (lang) async => recordedJson(lang: lang),
        audio: audio,
      ),
    );
    await tester.pump();
    await _toPrivacyAndContinue(tester);
    expect(find.byType(WrIntroVideoSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('intro_video_close')));
    await _settleOpen(tester);
    expect(find.byType(WrIntroVideoSheet), findsNothing);
    expect(find.byKey(const Key('onboarding_mood_ok')), findsOneWidget);
    // Hết hạn 8 giây sau khi đã đóng cũng không được ném lỗi.
    await tester.pump(const Duration(seconds: 9));
    expect(tester.takeException(), isNull);
  });

  // -------------------------------------------------------------------------
  // Phát
  // -------------------------------------------------------------------------

  testWidgets('không có giọng đọc: cảnh tự chuyển theo thời gian, có phụ đề', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const WrIntroVideoSheet()));
    await _settleOpen(tester);

    final t = buildIntroTimeline(introNarrationScenes);
    expect(find.text(t.cues.first.text), findsOneWidget);
    expect(
      tester.widget<IntroSceneView>(find.byType(IntroSceneView)).sceneId,
      IntroSceneId.welcome,
    );
    // Không có giọng đọc thì không có nút bật tiếng.
    expect(find.byKey(const Key('intro_video_unmute')), findsNothing);

    await tester.pump(Duration(milliseconds: t.scenes[1].startMs + 300));
    expect(
      tester.widget<IntroSceneView>(find.byType(IntroSceneView)).sceneId,
      IntroSceneId.reflect,
    );
  });

  testWidgets('có giọng đọc, không tắt tiếng → phát tiếng ngay', (
    tester,
  ) async {
    final audio = FakeIntroAudio();
    await tester.pumpWidget(
      _app(
        const WrIntroVideoSheet(startMuted: false),
        source: (lang) async => recordedJson(lang: lang),
        audio: audio,
      ),
    );
    await _settleOpen(tester);
    expect(audio.playCalls, 1);
    expect(find.text('Bật tiếng'), findsNothing);
  });

  testWidgets('web: bắt đầu tắt tiếng, có nút Bật tiếng, bấm thì phát', (
    tester,
  ) async {
    final audio = FakeIntroAudio();
    await tester.pumpWidget(
      _app(
        const WrIntroVideoSheet(startMuted: true),
        source: (lang) async => recordedJson(lang: lang),
        audio: audio,
      ),
    );
    await _settleOpen(tester);
    expect(audio.playCalls, 0);
    expect(find.text('Bật tiếng'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('intro_video_unmute')));
    await tester.pump();
    expect(audio.playCalls, 1);
    // Tiếng bắt đầu đúng chỗ hình đang chạy, không quay về đầu.
    expect(audio.seeks.last.inMilliseconds, greaterThan(1500));
  });

  testWidgets('bố cục cảnh không tràn ở màn hẹp', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final en in [false, true]) {
      wrEnglish = en;
      for (final id in IntroSceneId.values) {
        for (final p in [0.0, 0.5, 1.0]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: IntroSceneView(sceneId: id, progress: p),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$id $p en=$en');
        }
      }
    }
  });

  // -------------------------------------------------------------------------
  // Màn Hướng dẫn
  // -------------------------------------------------------------------------

  testWidgets('màn Hướng dẫn có dòng Xem lại video hướng dẫn', (tester) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const GuideScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          introTimingSourceProvider.overrideWithValue((_) async => null),
        ],
        child: MaterialApp.router(
          builder: wrTextScaleBuilder,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    final row = find.text('Xem lại video hướng dẫn');
    expect(row, findsOneWidget);
    await tester.tap(row);
    await _settleOpen(tester);
    expect(find.byType(WrIntroVideoSheet), findsOneWidget);
  });
}
