// Tính điểm Khảo sát tổ chức.
//
// Màn kết quả là chỗ duy nhất app nói với người dùng một câu về NƠI HỌ LÀM VIỆC
// so với mọi người khác. Một phép tính sai ở đây không hiện ra như lỗi — nó
// hiện ra như một khẳng định bình tĩnh, sai.
// Run: flutter test test/logic/wr_org_survey_scoring_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/logic/wr_org_survey_scoring.dart';
import 'package:workreflection_mobile/core/models/wr_org_survey.dart';

OrgSurveyQuestion q(String id, OrgSurveyArea area) => OrgSurveyQuestion(
      id: id,
      area: area,
      text: id,
      sortOrder: 0,
    );

final _questions = [
  q('OS-01', OrgSurveyArea.compensation),
  q('OS-02', OrgSurveyArea.compensation),
  q('OS-03', OrgSurveyArea.growth),
  q('OS-04', OrgSurveyArea.fairness),
];

void main() {
  group('trung bình theo mảng', () {
    test('chỉ tính trên câu đã trả lời', () {
      final avg = orgSurveyAreaAverage(
        {'OS-01': 4, 'OS-03': 0},
        _questions,
        OrgSurveyArea.compensation,
      );
      // OS-02 bỏ trống nên không kéo trung bình xuống.
      expect(avg, 4.0);
    });

    test('mảng chưa trả lời câu nào trả về null, KHÔNG phải 0', () {
      // Đây là khác biệt quan trọng nhất của cả file. Người bỏ qua mảng Đãi ngộ
      // mà bị vẽ vạch sát đáy là bị nói sai về mình.
      final avg = orgSurveyAreaAverage(
        {'OS-03': 3},
        _questions,
        OrgSurveyArea.compensation,
      );
      expect(avg, isNull);
    });

    test('giá trị ngoài thang 0..4 bị loại', () {
      final avg = orgSurveyAreaAverage(
        {'OS-01': 2, 'OS-02': 99},
        _questions,
        OrgSurveyArea.compensation,
      );
      expect(avg, 2.0);
    });

    test('câu không có trong bảng hỏi thì bỏ qua', () {
      final avg = orgSurveyAreaAverage(
        {'OS-01': 2, 'OS-99': 4},
        _questions,
        OrgSurveyArea.compensation,
      );
      expect(avg, 2.0);
    });

    test('mảng nào trống thì vắng mặt trong map', () {
      final all = orgSurveyAreaAverages({'OS-01': 1}, _questions);
      expect(all.keys, [OrgSurveyArea.compensation]);
      expect(all.containsKey(OrgSurveyArea.support), isFalse);
    });
  });

  group('phần trăm', () {
    test('đổi theo thang 0..4', () {
      expect(orgSurveyPercent(0), 0);
      expect(orgSurveyPercent(2), 50);
      expect(orgSurveyPercent(4), 100);
    });

    test('thang eNPS dùng max riêng', () {
      expect(orgSurveyPercent(6.4, max: kEnpsMaxScore), 64);
    });
  });

  group('so với mặt bằng chung', () {
    test('chưa trả lời thì nói CHƯA TRẢ LỜI, không nói thấp hơn', () {
      expect(
        orgSurveyStanding(mine: null, benchmark: 2.5),
        OrgSurveyStanding.unanswered,
      );
    });

    test('chưa có mặt bằng chung thì không kết luận gì', () {
      // Trạng thái lúc mới ra mắt: chưa đủ người trả lời. Rơi về "thấp hơn" ở
      // đây là bịa ra một mặt bằng không tồn tại.
      expect(
        orgSurveyStanding(mine: 3.0, benchmark: null),
        OrgSurveyStanding.noBenchmark,
      );
    });

    test('chênh trong dải ±3% là NGANG', () {
      // 2.5 → 62.5% → làm tròn 63; 2.4 → 60%. Chênh 3 điểm phần trăm, vẫn ngang.
      expect(
        orgSurveyStanding(mine: 2.5, benchmark: 2.4),
        OrgSurveyStanding.equal,
      );
    });

    test('chênh quá dải mới kết luận cao hơn hoặc thấp hơn', () {
      expect(
        orgSurveyStanding(mine: 3.5, benchmark: 2.4),
        OrgSurveyStanding.above,
      );
      expect(
        orgSurveyStanding(mine: 1.0, benchmark: 2.4),
        OrgSurveyStanding.below,
      );
    });

    test('bằng nhau tuyệt đối là NGANG', () {
      expect(
        orgSurveyStanding(mine: 2.4, benchmark: 2.4),
        OrgSurveyStanding.equal,
      );
    });
  });

  test('đếm số câu đã trả lời có tính cả eNPS', () {
    expect(
      orgSurveyAnsweredCount(
        answers: {'OS-01': 1, 'OS-02': 2},
        questions: _questions,
        enps: 7,
      ),
      3,
    );
    expect(
      orgSurveyAnsweredCount(
        answers: {'OS-01': 1},
        questions: _questions,
        enps: null,
      ),
      1,
    );
  });

  test('ngưỡng mẫu tối thiểu khớp mặc định của RPC', () {
    // Lệch số này với `wr_org_survey_benchmark(min_sample integer default 30)`
    // là app xin một ngưỡng, máy chủ dùng một ngưỡng khác.
    expect(kOrgSurveyMinSample, 30);
  });
}
