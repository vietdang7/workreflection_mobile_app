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
        SkillRelevance.nice => 'Nên có',
        SkillRelevance.needed => 'Cần',
        SkillRelevance.critical => 'Cần, ưu tiên cao',
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
const Map<String, Map<SeniorityTier, String>> kTransformByTier = {
  'pt-s1': {
    SeniorityTier.individual:
        'Với mọi việc mới, luôn làm rõ kết quả tốt trông như thế nào trước khi '
            'bắt đầu.',
    SeniorityTier.leadTeam:
        'Đặt rõ kỳ vọng cho từng người trong nhóm, không giả định họ tự hiểu '
            'như bạn.',
    SeniorityTier.leadOrg:
        'Giữ kỳ vọng nhất quán giữa các nhóm, để không ai nhận hai tiêu chuẩn '
            'khác nhau cho cùng một việc.',
  },
  'pt-s2': {
    SeniorityTier.individual:
        'Xây một cách phân loại việc theo mức độ bạn thực sự cần quyết định, '
            'dùng lại mỗi tuần.',
    SeniorityTier.leadTeam:
        'Giúp từng người trong nhóm tự phân biệt việc quan trọng và việc gấp, '
            'không quyết định thay họ mọi lúc.',
    SeniorityTier.leadOrg:
        'Phân bổ ưu tiên giữa nhiều nhóm dựa trên mục tiêu chung, không theo '
            'người nào lên tiếng to nhất.',
  },
  'pt-s3': {
    SeniorityTier.individual:
        'Xây thói quen xác nhận lại thông tin quan trọng trước khi hành động '
            'theo đó.',
    SeniorityTier.leadTeam:
        'Chủ động truyền đạt lý do đằng sau một thay đổi cho nhóm, trước khi họ '
            'phải tự đoán.',
    SeniorityTier.leadOrg:
        'Dẫn dắt nhiều nhóm qua một thay đổi lớn, giữ thông tin nhất quán ở mọi '
            'cấp truyền đạt.',
  },
  'pt-c1': {
    SeniorityTier.individual:
        'Giữ việc giao trọn vẹn, không kiểm soát chi tiết, như một thói quen '
            'chứ không phải ngoại lệ.',
    SeniorityTier.leadTeam:
        'Học cách giao việc và thật sự buông, thay vì giao rồi vẫn kiểm tra như '
            'chưa từng giao.',
    SeniorityTier.leadOrg:
        'Xây một văn hóa tin tưởng áp dụng nhất quán cho nhiều nhóm, không chỉ '
            'ở người bạn thân cận nhất.',
  },
  'pt-c2': {
    SeniorityTier.individual:
        'Chủ động chia sẻ một góc nhìn của riêng bạn, không chỉ trả lời khi '
            'được hỏi.',
    SeniorityTier.leadTeam:
        'Tạo một khoảng an toàn rõ ràng để từng người trong nhóm dám nói, không '
            'chỉ chờ họ tự dũng cảm.',
    SeniorityTier.leadOrg:
        'Đảm bảo tiếng nói từ các nhóm phía dưới thật sự đến được nơi ra quyết '
            'định, không bị lọc mất giữa đường.',
  },
  'pt-c3': {
    SeniorityTier.individual:
        'Đưa phản hồi trở thành nhịp thường xuyên trong đội, không chỉ khi có '
            'vấn đề.',
    SeniorityTier.leadTeam:
        'Đưa phản hồi đều đặn cho từng người, không dồn lại đến kỳ đánh giá mới '
            'nói.',
    SeniorityTier.leadOrg:
        'Xây một quy trình phản hồi hai chiều cho toàn bộ phạm vi phụ trách, '
            'không chỉ từ trên xuống.',
  },
  'pt-a1': {
    SeniorityTier.individual:
        'Đặt một nhịp định kỳ để tự hỏi lại mục tiêu, thay vì làm theo quán '
            'tính.',
    SeniorityTier.leadTeam:
        'Kết nối mục tiêu của từng người trong nhóm với mục tiêu chung, để không '
            'ai chỉ làm vì được giao.',
    SeniorityTier.leadOrg:
        'Giữ định hướng chiến lược rõ ràng và nhất quán, để nhiều nhóm không đi '
            'lệch nhau theo thời gian.',
  },
  'pt-a2': {
    SeniorityTier.individual:
        'Đặt một nhịp nghỉ cố định, không đợi đến khi kiệt sức mới nghỉ.',
    SeniorityTier.leadTeam:
        'Chủ động bảo vệ nhịp làm việc của nhóm, không để deadline gấp trở thành '
            'trạng thái bình thường.',
    SeniorityTier.leadOrg:
        'Xây văn hóa làm việc bền vững ở quy mô rộng, để kiệt sức không trở '
            'thành cái giá ngầm định của hiệu suất.',
  },
  'pt-a3': {
    SeniorityTier.individual:
        'Học cách nhận ra sớm dấu hiệu của phản ứng, trước khi đã lỡ nói ra.',
    SeniorityTier.leadTeam:
        'Giữ bình tĩnh khi cả nhóm đang căng thẳng, vì phản ứng của bạn lúc đó '
            'ảnh hưởng đến tất cả.',
    SeniorityTier.leadOrg:
        'Ra quyết định bình tĩnh ở những tình huống có phạm vi ảnh hưởng lớn, '
            'khi áp lực dồn về một người.',
  },
  'pt-a4': {
    SeniorityTier.individual:
        'Đặt một nhịp nhìn lại định kỳ (retro cá nhân), để việc học không chỉ là '
            'tình cờ.',
    SeniorityTier.leadTeam:
        'Xây một nhịp nhìn lại định kỳ cho cả nhóm, để bài học không chỉ nằm lại '
            'ở một người.',
    SeniorityTier.leadOrg:
        'Xây một hệ thống ghi nhận và chia sẻ bài học cho toàn bộ phạm vi phụ '
            'trách, để cùng một sai lầm không lặp lại ở nhóm khác.',
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
