// Ảnh màn Paywall để nộp cho App Review — ô "Screenshot" của TỪNG gói IAP.
//
// KHÁC HẲN `app_store_test.dart` dù dùng cùng cách dựng:
//
//   • Bộ kia là ảnh BÁN HÀNG, hiện trên trang App Store cho người mua xem, và
//     nó có luật riêng "không chụp màn Premium, không lộ giá".
//   • Bộ này là BẰNG CHỨNG cho người duyệt: App Store Connect bắt mỗi gói đính
//     một ảnh cho thấy gói ấy nằm ở đâu trong app. Ảnh này Apple xem rồi thôi,
//     không ai ngoài App Review nhìn thấy.
//
// Nên hai bộ ra hai thư mục khác nhau, và đừng bao giờ tải nhầm bộ này lên ô
// ảnh App Store.
//
// ---------------------------------------------------------------------------
// PHẢI ĐỌC TRƯỚC KHI DÙNG ẢNH NÀY
//
// Đây là ảnh RENDER, không phải ảnh chụp từ máy thật. Trong môi trường test
// không có StoreKit, nên `wrIapOffersProvider` sẽ trả rỗng và màn Paywall hiện
// "Chưa mở bán được trên thiết bị này" — vô dụng với người duyệt. Vì vậy bộ này
// GIEO danh sách gói.
//
// Số liệu gieo lấy nguyên từ nguồn thật, không bịa:
//   • mã gói  ← `kWrIapProducts` (`lib/core/logic/wr_iap_catalog.dart`)
//   • tên gói ← Display Name đã khai trên ASC
//   • giá     ← bậc giá đã chọn trên ASC
//
// **Giá là chỗ duy nhất có thể lệch.** Apple bán theo bậc, và bậc hiển thị ở
// từng nước có thể khác con số dưới đây. Trước khi nộp, mở ASC đối chiếu lại
// hai dòng `_kYearlyPriceLabel` / `_kMonthlyPriceLabel`; lệch thì sửa ở đây rồi
// chạy lại, đừng sửa tay lên file ảnh.
//
// Chạy:
//   WR_SCREENSHOTS=1 flutter test test/screenshots/iap_review_test.dart \
//     --update-goldens
//
// Ảnh ra ở `screenshots/app_store/iap_review/`.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_iap_repository.dart';
import 'package:workreflection_mobile/core/data/wr_intelligence_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_entitlement.dart';
import 'package:workreflection_mobile/core/logic/wr_iap_catalog.dart';
import 'package:workreflection_mobile/core/logic/wr_store_policy.dart';
import 'package:workreflection_mobile/core/models/wr_intelligence.dart';
import 'package:workreflection_mobile/core/theme/wr_text.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/wr/presentation/wr_paywall_screen.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_wr_intelligence_repository.dart';

final bool _enabled = Platform.environment['WR_SCREENSHOTS'] == '1';

/// Giá đã khai trên App Store Connect. Đối chiếu lại trước khi nộp — xem đầu
/// file.
const String _kYearlyPriceLabel = '499.000 ₫';
const String _kMonthlyPriceLabel = '70.000 ₫';

/// Khổ ảnh. Apple chỉ đòi tối thiểu 640×920 cho ô này, nhưng dùng luôn khổ
/// 6.9" cho khỏi phải nhớ thêm một con số.
const Size _kSurface = Size(430, 932);

const String _kUserId = 'u1';

// ---------------------------------------------------------------------------

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    final loader = FontLoader(family)
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }

  await load('NotoSans', 'assets/fonts/NotoSans-Regular.ttf');
  await load('NotoSans', 'assets/fonts/NotoSans-Bold.ttf');
  await load(WrText.serifFamily, 'assets/fonts/Lora-Italic.ttf');

  for (final candidate in _materialIconCandidates()) {
    if (File(candidate).existsSync()) {
      await load('MaterialIcons', candidate);
      break;
    }
  }
}

List<String> _materialIconCandidates() {
  const relative =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      Platform.environment['FLUTTER_ROOT']!,
    '${Platform.environment['HOME']}/snap/flutter/common/flutter',
    '${Platform.environment['HOME']}/flutter',
    '/opt/flutter',
    '/usr/local/flutter',
  ];
  return [for (final r in roots) '$r/$relative'];
}

// ---------------------------------------------------------------------------

