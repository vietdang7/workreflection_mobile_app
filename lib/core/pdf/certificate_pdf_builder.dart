// Certificate PDF builder — Phase 5 Task 10.
//
// Pure function — no Riverpod, no BuildContext.
//
// Mirrors web MyWorkshops.tsx generateCertificate (jsPDF landscape A4):
//   - Landscape A4 (297mm × 210mm)
//   - Participant name (cc_profiles.full_name fallback → email → "Participant")
//   - Workshop title + date + optional location
//   - Ornament borders (corner accents via line drawing)
//   - Title lines bilingual (EN + VI)
//   - Signature lines: Facilitator / Cloud & Coral
//   - Footer with issue date
//
// Eligibility rule (mirrors web line 586):
//   Button shown when `reg.attended == true`.
//
// Font: NotoSans-Regular + NotoSans-Bold for Vietnamese diacritics.

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class CertificateData {
  const CertificateData({
    required this.participantName,
    required this.workshopTitle,
    required this.workshopDate,
    this.workshopLocation,
    required this.locale,
  });

  /// Full name from cc_profiles. Null triggers fallback to "Participant".
  final String? participantName;
  final String workshopTitle;
  final DateTime workshopDate;
  final String? workshopLocation;
  final String locale;

  String get displayName => participantName?.isNotEmpty == true
      ? participantName!
      : 'Participant';

  CertificateData copyWith({
    String? participantName,
    String? workshopTitle,
    DateTime? workshopDate,
    String? workshopLocation,
    String? locale,
  }) {
    return CertificateData(
      participantName: participantName ?? this.participantName,
      workshopTitle: workshopTitle ?? this.workshopTitle,
      workshopDate: workshopDate ?? this.workshopDate,
      workshopLocation: workshopLocation ?? this.workshopLocation,
      locale: locale ?? this.locale,
    );
  }
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

class CertificatePdfBuilder {
  CertificatePdfBuilder._();

  /// Builds and returns raw PDF bytes for a landscape A4 certificate.
  static Future<Uint8List> build(CertificateData data) async {
    final regularData =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);

    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final pdf = pw.Document(theme: theme);

    // Landscape A4: 297mm wide × 210mm tall
    const pageFormat =
        PdfPageFormat(297 * PdfPageFormat.mm, 210 * PdfPageFormat.mm);

    pdf.addPage(pw.Page(
      pageFormat: pageFormat,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => _buildCertificate(ctx, data, regular, bold),
    ));

    return pdf.save();
  }

  static pw.Widget _buildCertificate(
    pw.Context ctx,
    CertificateData d,
    pw.Font regular,
    pw.Font bold,
  ) {
    final isVi = d.locale == 'vi';

    // Localised strings
    final certifiesLine = 'This is to certify that / Chứng nhận rằng';
    final attendedLine =
        'has successfully completed the workshop / Đã tham dự thành công';
    final facilitator = 'Facilitator';
    final orgName = 'Cloud & Coral';
    final footerText = isVi
        ? 'Cloud & Coral  |  Nền tảng phát triển tổ chức  |  www.cloudandcoral.com'
        : 'Cloud & Coral  |  Work Reflection Platform  |  www.cloudandcoral.com';
    final issuedLabel = isVi ? 'Ngày cấp' : 'Issued';
    final dateStr = _formatDate(d.workshopDate, isVi);
    final issueDateStr = _formatDate(DateTime.now(), isVi);

    return pw.Stack(
      children: [
        // ── Background ──────────────────────────────────────────────────────
        pw.Positioned.fill(
          child: pw.Container(color: const PdfColor.fromInt(0xFFFDFAF6)),
        ),

        // ── Outer border ────────────────────────────────────────────────────
        pw.Positioned.fill(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _navy, width: 2),
              ),
            ),
          ),
        ),

        // ── Inner border ────────────────────────────────────────────────────
        pw.Positioned.fill(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _navy, width: 0.5),
              ),
            ),
          ),
        ),

        // ── Top accent line ──────────────────────────────────────────────────
        pw.Positioned(
          left: 30,
          right: 30,
          top: 18,
          child: pw.Container(height: 1.5, color: _coral),
        ),

        // ── Bottom accent line ───────────────────────────────────────────────
        pw.Positioned(
          left: 30,
          right: 30,
          bottom: 18,
          child: pw.Container(height: 1.5, color: _coral),
        ),

        // ── Main content ─────────────────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 22),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Logo / org name placeholder
              pw.Text(
                'Cloud & Coral',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 14,
                  color: _navy,
                  letterSpacing: 2,
                ),
                textAlign: pw.TextAlign.center,
              ),

              // Certificate title
              pw.Column(
                children: [
                  pw.Text(
                    'CERTIFICATE OF ATTENDANCE',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 26,
                      color: _navy,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Chứng nhận tham dự',
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 12,
                      color: _muted,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),

              // "This certifies that" line
              pw.Text(
                certifiesLine,
                style: pw.TextStyle(
                    font: regular, fontSize: 10, color: _muted),
                textAlign: pw.TextAlign.center,
              ),

              // Participant name + underline
              pw.Column(
                children: [
                  pw.Text(
                    d.displayName,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 24,
                      color: _navy,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: 200,
                    height: 0.6,
                    color: _coral,
                  ),
                ],
              ),

              // "has successfully attended" line
              pw.Text(
                attendedLine,
                style: pw.TextStyle(
                    font: regular, fontSize: 10, color: _muted),
                textAlign: pw.TextAlign.center,
              ),

              // Workshop title
              pw.Text(
                d.workshopTitle,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 16,
                  color: _textDark,
                ),
                textAlign: pw.TextAlign.center,
                maxLines: 2,
              ),

              // Date & location
              pw.Column(
                children: [
                  pw.Text(
                    dateStr,
                    style: pw.TextStyle(
                        font: regular, fontSize: 10, color: _muted),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (d.workshopLocation != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      d.workshopLocation!,
                      style: pw.TextStyle(
                          font: regular, fontSize: 10, color: _muted),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ],
              ),

              // Signature section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _signatureBlock(facilitator, regular, bold),
                  _signatureBlock(orgName, regular, bold),
                ],
              ),

              // Footer
              pw.Text(
                '$footerText\n$issuedLabel: $issueDateStr',
                style: pw.TextStyle(
                    font: regular, fontSize: 7.5, color: _muted),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _signatureBlock(
      String label, pw.Font regular, pw.Font bold) {
    return pw.Column(
      children: [
        pw.Container(width: 100, height: 0.4, color: _navy),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(font: regular, fontSize: 9, color: _textDark),
        ),
      ],
    );
  }

  static String _formatDate(DateTime d, bool isVi) {
    final months = isVi
        ? [
            '', 'tháng 1', 'tháng 2', 'tháng 3', 'tháng 4',
            'tháng 5', 'tháng 6', 'tháng 7', 'tháng 8',
            'tháng 9', 'tháng 10', 'tháng 11', 'tháng 12'
          ]
        : [
            '', 'January', 'February', 'March', 'April',
            'May', 'June', 'July', 'August',
            'September', 'October', 'November', 'December'
          ];
    if (isVi) {
      return '${d.day} ${months[d.month]} ${d.year}';
    } else {
      return '${months[d.month]} ${d.day}, ${d.year}';
    }
  }

  // Brand colours
  static const _navy = PdfColor.fromInt(0xFF2C335D);
  static const _coral = PdfColor.fromInt(0xFFFF6859);
  static const _muted = PdfColor.fromInt(0xFF757575);
  static const _textDark = PdfColor.fromInt(0xFF212121);
}
