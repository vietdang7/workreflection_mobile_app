// Ma trận cấp bậc — "Thói quen và Ma trận Cấp bậc v1.0", Phần B.
//
// Một bộ 10 chiều DUY NHẤT, không tách nhánh riêng theo cấp bậc (Nguyên tắc 1).
// Thứ đổi theo cấp bậc chỉ là hai thứ:
//   • trọng số khi xếp hạng khoảng trống lúc đối chiếu JD (B.2), và
//   • chữ của bước Chuyển hoá — bước thứ ba, sâu nhất (B.3).
// Bộ khung, chiều SCA và vị trí bước giữ nguyên. Cài theo đúng cơ chế cá nhân
// hoá đã có (§XIV Kiến trúc Dữ liệu): viết lại nội dung LÚC ĐỌC, không sinh
// bước mới và không ghi đè dữ liệu gốc trong DB.
//
// Pure Dart, không phụ thuộc Flutter.

import '../l10n/wr_tr.dart';
import '../models/wr_content.dart';
import '../models/wr_intelligence.dart';

// ---------------------------------------------------------------------------
// Ba cấp bậc
// ---------------------------------------------------------------------------

/// Ba cột của bảng B.2/B.3.
enum SeniorityTier {
  /// Tự làm việc của mình.
  individual,

  /// Quản lý nhóm nhỏ.
  leadTeam,

  /// Quản lý nhiều nhóm / bộ phận.
  leadOrg;

  /// Từ mức quản lý nhóm nhỏ trở lên — điều kiện của Nguyên tắc 3 (B.1).
  bool get isManaging => this != SeniorityTier.individual;
}

/// Cấp bậc suy từ `cc_profiles.position`.
///
/// Tám mã vị trí của web (xem `positionOptions`) gộp về ba cột của bảng. Không
/// khai, hoặc mã lạ, thì trả null — KHÔNG mặc định về `individual`: chưa biết
/// và biết-là-nhân-viên là hai chuyện khác nhau, và mọi chỗ dùng đều phải giữ
/// nguyên bản mặc định khi chưa biết (B.3).
///
/// ⚠ `manager` xếp vào [SeniorityTier.leadOrg]: trong thang tám mức của web,
/// "Trưởng nhóm" (`team_lead`) đã là người quản lý nhóm nhỏ, nên "Quản lý"
/// nằm ở nấc trên đó — phụ trách một bộ phận. Đây là điểm duy nhất của phép
/// ánh xạ này cần khách xác nhận lại.
SeniorityTier? seniorityFromPosition(String? position) {
  final p = position?.trim().toLowerCase();
  if (p == null || p.isEmpty) return null;
  return switch (p) {
    'intern' || 'staff' || 'freelancer' => SeniorityTier.individual,
    'team_lead' => SeniorityTier.leadTeam,
    'manager' || 'director' || 'c_level' => SeniorityTier.leadOrg,
    // 'other' và mọi mã lạ: có khai nhưng không nói lên cấp bậc nào.
    _ => null,
  };
}

// ---------------------------------------------------------------------------
// B.2 — Mức độ liên quan
// ---------------------------------------------------------------------------

/// Ba mức của bảng B.2, xếp theo thứ tự ưu tiên tăng dần.
enum SkillRelevance {
  /// "Nên có".
  nice,

  /// "Cần".
  needed,

  /// "Cần, ưu tiên cao".
  critical;

  /// Chữ hiện cho người dùng. Ngắn, không diễn giải thêm.
  String get label => switch (this) {
        SkillRelevance.nice => tr('Nên có', 'Nice to have'),
        SkillRelevance.needed => tr('Cần', 'Needed'),
        SkillRelevance.critical => tr('Cần, ưu tiên cao', 'Needed, high priority'),
      };

  /// Càng lớn càng xếp trước.
  int get rank => index;
}

