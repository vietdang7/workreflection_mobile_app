import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';

void main() {
  group('WrTextScaler', () {
    const scaler = WrTextScaler();

    test('nới mạnh chữ nhỏ — cỡ 11 lên xấp xỉ 14', () {
      expect(scaler.scale(11), closeTo(13.86, 0.01));
      expect(scaler.scale(13), closeTo(15.57, 0.01));
      expect(scaler.scale(14), closeTo(16.43, 0.01));
    });

    test('gần như giữ nguyên chữ tiêu đề lớn', () {
      expect(scaler.scale(32), closeTo(33.28, 0.01));
      expect(scaler.scale(56), closeTo(58.24, 0.01));
    });

    test('đơn điệu tăng — không đảo bậc phân cấp cỡ chữ', () {
      var previous = 0.0;
      for (var size = 8.0; size <= 60; size += 0.5) {
        final scaled = scaler.scale(size);
        expect(scaled, greaterThan(previous));
        previous = scaled;
      }
    });

    test('chặn hệ số hệ thống trong khoảng an toàn', () {
      // Người dùng kéo cỡ chữ hệ thống lên 3.0 → chỉ nhận tối đa 1.3.
      expect(
        const WrTextScaler(systemScale: 3).scale(14),
        closeTo(scaler.scale(14) * WrTextScaler.maxSystemScale, 0.01),
      );
      expect(
        const WrTextScaler(systemScale: 0.5).scale(14),
        closeTo(scaler.scale(14) * WrTextScaler.minSystemScale, 0.01),
      );
    });

    testWidgets('builder gắn scaler vào MediaQuery của cây con', (tester) async {
      late TextScaler seen;
      await tester.pumpWidget(
        MaterialApp(
          builder: wrTextScaleBuilder,
          home: Builder(
            builder: (context) {
              seen = MediaQuery.textScalerOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen, isA<WrTextScaler>());
      expect(seen.scale(13), closeTo(15.57, 0.01));
    });

    testWidgets('nhân chồng lên cỡ chữ người dùng đặt ở hệ thống',
        (tester) async {
      late TextScaler seen;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
          child: MaterialApp(
            builder: wrTextScaleBuilder,
            home: Builder(
              builder: (context) {
                seen = MediaQuery.textScalerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(seen.scale(13), closeTo(15.57 * 1.2, 0.02));
    });
  });
}
