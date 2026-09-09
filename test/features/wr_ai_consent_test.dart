// Xin phép trước khi gửi dữ liệu sang dịch vụ AI bên thứ ba.
//
// Vì sao phải có test: App Store từ chối bản 1.0 (6) ngày 06/09/2026 theo
// Guideline 5.1.1(i) và 5.1.2(i). Bốn điều kiện Apple đặt ra — nói rõ gửi gì,
// nêu đích danh gửi cho ai, xin phép TRƯỚC khi gửi, và cho người dùng đổi ý —
// đều được khoá lại ở đây.
//
// Điều kiện thứ ba là điều kiện dễ vỡ nhất khi sửa code về sau: chỉ cần một màn
// hình mới quên gọi `ensureAiConsent` là dữ liệu lại chảy đi mà không ai hay.
// Nên các test dưới đây bám vào HÀNH VI (có gọi repository AI hay không), không
// bám vào việc có hiện đúng cái hộp thoại nào.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/data/wr_ai_consent_repository.dart';
import 'package:workreflection_mobile/core/logic/wr_ai_disclosure.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/widgets/wr_ai_consent_sheet.dart';
import 'package:workreflection_mobile/features/wr/ai_consent_providers.dart';
import 'package:workreflection_mobile/features/wr/wr_providers.dart';

const _userId = 'user-1';

class _FakeConsentRepository implements WrAiConsentRepository {
  _FakeConsentRepository([this.current = WrAiConsent.unknown]);

  WrAiConsent current;
  final List<String> calls = [];

  /// Ghi hỏng (mất mạng).
  bool failWrites = false;

  @override
  Future<WrAiConsent> fetch() async => current;

  @override
  Future<void> grant() async {
    calls.add('grant');
    if (failWrites) throw Exception('mạng hỏng');
    current = WrAiConsent(
      version: kWrAiDisclosureVersion,
      grantedAt: DateTime.now(),
    );
  }

  @override
  Future<void> revoke() async {
    calls.add('revoke');
    if (failWrites) throw Exception('mạng hỏng');
    current = WrAiConsent(
      version: kWrAiDisclosureVersion,
      grantedAt: current.grantedAt,
      revokedAt: DateTime.now(),
    );
  }
}

WrAiConsent _granted({int? version}) => WrAiConsent(
      version: version ?? kWrAiDisclosureVersion,
      grantedAt: DateTime(2026, 9, 7, 10),
    );

