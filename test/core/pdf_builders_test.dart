// Tests for report_pdf_builder.dart and certificate_pdf_builder.dart.
// These are pure-data builders (no Flutter/Riverpod), so they can run as
// plain unit tests.  They use the bundled NotoSans font asset which must be
// resolvable via rootBundle — the test harness loads the flutter test binding
// automatically when flutter_test is imported.

import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/core/pdf/certificate_pdf_builder.dart';
import 'package:workreflection_mobile/core/pdf/report_pdf_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // ReportPdfBuilder
  // -------------------------------------------------------------------------
  group('ReportPdfBuilder', () {
    ReportPdfData freeData({String locale = 'vi'}) => ReportPdfData(
          userName: 'Nguyễn Văn An',
          reportDate: DateTime(2026, 7, 18),
          totalScore: 3.8,
          scoreLevel: ScoreLevel.good,
          scoreStructure: 4.0,
          scoreCulture: 3.5,
          scoreActivity: 3.9,
          bottleneckLayer: 'Culture',
          bottleneckNarrative: 'Văn hóa tổ chức cần được cải thiện.',
          structureNarrative: 'Cấu trúc tổ chức của bạn khá tốt.',
          cultureNarrative: 'Văn hóa cần chú trọng hơn.',
          activityNarrative: 'Hoạt động hàng ngày ổn định.',
          scoreEsi: null,
          scoreEnps: null,
          locale: locale,
        );

    ReportPdfData premiumData({String locale = 'vi'}) => freeData(locale: locale).copyWith(
          scoreEsi: 3.9,
          scoreEnps: 7,
        );

    test('build returns non-empty bytes for VI free report', () async {
      final bytes = await ReportPdfBuilder.build(freeData());
      expect(bytes.isNotEmpty, isTrue,
          reason: 'PDF bytes must not be empty for VI free report');
      expect(bytes.length, greaterThan(1000),
          reason: 'A real PDF must be larger than 1KB');
    });

    test('build returns non-empty bytes for EN free report', () async {
      final bytes = await ReportPdfBuilder.build(freeData(locale: 'en'));
      expect(bytes.isNotEmpty, isTrue,
          reason: 'PDF bytes must not be empty for EN free report');
    });

    test('build returns non-empty bytes for VI premium report', () async {
      final bytes = await ReportPdfBuilder.build(premiumData());
      expect(bytes.isNotEmpty, isTrue,
          reason: 'PDF bytes must not be empty for VI premium report');
    });

    test('build returns non-empty bytes for EN premium report', () async {
      final bytes = await ReportPdfBuilder.build(premiumData(locale: 'en'));
      expect(bytes.isNotEmpty, isTrue,
          reason: 'PDF bytes must not be empty for EN premium report');
    });

    test('VI report bytes contain PDF magic bytes', () async {
      final bytes = await ReportPdfBuilder.build(freeData());
      // Every PDF starts with "%PDF"
      expect(bytes[0], equals(0x25)); // '%'
      expect(bytes[1], equals(0x50)); // 'P'
      expect(bytes[2], equals(0x44)); // 'D'
      expect(bytes[3], equals(0x46)); // 'F'
    });

    test('build handles Vietnamese diacritics in user name without throwing',
        () async {
      final data = freeData().copyWith(
        userName: 'Phạm Thị Bích Ngọc',
        bottleneckNarrative:
            'Điểm cần cải thiện: văn hóa tổ chức và hoạt động hàng ngày.',
      );
      // Should not throw
      final bytes = await ReportPdfBuilder.build(data);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('premium report includes ESI score section', () async {
      // Smoke test: just verify it builds without error when ESI/eNPS present
      final data = freeData().copyWith(scoreEsi: 4.2, scoreEnps: 9);
      final bytes = await ReportPdfBuilder.build(data);
      expect(bytes.isNotEmpty, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // CertificatePdfBuilder
  // -------------------------------------------------------------------------
  group('CertificatePdfBuilder', () {
    CertificateData certData({String locale = 'vi'}) => CertificateData(
          participantName: 'Trần Thị Lan',
          workshopTitle: 'Lãnh đạo & Văn hóa tổ chức',
          workshopDate: DateTime(2026, 8, 5),
          workshopLocation: 'TP. Hồ Chí Minh',
          locale: locale,
        );

    test('build returns non-empty bytes for VI certificate', () async {
      final bytes = await CertificatePdfBuilder.build(certData());
      expect(bytes.isNotEmpty, isTrue,
          reason: 'Certificate PDF bytes must not be empty');
      expect(bytes.length, greaterThan(1000));
    });

    test('build returns non-empty bytes for EN certificate', () async {
      final bytes = await CertificatePdfBuilder.build(certData(locale: 'en'));
      expect(bytes.isNotEmpty, isTrue);
    });

    test('certificate PDF has PDF magic bytes', () async {
      final bytes = await CertificatePdfBuilder.build(certData());
      expect(bytes[0], equals(0x25)); // '%'
      expect(bytes[1], equals(0x50)); // 'P'
      expect(bytes[2], equals(0x44)); // 'D'
      expect(bytes[3], equals(0x46)); // 'F'
    });

    test(
        'build handles Vietnamese diacritics in participant name without throwing',
        () async {
      final data = certData().copyWith(
        participantName: 'Nguyễn Thị Ánh Nguyệt',
        workshopTitle: 'Phát triển năng lực lãnh đạo',
      );
      final bytes = await CertificatePdfBuilder.build(data);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('build works without location', () async {
      final data = CertificateData(
        participantName: 'John Doe',
        workshopTitle: 'Leadership & Culture',
        workshopDate: DateTime(2026, 9, 1),
        workshopLocation: null,
        locale: 'en',
      );
      final bytes = await CertificatePdfBuilder.build(data);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('build works with null participant name fallback', () async {
      final data = CertificateData(
        participantName: null,
        workshopTitle: 'Workshop Title',
        workshopDate: DateTime(2026, 9, 1),
        workshopLocation: null,
        locale: 'vi',
      );
      final bytes = await CertificatePdfBuilder.build(data);
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
