import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/coaching_models.dart';

void main() {
  // ---------------------------------------------------------------------------
  // CoachingPackage
  // ---------------------------------------------------------------------------
  group('CoachingPackage.fromJson', () {
    final fullJson = {
      'id': 'pkg1',
      'name': 'Gói cơ bản',
      'description': 'Phù hợp cho người mới bắt đầu',
      'price': 1500000,
      'currency': 'VND',
      'sessions_count': 4,
      'duration_minutes': 60,
      'features': ['Tư vấn 1-1', 'Tài liệu miễn phí', 'Hỗ trợ qua chat'],
      'target_audience': 'Nhân viên văn phòng',
      'is_active': true,
      'display_order': 1,
    };

    test('parses all fields correctly', () {
      final p = CoachingPackage.fromJson(fullJson);
      expect(p.id, 'pkg1');
      expect(p.name, 'Gói cơ bản');
      expect(p.description, 'Phù hợp cho người mới bắt đầu');
      expect(p.price, 1500000);
      expect(p.currency, 'VND');
      expect(p.sessionsCount, 4);
      expect(p.durationMinutes, 60);
      expect(p.features, ['Tư vấn 1-1', 'Tài liệu miễn phí', 'Hỗ trợ qua chat']);
      expect(p.targetAudience, 'Nhân viên văn phòng');
      expect(p.isActive, isTrue);
      expect(p.displayOrder, 1);
    });

    test('isFree true when price == 0', () {
      final j = Map<String, dynamic>.from(fullJson)..['price'] = 0;
      final p = CoachingPackage.fromJson(j);
      expect(p.isFree, isTrue);
    });

    test('isFree false when price > 0', () {
      final p = CoachingPackage.fromJson(fullJson);
      expect(p.isFree, isFalse);
    });

    test('null price defaults to 0 and isFree is true', () {
      final j = Map<String, dynamic>.from(fullJson)..['price'] = null;
      final p = CoachingPackage.fromJson(j);
      expect(p.price, 0);
      expect(p.isFree, isTrue);
    });

    test('null currency defaults to VND', () {
      final j = Map<String, dynamic>.from(fullJson)..['currency'] = null;
      final p = CoachingPackage.fromJson(j);
      expect(p.currency, 'VND');
    });

    test('null sessions_count defaults to 1', () {
      final j = Map<String, dynamic>.from(fullJson)..['sessions_count'] = null;
      final p = CoachingPackage.fromJson(j);
      expect(p.sessionsCount, 1);
    });

    test('null features defaults to empty list', () {
      final j = Map<String, dynamic>.from(fullJson)..['features'] = null;
      final p = CoachingPackage.fromJson(j);
      expect(p.features, isEmpty);
    });

    test('null display_order defaults to 0', () {
      final j = Map<String, dynamic>.from(fullJson)..['display_order'] = null;
      final p = CoachingPackage.fromJson(j);
      expect(p.displayOrder, 0);
    });

    test('null optional fields parse correctly', () {
      final j = {
        'id': 'pkg2',
        'name': 'Gói miễn phí',
        'description': null,
        'price': null,
        'currency': null,
        'sessions_count': null,
        'duration_minutes': null,
        'features': null,
        'target_audience': null,
        'is_active': false,
        'display_order': null,
      };
      final p = CoachingPackage.fromJson(j);
      expect(p.description, isNull);
      expect(p.durationMinutes, isNull);
      expect(p.targetAudience, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Coach
  // ---------------------------------------------------------------------------
  group('Coach.fromJson', () {
    final fullJson = {
      'id': 'c1',
      'full_name': 'Nguyễn Thị Lan',
      'title': 'Senior Coach',
      'bio': 'Hơn 10 năm kinh nghiệm',
      'avatar_url': 'https://example.com/avatar.jpg',
      'specializations': ['Lãnh đạo', 'Quản lý stress'],
      'experience_years': 10,
      'is_active': true,
      'display_order': 1,
    };

    test('parses all fields correctly', () {
      final c = Coach.fromJson(fullJson);
      expect(c.id, 'c1');
      expect(c.fullName, 'Nguyễn Thị Lan');
      expect(c.title, 'Senior Coach');
      expect(c.bio, 'Hơn 10 năm kinh nghiệm');
      expect(c.avatarUrl, 'https://example.com/avatar.jpg');
      expect(c.specializations, ['Lãnh đạo', 'Quản lý stress']);
      expect(c.experienceYears, 10);
      expect(c.isActive, isTrue);
      expect(c.displayOrder, 1);
    });

    test('initials from two-word name', () {
      final c = Coach.fromJson(fullJson); // 'Nguyễn Thị Lan'
      // first word = 'Nguyễn', last word = 'Lan' → 'NL'
      expect(c.initials, 'NL');
    });

    test('initials from single-word name', () {
      final j = Map<String, dynamic>.from(fullJson)..['full_name'] = 'Coach';
      final c = Coach.fromJson(j);
      // single word: first = last = 'Coach' → 'CC'
      expect(c.initials, 'CC');
    });

    test('initials from empty/blank name never throws', () {
      final j = Map<String, dynamic>.from(fullJson)..['full_name'] = '   ';
      final c = Coach.fromJson(j);
      expect(c.initials, '?');
    });

    test('null optional fields default correctly', () {
      final j = {
        'id': 'c2',
        'full_name': 'An Bình',
        'title': null,
        'bio': null,
        'avatar_url': null,
        'specializations': null,
        'experience_years': null,
        'is_active': false,
        'display_order': null,
      };
      final c = Coach.fromJson(j);
      expect(c.title, isNull);
      expect(c.bio, isNull);
      expect(c.avatarUrl, isNull);
      expect(c.specializations, isEmpty);
      expect(c.experienceYears, isNull);
      expect(c.displayOrder, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // CoachingBooking
  // ---------------------------------------------------------------------------
  group('CoachingBooking.fromJson', () {
    test('parses all fields', () {
      final json = {
        'id': 'bk1',
        'package_id': 'pkg1',
        'coach_id': 'c1',
        'order_id': 'ord1',
        'status': 'confirmed',
        'session_number': 2,
        'total_sessions': 4,
        'scheduled_at': '2026-08-05T10:00:00.000Z',
        'duration_minutes': 60,
        'meeting_link': 'https://meet.example.com/session',
      };
      final b = CoachingBooking.fromJson(json);
      expect(b.id, 'bk1');
      expect(b.packageId, 'pkg1');
      expect(b.coachId, 'c1');
      expect(b.orderId, 'ord1');
      expect(b.status, 'confirmed');
      expect(b.sessionNumber, 2);
      expect(b.totalSessions, 4);
      expect(b.scheduledAt, DateTime.parse('2026-08-05T10:00:00.000Z'));
      expect(b.durationMinutes, 60);
      expect(b.meetingLink, 'https://meet.example.com/session');
    });

    test('null optional fields parse to null', () {
      final json = {
        'id': 'bk2',
        'package_id': 'pkg1',
        'coach_id': null,
        'order_id': null,
        'status': 'pending',
        'session_number': null,
        'total_sessions': null,
        'scheduled_at': null,
        'duration_minutes': null,
        'meeting_link': null,
      };
      final b = CoachingBooking.fromJson(json);
      expect(b.coachId, isNull);
      expect(b.orderId, isNull);
      expect(b.sessionNumber, isNull);
      expect(b.totalSessions, isNull);
      expect(b.scheduledAt, isNull);
      expect(b.durationMinutes, isNull);
      expect(b.meetingLink, isNull);
    });
  });
}
