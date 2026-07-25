// Video Report — deterministic narration script builder.

import 'package:workreflection_mobile/core/models/survey_models.dart';
import 'package:workreflection_mobile/features/video_report/models/video_report_models.dart';

/// Turns report data into an ordered, deterministic list of narration scenes.
///
/// Pure and framework-agnostic (no Flutter imports). Text is Vietnamese when
/// [locale] != 'en', otherwise English.
class NarrationScriptBuilder {
  const NarrationScriptBuilder();

  List<NarrationScene> build({
    required CcReportFull report,
    // Reserved for future narrative-based enrichment; current scenes are
    // score-based text only, so [narratives] is intentionally unused for now.
    required List<CcNarrative> narratives,
    required String userName,
    required String locale,
    required SurveyType surveyType,
  }) {
    final bool en = locale == 'en';
    final scenes = <NarrationScene>[];

    scenes.add(NarrationScene(
      id: VideoSceneId.intro,
      text: _intro(userName, en),
    ));
    scenes.add(NarrationScene(
      id: VideoSceneId.overall,
      text: _overall(report, en),
    ));

    if (surveyType == SurveyType.premium) {
      scenes.add(NarrationScene(
        id: VideoSceneId.structure,
        text: _layer(SurveyLayer.structure, report.scoreStructure, en),
      ));
      scenes.add(NarrationScene(
        id: VideoSceneId.culture,
        text: _layer(SurveyLayer.culture, report.scoreCulture, en),
      ));
      scenes.add(NarrationScene(
        id: VideoSceneId.activity,
        text: _layer(SurveyLayer.activity, report.scoreActivity, en),
      ));

      final esi = report.scoreEsi;
      if (esi != null && esi > 0) {
        scenes.add(NarrationScene(id: VideoSceneId.esi, text: _esi(esi, en)));
      }
      final enps = report.scoreEnps;
      if (enps != null) {
        scenes.add(NarrationScene(id: VideoSceneId.enps, text: _enps(enps, en)));
      }
    }

    scenes.add(NarrationScene(
      id: VideoSceneId.bottleneck,
      text: _bottleneck(report.bottleneckLayer, en),
    ));
    scenes.add(NarrationScene(
      id: VideoSceneId.recommendations,
      text: _recommendations(report.bottleneckLayer, en),
    ));
    scenes.add(NarrationScene(
      id: VideoSceneId.closing,
      text: _closing(en),
    ));

    return scenes;
  }

  String _intro(String userName, bool en) {
    final name = userName.trim().isEmpty ? (en ? 'there' : 'bạn') : userName;
    return en
        ? 'Hello $name, this is your work reflection report.'
        : 'Xin chào $name, đây là báo cáo phản chiếu của bạn.';
  }

  String _overall(CcReportFull report, bool en) {
    final total = report.scoreTotal.toStringAsFixed(1);
    final level = _levelName(report.scoreLevel, en);
    return en
        ? 'Your overall score is $total out of 5, at the $level level.'
        : 'Điểm tổng của bạn là $total trên 5, ở mức $level.';
  }

  String _layer(SurveyLayer layer, double score, bool en) {
    final s = score.toStringAsFixed(1);
    final name = _layerName(layer, en);
    return en
        ? 'The $name layer scored $s out of 5.'
        : 'Lớp $name đạt $s trên 5.';
  }

  String _esi(double esi, bool en) {
    final s = esi.toStringAsFixed(1);
    return en
        ? 'Your employee satisfaction index is $s out of 5.'
        : 'Chỉ số hài lòng nhân viên đạt $s trên 5.';
  }

  String _enps(int enps, bool en) {
    return en
        ? 'Your eNPS score is $enps.'
        : 'Chỉ số eNPS của bạn là $enps.';
  }

  String _bottleneck(SurveyLayer layer, bool en) {
    final name = _layerName(layer, en);
    return en
        ? 'Your biggest bottleneck is in the $name layer. This is where you should focus your improvements.'
        : 'Điểm nghẽn lớn nhất nằm ở lớp $name. Đây là nơi nên tập trung cải thiện.';
  }

  String _recommendations(SurveyLayer layer, bool en) {
    final name = _layerName(layer, en);
    return en
        ? 'Three suggested actions will help you improve the $name layer over the next 30 days.'
        : 'Ba hành động gợi ý sẽ giúp bạn cải thiện lớp $name trong 30 ngày tới.';
  }

  String _closing(bool en) {
    return en
        ? 'Thank you for listening. Start your growth journey today.'
        : 'Cảm ơn bạn đã lắng nghe. Hãy bắt đầu hành trình phát triển của mình.';
  }

  String _layerName(SurveyLayer layer, bool en) {
    if (en) {
      return switch (layer) {
        SurveyLayer.structure => 'Structure',
        SurveyLayer.culture => 'Culture',
        SurveyLayer.activity => 'Activity',
        SurveyLayer.esi => 'ESI',
        SurveyLayer.enps => 'eNPS',
      };
    }
    return switch (layer) {
      SurveyLayer.structure => 'Cấu trúc',
      SurveyLayer.culture => 'Văn hoá',
      SurveyLayer.activity => 'Hoạt động',
      SurveyLayer.esi => 'ESI',
      SurveyLayer.enps => 'eNPS',
    };
  }

  String _levelName(ScoreLevel level, bool en) {
    if (en) {
      return switch (level) {
        ScoreLevel.high => 'high',
        ScoreLevel.good => 'good',
        ScoreLevel.warning => 'warning',
        ScoreLevel.critical => 'critical',
      };
    }
    return switch (level) {
      ScoreLevel.high => 'cao',
      ScoreLevel.good => 'tốt',
      ScoreLevel.warning => 'cảnh báo',
      ScoreLevel.critical => 'nghiêm trọng',
    };
  }
}
