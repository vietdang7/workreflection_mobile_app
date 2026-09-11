// Nhắc trước khi kỳ thuê bao App Store kết thúc — khách chốt 08/09/2026.
//
// Thứ đáng test ở đây không phải "có hiện thẻ không" mà là NÓI ĐÚNG VẾ NÀO:
// cùng một ngày trên lịch, người còn bật gia hạn sắp bị trừ tiền còn người đã
// tắt thì sắp mất quyền. Nói nhầm vế là nói sai với đúng một nửa người đọc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:workreflection_mobile/core/logic/wr_iap_renewal.dart';
import 'package:workreflection_mobile/core/widgets/wr_renewal_notice_card.dart';
import 'package:workreflection_mobile/features/wr/iap_providers.dart';

WrIapSubscription _sub({
  DateTime? expiresAt,
  bool? autoRenew,
  DateTime? revokedAt,
}) =>
    WrIapSubscription(
      productId: 'app.workreflection.mobile.premium.yearly',
      expiresAt: expiresAt,
      autoRenew: autoRenew,
      revokedAt: revokedAt,
    );

void main() {
  final now = DateTime(2026, 9, 8, 10);

  group('Khi nào IM LẶNG', () {
    test('chưa mua bao giờ', () {
      expect(wrRenewalNotice(null, now: now), isNull);
    });

    test('không có hạn thì không nhắc được gì', () {
      expect(wrRenewalNotice(_sub(), now: now), isNull);
    });

    test('đã hoàn tiền thì thôi, việc của app là mời mua lại', () {
      final sub = _sub(
        expiresAt: now.add(const Duration(days: 3)),
        autoRenew: false,
        revokedAt: now.subtract(const Duration(days: 1)),
      );
      expect(wrRenewalNotice(sub, now: now), isNull);
    });

    test('hạn đã qua', () {
      final sub = _sub(
        expiresAt: now.subtract(const Duration(hours: 1)),
        autoRenew: true,
      );
      expect(wrRenewalNotice(sub, now: now), isNull);
    });

    test('còn quá xa — nhắc sớm quá là dạy người ta bỏ qua lời nhắc', () {
      final sub = _sub(
        expiresAt: now.add(const Duration(days: 60)),
        autoRenew: true,
      );
      expect(wrRenewalNotice(sub, now: now), isNull);
    });
  });

  group('Nói đúng vế', () {
    test('còn bật gia hạn → nói SẮP TRỪ TIỀN, không nói sắp hết hạn', () {
      final notice = wrRenewalNotice(
        _sub(expiresAt: DateTime(2026, 9, 12), autoRenew: true),
        now: now,
      )!;

      expect(notice.kind, WrRenewalKind.willRenew);
      expect(notice.title, contains('tự động gia hạn'));
      expect(notice.title, contains('12/09/2026'));
      expect(notice.body, contains('trừ tiền'));
      expect(notice.body, isNot(contains('trở về bản miễn phí')));
    });

    test('đã tắt gia hạn → nói SẮP MẤT QUYỀN', () {
      final notice = wrRenewalNotice(
        _sub(expiresAt: DateTime(2026, 9, 12), autoRenew: false),
        now: now,
      )!;

      expect(notice.kind, WrRenewalKind.willEnd);
      expect(notice.title, contains('hết hạn'));
      expect(notice.body, contains('miễn phí'));
      // Không được doạ mất dữ liệu: hết Premium thì mất tính năng, không mất
      // những gì người dùng đã ghi.
      expect(notice.body, contains('vẫn còn nguyên'));
    });

    test('chưa biết → nói cả hai vế chứ không đoán bừa', () {
      final notice = wrRenewalNotice(
        _sub(expiresAt: DateTime(2026, 9, 12)),
        now: now,
      )!;

      expect(notice.kind, WrRenewalKind.unknown);
      expect(notice.body, contains('Nếu bạn chưa tắt'));
    });
  });

  group('Cửa sổ nhắc', () {
    test('người sắp MẤT quyền được báo sớm hơn người sắp bị trừ tiền', () {
      final in10Days = now.add(const Duration(days: 10));

      // Cùng một ngày, khác nhau đúng ở trạng thái gia hạn.
      expect(
        wrRenewalNotice(_sub(expiresAt: in10Days, autoRenew: true), now: now),
        isNull,
      );
      expect(
        wrRenewalNotice(_sub(expiresAt: in10Days, autoRenew: false), now: now)
            ?.kind,
        WrRenewalKind.willEnd,
      );
    });

    test('"chưa biết" đi theo cửa sổ dài — im lặng là rủi ro cho người dùng',
        () {
      final notice = wrRenewalNotice(
        _sub(expiresAt: now.add(const Duration(days: 10))),
        now: now,
      );
      expect(notice?.kind, WrRenewalKind.unknown);
    });

    test('làm tròn LÊN: còn 20 tiếng vẫn là 1 ngày, không phải 0', () {
      final notice = wrRenewalNotice(
        _sub(expiresAt: now.add(const Duration(hours: 20)), autoRenew: true),
        now: now,
      )!;
      expect(notice.daysLeft, 1);
    });
  });

  group('Thẻ nhắc', () {
    Widget wrap(WrRenewalNotice? notice) => ProviderScope(
          overrides: [
            wrRenewalNoticeProvider.overrideWithValue(notice),
          ],
          child: const MaterialApp(
            home: Scaffold(body: WrRenewalNoticeCard()),
          ),
        );

    testWidgets('không có gì để nói thì thẻ biến mất hẳn', (tester) async {
      await tester.pumpWidget(wrap(null));
      expect(find.byKey(const Key('wr_renewal_notice_title')), findsNothing);
    });

    testWidgets('có lời nhắc thì hiện câu và lối quản lý gói', (tester) async {
      await tester.pumpWidget(wrap(WrRenewalNotice(
        kind: WrRenewalKind.willRenew,
        date: DateTime(2026, 9, 12),
        daysLeft: 4,
      )));

      expect(
        find.text('Gói tự động gia hạn ngày 12/09/2026'),
        findsOneWidget,
      );
      // Lối huỷ phải bấm được ngay tại chỗ, không phải một lộ trình bốn bước
      // trong Cài đặt mà người đọc phải tự nhớ.
      expect(find.byKey(const Key('wr_renewal_notice_manage')), findsOneWidget);
    });
  });
}