/// Bảng B.2 nguyên văn: chiều SCA × cấp bậc → mức độ liên quan.
const Map<ScaDimension, Map<SeniorityTier, SkillRelevance>> kSeniorityMatrix = {
  ScaDimension.s1: {
    SeniorityTier.individual: SkillRelevance.needed,
    SeniorityTier.leadTeam: SkillRelevance.needed,
    SeniorityTier.leadOrg: SkillRelevance.needed,
  },
  ScaDimension.s2: {
    SeniorityTier.individual: SkillRelevance.needed,
    SeniorityTier.leadTeam: SkillRelevance.needed,
    SeniorityTier.leadOrg: SkillRelevance.needed,
  },
  ScaDimension.s3: {
    SeniorityTier.individual: SkillRelevance.nice,
    SeniorityTier.leadTeam: SkillRelevance.needed,
    SeniorityTier.leadOrg: SkillRelevance.critical,
  },
  ScaDimension.c1: {
    SeniorityTier.individual: SkillRelevance.nice,
    SeniorityTier.leadTeam: SkillRelevance.critical,
    SeniorityTier.leadOrg: SkillRelevance.critical,
  },
  ScaDimension.c2: {
    SeniorityTier.individual: SkillRelevance.needed,
    SeniorityTier.leadTeam: SkillRelevance.critical,
    SeniorityTier.leadOrg: SkillRelevance.critical,
  },
  ScaDimension.c3: {
    SeniorityTier.individual: SkillRelevance.nice,
    SeniorityTier.leadTeam: SkillRelevance.critical,
    SeniorityTier.leadOrg: SkillRelevance.critical,
  },
  ScaDimension.a1: {
    SeniorityTier.individual: SkillRelevance.needed,
    SeniorityTier.leadTeam: SkillRelevance.nice,
    SeniorityTier.leadOrg: SkillRelevance.needed,
  },
  ScaDimension.a2: {
    SeniorityTier.individual: SkillRelevance.needed,
    SeniorityTier.leadTeam: SkillRelevance.needed,
    SeniorityTier.leadOrg: SkillRelevance.needed,
  },
  ScaDimension.a3: {
    SeniorityTier.individual: SkillRelevance.nice,
    SeniorityTier.leadTeam: SkillRelevance.needed,
    SeniorityTier.leadOrg: SkillRelevance.critical,
  },
  ScaDimension.a4: {
    SeniorityTier.individual: SkillRelevance.nice,
    SeniorityTier.leadTeam: SkillRelevance.nice,
    SeniorityTier.leadOrg: SkillRelevance.needed,
  },
};

/// Ba chiều nhóm Kết nối — Nguyên tắc 3 (B.1).
///
/// JD vị trí quản lý thường không ghi "cần biết tin tưởng đội" hay "cần dám lên
/// tiếng", vì được ngầm hiểu là đương nhiên. Không có luật này thì đúng những
/// chiều quan trọng nhất với người quản lý lại không bao giờ hiện ra.
const Set<ScaDimension> kConnectionDimensions = {
  ScaDimension.c1,
  ScaDimension.c2,
  ScaDimension.c3,
};

/// Mức độ liên quan của [dimension] với người ở [tier].
///
/// Trả null khi chưa biết cấp bậc, hoặc chiều nằm ngoài bộ 10 (hai nhóm tình
/// huống tích cực). Chưa biết thì không xếp hạng — đoán một cấp bậc rồi đảo
/// thứ tự khoảng trống của người dùng còn tệ hơn là để nguyên.
SkillRelevance? relevanceOf(ScaDimension? dimension, SeniorityTier? tier) {
  if (dimension == null || tier == null) return null;
  return kSeniorityMatrix[dimension]?[tier];
}

/// Nguyên tắc 3: chiều này có được tự động nâng lên mức "cần" cho [tier] không,
/// bất kể JD có nhắc tới hay không.
bool isAutoRaised(ScaDimension? dimension, SeniorityTier? tier) =>
    dimension != null &&
    tier != null &&
    tier.isManaging &&
    kConnectionDimensions.contains(dimension);

// ---------------------------------------------------------------------------
// B.3 — Bước Chuyển hoá viết lại theo cấp bậc
// ---------------------------------------------------------------------------

/// Bước Chuyển hoá là bước thứ ba trong chuỗi ba bước.
///
/// Hai bước đầu (Nhận diện, Thử nghiệm) giữ nguyên chung cho mọi cấp bậc: việc
/// nhận ra và thử nghiệm ở quy mô cá nhân là như nhau bất kể vị trí (B.3).
const int kTransformStepOrder = 3;

