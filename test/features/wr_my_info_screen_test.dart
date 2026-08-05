// Màn "Thông tin của bạn" — mockup Sprint 2 bản (4), `screenMyInfo`.
//
// Run: flutter test test/features/wr_my_info_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/core/models/mobile_profile.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/features/profile/presentation/my_info_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';

MobileProfile _profile({
  String? city,
  String? orgIndustry,
  String? orgCompanyType,
  String? roleText,
}) =>
    MobileProfile(
      userId: 'u1',
      displayName: 'Thông',
      reminderEnabled: true,
      language: 'vi',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      city: city,
      orgIndustry: orgIndustry,
      orgCompanyType: orgCompanyType,
      roleText: roleText,
    );

Widget _wrap(FakeWrRepository repo) {
  final router = GoRouter(
    initialLocation: '/profile/my-info',
    routes: [
      GoRoute(
        path: '/profile/my-info',
        builder: (_, __) => const MyInfoScreen(),
      ),
      GoRoute(
        path: '/wr/work-info',
        builder: (_, __) => const Scaffold(body: Text('THÔNG TIN CÔNG VIỆC')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [wrRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(
      builder: wrTextScaleBuilder,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      routerConfig: router,
    ),
  );
}

void main() {
  // Màn này dài hơn khung 800px mặc định của flutter_test — bảy dòng cộng phần
  // mở đầu. Nới khung ra thay vì cuộn từng lần: mọi khẳng định ở đây nói về nội
  // dung, không nói về việc cuộn.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(420, 2000);
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetDevicePixelRatio();
    view.resetPhysicalSize();
  });

  testWidgets('bày đủ bảy trường, gom theo ba nhóm', (tester) async {
    final repo = FakeWrRepository()..seedProfile(_profile());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    for (final column in [
      'total_work_experience',
      'city',
      'org_industry',
      'company_size',
      'org_company_type',
      'department',
      'position',
    ]) {
      expect(
        find.byKey(Key('my_info_row_$column')),
        findsOneWidget,
        reason: column,
      );
    }
    expect(find.text('Về bạn'), findsOneWidget);
    expect(find.text('Công ty của bạn'), findsOneWidget);
    expect(find.text('Công việc hiện tại'), findsOneWidget);
  });

  testWidgets('trường trống hiện "Chưa có", đã điền hiện NHÃN chứ không hiện mã',
      (tester) async {
    final repo = FakeWrRepository()
      ..seedProfile(_profile(city: 'hcm'))
      ..seedCcProfile({'position': 'team_lead'});
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('TP.HCM'), findsOneWidget);
    // Mã thô không được lọt ra màn hình.
    expect(find.text('hcm'), findsNothing);
    expect(find.text('team_lead'), findsNothing);
    // Năm trường còn lại vẫn trống.
    expect(find.text('Chưa có'), findsNWidgets(5));
  });

  testWidgets('dòng đếm hợp số từ CẢ hai bảng', (tester) async {
    // Đây là chỗ dễ sai nhất: đếm mỗi một bảng thì con số luôn thiếu, mà vẫn
    // trông hợp lý nên không ai để ý.
    final repo = FakeWrRepository()
      ..seedProfile(_profile(city: 'hcm', orgIndustry: 'tech'))
      ..seedCcProfile({'position': 'manager'});
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('my_info_filled_count')))
          .data,
      startsWith('3/7'),
    );
  });

  testWidgets('chạm một dòng mới bung danh sách lựa chọn của dòng đó',
      (tester) async {
    final repo = FakeWrRepository()..seedProfile(_profile());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my_info_option_hcm')), findsNothing);
    await tester.tap(find.byKey(const Key('my_info_row_city')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my_info_option_hcm')), findsOneWidget);
    expect(find.byKey(const Key('my_info_option_hanoi')), findsOneWidget);
  });

  testWidgets('mỗi lúc chỉ một dòng mở', (tester) async {
    final repo = FakeWrRepository()..seedProfile(_profile());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my_info_row_city')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my_info_row_org_industry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my_info_option_hcm')), findsNothing);
    expect(find.byKey(const Key('my_info_option_tech')), findsOneWidget);
  });

  testWidgets('trường của app ghi vào wr_mobile_profiles, chỉ gửi ĐÚNG một khoá',
      (tester) async {
    final repo = FakeWrRepository()..seedProfile(_profile());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my_info_row_city')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my_info_option_hanoi')));
    await tester.pumpAndSettle();

    expect(repo.saveMyInfoCalls, [
      {'city': 'hanoi'},
    ]);
    // Gửi kèm hai khoá kia là xoá trắng hai trường người dùng không đụng tới.
    expect(repo.saveMyInfoCalls.single.keys, ['city']);
    expect(repo.updateCcProfileCalls, isEmpty);
  });

  testWidgets('trường dùng chung ghi vào cc_profiles, đúng tên cột của web',
      (tester) async {
    final repo = FakeWrRepository()..seedProfile(_profile());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my_info_row_position')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my_info_option_manager')));
    await tester.pumpAndSettle();

    expect(repo.updateCcProfileCalls, [
      {'position': 'manager'},
    ]);
    expect(repo.saveMyInfoCalls, isEmpty);
  });

  testWidgets('chọn xong thì danh sách đóng lại và giá trị mới hiện ra',
      (tester) async {
    final repo = FakeWrRepository()..seedProfile(_profile());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my_info_row_city')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my_info_option_hanoi')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my_info_option_hcm')), findsNothing);
    expect(find.text('Hà Nội'), findsOneWidget);
  });

  testWidgets('dòng Thông tin công việc dẫn sang màn riêng', (tester) async {
    final repo = FakeWrRepository()..seedProfile(_profile());
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có, chạm để thêm'), findsOneWidget);
    await tester.tap(find.byKey(const Key('my_info_work_info_row')));
    await tester.pumpAndSettle();
    expect(find.text('THÔNG TIN CÔNG VIỆC'), findsOneWidget);
  });

  testWidgets('đã có mô tả vai trò thì dòng đó đổi lời', (tester) async {
    final repo = FakeWrRepository()
      ..seedProfile(_profile(roleText: 'phụ trách mảng B2C'));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Đã có, chạm để xem hoặc sửa'), findsOneWidget);
  });
}
