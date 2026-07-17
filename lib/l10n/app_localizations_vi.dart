// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'WorkReflection';

  @override
  String get onb1Tag => 'Reflection';

  @override
  String get onb1Title => 'Hành trình bắt đầu\ntừ một câu hỏi nhỏ.';

  @override
  String get onb1Body =>
      'Mỗi ngày một khoảnh khắc dừng lại.\nĐể nhìn rõ hơn — không phán xét.';

  @override
  String get onb1Cta => 'Tiếp tục';

  @override
  String get onb2Tag => 'Understand';

  @override
  String get onb2Title => 'Điều gì đang khiến\nbạn trăn trở nhất?';

  @override
  String get onb2Body =>
      'Hãy gọi tên nó.\nSự rõ ràng là bước đầu tiên\nđể thay đổi.';

  @override
  String get onb2Opt1 => 'Mệt nhưng không biết tại sao';

  @override
  String get onb2Opt2 => 'Cố gắng nhưng không thấy tiến';

  @override
  String get onb2Opt3 => 'Muốn thay đổi, chưa biết bắt đầu từ đâu';

  @override
  String get onb2Opt4 => 'Đang khá ổn, muốn hiểu mình hơn';

  @override
  String get onb2Cta => 'Bắt đầu ngay';

  @override
  String get onb3Tag => 'Grow';

  @override
  String get onb3Title => 'Đồng hành cùng\nsự nghiệp của bạn.';

  @override
  String get onb3Body =>
      'WorkReflection ghi nhớ hành trình,\ntích lũy insight thành\ncareer intelligence của riêng bạn.';

  @override
  String get onb3Promise1Title => '5–15 phút mỗi ngày';

  @override
  String get onb3Promise1Sub => 'Đủ để tạo ra sự khác biệt';

  @override
  String get onb3Promise2Title => 'Riêng tư hoàn toàn';

  @override
  String get onb3Promise2Sub => 'Chỉ bạn mới thấy hành trình của mình';

  @override
  String get onb3Promise3Title => 'Không phán xét';

  @override
  String get onb3Promise3Sub => 'Chỉ lắng nghe và phản chiếu';

  @override
  String get onb3Cta => 'Vào WorkReflection';

  @override
  String get authLoginTitle => 'Chào mừng trở lại';

  @override
  String get authRegisterTitle => 'Tạo tài khoản';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Mật khẩu';

  @override
  String get authNameLabel => 'Tên của bạn';

  @override
  String get authLoginBtn => 'Đăng nhập';

  @override
  String get authRegisterBtn => 'Đăng ký';

  @override
  String get authSwitchToRegister => 'Chưa có tài khoản? Đăng ký';

  @override
  String get authSwitchToLogin => 'Đã có tài khoản? Đăng nhập';

  @override
  String get authOrDivider => 'hoặc';

  @override
  String get authGoogleBtn => 'Tiếp tục với Google';

  @override
  String homeGreeting(String name) {
    return 'Chào $name';
  }

  @override
  String get homeCheckinQuestion => 'Bạn đang trải qua điều gì?';

  @override
  String get homeMoodStressed => 'Tôi đang căng thẳng';

  @override
  String get homeMoodTired => 'Tôi mệt mỏi cần nghỉ ngơi';

  @override
  String get homeMoodOkay => 'Tôi khá ổn';

  @override
  String get homeMoodHappy => 'Tôi đang vui';

  @override
  String get homeEyebrowSystem => 'Hệ thống nhận ra';

  @override
  String get homeEyebrowSuggestion => 'Gợi ý khi mệt mỏi';

  @override
  String get homeEyebrowInsight => 'Insight gần nhất';

  @override
  String get homeLinkLearnMore => 'Tìm hiểu thêm';

  @override
  String get homeSuggestionTitle => 'Khi bạn muốn nói nhưng chọn im lặng';

  @override
  String get homeSuggestionMeta => 'VOICE · 5 phút đọc';

  @override
  String get homeSuggestionProgress => '3/8 phút';

  @override
  String get homeSuggestionStatus => 'Đang đọc';

  @override
  String homeInsightSavedDate(String date) {
    return 'Lưu ngày $date';
  }

  @override
  String get understandGreeting => 'Career Snapshot';

  @override
  String get understandTitle => 'Hiểu mình';

  @override
  String get understandEyebrowNeed => 'Điều bạn đang tìm kiếm';

  @override
  String get understandEyebrowSituations => 'Tình huống lặp lại';

  @override
  String get understandEyebrowSca => 'Trải nghiệm hiện tại (SCA)';

  @override
  String get understandEyebrowHealth => 'Career Health Check';

  @override
  String get understandScaRole => 'Minh bạch vai trò';

  @override
  String get understandScaVoice => 'An toàn khi lên tiếng';

  @override
  String get understandScaMeaning => 'Định hướng ý nghĩa';

  @override
  String get understandStatusStable => 'Ổn định';

  @override
  String get understandStatusImproving => 'Đang cải thiện';

  @override
  String get understandStatusUnrated => 'Chưa đánh giá';

  @override
  String understandHealthReady(int n) {
    return 'Bạn đã có đủ $n reflection.';
  }

  @override
  String get understandHealthPrompt => 'Sẵn sàng xem bức tranh tổng thể chưa?';

  @override
  String get understandHealthCta => 'Bắt đầu kiểm tra';

  @override
  String understandSituationCount(int n) {
    return '$n lần';
  }

  @override
  String get developGreeting => 'Development Map';

  @override
  String get developTitle => 'Phát triển';

  @override
  String get developEyebrowFocus => 'Trọng tâm hiện tại';

  @override
  String get developEyebrowPractices => 'Practices hôm nay';

  @override
  String get developEyebrowOpportunity => 'Cơ hội phát triển';

  @override
  String developStage(int x, int y) {
    return 'Giai đoạn $x / $y';
  }

  @override
  String get developStatusDone => 'Hoàn thành';

  @override
  String get developStatusDoing => 'Đang thực hiện';

  @override
  String get developStatusTodo => 'Chưa bắt đầu';

  @override
  String get developWorkshopTag => 'Workshop';

  @override
  String get developWorkshopLink => 'Tại sao bây giờ?';

  @override
  String get journeyGreeting => 'Career Memory';

  @override
  String get journeyTitle => 'Hành trình';

  @override
  String get journeyEyebrowStory => 'Câu chuyện của bạn';

  @override
  String journeyEyebrowMonth(int m) {
    return 'Tháng $m';
  }

  @override
  String journeyCaption(int m, int yyyy) {
    return 'Career Companion · Tháng $m, $yyyy';
  }

  @override
  String get journeyTypeMilestone => 'MILESTONE';

  @override
  String get journeyTypeStory => 'STORY';

  @override
  String get journeyTypeTheme => 'THEME';

  @override
  String get profileGreeting => 'Tài khoản';

  @override
  String get profileBadgePremium => 'PREMIUM MEMBER';

  @override
  String get profileBadgeMember => 'Thành viên';

  @override
  String get profileStatStreak => 'Ngày streak';

  @override
  String get profileStatInsights => 'Insight lưu';

  @override
  String get profileStatMilestones => 'Milestone';

  @override
  String get profileEyebrowSettings => 'Cài đặt';

  @override
  String get profileSettingReminder => 'Nhắc nhở hằng ngày';

  @override
  String get profileSettingLanguage => 'Ngôn ngữ';

  @override
  String get profileSettingExport => 'Xuất dữ liệu';

  @override
  String get profileSettingLogout => 'Đăng xuất';

  @override
  String get profileLanguageValue => 'Tiếng Việt';

  @override
  String get understandStatusNeedsAttention => 'Cần chú ý';

  @override
  String get understandNeedSuffix => '· Nhu cầu chủ đạo';

  @override
  String get understandNoSituations => 'Chưa có tình huống nào được ghi nhận.';

  @override
  String get homeInsightEmpty =>
      'Chưa có insight nào. Hãy bắt đầu hành trình của bạn!';

  @override
  String get homeErrorLoadData => 'Không thể tải dữ liệu.';

  @override
  String get homeRetry => 'Thử lại';

  @override
  String homeSystemNoticeQuote(int n, String label) {
    return '\"Đây là lần thứ $n bạn gặp tình huống $label.\"';
  }

  @override
  String get developNoTheme =>
      'Chưa có trọng tâm phát triển nào. Hãy bắt đầu hành trình của bạn!';

  @override
  String get developNoPractices => 'Không có practice nào hôm nay.';

  @override
  String get developErrorLoadData => 'Không thể tải dữ liệu.';

  @override
  String get authValidatorName => 'Vui lòng nhập tên';

  @override
  String get authValidatorEmail => 'Vui lòng nhập email';

  @override
  String get authValidatorPassword => 'Vui lòng nhập mật khẩu';

  @override
  String get languageDialogTitle => 'Ngôn ngữ';

  @override
  String get languageOptionVietnamese => 'Tiếng Việt';

  @override
  String get languageOptionEnglish => 'English';

  @override
  String get tabToday => 'Hôm nay';

  @override
  String get tabUnderstand => 'Hiểu mình';

  @override
  String get tabDevelop => 'Phát triển';

  @override
  String get tabJourney => 'Hành trình';

  @override
  String get tabProfile => 'Tôi';
}
