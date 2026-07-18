import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/workshop_models.dart';

void main() {
  // ---------------------------------------------------------------------------
  // WorkshopDetail
  // ---------------------------------------------------------------------------
  group('WorkshopDetail.fromJson', () {
    final fullJson = {
      'id': 'w1',
      'title': 'Lãnh đạo bền vững',
      'description': 'Workshop về kỹ năng lãnh đạo',
      'category': 'leadership',
      'date': '2026-08-01',
      'starts_at': '2026-08-01T09:00:00.000Z',
      'ends_at': '2026-08-01T17:00:00.000Z',
      'location': 'Hà Nội',
      'price': 500000,
      'currency': 'VND',
      'max_participants': 30,
      'current_participants': 15,
      'image_url': 'https://example.com/img.jpg',
      'video_url': 'https://example.com/video.mp4',
      'status': 'published',
      'is_active': true,
      'checkin_code': 'AB12CD34',
      'org_id': 'org1',
    };

    test('parses all fields correctly', () {
      final w = WorkshopDetail.fromJson(fullJson);
      expect(w.id, 'w1');
      expect(w.title, 'Lãnh đạo bền vững');
      expect(w.description, 'Workshop về kỹ năng lãnh đạo');
      expect(w.category, 'leadership');
      expect(w.date, DateTime.parse('2026-08-01'));
      expect(w.startsAt, DateTime.parse('2026-08-01T09:00:00.000Z'));
      expect(w.endsAt, DateTime.parse('2026-08-01T17:00:00.000Z'));
      expect(w.location, 'Hà Nội');
      expect(w.price, 500000);
      expect(w.currency, 'VND');
      expect(w.maxParticipants, 30);
      expect(w.currentParticipants, 15);
      expect(w.imageUrl, 'https://example.com/img.jpg');
      expect(w.videoUrl, 'https://example.com/video.mp4');
      expect(w.status, 'published');
      expect(w.isActive, true);
      expect(w.checkinCode, 'AB12CD34');
      expect(w.orgId, 'org1');
    });

    test('null price defaults to 0', () {
      final j = Map<String, dynamic>.from(fullJson)..['price'] = null;
      final w = WorkshopDetail.fromJson(j);
      expect(w.price, 0);
    });

    test('absent price defaults to 0', () {
      final j = Map<String, dynamic>.from(fullJson)..remove('price');
      final w = WorkshopDetail.fromJson(j);
      expect(w.price, 0);
    });

    test('isFree true when price == 0', () {
      final j = Map<String, dynamic>.from(fullJson)..['price'] = 0;
      final w = WorkshopDetail.fromJson(j);
      expect(w.isFree, isTrue);
    });

    test('isFree false when price > 0', () {
      final w = WorkshopDetail.fromJson(fullJson);
      expect(w.isFree, isFalse);
    });

    test('isFull true when current == max', () {
      final j = Map<String, dynamic>.from(fullJson)
        ..['max_participants'] = 30
        ..['current_participants'] = 30;
      final w = WorkshopDetail.fromJson(j);
      expect(w.isFull, isTrue);
    });

    test('isFull false when current < max', () {
      final w = WorkshopDetail.fromJson(fullJson); // 15 < 30
      expect(w.isFull, isFalse);
    });

    test('isFull false when maxParticipants is null', () {
      final j = Map<String, dynamic>.from(fullJson)
        ..['max_participants'] = null;
      final w = WorkshopDetail.fromJson(j);
      expect(w.isFull, isFalse);
    });

    test('null optional fields parse to null', () {
      final j = {
        'id': 'w2',
        'title': 'Basic Workshop',
        'description': null,
        'category': null,
        'date': '2026-08-10',
        'starts_at': null,
        'ends_at': null,
        'location': null,
        'price': null,
        'currency': null,
        'max_participants': null,
        'current_participants': null,
        'image_url': null,
        'video_url': null,
        'status': 'draft',
        'is_active': false,
        'checkin_code': null,
        'org_id': null,
      };
      final w = WorkshopDetail.fromJson(j);
      expect(w.description, isNull);
      expect(w.category, isNull);
      expect(w.startsAt, isNull);
      expect(w.endsAt, isNull);
      expect(w.location, isNull);
      expect(w.price, 0);
      expect(w.currency, 'VND');
      expect(w.maxParticipants, isNull);
      expect(w.currentParticipants, 0);
      expect(w.imageUrl, isNull);
      expect(w.videoUrl, isNull);
      expect(w.checkinCode, isNull);
      expect(w.orgId, isNull);
    });

    test('price as double (num) is tolerated', () {
      final j = Map<String, dynamic>.from(fullJson)..['price'] = 500000.0;
      final w = WorkshopDetail.fromJson(j);
      expect(w.price, 500000.0);
    });
  });

  // ---------------------------------------------------------------------------
  // WorkshopRegistration
  // ---------------------------------------------------------------------------
  group('WorkshopRegistration.fromJson', () {
    test('parses all fields', () {
      final json = {
        'id': 'reg1',
        'workshop_id': 'w1',
        'user_id': 'u1',
        'status': 'confirmed',
        'checked_in_at': '2026-08-01T09:05:00.000Z',
        'attended': true,
        'image_consent': true,
        'created_at': '2026-07-15T12:00:00.000Z',
      };
      final r = WorkshopRegistration.fromJson(json);
      expect(r.id, 'reg1');
      expect(r.workshopId, 'w1');
      expect(r.userId, 'u1');
      expect(r.status, 'confirmed');
      expect(r.checkedInAt, DateTime.parse('2026-08-01T09:05:00.000Z'));
      expect(r.attended, isTrue);
      expect(r.imageConsent, isTrue);
      expect(r.createdAt, DateTime.parse('2026-07-15T12:00:00.000Z'));
    });

    test('null optional fields default correctly', () {
      final json = {
        'id': 'reg2',
        'workshop_id': 'w1',
        'user_id': 'u2',
        'status': 'pending',
        'checked_in_at': null,
        'attended': null,
        'image_consent': null,
        'created_at': null,
      };
      final r = WorkshopRegistration.fromJson(json);
      expect(r.checkedInAt, isNull);
      expect(r.attended, isFalse);
      expect(r.imageConsent, isNull);
      expect(r.createdAt, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // WorkshopAttachment
  // ---------------------------------------------------------------------------
  group('WorkshopAttachment.fromJson', () {
    test('parses all fields', () {
      final json = {
        'id': 'att1',
        'workshop_id': 'w1',
        'file_name': 'slides.pdf',
        'file_url': 'https://example.com/slides.pdf',
        'file_type': 'application/pdf',
        'file_size': 1024000,
        'category': 'document',
        'sort_order': 1,
      };
      final a = WorkshopAttachment.fromJson(json);
      expect(a.id, 'att1');
      expect(a.workshopId, 'w1');
      expect(a.fileName, 'slides.pdf');
      expect(a.fileUrl, 'https://example.com/slides.pdf');
      expect(a.fileType, 'application/pdf');
      expect(a.fileSize, 1024000);
      expect(a.category, 'document');
      expect(a.sortOrder, 1);
    });

    test('null optional fields and sort_order defaults to 0', () {
      final json = {
        'id': 'att2',
        'workshop_id': 'w1',
        'file_name': 'photo.jpg',
        'file_url': 'https://example.com/photo.jpg',
        'file_type': null,
        'file_size': null,
        'category': 'image',
        'sort_order': null,
      };
      final a = WorkshopAttachment.fromJson(json);
      expect(a.fileType, isNull);
      expect(a.fileSize, isNull);
      expect(a.sortOrder, 0);
    });
  });
}
