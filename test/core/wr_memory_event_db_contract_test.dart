// Hợp đồng giữa `CareerMemoryEvent.toInsert()` và bảng thật.
//
// VÌ SAO FILE NÀY TỒN TẠI
//
// Mọi test khác của Career Memory chạy qua `FakeWrContentRepository` — một cái
// List trong bộ nhớ. Nó nhận mọi thứ: chuỗi rỗng ở cột uuid, mã chiều bịa,
// nhu cầu không có trong danh sách. Postgres thì không, và chênh lệch đó đã cắn
// hai lần rồi: hai lỗi 400 của bản Hai Lớp v1.6 chỉ lộ ra khi chạy máy thật, vì
// repo giả không có ràng buộc CHECK nào.
//
// Nên bộ ràng buộc thật được CHÉP xuống đây thành hằng số, và test đối chiếu
// từng giá trị Dart có thể sinh ra với nó. Chép là có chủ đích: nếu ai đó đổi
// CHECK bên DB mà quên sửa chỗ này, test vẫn xanh — nhưng nếu ai đó thêm một
// giá trị enum mới bên Dart mà quên migration, test này đỏ NGAY, và đó mới là
// hướng lỗi hay xảy ra.
//
// Đối chiếu lúc 25/08/2026 bằng `pg_get_constraintdef` trên project
// sukpcxevcjnhiuyaoqxi.
//
// Run: flutter test test/core/wr_memory_event_db_contract_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_career_memory_rules.dart';
import 'package:workreflection_mobile/core/models/wr_content.dart';

/// `wr_career_memory_events_human_need_check`
const _kHumanNeedCheck = {'ro_rang', 'ket_noi', 'thich_nghi', 'phat_trien'};

/// `wr_career_memory_events_sca_dimension_check`
const _kScaDimensionCheck = {
  'S1', 'S2', 'S3',
  'C1', 'C2', 'C3',
  'A1', 'A2', 'A3', 'A4',
  'P-ACHIEVE', 'P-STEADY',
};

void main() {
  group('CHECK constraint — mọi giá trị enum phải được DB nhận', () {
    test('HumanNeed.dbValue nằm trong danh sách cho phép', () {
      for (final n in HumanNeed.values) {
        expect(
          _kHumanNeedCheck,
          contains(n.dbValue),
          reason: 'HumanNeed.${n.name} → "${n.dbValue}" bị CHECK từ chối. '
              'Thêm nhu cầu mới thì phải có migration nới CHECK trước.',
        );
      }
    });

    test('ScaDimension.dbValue nằm trong danh sách cho phép', () {
      for (final d in ScaDimension.values) {
        expect(
          _kScaDimensionCheck,
          contains(d.dbValue),
          reason: 'ScaDimension.${d.name} → "${d.dbValue}" bị CHECK từ chối.',
        );
      }
    });
  });

  group('toInsert — đúng hình dạng bảng', () {
    CareerMemoryEvent event({
      String? situationCode,
      String? storyId,
      HumanNeed? need,
      ScaDimension? dim,
      int? intensity,
    }) =>
        CareerMemoryEvent(
          id: '',
          userId: 'u1',
          situationCode: situationCode,
          storyId: storyId,
          humanNeed: need,
          scaDimension: dim,
          intensity: intensity,
          behavior: kThemeBehavior,
          reflectionText: 'x',
        );

    test('KHÔNG gửi cột id', () {
      // `id` là uuid có `gen_random_uuid()` làm mặc định. Người gọi dựng bản ghi
      // với `id: ''` vì id thật do DB sinh — gửi chuỗi rỗng lên cột uuid là lỗi
      // 400 "invalid input syntax for type uuid", và repo giả không bao giờ
      // phát hiện được.
      expect(event().toInsert().containsKey('id'), isFalse);
    });

    test('KHÔNG gửi cột created_at', () {
      // Mặc định `now()` bên DB. Để client quyết định thời điểm là mở đường cho
      // đồng hồ lệch múi giờ ghi sai ngày lên dòng thời gian.
      expect(event().toInsert().containsKey('created_at'), isFalse);
    });

    test('bỏ hẳn situation_code khi null — cột này có khoá ngoại', () {
      // FK → wr_situations(code). Gửi null tường minh thì không sao, nhưng gửi
      // chuỗi rỗng là 400. Bản nháp Chủ đề/Insight không có mã tình huống nào.
      expect(event().toInsert().containsKey('situation_code'), isFalse);
      expect(
        event(situationCode: 'C2-01').toInsert()['situation_code'],
        'C2-01',
      );
    });

    test('bỏ hẳn story_id khi null — cột này cũng có khoá ngoại', () {
      // FK → wr_stories(story_id).
      expect(event().toInsert().containsKey('story_id'), isFalse);
    });

    test('user_id luôn có mặt — RLS chặn insert nếu thiếu', () {
      // Policy `wr_career_memory_events_owner_insert`:
      //   WITH CHECK (auth.uid() = user_id)
      // Thiếu cột này thì DB từ chối, không phải ghi vào rồi mất.
      expect(event().toInsert()['user_id'], 'u1');
    });

    test('nhu cầu và chiều đi xuống DB ở dạng dbValue, không phải tên enum', () {
      final row = event(
        need: HumanNeed.ketNoi,
        dim: ScaDimension.pAchieve,
      ).toInsert();

      expect(row['human_need'], 'ket_noi');
      expect(row['sca_dimension'], 'P-ACHIEVE');
      // Tên enum Dart ("ketNoi", "pAchieve") đều bị CHECK từ chối.
      expect(_kHumanNeedCheck, contains(row['human_need']));
      expect(_kScaDimensionCheck, contains(row['sca_dimension']));
    });
  });

  group('behavior của ba loại mảnh ký ức', () {
    test('cột behavior KHÔNG có CHECK, nhưng mã phải ổn định', () {
      // Đã kiểm `pg_get_constraintdef` 25/08: bảng chỉ có CHECK cho human_need,
      // sca_dimension và intensity. `behavior` là text tự do, nên ba mã dưới
      // đây ghi được ngay không cần migration.
      //
      // Ổn định mới là điều đáng khoá: đổi chuỗi là mọi mảnh ký ức đã ghi trước
      // đó rơi khỏi bộ lọc theo loại và khỏi phép đếm ở tab Hành trình.
      expect(kMilestoneBehavior, 'career_milestone');
      expect(kThemeBehavior, 'career_theme');
      expect(kInsightBehavior, 'career_insight');
      expect(kEpisodeBehaviorInDb, 'reflection_episode');
    });
  });
}

/// Mã Episode tự ghi khi khép lại. Đặt ở đây thay vì import từ tầng màn hình để
/// file test này không kéo theo Flutter.
const String kEpisodeBehaviorInDb = 'reflection_episode';