/// Bảng B.3 nguyên văn: theme_id → cấp bậc → nội dung bước Chuyển hoá.
///
/// Khoá theo `theme_id`, KHÔNG theo tên hiển thị — cùng lý do với bộ đếm thực
/// hành (Phần C.1): thư viện có những chủ đề trùng tên.
Map<String, Map<SeniorityTier, String>> get kTransformByTier => {
  'pt-s1': {
    SeniorityTier.individual:
        tr('Với mọi việc mới, luôn làm rõ kết quả tốt trông như thế nào trước khi '
            'bắt đầu.', 'For anything new, make clear what a good outcome looks like before you '
            'start.'),
    SeniorityTier.leadTeam:
        tr('Đặt rõ kỳ vọng cho từng người trong nhóm, không giả định họ tự hiểu '
            'như bạn.', 'Set expectations for each person on the team; do not assume they read '
            'it the way you do.'),
    SeniorityTier.leadOrg:
        tr('Giữ kỳ vọng nhất quán giữa các nhóm, để không ai nhận hai tiêu chuẩn '
            'khác nhau cho cùng một việc.', 'Keep expectations consistent across teams, so nobody gets two different '
            'standards for the same work.'),
  },
  'pt-s2': {
    SeniorityTier.individual:
        tr('Xây một cách phân loại việc theo mức độ bạn thực sự cần quyết định, '
            'dùng lại mỗi tuần.', 'Build a way of sorting work by how much you genuinely need to decide, '
            'and reuse it weekly.'),
    SeniorityTier.leadTeam:
        tr('Giúp từng người trong nhóm tự phân biệt việc quan trọng và việc gấp, '
            'không quyết định thay họ mọi lúc.', 'Help each person tell important from urgent themselves, rather than '
            'deciding for them every time.'),
    SeniorityTier.leadOrg:
        tr('Phân bổ ưu tiên giữa nhiều nhóm dựa trên mục tiêu chung, không theo '
            'người nào lên tiếng to nhất.', 'Allocate priority across teams from shared goals, not from whoever is '
            'loudest.'),
  },
  'pt-s3': {
    SeniorityTier.individual:
        tr('Xây thói quen xác nhận lại thông tin quan trọng trước khi hành động '
            'theo đó.', 'Make it a habit to confirm important information before acting on it.'),
    SeniorityTier.leadTeam:
        tr('Chủ động truyền đạt lý do đằng sau một thay đổi cho nhóm, trước khi họ '
            'phải tự đoán.', 'Tell the team the reasoning behind a change before they have to guess '
            'at it.'),
    SeniorityTier.leadOrg:
        tr('Dẫn dắt nhiều nhóm qua một thay đổi lớn, giữ thông tin nhất quán ở mọi '
            'cấp truyền đạt.', 'Lead several teams through a large change, keeping the message '
            'consistent at every level it passes through.'),
  },
  'pt-c1': {
    SeniorityTier.individual:
        tr('Giữ việc giao trọn vẹn, không kiểm soát chi tiết, như một thói quen '
            'chứ không phải ngoại lệ.', 'Hand work over whole, without managing the detail, as a habit rather '
            'than an exception.'),
    SeniorityTier.leadTeam:
        tr('Học cách giao việc và thật sự buông, thay vì giao rồi vẫn kiểm tra như '
            'chưa từng giao.', 'Learn to delegate and actually let go, instead of handing over and '
            'still checking as though you had not.'),
    SeniorityTier.leadOrg:
        tr('Xây một văn hóa tin tưởng áp dụng nhất quán cho nhiều nhóm, không chỉ '
            'ở người bạn thân cận nhất.', 'Build a culture of trust applied consistently across teams, not just '
            'with the people closest to you.'),
  },
  'pt-c2': {
    SeniorityTier.individual:
        tr('Chủ động chia sẻ một góc nhìn của riêng bạn, không chỉ trả lời khi '
            'được hỏi.', 'Offer a view of your own, rather than only answering when asked.'),
    SeniorityTier.leadTeam:
        tr('Tạo một khoảng an toàn rõ ràng để từng người trong nhóm dám nói, không '
            'chỉ chờ họ tự dũng cảm.', 'Create clear room for each person to speak up, rather than waiting for '
            'them to find the courage.'),
    SeniorityTier.leadOrg:
        tr('Đảm bảo tiếng nói từ các nhóm phía dưới thật sự đến được nơi ra quyết '
            'định, không bị lọc mất giữa đường.', 'Make sure voices from the teams below genuinely reach where decisions '
            'are made, without being filtered out on the way.'),
  },
  'pt-c3': {
    SeniorityTier.individual:
        tr('Đưa phản hồi trở thành nhịp thường xuyên trong đội, không chỉ khi có '
            'vấn đề.', 'Make feedback a regular rhythm in the team, not something that only '
            'appears when there is a problem.'),
    SeniorityTier.leadTeam:
        tr('Đưa phản hồi đều đặn cho từng người, không dồn lại đến kỳ đánh giá mới '
            'nói.', 'Give each person feedback steadily, rather than saving it all for '
            'review season.'),
    SeniorityTier.leadOrg:
        tr('Xây một quy trình phản hồi hai chiều cho toàn bộ phạm vi phụ trách, '
            'không chỉ từ trên xuống.', 'Build a two-way feedback process across everything you cover, not just '
            'top-down.'),
  },
  'pt-a1': {
    SeniorityTier.individual:
        tr('Đặt một nhịp định kỳ để tự hỏi lại mục tiêu, thay vì làm theo quán '
            'tính.', 'Set a regular rhythm for questioning the goal, instead of running on '
            'momentum.'),
    SeniorityTier.leadTeam:
        tr('Kết nối mục tiêu của từng người trong nhóm với mục tiêu chung, để không '
            'ai chỉ làm vì được giao.', 'Connect each person\'s goals to the shared one, so nobody is working '
            'only because they were told to.'),
    SeniorityTier.leadOrg:
        tr('Giữ định hướng chiến lược rõ ràng và nhất quán, để nhiều nhóm không đi '
            'lệch nhau theo thời gian.', 'Keep strategic direction clear and consistent, so teams do not drift '
            'apart over time.'),
  },
  'pt-a2': {
    SeniorityTier.individual:
        tr('Đặt một nhịp nghỉ cố định, không đợi đến khi kiệt sức mới nghỉ.', 'Set a fixed rhythm of rest, rather than waiting until you are spent.'),
    SeniorityTier.leadTeam:
        tr('Chủ động bảo vệ nhịp làm việc của nhóm, không để deadline gấp trở thành '
            'trạng thái bình thường.', 'Protect the team\'s working rhythm, so rushed deadlines do not become '
            'the normal state.'),
    SeniorityTier.leadOrg:
        tr('Xây văn hóa làm việc bền vững ở quy mô rộng, để kiệt sức không trở '
            'thành cái giá ngầm định của hiệu suất.', 'Build sustainable ways of working at scale, so burnout is not the '
            'unspoken price of performance.'),
  },
  'pt-a3': {
    SeniorityTier.individual:
        tr('Học cách nhận ra sớm dấu hiệu của phản ứng, trước khi đã lỡ nói ra.', 'Learn to catch the signs of a reaction early, before it is already said.'),
    SeniorityTier.leadTeam:
        tr('Giữ bình tĩnh khi cả nhóm đang căng thẳng, vì phản ứng của bạn lúc đó '
            'ảnh hưởng đến tất cả.', 'Stay steady when the team is under strain, because how you react then '
            'lands on everyone.'),
    SeniorityTier.leadOrg:
        tr('Ra quyết định bình tĩnh ở những tình huống có phạm vi ảnh hưởng lớn, '
            'khi áp lực dồn về một người.', 'Decide calmly in situations with wide consequences, when the pressure '
            'lands on one person.'),
  },
  'pt-a4': {
    SeniorityTier.individual:
        tr('Đặt một nhịp nhìn lại định kỳ (retro cá nhân), để việc học không chỉ là '
            'tình cờ.', 'Set a regular look-back rhythm for yourself, so learning is not just '
            'accidental.'),
    SeniorityTier.leadTeam:
        tr('Xây một nhịp nhìn lại định kỳ cho cả nhóm, để bài học không chỉ nằm lại '
            'ở một người.', 'Build a regular look-back rhythm for the team, so the lesson does not '
            'stay with one person.'),
    SeniorityTier.leadOrg:
        tr('Xây một hệ thống ghi nhận và chia sẻ bài học cho toàn bộ phạm vi phụ '
            'trách, để cùng một sai lầm không lặp lại ở nhóm khác.', 'Build a way of capturing and sharing lessons across everything you '
            'cover, so the same mistake does not repeat in another team.'),
  },
};

