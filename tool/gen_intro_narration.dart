// Sinh giọng đọc cho video hướng dẫn (màn chào), MỘT LẦN, rồi đóng gói vào app.
//
//     dart run tool/gen_intro_narration.dart vi
//     dart run tool/gen_intro_narration.dart en
//
// Vì sao sinh sẵn chứ không gọi lúc người dùng mở video: khoá Ausynclab đang ở
// gói miễn phí, mỗi lần mở mà gọi đọc giọng là đốt hạn mức cho cùng một câu.
// Lời đọc giống nhau với mọi người, nên đọc một lần là đủ.
//
// Cách làm:
//   1. Đọc lời đọc từ `lib/features/onboarding/intro_video_script.dart` (nguồn
//      duy nhất, cùng chỗ app lấy phụ đề).
//   2. Mỗi cảnh gọi `tts-proxy` hành động `generate_and_wait`, đúng cách màn
//      khảo sát đang gọi (`SurveyRepository.tts`). Không dùng `create`/`poll`
//      như video báo cáo: `create` ghi một dòng `cc_video_jobs` gắn với một
//      báo cáo và một người dùng có thật. `generate_and_wait` chỉ ghi bảng đệm
//      `cc_tts_cache` theo băm của câu, nên chạy lại với câu không đổi thì lấy
//      lại từ đệm, KHÔNG gọi Ausynclab lần nữa.
//   3. Đọc theo từng cảnh nên biết chính xác cảnh nào dài bao lâu, không phải
//      đoán ranh giới từ phụ đề.
//   4. ffmpeg nối các cảnh (mỗi cảnh cách nhau một khoảng lặng ngắn) thành
//      `assets/intro/intro_<lang>.mp3`, và ghi thời điểm từng cảnh vào
//      `assets/intro/intro_<lang>.json`.
//
// Cần: `ffmpeg`, `ffprobe` trong PATH và mạng tới Supabase.
// Lỗi ở bất kỳ cảnh nào thì dừng, không ghi file nào: app khi đó chạy video
// không tiếng (cảnh tự chuyển theo thời lượng ước tính, kèm phụ đề).

import 'dart:convert';
import 'dart:io';

import 'package:workreflection_mobile/core/l10n/wr_tr.dart';
import 'package:workreflection_mobile/core/supabase/supabase_config.dart';
import 'package:workreflection_mobile/features/onboarding/intro_video_script.dart';

/// Cùng giọng với video báo cáo (`SupabaseVideoReportRepository`) và khảo sát.
const _voiceIds = {'vi': 1619321, 'en': 1914576};

/// Khoảng lặng chèn sau mỗi cảnh (trừ cảnh cuối), để hai cảnh không dính nhau.
const _gapSeconds = 0.6;

