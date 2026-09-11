// Career Snapshot — hồ sơ nghề nghiệp nhẹ dùng để cá nhân hoá nội dung.
//
// Spec: giao-dien-ho-tro.jsx (CareerSetupScreen, CareerSnapshotCard,
// ROLE_TO_DIMS, ROLE_TO_STAGES) + DataSpec v3 Tầng 4 (thứ tự triển khai đợt).
//
// Pure Dart, không phụ thuộc Flutter → test được trực tiếp.

import '../l10n/wr_tr.dart';
import '../models/wr_content.dart';

// ---------------------------------------------------------------------------
// Danh sách lựa chọn (3 bước thiết lập hồ sơ)
// ---------------------------------------------------------------------------

List<String> get kCareerRoleOptions => <String>[
  tr('Chuyên viên', 'Individual contributor'),
  'Senior Specialist',
  'Team Leader',
  'Manager',
  'Director',
  'Founder / Business Owner',
];

List<String> get kCareerGoalOptions => <String>[
  tr('Phát triển năng lực', 'Building capability'),
  tr('Thăng tiến', 'Getting promoted'),
  tr('Chuyển việc', 'Changing jobs'),
  tr('Xây dựng đội ngũ', 'Building a team'),
  tr('Cân bằng cuộc sống', 'Life balance'),
  tr('Khởi nghiệp', 'Starting something of my own'),
];

List<String> get kCareerChallengeOptions => <String>[
  tr('Thiếu động lực', 'Low motivation'),
  tr('Áp lực công việc', 'Pressure at work'),
  tr('Không rõ hướng đi', 'No clear direction'),
  tr('Mâu thuẫn trong công việc', 'Conflict at work'),
  tr('Thiếu cơ hội phát triển', 'No room to grow'),
  tr('Khó cân bằng cuộc sống', 'Hard to keep balance'),
];

/// DataSpec v3 Tầng 4 — Đợt 1: những chiều được ưu tiên hiển thị khi chưa
/// biết gì về người dùng.
const kWave1Dimensions = <ScaDimension>[
  ScaDimension.c2,
  ScaDimension.a1,
  ScaDimension.a3,
  ScaDimension.c1,
];

/// DataSpec v3 Tầng 4 — thứ tự triển khai đầy đủ (Đợt 1 → 2 → 3).
/// Dùng làm thứ tự nền cho phần còn lại sau các chiều ưu tiên của vai trò.
const kWaveOrderDimensions = <ScaDimension>[
  // Đợt 1
  ScaDimension.c2,
  ScaDimension.a1,
  ScaDimension.a3,
  ScaDimension.c1,
  // Đợt 2
  ScaDimension.a4,
  ScaDimension.a2,
  ScaDimension.s1,
  // Đợt 3
  ScaDimension.c3,
  ScaDimension.s2,
  ScaDimension.s3,
];

// ---------------------------------------------------------------------------
// Ánh xạ vai trò
// ---------------------------------------------------------------------------

dynamic get _roleToDims => <String, List<ScaDimension>>{
  tr('Chuyên viên', 'Individual contributor'): [ScaDimension.c2, ScaDimension.a1, ScaDimension.s1],
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

dynamic get _roleToStages => <String, List<String>>{
  tr('Chuyên viên', 'Individual contributor'): ['Early Career', 'Growth'],
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

/// Thứ tự chiều SCA hiệu dụng cho [role]: ba chiều của vai trò trước, phần
/// còn lại theo thứ tự đợt triển khai của DataSpec v3.
///
/// Với vai trò không xác định, kết quả chính là [kWaveOrderDimensions].
List<ScaDimension> effectiveDimensionOrder(String? role) {
  final head = roleToDimensions(role);
  return [
    ...head,
    ...kWaveOrderDimensions.where((d) => !head.contains(d)),
  ];
}

/// Sắp xếp lại [stories] theo mức phù hợp với [snapshot].
///
/// Thứ tự ưu tiên:
///   1. Chiều SCA theo [effectiveDimensionOrder] của vai trò.
///   2. Trong cùng một chiều: story có `careerStages` trùng giai đoạn của
///      vai trò xếp trước.
///   3. Còn lại giữ nguyên thứ tự đầu vào (stable).
///
/// Không bao giờ loại bỏ story — chỉ đổi thứ tự. Không sửa danh sách gốc.
List<WrStory> rankStoriesForProfile(
  List<WrStory> stories,
  CareerSnapshot snapshot,
) {
  final dims = effectiveDimensionOrder(snapshot.currentRole);
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