/// Hai gói đúng như đã khai trên ASC.
///
/// `id` và `durationDays` đọc thẳng từ `kWrIapProducts` chứ không gõ lại: mã
/// gói sai một ký tự là app không tìm thấy gói, và bài này tồn tại để chứng
/// minh điều ngược lại.
List<WrIapOffer> _offers() {
  WrIapOffer offerFor(String productId, String priceLabel, double rawPrice) {
    final product = wrIapProductById(productId)!;
    return WrIapOffer(
      id: product.id,
      title: product.title,
      description: product.blurb,
      priceLabel: priceLabel,
      rawPrice: rawPrice,
      currencyCode: 'VND',
      durationDays: product.durationDays,
    );
  }

  return [
    offerFor(kIapYearlyProductId, _kYearlyPriceLabel, 499000),
    offerFor(kIapMonthlyProductId, _kMonthlyPriceLabel, 70000),
  ];
}

/// Chỉ trả về danh sách gói. Mọi nhánh mua/khôi phục đều ném — bài này chỉ
/// DỰNG màn, không bấm gì, nên chạm tới chúng nghĩa là bài đã sai.
class _OffersOnlyIapRepository implements WrIapRepository {
  @override
  Future<bool> isStoreAvailable() async => true;

  @override
  Future<List<WrIapOffer>> fetchOffers() async => _offers();

  @override
  Stream<WrIapPurchase> get purchaseUpdates =>
      const Stream<WrIapPurchase>.empty();

  @override
  Future<void> buy({required String productId, required String userId}) async =>
      throw UnimplementedError('ảnh tĩnh, không mua');

  @override
  Future<void> restore({required String userId}) async =>
      throw UnimplementedError('ảnh tĩnh, không khôi phục');

  @override
  Future<void> finish(WrIapPurchase purchase) async =>
      throw UnimplementedError('ảnh tĩnh');

  @override
  Future<WrEntitlementRecord> verify(WrIapPurchase purchase) async =>
      throw UnimplementedError('ảnh tĩnh');
}

Widget _paywallApp() {
  final router = GoRouter(
    initialLocation: '/wr/paywall',
    routes: [
      GoRoute(path: '/wr/paywall', builder: (_, __) => const WrPaywallScreen()),
      // Đích phụ, có mặt để router không nổ khi màn dựng link tới.
      GoRoute(path: '/home', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold()),
    ],
  );

  return ProviderScope(
    overrides: [
      // `appStore` là chính sách của bản phát hành iOS: bán bằng IAP, không có
      // nhánh QR, không có link sang web. Đây đúng là thứ người duyệt phải thấy.
      wrStorePolicyProvider.overrideWithValue(WrStorePolicy.appStore),
      wrIapRepositoryProvider.overrideWithValue(_OffersOnlyIapRepository()),
      wrIntelligenceRepositoryProvider
          .overrideWithValue(FakeWrIntelligenceRepository()),
      currentUserIdProvider.overrideWithValue(_kUserId),
      // Tài khoản FREE. Người đã có quyền thì Paywall đổi thành trang xác nhận,
      // không còn nút mua nào — chụp ra là vô nghĩa với App Review.
      wrEntitlementProvider.overrideWith((ref) async => WrEntitlement(
            plan: WrPlan.free,
          )),
    ],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'NotoSans', useMaterial3: true),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('Paywall — hai gói IAP đang hiện giá', skip: !_enabled,
      (tester) async {
    tester.view.physicalSize = _kSurface * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_paywallApp());
    await tester.pumpAndSettle();

    // Chốt rằng ảnh sắp ghi THẬT SỰ có hai nút mua. Không có hai dòng này thì
    // một lần đổi provider làm màn rơi về "Chưa mở bán được trên thiết bị này"
    // vẫn ghi đè ảnh, và không ai biết cho tới lúc Apple từ chối.
    expect(find.byKey(const Key('wr_paywall_iap_unavailable')), findsNothing);
    for (final offer in _offers()) {
      expect(
        find.byKey(Key('wr_paywall_iap_buy_${offer.id}')),
        findsOneWidget,
        reason: offer.id,
      );
    }

    // CUỘN XUỐNG NÚT MUA trước khi chụp.
    //
    // Paywall dài hơn một màn, và phần đầu là mấy thẻ giới thiệu tính năng.
    // Chụp nguyên đầu màn thì ảnh không có nút mua lẫn giá — tức là không
    // chứng minh được đúng cái ô này sinh ra để chứng minh.
    //
    // Cuộn tới nút gói THÁNG (nút cuối trong hai nút) để cả hai cùng lọt vào
    // khung; canh theo nút năm thì nút tháng có thể còn nằm dưới mép.
    await tester.scrollUntilVisible(
      find.byKey(const Key('wr_paywall_iap_buy_$kIapMonthlyProductId')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../screenshots/app_store/iap_review/paywall.png'),
    );
  });
}
