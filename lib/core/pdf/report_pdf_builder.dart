// Report PDF builder — Phase 5 Task 10.
//
// Pure function — no Riverpod, no BuildContext.  Takes a [ReportPdfData]
// value object and returns raw PDF bytes that the caller can share/save.
//
// Content mirrors web Premium.tsx sections (html2canvas+jsPDF) converted to
// the `pdf` package widget tree:
//   Page 1 — Cover  (title, date, user name)
//   Page 2 — Score overview  (total score + level, S/C/A scores + narratives)
//   Page 3 — Bottleneck
//   Page 4 — ESI / eNPS  (premium only)
//   Footer on every page.
//
// Font: NotoSans-Regular + NotoSans-Bold bundled as assets/fonts/*.ttf.
// These fonts fully support Vietnamese diacritics.

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/survey_models.dart';

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class ReportPdfData {
  const ReportPdfData({
    required this.userName,
    required this.reportDate,
    required this.totalScore,
    required this.scoreLevel,
    required this.scoreStructure,
    required this.scoreCulture,
    required this.scoreActivity,
    required this.bottleneckLayer,
    required this.bottleneckNarrative,
    required this.structureNarrative,
    required this.cultureNarrative,
    required this.activityNarrative,
    this.scoreEsi,
    this.scoreEnps,
    required this.locale,
  });

  final String userName;
  final DateTime reportDate;
  final double totalScore;
  final ScoreLevel scoreLevel;
  final double scoreStructure;
  final double scoreCulture;
  final double scoreActivity;
  final String bottleneckLayer;
  final String? bottleneckNarrative;
  final String? structureNarrative;
  final String? cultureNarrative;
  final String? activityNarrative;
  final double? scoreEsi;
  final int? scoreEnps;
  final String locale;

  bool get isPremium => scoreEsi != null || scoreEnps != null;

  ReportPdfData copyWith({
    String? userName,
    DateTime? reportDate,
    double? totalScore,
    ScoreLevel? scoreLevel,
    double? scoreStructure,
    double? scoreCulture,
    double? scoreActivity,
    String? bottleneckLayer,
    String? bottleneckNarrative,
    String? structureNarrative,
    String? cultureNarrative,
    String? activityNarrative,
    double? scoreEsi,
    int? scoreEnps,
    String? locale,
  }) {
    return ReportPdfData(
      userName: userName ?? this.userName,
      reportDate: reportDate ?? this.reportDate,
      totalScore: totalScore ?? this.totalScore,
      scoreLevel: scoreLevel ?? this.scoreLevel,
      scoreStructure: scoreStructure ?? this.scoreStructure,
      scoreCulture: scoreCulture ?? this.scoreCulture,
      scoreActivity: scoreActivity ?? this.scoreActivity,
      bottleneckLayer: bottleneckLayer ?? this.bottleneckLayer,
      bottleneckNarrative: bottleneckNarrative ?? this.bottleneckNarrative,
      structureNarrative: structureNarrative ?? this.structureNarrative,
      cultureNarrative: cultureNarrative ?? this.cultureNarrative,
      activityNarrative: activityNarrative ?? this.activityNarrative,
      scoreEsi: scoreEsi ?? this.scoreEsi,
      scoreEnps: scoreEnps ?? this.scoreEnps,
      locale: locale ?? this.locale,
    );
  }
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

class ReportPdfBuilder {
  ReportPdfBuilder._();

  /// Builds and returns raw PDF bytes.
  ///
  /// Loads NotoSans TTF from assets so Vietnamese diacritics render correctly.
  static Future<Uint8List> build(ReportPdfData data) async {
    final regularData =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');

    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);

    final theme = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
    );

    final pdf = pw.Document(theme: theme);

    // --- Page 1: Cover ---
    pdf.addPage(_coverPage(data, regular, bold));

    // --- Page 2: Score overview ---
    pdf.addPage(_scorePage(data, regular, bold));

    // --- Page 3: Bottleneck ---
    pdf.addPage(_bottleneckPage(data, regular, bold));

    // --- Page 4: ESI / eNPS (premium only) ---
    if (data.isPremium) {
      pdf.addPage(_premiumPage(data, regular, bold));
    }

    return pdf.save();
  }

  // =========================================================================
  // Pages
  // =========================================================================

  static pw.Page _coverPage(
      ReportPdfData d, pw.Font regular, pw.Font bold) {
    final isVi = d.locale == 'vi';
    final title = isVi ? 'Báo cáo Work Reflection' : 'Work Reflection Report';
    final tier = d.isPremium
        ? (isVi ? 'Báo cáo Premium' : 'Premium Report')
        : (isVi ? 'Báo cáo Miễn phí' : 'Free Report');
    final preparedFor = isVi ? 'Báo cáo dành cho' : 'Prepared for';
    final dateLabel = isVi ? 'Ngày báo cáo' : 'Report date';
    final dateStr = _formatDate(d.reportDate, isVi);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Top accent bar
          pw.Container(
            height: 6,
            color: _coral,
          ),
          pw.SizedBox(height: 48),

          // Title
          pw.Text(
            title,
            style: pw.TextStyle(
              font: bold,
              fontSize: 32,
              color: _navy,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            tier,
            style: pw.TextStyle(
              font: regular,
              fontSize: 14,
              color: _coral,
            ),
          ),
          pw.SizedBox(height: 48),

          // Divider
          pw.Divider(color: _lightGrey, thickness: 1),
          pw.SizedBox(height: 24),

          // User info block
          pw.Text(
            preparedFor,
            style: pw.TextStyle(
              font: regular,
              fontSize: 11,
              color: _muted,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            d.userName,
            style: pw.TextStyle(
              font: bold,
              fontSize: 24,
              color: _navy,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            '$dateLabel: $dateStr',
            style: pw.TextStyle(
              font: regular,
              fontSize: 12,
              color: _muted,
            ),
          ),
          pw.Spacer(),

          // Footer
          _footer(d.locale, regular),
        ],
      ),
    );
  }

  static pw.Page _scorePage(
      ReportPdfData d, pw.Font regular, pw.Font bold) {
    final isVi = d.locale == 'vi';
    final totalLabel =
        isVi ? 'Điểm tổng' : 'Total Score';
    final levelLabel = _scoreLevelLabel(d.scoreLevel, isVi);
    final sLabel = isVi ? 'Cấu trúc tổ chức' : 'Organisational Structure';
    final cLabel = isVi ? 'Văn hóa làm việc' : 'Work Culture';
    final aLabel = isVi ? 'Hoạt động hàng ngày' : 'Daily Activity';

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _pageHeader(isVi ? 'Điểm số tổng quan' : 'Score Overview', bold),
          pw.SizedBox(height: 24),

          // Total score box
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: _navyLight,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  d.totalScore.toStringAsFixed(1),
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 48,
                    color: _navy,
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      totalLabel,
                      style: pw.TextStyle(
                          font: regular, fontSize: 11, color: _muted),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: _scoreLevelColor(d.scoreLevel),
                        borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(100)),
                      ),
                      child: pw.Text(
                        levelLabel,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // S / C / A layer rows
          _layerRow(sLabel, d.scoreStructure, d.structureNarrative, regular, bold),
          pw.SizedBox(height: 16),
          _layerRow(cLabel, d.scoreCulture, d.cultureNarrative, regular, bold),
          pw.SizedBox(height: 16),
          _layerRow(aLabel, d.scoreActivity, d.activityNarrative, regular, bold),

          pw.Spacer(),
          _footer(d.locale, regular),
        ],
      ),
    );
  }

  static pw.Page _bottleneckPage(
      ReportPdfData d, pw.Font regular, pw.Font bold) {
    final isVi = d.locale == 'vi';
    final headingLabel = isVi
        ? 'Điểm cần cải thiện nhất'
        : 'Area Needing Most Improvement';

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _pageHeader(headingLabel, bold),
          pw.SizedBox(height: 24),

          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFFFF3E0),
              border: pw.Border.all(color: _coral, width: 1),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  d.bottleneckLayer,
                  style: pw.TextStyle(font: bold, fontSize: 18, color: _coral),
                ),
                if (d.bottleneckNarrative != null) ...[
                  pw.SizedBox(height: 12),
                  pw.Text(
                    d.bottleneckNarrative!,
                    style: pw.TextStyle(
                        font: regular, fontSize: 12, color: _textDark),
                  ),
                ],
              ],
            ),
          ),

          pw.Spacer(),
          _footer(d.locale, regular),
        ],
      ),
    );
  }

  static pw.Page _premiumPage(
      ReportPdfData d, pw.Font regular, pw.Font bold) {
    final isVi = d.locale == 'vi';
    final esiLabel = isVi
        ? 'Chỉ số hài lòng nhân viên (ESI)'
        : 'Employee Satisfaction Index (ESI)';
    final enpsLabel = isVi
        ? 'Mức độ gắn kết (eNPS)'
        : 'Employee Engagement (eNPS)';

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _pageHeader('ESI / eNPS', bold),
          pw.SizedBox(height: 24),

          if (d.scoreEsi != null) ...[
            _metricBox(
              label: esiLabel,
              value: d.scoreEsi!.toStringAsFixed(1),
              suffix: '/ 5.0',
              regular: regular,
              bold: bold,
            ),
            pw.SizedBox(height: 16),
          ],

          if (d.scoreEnps != null) ...[
            _metricBox(
              label: enpsLabel,
              value: d.scoreEnps!.toString(),
              suffix: '/ 10',
              regular: regular,
              bold: bold,
            ),
          ],

          pw.Spacer(),
          _footer(d.locale, regular),
        ],
      ),
    );
  }

  // =========================================================================
  // Helpers
  // =========================================================================

  static pw.Widget _pageHeader(String title, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 4, color: _coral),
        pw.SizedBox(height: 12),
        pw.Text(
          title,
          style: pw.TextStyle(font: bold, fontSize: 20, color: _navy),
        ),
      ],
    );
  }

  static pw.Widget _layerRow(String label, double score,
      String? narrative, pw.Font regular, pw.Font bold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lightGrey),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style:
                      pw.TextStyle(font: bold, fontSize: 13, color: _navy)),
              pw.Text(
                score.toStringAsFixed(1),
                style: pw.TextStyle(font: bold, fontSize: 13, color: _coral),
              ),
            ],
          ),
          if (narrative != null && narrative.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              narrative,
              style:
                  pw.TextStyle(font: regular, fontSize: 11, color: _muted),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _metricBox({
    required String label,
    required String value,
    required String suffix,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _navyLight,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: regular, fontSize: 11, color: _muted)),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(value,
                  style:
                      pw.TextStyle(font: bold, fontSize: 32, color: _navy)),
              pw.SizedBox(width: 4),
              pw.Text(suffix,
                  style: pw.TextStyle(
                      font: regular, fontSize: 14, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(String locale, pw.Font regular) {
    final isVi = locale == 'vi';
    final text = isVi
        ? 'Cloud & Coral  |  Nền tảng Work Reflection  |  www.cloudandcoral.com'
        : 'Cloud & Coral  |  Work Reflection Platform  |  www.cloudandcoral.com';
    return pw.Column(
      children: [
        pw.Divider(color: _lightGrey, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Text(
          text,
          style: pw.TextStyle(
              font: regular, fontSize: 8, color: _muted),
          textAlign: pw.TextAlign.center,
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

  static String _scoreLevelLabel(ScoreLevel level, bool isVi) {
    return switch (level) {
      ScoreLevel.high => isVi ? 'Xuất sắc' : 'Excellent',
      ScoreLevel.good => isVi ? 'Tốt' : 'Good',
      ScoreLevel.warning => isVi ? 'Cần chú ý' : 'Needs Attention',
      ScoreLevel.critical =>
        isVi ? 'Cần cải thiện' : 'Needs Improvement',
    };
  }

  static PdfColor _scoreLevelColor(ScoreLevel level) {
    return switch (level) {
      ScoreLevel.high => const PdfColor.fromInt(0xFF00897B),
      ScoreLevel.good => _navy,
      ScoreLevel.warning => const PdfColor.fromInt(0xFFF57C00),
      ScoreLevel.critical => const PdfColor.fromInt(0xFFD32F2F),
    };
  }

  // Brand colours
  static const _navy = PdfColor.fromInt(0xFF2C335D);
  static const _coral = PdfColor.fromInt(0xFFFF6859);
  static const _navyLight = PdfColor.fromInt(0xFFF0F2FC);
  static const _lightGrey = PdfColor.fromInt(0xFFE0E0E0);
  static const _muted = PdfColor.fromInt(0xFF757575);
  static const _textDark = PdfColor.fromInt(0xFF212121);
}
