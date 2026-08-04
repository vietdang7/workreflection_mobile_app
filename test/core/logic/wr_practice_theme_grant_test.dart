// Hai hướng đổi ra chủ đề thực hành — khách chốt ngưỡng 2026-08-04.
// Run: flutter test test/core/logic/wr_practice_theme_grant_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_practice_theme_grant.dart';

void main() {
  test('ngưỡng hướng 1 là 15 LẦN nhìn lại', () {
    expect(kReflectionsPerPracticeTheme, 15);
  });

  group('earnedPracticeThemes', () {
    int earned(int reflections, int selfChecks) => earnedPracticeThemes(
          reflectionCount: reflections,
          selfCheckCount: selfChecks,
        );

    test('chưa làm gì thì chưa được chủ đề nào', () {
      expect(earned(0, 0), 0);
    });

    test('14 lần chưa đủ, 15 lần được một chủ đề', () {
      expect(earned(14, 0), 0);
      expect(earned(15, 0), 1);
    });

    // Ngưỡng lặp lại chứ không phải một lần rồi thôi: người theo lâu vẫn được
    // thêm chủ đề mới, không đứng yên ở con số của tháng đầu.
    test('cứ thêm 15 lần là thêm một chủ đề', () {
      expect(earned(29, 0), 1);
      expect(earned(30, 0), 2);
      expect(earned(45, 0), 3);
    });

    test('mỗi lần tự đánh giá là một chủ đề, không cần lặp lần nào', () {
      expect(earned(0, 1), 1);
      expect(earned(0, 3), 3);
    });

    test('hai hướng cộng vào nhau', () {
      expect(earned(30, 2), 4);
    });
  });

  group('reflectionsToNextTheme', () {
    test('đếm ngược tới mốc 15 kế tiếp', () {
      expect(reflectionsToNextTheme(0), 15);
      expect(reflectionsToNextTheme(14), 1);
      expect(reflectionsToNextTheme(15), 15);
      expect(reflectionsToNextTheme(16), 14);
    });
  });
}
