/// Mood enum matching the wr_checkins.mood check constraint in the migration.
///
/// Sáu giá trị từ 24/08/2026 (changelog mockup §3): `foggy` và `outofsync` chèn
/// GIỮA `tired` và `okay` — nhóm cảm xúc khó khăn đứng trước, nhóm tích cực
/// đứng sau. Thứ tự khai báo ở đây là thứ tự đọc của lưới check-in trên Home.
///
/// ⚠ Thêm giá trị mới ở đây thôi là chưa đủ: `wr_checkins.mood` có CHECK
/// constraint, nên thiếu migration đi kèm thì mọi lần check-in bằng cảm xúc mới
/// sẽ trả 400 — và lỗi đó KHÔNG lộ ra trong test vì fake repository không có
/// constraint. Migration tương ứng:
/// `20260825000000_wr_two_new_moods.sql`.
enum Mood {
  stressed,
  tired,
  foggy,
  outofsync,
  okay,
  happy;

  /// 'stressed' | 'tired' | 'foggy' | 'outofsync' | 'okay' | 'happy'
  String get dbValue => name;

  static Mood fromDb(String value) {
    return switch (value) {
      'stressed' => Mood.stressed,
      'tired' => Mood.tired,
      'foggy' => Mood.foggy,
      'outofsync' => Mood.outofsync,
      'okay' => Mood.okay,
      'happy' => Mood.happy,
      _ => throw ArgumentError('Unknown mood db value: $value'),
    };
  }
}

/// Energy level for the new check-in UI (Phase 2).
/// Maps to wr_checkins.energy check constraint.
enum CheckinEnergy {
  good,
  ok,
  low;

  String get dbValue => switch (this) {
        CheckinEnergy.good => 'good',
        CheckinEnergy.ok => 'ok',
        CheckinEnergy.low => 'low',
      };

  static CheckinEnergy fromDb(String value) => switch (value) {
        'good' => CheckinEnergy.good,
        'ok' => CheckinEnergy.ok,
        'low' => CheckinEnergy.low,
        _ => throw ArgumentError('Unknown CheckinEnergy db value: $value'),
      };

  /// Maps energy → legacy Mood for backward-compatible upsert.
  Mood toMood() => switch (this) {
        CheckinEnergy.good => Mood.happy,
        CheckinEnergy.ok => Mood.okay,
        CheckinEnergy.low => Mood.tired,
      };
}

/// Perceived direction — forward/steady/backward.
/// Maps to wr_checkins.direction check constraint.
enum CheckinDirection {
  forward,
  steady,
  backward;

  String get dbValue => switch (this) {
        CheckinDirection.forward => 'forward',
        CheckinDirection.steady => 'steady',
        CheckinDirection.backward => 'backward',
      };

  static CheckinDirection fromDb(String value) => switch (value) {
        'forward' => CheckinDirection.forward,
        'steady' => CheckinDirection.steady,
        'backward' => CheckinDirection.backward,
        _ => throw ArgumentError('Unknown CheckinDirection db value: $value'),
      };
}

/// Maps to the public.wr_checkins table.
class Checkin {
  const Checkin({
    required this.id,
    required this.userId,
    required this.mood,
    required this.checkinDate,
    required this.createdAt,
    this.energy,
    this.direction,
  });

  final String id;
  final String userId;
  final Mood mood;
  final CheckinEnergy? energy;
  final CheckinDirection? direction;

  /// The calendar date of the check-in (time component stripped).
  final DateTime checkinDate;
  final DateTime createdAt;

  factory Checkin.fromJson(Map<String, dynamic> json) {
    return Checkin(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mood: Mood.fromDb(json['mood'] as String),
      checkinDate: DateTime.parse(json['checkin_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      energy: json['energy'] != null
          ? CheckinEnergy.fromDb(json['energy'] as String)
          : null,
      direction: json['direction'] != null
          ? CheckinDirection.fromDb(json['direction'] as String)
          : null,
    );
  }
}
