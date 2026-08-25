// Minh hoạ mở đầu Home theo khung giờ — changelog 24/08/2026 §5.
//
// Ranh giới giờ là thứ dễ sai nhất và cũng dễ trôi qua nhất: sai một giờ thì
// người dùng vẫn thấy MỘT bức tranh hợp lý, chỉ là không phải bức của giờ đó.
// Không màn hình nào tố giác được điều ấy, nên nó phải bị chặn ở đây.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/vn_date.dart';
import 'package:workreflection_mobile/core/widgets/wr_hero_scene.dart';

void main() {
  group('§5 · khung giờ', () {
    test('đúng bốn khoảng của getDayPeriod()', () {
      // 5h–11h sáng · 11h–18h chiều · 18h–22h tối · còn lại khuya.
      const expected = <int, WrDayPeriod>{
        0: WrDayPeriod.latenight,
        4: WrDayPeriod.latenight,
        5: WrDayPeriod.morning,
        10: WrDayPeriod.morning,
        11: WrDayPeriod.afternoon,
        17: WrDayPeriod.afternoon,
        18: WrDayPeriod.evening,
        21: WrDayPeriod.evening,
        22: WrDayPeriod.latenight,
        23: WrDayPeriod.latenight,
      };
      expected.forEach((hour, period) {
        expect(WrDayPeriod.fromHour(hour), period, reason: '${hour}h');
      });
    });

    test('mọi giờ trong ngày đều rơi vào đúng một khoảng', () {
      for (var h = 0; h < 24; h++) {
        expect(() => WrDayPeriod.fromHour(h), returnsNormally);
      }
    });

    test('nowVn giữ nguyên phần giờ, todayVn thì không', () {
      // Cái bẫy đã suýt dính: `todayVn()` cắt về nửa đêm, nên đọc `.hour` của
      // nó thì Home vĩnh viễn hiện bản KHUYA, kể cả giữa trưa.
      final utc = DateTime.utc(2026, 8, 25, 3); // 10h sáng giờ Việt Nam
      expect(nowVnFrom(utc).hour, 10);
      expect(todayVnFrom(utc).hour, 0);
      expect(WrDayPeriod.fromHour(nowVnFrom(utc).hour), WrDayPeriod.morning);
    });
  });

  group('§5 · minh hoạ', () {
    testWidgets('dựng được cả bốn bản, mỗi bản một khoá riêng', (tester) async {
      for (final period in WrDayPeriod.values) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: WrHeroScene(period: period)),
        ));
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key('wr_hero_scene_${period.name}')),
          findsOneWidget,
          reason: 'thiếu bản ${period.name}',
        );
      }
    });

    testWidgets('có nhãn cho trình đọc màn hình', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: WrHeroScene(period: WrDayPeriod.morning)),
      ));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Minh hoạ: một chỗ ngồi đang chờ bạn'),
        findsOneWidget,
      );
    });

    testWidgets('giữ đúng tỉ lệ khung 335:170 của bản thiết kế',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 335, child: WrHeroScene(period: WrDayPeriod.evening)),
        ),
      ));
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(WrHeroScene));
      expect(size.width, 335);
      expect(size.height, closeTo(170, 0.5));
    });
  });
}
