// Hợp đồng giữa app, repo giả và migration của "Việc bạn tự đặt" (Task D1).
//
// Fake phải từ chối đúng những gì DB từ chối, và app phải gửi đúng hình dạng
// bảng. Hai lần trước dính lỗi 400 chỉ lộ khi chạy thật vì thiếu đúng loại test
// này.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:workreflection_mobile/core/data/wr_user_action_repository.dart';
import 'package:workreflection_mobile/core/models/wr_user_action.dart';

import '../support/fake_wr_user_action_repository.dart';

const _migrationPath =
    'supabase/migrations/20261001120000_wr_user_practice_actions.sql';

String _normalize(String s) => s.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

void main() {
  late String sql;

  setUpAll(() {
    sql = _normalize(File(_migrationPath).readAsStringSync());
  });

  group('migration ↔ fake: cùng một bộ luật', () {
    test('CHECK của title trong fake có nguyên văn trong migration', () {
      expect(sql, contains(_normalize(fakeUserActionTitleCheck)));
    });

    test('CHECK của target_count trong fake có nguyên văn trong migration', () {
      expect(sql, contains(_normalize(fakeUserActionTargetCheck)));
    });

    test('khoá chính một-lần-mỗi-ngày có trong migration', () {
      expect(sql, contains(_normalize(fakeUserActionLogPrimaryKey)));
    });

    test('mặc định target_count trong migration khớp hằng của app', () {
      expect(
        sql,
        contains(
          'target_count smallint not null default $kUserActionDefaultTarget',
        ),
      );
    });

    test('trần độ dài tiêu đề của app khớp CHECK', () {
      expect(sql, contains('between 1 and $kUserActionTitleMax'));
    });

    test('đủ 4 policy owner-only cho mỗi bảng', () {
      for (final table in [
        'wr_user_practice_actions',
        'wr_user_practice_action_logs',
      ]) {
        for (final op in ['select', 'insert', 'update', 'delete']) {
          expect(sql, contains('"${table}_owner_$op"'), reason: '$table $op');
        }
      }
    });
  });

  group('fake từ chối đúng như DB', () {
    test('tiêu đề toàn dấu cách → 23514', () async {
      final repo = FakeWrUserActionRepository();
      await expectLater(
        repo.add('    '),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
        ),
      );
    });

    test('121 ký tự → 23514, 120 ký tự → nhận', () async {
      final repo = FakeWrUserActionRepository();
      await expectLater(
        repo.add('x' * 121),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
        ),
      );
      final ok = await repo.add('y' * 120);
      expect(ok.title.length, 120);
    });

    test('tiếng Việt có dấu đếm theo ký tự, không theo byte', () async {
      final repo = FakeWrUserActionRepository();
      final ok = await repo.add('ệ' * 120);
      expect(ok.title.runes.length, 120);
    });

    test('ghi hai lần cùng ngày → 23505', () async {
      final repo = FakeWrUserActionRepository();
      final a = await repo.add('Hỏi ý kiến 1 đồng nghiệp mỗi ngày');
      await repo.logToday(a.id);
      await expectLater(
        repo.logToday(a.id),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '23505'),
        ),
      );
    });
  });

  group('hình dạng dòng app gửi lên', () {
    test('thêm việc: chỉ user_id + title, không id / created_at', () {
      final row = userActionInsertRow(userId: 'u1', title: '  Hỏi ý kiến  ');
      expect(row.keys.toSet(), {'user_id', 'title'});
      // App tự cắt khoảng trắng trước khi gửi.
      expect(row['title'], 'Hỏi ý kiến');
    });

    test('ghi log: action_id + user_id + done_on dạng yyyy-MM-dd', () {
      final row = userActionLogRow(
        userId: 'u1',
        actionId: 'a1',
        day: DateTime(2026, 10, 3, 23, 59),
      );
      expect(row, {
        'action_id': 'a1',
        'user_id': 'u1',
        'done_on': '2026-10-03',
      });
    });

    test('mọi cột app gửi đều có trong migration', () {
      for (final col in [
        ...userActionInsertRow(userId: 'u', title: 't').keys,
        ...userActionLogRow(
          userId: 'u',
          actionId: 'a',
          day: DateTime(2026),
        ).keys,
      ]) {
        expect(sql, contains(col), reason: col);
      }
    });
  });

  test(
    'exportUserData xuất cả hai bảng (quy định chung cho bảng wr_* mới)',
    () {
      // Bản Supabase thật không chạy được trong unit test, nên quét mã nguồn.
      final src = File('lib/core/data/wr_repository.dart').readAsStringSync();
      final start = src.indexOf(
        'Future<Map<String, dynamic>> exportUserData() async',
      );
      expect(start, greaterThan(0));
      final body = src.substring(start, src.indexOf('// --- Seed', start));
      expect(body, contains("from('wr_user_practice_actions')"));
      expect(body, contains("from('wr_user_practice_action_logs')"));
    },
  );

  group('WrUserAction.fromJson đọc kèm log nhúng', () {
    test('đếm ngày đã làm và nhận ra hôm nay', () {
      final today = DateTime.now();
      final a = WrUserAction.fromJson({
        'id': 'a1',
        'title': 'Hỏi ý kiến',
        'target_count': 5,
        'created_at': '2026-10-01T02:00:00Z',
        'completed_at': null,
        'wr_user_practice_action_logs': [
          {'done_on': '2026-10-01'},
          {'done_on': wrDateKey(today)},
        ],
      });
      expect(a.doneCount, 2);
      expect(a.doneToday, isTrue);
      expect(a.reachedTarget, isFalse);
      expect(a.isCompleted, isFalse);
    });
  });
}