Future<void> main(List<String> args) async {
  final lang = args.isEmpty ? '' : args.first;
  if (!_voiceIds.containsKey(lang)) {
    stderr.writeln('Dùng: dart run tool/gen_intro_narration.dart <vi|en>');
    exit(64);
  }
  wrEnglish = lang == 'en';
  final scenes = introNarrationScenes;
  final voiceId = _voiceIds[lang]!;

  final work = await Directory.systemTemp.createTemp('wr_intro_$lang');
  final client = HttpClient();
  try {
    final padded = <File>[];
    final durationsMs = <int>[];
    for (var i = 0; i < scenes.length; i++) {
      final scene = scenes[i];
      stdout.writeln('[$lang] cảnh ${scene.id.name}: gọi tts-proxy...');
      final res = await _postJson(
        client,
        Uri.parse('${SupabaseConfig.url}/functions/v1/tts-proxy'),
        {
          'action': 'generate_and_wait',
          'text': scene.text,
          'voiceId': voiceId,
          'speed': 1.0,
          'language': lang,
        },
      );
      final audioUrl = res['audioUrl'];
      if (audioUrl is! String || audioUrl.isEmpty) {
        throw StateError('tts-proxy không trả audioUrl: ${jsonEncode(res)}');
      }
      stdout.writeln(
        '[$lang]   ${res['fromCache'] == true ? 'lấy từ đệm' : 'đã sinh mới'}',
      );

      final raw = File('${work.path}/scene_$i.raw');
      await _download(client, Uri.parse(audioUrl), raw);

      // Chuẩn hoá về PCM mono 24 kHz và chèn khoảng lặng sau cảnh, để các mảnh
      // nối thẳng với nhau được.
      final wav = File('${work.path}/scene_$i.wav');
      final isLast = i == scenes.length - 1;
      await _run('ffmpeg', [
        '-y',
        '-loglevel',
        'error',
        '-i',
        raw.path,
        '-ac',
        '1',
        '-ar',
        '24000',
        if (!isLast) ...['-af', 'apad=pad_dur=$_gapSeconds'],
        wav.path,
      ]);
      padded.add(wav);
      durationsMs.add(await _durationMs(wav.path));
    }

    final list = File('${work.path}/list.txt');
    await list.writeAsString(padded.map((f) => "file '${f.path}'").join('\n'));
    final outDir = Directory('assets/intro');
    await outDir.create(recursive: true);
    final mp3Path = '${outDir.path}/intro_$lang.mp3';
    await _run('ffmpeg', [
      '-y',
      '-loglevel',
      'error',
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      list.path,
      '-ac',
      '1',
      '-b:a',
      '64k',
      mp3Path,
    ]);
    final totalMs = await _durationMs(mp3Path);

    final timed = <Map<String, Object>>[];
    var start = 0;
    for (var i = 0; i < scenes.length; i++) {
      final isLast = i == scenes.length - 1;
      final end = isLast ? totalMs : start + durationsMs[i];
      timed.add({
        'id': scenes[i].id.name,
        'text': scenes[i].text,
        'startMs': start,
        'endMs': end,
      });
      start = end;
    }
    final json = {
      'lang': lang,
      'voiceId': voiceId,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'audio': mp3Path,
      'durationMs': totalMs,
      'scenes': timed,
    };
    await File(
      '${outDir.path}/intro_$lang.json',
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(json)}\n');
    stdout.writeln(
      '[$lang] xong: $mp3Path, ${(totalMs / 1000).toStringAsFixed(1)} giây',
    );
  } catch (e) {
    stderr.writeln('[$lang] DỪNG, không ghi file nào: $e');
    exitCode = 1;
  } finally {
    client.close(force: true);
    await work.delete(recursive: true);
  }
}

Future<Map<String, dynamic>> _postJson(
  HttpClient client,
  Uri uri,
  Map<String, Object> body,
) async {
  final req = await client.postUrl(uri);
  req.headers
    ..set('Authorization', 'Bearer ${SupabaseConfig.anonKey}')
    ..set('apikey', SupabaseConfig.anonKey)
    ..contentType = ContentType.json;
  req.write(jsonEncode(body));
  final res = await req.close();
  final text = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) {
    throw HttpException('tts-proxy ${res.statusCode}: $text', uri: uri);
  }
  return Map<String, dynamic>.from(jsonDecode(text) as Map);
}

Future<void> _download(HttpClient client, Uri uri, File to) async {
  final req = await client.getUrl(uri);
  req.headers
    ..set('Authorization', 'Bearer ${SupabaseConfig.anonKey}')
    ..set('apikey', SupabaseConfig.anonKey);
  final res = await req.close();
  if (res.statusCode != 200) {
    throw HttpException('tải audio ${res.statusCode}', uri: uri);
  }
  await res.pipe(to.openWrite());
}

Future<void> _run(String exe, List<String> args) async {
  final r = await Process.run(exe, args);
  if (r.exitCode != 0) {
    throw ProcessException(exe, args, '${r.stderr}', r.exitCode);
  }
}

Future<int> _durationMs(String path) async {
  final r = await Process.run('ffprobe', [
    '-v',
    'error',
    '-show_entries',
    'format=duration',
    '-of',
    'default=noprint_wrappers=1:nokey=1',
    path,
  ]);
  if (r.exitCode != 0) {
    throw ProcessException('ffprobe', [path], '${r.stderr}', r.exitCode);
  }
  return (double.parse('${r.stdout}'.trim()) * 1000).round();
}
