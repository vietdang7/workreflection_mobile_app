// Bộ mô tả bảy trường của màn "Thông tin của bạn".
//
// Điều đáng canh nhất ở đây KHÔNG phải nhãn hay thứ tự, mà là bản đồ cột: trường
// nào nằm ở bảng nào. Ghi nhầm bảng thì màn này và màn Sửa hồ sơ hiện hai giá
// trị khác nhau cho cùng một câu hỏi, và không test giao diện nào bắt được.
//
// Run: flutter test test/logic/wr_my_info_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_my_info.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';
import 'package:workreflection_mobile/l10n/app_localizations_vi.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsVi();

  group('myInfoFields', () {
    test('có đúng bảy trường, đúng thứ tự của mockup', () {
      final fields = myInfoFields(l10n);
      expect(fields.length, 7);
      expect(
        fields.map((f) => f.column).toList(),
        [
          'total_work_experience',
          'city',
          'org_industry',
          'company_size',
          'org_company_type',
          'department',
          'position',
        ],
      );
    });

    test('bốn trường dùng chung cột với web đi về cc_profiles', () {
      final byColumn = {for (final f in myInfoFields(l10n)) f.column: f.store};
      expect(byColumn['total_work_experience'], MyInfoStore.ccProfile);
      expect(byColumn['company_size'], MyInfoStore.ccProfile);
      expect(byColumn['department'], MyInfoStore.ccProfile);
      expect(byColumn['position'], MyInfoStore.ccProfile);
    });

    test('ba trường riêng của app đi về wr_mobile_profiles', () {
      final byColumn = {for (final f in myInfoFields(l10n)) f.column: f.store};
      expect(byColumn['city'], MyInfoStore.mobileProfile);
      expect(byColumn['org_industry'], MyInfoStore.mobileProfile);
      expect(byColumn['org_company_type'], MyInfoStore.mobileProfile);
    });

    test('trường dùng chung giữ NGUYÊN danh sách mã của web', () {
      // Mockup rút "Vị trí" còn ba mức. Lấy theo mockup là làm mồ côi giá trị
      // của người đã khai bên web — họ sẽ thấy "Chưa có" ở trường mình đã điền.
      final position =
          myInfoFields(l10n).firstWhere((f) => f.column == 'position');
      expect(position.options.length, 8);
      expect(position.options.map((o) => o.value), contains('team_lead'));
    });

    test('không trường nào rỗng lựa chọn', () {
      for (final f in myInfoFields(l10n)) {
        expect(f.options, isNotEmpty, reason: f.column);
      }
    });
  });

  test('myInfoGroups trả về ba nhóm, không lặp, đúng thứ tự', () {
    expect(
      myInfoGroups(myInfoFields(l10n)),
      [kMyInfoGroupAboutYou, kMyInfoGroupCompany, kMyInfoGroupWork],
    );
  });

  group('myInfoLabelFor', () {
    final city = myInfoFields(l10n).firstWhere((f) => f.column == 'city');

    test('đổi mã sang nhãn', () {
      expect(myInfoLabelFor(city, 'hcm'), 'TP.HCM');
    });

    test('null và chuỗi trắng đều là chưa điền', () {
      expect(myInfoLabelFor(city, null), isNull);
      expect(myInfoLabelFor(city, '   '), isNull);
    });

    test('mã lạ trả về nguyên văn, KHÔNG coi là chưa điền', () {
      // Người đó có khai, chỉ là app không dịch được mã. Nói "Chưa có" là nói
      // sai và còn xui họ khai đè lên.
      expect(myInfoLabelFor(city, 'da_nang'), 'da_nang');
    });
  });

  group('myInfoFilledCount', () {
    final fields = myInfoFields(l10n);

    test('chưa điền gì là 0', () {
      expect(myInfoFilledCount(fields, (_) => null), 0);
    });

    test('điền hết là 7', () {
      expect(myInfoFilledCount(fields, (_) => 'x'), 7);
    });

    test('chuỗi trắng không tính là đã điền', () {
      expect(
        myInfoFilledCount(fields, (f) => f.column == 'city' ? '  ' : null),
        0,
      );
    });

    test('đếm đúng khi điền một phần', () {
      const filled = {'city', 'position', 'org_industry'};
      expect(
        myInfoFilledCount(
          fields,
          (f) => filled.contains(f.column) ? 'x' : null,
        ),
        3,
      );
    });
  });
}
