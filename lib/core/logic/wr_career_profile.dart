// Career Snapshot — hồ sơ nghề nghiệp nhẹ dùng để cá nhân hoá nội dung.
//
// Spec: giao-dien-ho-tro.jsx (CareerSetupScreen, CareerSnapshotCard,
// ROLE_TO_DIMS, ROLE_TO_STAGES) + DataSpec v3 Tầng 4 (thứ tự triển khai đợt).
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

import '../models/wr_content.dart';

// ---------------------------------------------------------------------------
// Danh sách lựa chọn (3 bước thiết lập hồ sơ)
// ---------------------------------------------------------------------------

const kCareerRoleOptions = <String>[
  'Chuyên viên',
  'Senior Specialist',
  'Team Leader',
  'Manager',
  'Director',
  'Founder / Business Owner',
];

const kCareerGoalOptions = <String>[
  'Phát triển năng lực',
  'Thăng tiến',
  'Chuyển việc',
  'Xây dựng đội ngũ',
  'Cân bằng cuộc sống',
  'Khởi nghiệp',
];

const kCareerChallengeOptions = <String>[
  'Thiếu động lực',
  'Áp lực công việc',
  'Không rõ hướng đi',
  'Mâu thuẫn trong công việc',
  'Thiếu cơ hội phát triển',
  'Khó cân bằng cuộc sống',
];

/// DataSpec v3 Tầng 4 — Đợt 1: những chiều được ưu tiên hiển thị khi chưa
/// biết gì về người dùng.
const kWave1Dimensions = <ScaDimension>[
  ScaDimension.c2,
  ScaDimension.a1,
  ScaDimension.a3,
  ScaDimension.c1,
];

// ---------------------------------------------------------------------------
// Ánh xạ vai trò
// ---------------------------------------------------------------------------

const _roleToDims = <String, List<ScaDimension>>{
  'Chuyên viên': [ScaDimension.c2, ScaDimension.a1, ScaDimension.s1],
  'Senior Specialist': [ScaDimension.a1, ScaDimension.a3, ScaDimension.s1],
  'Team Leader': [ScaDimension.c1, ScaDimension.c2, ScaDimension.c3],
  'Manager': [ScaDimension.c1, ScaDimension.s2, ScaDimension.a4],
  'Director': [ScaDimension.c3, ScaDimension.s3, ScaDimension.a1],
  'Founder / Business Owner': [
    ScaDimension.a1,
    ScaDimension.c1,
    ScaDimension.a3,
  ],
};

const _roleToStages = <String, List<String>>{
  'Chuyên viên': ['Early Career', 'Growth'],
  'Senior Specialist': ['Growth', 'Mid Career'],
  'Team Leader': ['Mid Career', 'Leadership'],
  'Manager': ['Mid Career', 'Leadership'],
  'Director': ['Leadership'],
  'Founder / Business Owner': ['Leadership', 'Career Transition'],
};

/// Ba chiều SCA ưu tiên cho [role]. Vai trò không xác định → Đợt 1.
List<ScaDimension> roleToDimensions(String? role) =>
    _roleToDims[role] ?? kWave1Dimensions;

/// Các giai đoạn sự nghiệp tương ứng [role]. Không xác định → rỗng (không lọc).
List<String> roleToCareerStages(String? role) => _roleToStages[role] ?? const [];

// ---------------------------------------------------------------------------
// CareerSnapshot
// ---------------------------------------------------------------------------

/// Ba câu trả lời của bước "Thiết lập hồ sơ". Mọi trường đều tuỳ chọn —
/// người dùng có thể bỏ qua từng bước.
class CareerSnapshot {
  const CareerSnapshot({
    String? currentRole,
    String? careerGoal,
    String? currentChallenge,
    this.updatedAt,
  })  : _currentRole = currentRole,
        _careerGoal = careerGoal,
        _currentChallenge = currentChallenge;

  final String? _currentRole;
  final String? _careerGoal;
  final String? _currentChallenge;
  final DateTime? updatedAt;

  static String? _clean(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  String? get currentRole => _clean(_currentRole);
  String? get careerGoal => _clean(_careerGoal);
  String? get currentChallenge => _clean(_currentChallenge);

  factory CareerSnapshot.fromJson(Map<String, dynamic> json) => CareerSnapshot(
        currentRole: json['current_role'] as String?,
        careerGoal: json['career_goal'] as String?,
        currentChallenge: json['current_challenge'] as String?,
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.tryParse(json['updated_at'] as String),
      );

  bool get isEmpty =>
      currentRole == null && careerGoal == null && currentChallenge == null;

  bool get isComplete =>
      currentRole != null && careerGoal != null && currentChallenge != null;

  /// Payload cho `update()` trên `wr_mobile_profiles`.
  /// Bước bị bỏ qua được ghi null để xoá giá trị cũ.
  Map<String, dynamic> toUpdate() => {
        'current_role': currentRole,
        'career_goal': careerGoal,
        'current_challenge': currentChallenge,
      };

  CareerSnapshot copyWith({
    String? currentRole,
    String? careerGoal,
    String? currentChallenge,
  }) =>
      CareerSnapshot(
        currentRole: currentRole ?? this.currentRole,
        careerGoal: careerGoal ?? this.careerGoal,
        currentChallenge: currentChallenge ?? this.currentChallenge,
        updatedAt: updatedAt,
      );
}

// ---------------------------------------------------------------------------
// Xếp hạng story theo hồ sơ
// ---------------------------------------------------------------------------

/// Sắp xếp lại [stories] theo mức phù hợp với [snapshot].
///
/// Thứ tự ưu tiên:
///   1. Chiều SCA nằm trong danh sách ưu tiên của vai trò (theo đúng thứ tự).
///   2. Trong cùng một chiều: story có `careerStages` trùng giai đoạn của
///      vai trò xếp trước.
///   3. Còn lại giữ nguyên thứ tự đầu vào (stable).
///
/// Không bao giờ loại bỏ story — chỉ đổi thứ tự. Không sửa danh sách gốc.
List<WrStory> rankStoriesForProfile(
  List<WrStory> stories,
  CareerSnapshot snapshot,
) {
  final dims = roleToDimensions(snapshot.currentRole);
  final stages = roleToCareerStages(snapshot.currentRole).toSet();

  int dimRank(ScaDimension d) {
    final i = dims.indexOf(d);
    return i == -1 ? dims.length : i;
  }

  final indexed = <(int, WrStory)>[
    for (var i = 0; i < stories.length; i++) (i, stories[i]),
  ];

  indexed.sort((a, b) {
    final byDim = dimRank(a.$2.scaDimension).compareTo(
      dimRank(b.$2.scaDimension),
    );
    if (byDim != 0) return byDim;

    final aStage = a.$2.careerStages.any(stages.contains) ? 0 : 1;
    final bStage = b.$2.careerStages.any(stages.contains) ? 0 : 1;
    if (aStage != bStage) return aStage - bStage;

    return a.$1.compareTo(b.$1); // stable
  });

  return [for (final e in indexed) e.$2];
}