ProviderContainer _container(_FakeConsentRepository repo) {
  final c = ProviderContainer(
    overrides: [
      wrAiConsentRepositoryProvider.overrideWithValue(repo),
      currentUserIdProvider.overrideWithValue(_userId),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('Bản công bố nói đủ những gì Apple đòi', () {
    test('nêu ĐÍCH DANH từng bên nhận dữ liệu, không nói tránh', () {
      final names = kWrAiRecipients.map((r) => r.name).toList();
      // Apple: "identify who the data is sent to". "Các đối tác công nghệ" là
      // cách nói tránh và không qua được điều kiện đó.
      //
      // Từ 09/09/2026 chỉ còn hai bên: các Edge Function gọi thẳng Google, bỏ
      // OpenRouter (bên trung chuyển) và DeepSeek khỏi đường đi. Danh sách này
      // phải khớp mã nguồn Edge Function — đổi nhà cung cấp mà quên sửa bản
      // công bố là khai sai.
      expect(names, contains('Google (Gemini)'));
      expect(names, contains('Ausynclab'));
      expect(names, isNot(contains('OpenRouter')));
      expect(names, isNot(contains('DeepSeek')));
    });

    test('mỗi bên nhận đều kèm link chính sách để tự kiểm', () {
      for (final r in kWrAiRecipients) {
        expect(r.privacyUrl, startsWith('https://'), reason: r.name);
        expect(r.role.trim(), isNotEmpty, reason: r.name);
      }
    });

    test('kể đủ CẢ NĂM luồng gửi dữ liệu đang có trong app', () {
      // Năm luồng, đối chiếu mã nguồn 09/09/2026: chat, đọc JD/CV, sinh Diễn
      // biến, đọc thành tiếng, và cá nhân hoá Báo cáo khảo sát
      // (`ai-personalize` → Gemini). Thêm một luồng AI mới mà quên khai ở đây
      // thì bản công bố thành lời khai thiếu.
      //
      // Luồng thứ năm từng bị bỏ sót vì nó gọi một Edge Function có sẵn từ bản
      // web, không nằm trong `supabase/functions/` của repo này. Muốn soát lại
      // cho đủ thì quét theo điểm gọi trong `lib/` — `functions.invoke(` và các
      // URL ngoài — chứ đừng quét theo thư mục mã nguồn.
      expect(kWrAiDataFlows.length, 5);
      for (final f in kWrAiDataFlows) {
        expect(f.trigger.trim(), isNotEmpty);
        expect(f.data.trim(), isNotEmpty);
        expect(f.recipient.trim(), isNotEmpty);
      }
    });

    test('nói rõ mục Diễn biến chạy TỰ ĐỘNG', () {
      // Luồng duy nhất không do người dùng bấm. Không nói ra thì bản công bố
      // đang giấu đúng cái luồng người ta không ngờ tới.
      final auto = kWrAiDataFlows.firstWhere(
        (f) => f.trigger.contains('Diễn biến'),
      );
      expect(auto.data, contains('tự động'));
    });

    test('nói được chỗ tắt lại, và chỗ đó khớp đường dẫn thật', () {
      expect(kWrAiRevokeNote, contains('Xử lý dữ liệu bằng AI'));
      expect(kWrAiRevokePath, '/wr/ai-consent');
    });

    test('lời hứa "không gửi tên và email" phải nêu rõ cả hai', () {
      // Đây không phải chữ trang trí — nó là một cam kết kiểm chứng được, và
      // 07/09/2026 nó ĐÃ TỪNG SAI: kịch bản đọc của Video Report ghép thẳng
      // `userName` (rơi về email khi chưa có tên) vào đoạn chữ gửi sang
      // Ausynclab. Xem `narration_script_builder.dart`.
      final joined = kWrAiNeverSent.join(' ').toLowerCase();
      expect(joined, contains('tên'));
      expect(joined, contains('email'));
    });
  });

  group('Đọc lựa chọn', () {
    test('chưa trả lời thì chưa được phép', () {
      expect(WrAiConsent.unknown.isGranted, isFalse);
      expect(WrAiConsent.unknown.hasAnswered, isFalse);
    });

    test('đã đồng ý thì được phép', () {
      expect(_granted().isGranted, isTrue);
      expect(_granted().hasAnswered, isTrue);
    });

    test('rút lại SAU khi đồng ý thì hết phép', () {
      final c = WrAiConsent(
        version: kWrAiDisclosureVersion,
        grantedAt: DateTime(2026, 9, 7, 10),
        revokedAt: DateTime(2026, 9, 7, 11),
      );
      expect(c.isGranted, isFalse);
      expect(c.hasAnswered, isTrue);
    });

    test('tắt rồi BẬT LẠI thì được phép — so mốc chứ không xem có hay không',
        () {
      final c = WrAiConsent(
        version: kWrAiDisclosureVersion,
        grantedAt: DateTime(2026, 9, 7, 12),
        revokedAt: DateTime(2026, 9, 7, 11),
      );
      expect(c.isGranted, isTrue);
    });

    test('đồng ý bản công bố CŨ thì phải hỏi lại', () {
      // Thêm một bên nhận dữ liệu rồi dùng lại lời đồng ý cũ là xin phép cho
      // việc A rồi làm việc B.
      final c = WrAiConsent(
        version: kWrAiDisclosureVersion - 1,
        grantedAt: DateTime(2026, 9, 7, 10),
      );
      expect(c.isGranted, isFalse);
    });
  });

  group('Provider', () {
    test('đọc hỏng thì coi như CHƯA cho phép', () async {
      final repo = _FakeConsentRepository();
      final c = ProviderContainer(
        overrides: [
          wrAiConsentRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(_userId),
          wrAiConsentProvider.overrideWith((ref) async => throw Exception('x')),
        ],
      );
      addTearDown(c.dispose);
      // Nghiêng về phía chưa-cho-phép: đoán nhầm thành đã-cho-phép là gửi dữ
      // liệu đi khi chưa được phép.
      expect(c.read(wrAiConsentGrantedProvider), isFalse);
    });

    test('chưa đăng nhập thì chưa cho phép', () async {
      final repo = _FakeConsentRepository(_granted());
      final c = ProviderContainer(
        overrides: [
          wrAiConsentRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      final consent = await c.read(wrAiConsentProvider.future);
      expect(consent.isGranted, isFalse);
    });

    test('đang tải thì chưa cho phép', () {
      final repo = _FakeConsentRepository(_granted());
      final c = _container(repo);
      // Chưa await lần nào — provider còn ở trạng thái loading.
      expect(c.read(wrAiConsentGrantedProvider), isFalse);
    });

    test('ghi hỏng thì KHÔNG được coi là đã đồng ý', () async {
      final repo = _FakeConsentRepository()..failWrites = true;
      final c = _container(repo);
      final ok = await c.read(wrAiConsentControllerProvider).grant();
      expect(ok, isFalse);
      expect(repo.current.isGranted, isFalse);
    });

    test('đồng ý xong thì được phép', () async {
      final repo = _FakeConsentRepository();
      final c = _container(repo);
      final ok = await c.read(wrAiConsentControllerProvider).grant();
      expect(ok, isTrue);
      expect(await c.read(wrAiConsentProvider.future), isA<WrAiConsent>());
      expect(repo.current.isGranted, isTrue);
    });

    test('rút lại thì hết phép', () async {
      final repo = _FakeConsentRepository(_granted());
      final c = _container(repo);
      final ok = await c.read(wrAiConsentControllerProvider).revoke();
      expect(ok, isTrue);
      expect(repo.current.isGranted, isFalse);
    });
  });

  group('Cổng chặn ensureAiConsent', () {
    /// Dựng một màn tối giản có nút gọi cổng chặn, ghi lại kết quả.
    Widget harness(_FakeConsentRepository repo, List<bool> results) {
      return ProviderScope(
        overrides: [
          wrAiConsentRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(_userId),
        ],
        child: MaterialApp(
          builder: wrTextScaleBuilder,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('go'),
                  onPressed: () async {
                    results.add(await ensureAiConsent(context, ref));
                  },
                  child: const Text('gửi'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('đã đồng ý thì đi thẳng, không hỏi lại', (tester) async {
      final repo = _FakeConsentRepository(_granted());
      final results = <bool>[];
      await tester.pumpWidget(harness(repo, results));
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(find.byKey(const Key('wr_ai_consent_title')), findsNothing);
    });

    testWidgets('chưa trả lời thì HỎI trước, và chưa bấm gì thì chưa được đi',
        (tester) async {
      final repo = _FakeConsentRepository();
      final results = <bool>[];
      await tester.pumpWidget(harness(repo, results));
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();

      // Màn xin phép đang mở, và cổng chặn CHƯA trả lời gì cả.
      expect(find.byKey(const Key('wr_ai_consent_title')), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('bấm Đồng ý thì đi tiếp', (tester) async {
      final repo = _FakeConsentRepository();
      final results = <bool>[];
      await tester.pumpWidget(harness(repo, results));
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_ai_consent_accept')));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(repo.calls, contains('grant'));
    });

    testWidgets('bấm Để sau thì DỪNG', (tester) async {
      final repo = _FakeConsentRepository();
      final results = <bool>[];
      await tester.pumpWidget(harness(repo, results));
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_ai_consent_decline')));
      await tester.pumpAndSettle();

      expect(results, [false]);
      expect(repo.calls, contains('revoke'));
    });

    testWidgets('đã từ chối thì KHÔNG hỏi lại ở lần sau', (tester) async {
      final repo = _FakeConsentRepository(
        WrAiConsent(
          version: kWrAiDisclosureVersion,
          revokedAt: DateTime(2026, 9, 7, 11),
        ),
      );
      final results = <bool>[];
      await tester.pumpWidget(harness(repo, results));
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();

      // Hỏi tới hỏi lui cho tới khi người ta bấm bừa là ép buộc, không phải xin
      // phép. Muốn bật lại thì vào Tài khoản.
      expect(results, [false]);
      expect(find.byKey(const Key('wr_ai_consent_title')), findsNothing);
    });

    testWidgets('ghi hỏng thì không đóng màn và không cho đi tiếp',
        (tester) async {
      final repo = _FakeConsentRepository()..failWrites = true;
      final results = <bool>[];
      await tester.pumpWidget(harness(repo, results));
      await tester.tap(find.byKey(const Key('go')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wr_ai_consent_accept')));
      await tester.pumpAndSettle();

      expect(results, isEmpty);
      expect(find.byKey(const Key('wr_ai_consent_title')), findsOneWidget);
    });
  });

  group('Màn xin phép hiện đủ nội dung', () {
    testWidgets('kể tên từng bên nhận và từng luồng dữ liệu', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wrAiConsentRepositoryProvider
                .overrideWithValue(_FakeConsentRepository()),
            currentUserIdProvider.overrideWithValue(_userId),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: WrAiDisclosureBody()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final r in kWrAiRecipients) {
        expect(find.text(r.name), findsOneWidget, reason: r.name);
      }
      for (final f in kWrAiDataFlows) {
        expect(find.text(f.trigger), findsOneWidget, reason: f.trigger);
      }
      expect(
        find.byKey(const Key('wr_ai_consent_revoke_note')),
        findsOneWidget,
      );
    });
  });
}
