// Hợp đồng giữa app, repo giả và migration của "Chứng chỉ, khoá học, kỹ năng
// đã có" (Task D2).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:workreflection_mobile/core/models/wr_owned_skill.dart';

import '../support/fake_wr_owned_skill_repository.dart';

const _migrationPath = 'supabase/migrations/20261001130000_wr_owned_skills.sql';

String _normalize(String s) => s.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

WrOwnedSkill _skill({
  OwnedSkillKind kind = OwnedSkillKind.certificate,
  String title = 'Chứng chỉ PMP',
  String? issuer,
  DateTime? completedOn,
  String? filePath,
  List<String> themeIds = const [],
}) => WrOwnedSkill(
  id: '',
  kind: kind,
  title: title,
  issuer: issuer,
  completedOn: completedOn,
  filePath: filePath,
  themeIds: themeIds,
  createdAt: DateTime(2026),
);

Matcher _pgCode(String code) =>
    throwsA(isA<PostgrestException>().having((e) => e.code, 'code', code));

void main() {
  late String sql;

  setUpAll(() {
    sql = _normalize(File(_migrationPath).readAsStringSync());
  });

  group('migration ↔ fake: cùng một bộ luật', () {
    test('CHECK kind/title/issuer của fake có nguyên văn trong migration', () {
      expect(sql, contains(_normalize(fakeOwnedSkillKindCheck)));
      expect(sql, contains(_normalize(fakeOwnedSkillTitleCheck)));
      expect(sql, contains(_normalize(fakeOwnedSkillIssuerCheck)));
    });

    test('mọi OwnedSkillKind đều được CHECK nhận', () {
      for (final k in OwnedSkillKind.values) {
        expect(fakeOwnedSkillKinds, contains(k.dbValue), reason: k.name);
      }
      expect(OwnedSkillKind.values, hasLength(fakeOwnedSkillKinds.length));
    });

    test('trần độ dài của app khớp CHECK', () {
      expect(sql, contains('between 1 and $kOwnedSkillTitleMax'));
      expect(sql, contains('char_length(issuer) <= $kOwnedSkillIssuerMax'));
    });

    test('đủ 4 policy owner-only', () {
      for (final op in ['select', 'insert', 'update', 'delete']) {
        expect(sql, contains('"wr_owned_skills_owner_$op"'));
      }
    });
  });

  group('fake từ chối đúng như DB', () {
    test('tiêu đề toàn dấu cách → 23514', () async {
      await expectLater(
        FakeWrOwnedSkillRepository().add(_skill(title: '   ')),
        _pgCode('23514'),
      );
    });

    test('tiêu đề 161 ký tự → 23514, 160 → nhận', () async {
      final repo = FakeWrOwnedSkillRepository();
      await expectLater(repo.add(_skill(title: 'x' * 161)), _pgCode('23514'));
      await repo.add(_skill(title: 'ệ' * 160));
      expect(repo.rows, hasLength(1));
    });

    test('đơn vị cấp 161 ký tự → 23514', () async {
      await expectLater(
        FakeWrOwnedSkillRepository().add(_skill(issuer: 'i' * 161)),
        _pgCode('23514'),
      );
    });
  });

  group('hình dạng dòng app gửi lên', () {
    test(
      'không gửi id / created_at; kind ở dạng chuỗi DB; ngày yyyy-MM-dd',
      () {
        final row = ownedSkillWriteRow(
          userId: 'u1',
          skill: _skill(
            kind: OwnedSkillKind.course,
            title: '  Khoá giao tiếp  ',
            issuer: '  ',
            completedOn: DateTime(2025, 6, 30, 15),
            themeIds: const ['pt-c3'],
          ),
        );
        expect(row.containsKey('id'), isFalse);
        expect(row.containsKey('created_at'), isFalse);
        expect(row['user_id'], 'u1');
        expect(row['kind'], 'course');
        expect(row['title'], 'Khoá giao tiếp');
        // Đơn vị cấp toàn khoảng trắng = không có.
        expect(row['issuer'], isNull);
        expect(row['completed_on'], '2025-06-30');
        expect(row['theme_ids'], ['pt-c3']);
      },
    );

    test('mọi cột app gửi đều có trong migration', () {
      for (final col in ownedSkillWriteRow(userId: 'u', skill: _skill()).keys) {
        expect(sql, contains(col), reason: col);
      }
    });

    test('tệp đính kèm nằm trong thư mục của người dùng, tiền tố cert-', () {
      expect(
        ownedSkillFilePath(userId: 'u1', ext: '.PDF', stamp: 42),
        'u1/cert-42.pdf',
      );
    });
  });

  test('fromJson đọc đủ cột', () {
    final s = WrOwnedSkill.fromJson({
      'id': 'os1',
      'kind': 'skill',
      'title': 'Thuyết trình',
      'issuer': null,
      'completed_on': '2025-01-02',
      'file_path': 'u1/cert-1.pdf',
      'theme_ids': ['pt-c2'],
      'created_at': '2026-10-01T00:00:00Z',
    });
    expect(s.kind, OwnedSkillKind.skill);
    expect(s.completedOn, DateTime(2025, 1, 2));
    expect(s.themeIds, ['pt-c2']);
    expect(s.filePath, 'u1/cert-1.pdf');
  });

  test('exportUserData xuất bảng wr_owned_skills', () {
    final src = File('lib/core/data/wr_repository.dart').readAsStringSync();
    final start = src.indexOf(
      'Future<Map<String, dynamic>> exportUserData() async',
    );
    final body = src.substring(start, src.indexOf('// --- Seed', start));
    expect(body, contains("from('wr_owned_skills')"));
  });
}