/// Nội dung bước Chuyển hoá của [themeId] cho người ở [tier].
///
/// Trả null khi chưa biết cấp bậc, hoặc chủ đề nằm ngoài bộ 10 chuẩn (ba chủ đề
/// đời đầu) — lúc đó giữ nguyên bản mặc định trong DB.
String? transformContentFor(String themeId, SeniorityTier? tier) {
  if (tier == null) return null;
  return kTransformByTier[themeId]?[tier];
}

/// Chuỗi bước của một chủ đề, đã viết lại bước Chuyển hoá theo [tier].
///
/// Giữ nguyên `stepId`, `stepOrder`, `title` và cờ Premium — chỉ đổi phần
/// `content`. Đây là toàn bộ phạm vi cá nhân hoá mà B.3 cho phép: không tạo
/// bước mới, không đổi chiều, không đổi vị trí.
List<PracticeStep> personalizePracticeSteps({
  required String themeId,
  required List<PracticeStep> steps,
  required SeniorityTier? tier,
}) {
  final replacement = transformContentFor(themeId, tier);
  if (replacement == null) return steps;
  return [
    for (final s in steps)
      if (s.stepOrder == kTransformStepOrder)
        PracticeStep(
          stepId: s.stepId,
          themeId: s.themeId,
          stepOrder: s.stepOrder,
          title: s.title,
          content: replacement,
          isPremium: s.isPremium,
          createdAt: s.createdAt,
        )
      else
        s,
  ];
}
