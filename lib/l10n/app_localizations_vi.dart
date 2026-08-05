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
  String get onb1Tag => 'Reflect';

  @override
  String get onb1Title => 'Hành trình bắt đầu\ntừ một câu hỏi nhỏ.';

  @override
  String get onb1Body =>
      'Mỗi ngày một khoảnh khắc dừng lại.\nĐể nhìn rõ hơn, không phán xét.';

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
  String get authLoginSubtitle => 'Đăng nhập để tiếp tục hành trình của bạn';

  @override
  String get authRegisterSubtitle =>
      'Vài bước ngắn để bắt đầu cùng WorkReflection';

  @override
  String get authPasswordShow => 'Hiện mật khẩu';

  @override
  String get authPasswordHide => 'Ẩn mật khẩu';

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
  String get understandEyebrowSca => 'Trải nghiệm hiện tại';

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
  String get developEyebrowOpportunity => 'Mở rộng offline';

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
  String get profileStatReflectDays => 'ngày Reflect';

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
  String get profileSettingExport => 'Xuất dữ liệu của tôi';

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
  String get homeCtaSurveyEyebrow => 'Phản chiếu công việc';

  @override
  String get homeCtaSurveyTitle => 'Làm bài phản chiếu';

  @override
  String get homeCtaSurveySubtitle =>
      'Nhìn lại trải nghiệm công việc của bạn để hiểu rõ hơn.';

  @override
  String get homeCtaSurveyButton => 'Bắt đầu ngay';

  @override
  String get homeStartReflection => 'Bắt đầu phản chiếu';

  @override
  String get homeCtaReportTitle => 'Xem báo cáo mới nhất';

  @override
  String get homeCtaReportSubtitle =>
      'Bạn đã hoàn thành bài phản chiếu. Xem kết quả của mình.';

  @override
  String get homeCtaReportButton => 'Xem báo cáo';

  @override
  String get homeCtaRetakeSurvey => 'Làm lại bài phản chiếu';

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
  String get authValidatorEmailFormat => 'Email không hợp lệ';

  @override
  String get authValidatorPassword => 'Vui lòng nhập mật khẩu';

  @override
  String get authValidatorPasswordMinLength =>
      'Mật khẩu phải có ít nhất 6 ký tự';

  @override
  String get authErrorDuplicateEmail =>
      'Email này đã được đăng ký. Vui lòng đăng nhập.';

  @override
  String get authErrorInvalidCredentials => 'Email hoặc mật khẩu không đúng.';

  @override
  String get authErrorGeneric => 'Đã xảy ra lỗi. Vui lòng thử lại.';

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

  @override
  String get surveyIntroEyebrow => 'Career Health Check';

  @override
  String get surveyIntroBadgeFree => 'FREE';

  @override
  String get surveyIntroBadgePremium => 'PREMIUM';

  @override
  String get surveyIntroTitle => 'Kiểm tra sức khỏe nghề nghiệp';

  @override
  String get surveyIntroBody =>
      'Trả lời thành thật để nhận báo cáo cá nhân chính xác nhất.';

  @override
  String get surveyIntroFieldPosition => 'Chức danh';

  @override
  String get surveyIntroFieldExperience => 'Thâm niên';

  @override
  String get surveyIntroFieldCompanyTenure => 'Thời gian tại công ty';

  @override
  String get surveyIntroFieldCompanySize => 'Quy mô công ty';

  @override
  String get surveyIntroFieldDepartment => 'Phòng ban';

  @override
  String get surveyIntroCta => 'Bắt đầu khảo sát';

  @override
  String get surveyLayerStructure => 'Cấu trúc';

  @override
  String get surveyLayerCulture => 'Văn hoá';

  @override
  String get surveyLayerActivity => 'Hoạt động';

  @override
  String get surveyLayerEsi => 'Sự hài lòng nhân viên';

  @override
  String get surveyLayerEnps => 'Gắn kết nhân viên';

  @override
  String surveyProgress(int current, int total) {
    return '$current/$total';
  }

  @override
  String get surveyCompleteCta => 'Hoàn thành';

  @override
  String get surveyProcessingTitle => 'Đang tạo báo cáo của bạn…';

  @override
  String get surveyProcessingRetry => 'Thử lại';

  @override
  String get surveyProcessingError => 'Có lỗi xảy ra. Vui lòng thử lại.';

  @override
  String get reportTitle => 'Báo cáo của bạn';

  @override
  String get reportScoreLevelHigh => 'Xuất sắc';

  @override
  String get reportScoreLevelGood => 'Tốt';

  @override
  String get reportScoreLevelWarning => 'Cần chú ý';

  @override
  String get reportScoreLevelCritical => 'Cần cải thiện';

  @override
  String get reportLayerStructure => 'Cấu trúc tổ chức';

  @override
  String get reportLayerCulture => 'Văn hoá làm việc';

  @override
  String get reportLayerActivity => 'Hoạt động hàng ngày';

  @override
  String get reportBottleneckTitle => 'Điểm cần cải thiện nhất';

  @override
  String get reportEsiTitle => 'Chỉ số hài lòng nhân viên (ESI)';

  @override
  String get reportEnpsTitle => 'Mức độ gắn kết (eNPS)';

  @override
  String get reportEnpsPromoter => 'Người ủng hộ';

  @override
  String get reportEnpsPassive => 'Trung lập';

  @override
  String get reportEnpsDetractor => 'Người phản đối';

  @override
  String get reportPremiumUpsell =>
      'Nâng cấp Premium để xem ESI, eNPS và phân tích chuyên sâu hơn.';

  @override
  String get reportActionPlanCta => 'Kế hoạch 30 ngày';

  @override
  String get reportViewLatest => 'Xem báo cáo gần nhất';

  @override
  String get reportViewHistory => 'Xem lịch sử khảo sát';

  @override
  String get reportScaChartTitle => 'Bức tranh S-C-A';

  @override
  String get reportAiPersonalizingLabel => 'Đang cá nhân hóa báo cáo…';

  @override
  String get reportAiModelSectionTitle => 'Mô hình làm việc của bạn';

  @override
  String get reportAiReflectionSectionTitle => 'Phản chiếu cá nhân';

  @override
  String get reportAiRelationshipSectionTitle => 'Mối quan hệ trong công việc';

  @override
  String get videoReportButton => 'Xem video báo cáo';

  @override
  String get videoReportTitle => 'Video báo cáo';

  @override
  String get videoReportGenerating => 'Đang tạo video báo cáo…';

  @override
  String get videoReportError => 'Không tạo được video. Vui lòng thử lại.';

  @override
  String get videoReportRetry => 'Thử lại';

  @override
  String get surveyHistoryTitle => 'Lịch sử khảo sát';

  @override
  String get surveyHistoryScoreLabel => 'Điểm';

  @override
  String get surveyHistoryTypeFree => 'Free';

  @override
  String get surveyHistoryTypePremium => 'Premium';

  @override
  String get surveyHistoryEmptyTitle => 'Chưa có khảo sát nào';

  @override
  String get surveyHistoryEmptyBody =>
      'Hoàn thành khảo sát đầu tiên để xem lịch sử tại đây.';

  @override
  String get surveyHistoryEmptyCta => 'Bắt đầu khảo sát';

  @override
  String get profileSurveyHistory => 'Lịch sử khảo sát';

  @override
  String get actionPlanTitle => 'Kế hoạch 30 ngày';

  @override
  String actionPlanDay(int day) {
    return 'Ngày $day';
  }

  @override
  String get actionPlanReflection => 'Câu hỏi phản chiếu';

  @override
  String get surveyTtsToggle => 'Đọc câu hỏi';

  @override
  String get journeyErrorCard => 'Không thể tải hành trình.';

  @override
  String get wsListTitle => 'Workshop';

  @override
  String get wsEmpty => 'Chưa có workshop nào sắp diễn ra';

  @override
  String get wsFree => 'Miễn phí';

  @override
  String get wsFullBadge => 'Đã đầy';

  @override
  String get wsRegister => 'Đăng ký';

  @override
  String get wsRegistered => 'Đã đăng ký';

  @override
  String get wsAttended => 'Đã tham dự';

  @override
  String get wsCancelled => 'Đã hủy';

  @override
  String get wsCheckin => 'Check-in';

  @override
  String wsCheckedInAt(String time) {
    return 'Đã check-in lúc $time';
  }

  @override
  String get wsResources => 'Tài liệu';

  @override
  String get wsResourcesLocked => 'Tài liệu dành cho người đã đăng ký';

  @override
  String wsParticipants(int current, int max) {
    return '$current/$max người tham gia';
  }

  @override
  String get wsLocation => 'Địa điểm';

  @override
  String get wsPaidDialogTitle => 'Thanh toán trên web';

  @override
  String get wsPaidDialogBody =>
      'Vui lòng hoàn tất thanh toán trên trang web WorkReflection để đăng ký.';

  @override
  String get wsPaidDialogOk => 'Đã hiểu';

  @override
  String get wsRegisterSuccess => 'Đăng ký thành công!';

  @override
  String get wsRegisterError => 'Đăng ký thất bại. Vui lòng thử lại.';

  @override
  String get wsCheckinTitle => 'Check-in workshop';

  @override
  String get wsCheckinScanHint => 'Quét mã QR của workshop';

  @override
  String get wsCheckinManualLabel => 'Hoặc nhập mã check-in';

  @override
  String get wsCheckinSubmit => 'Xác nhận';

  @override
  String get wsCheckinInvalidCode => 'Mã không hợp lệ';

  @override
  String get wsCheckinNotFound => 'Không tìm thấy workshop với mã này';

  @override
  String get wsCheckinNotRegistered => 'Bạn chưa đăng ký workshop này';

  @override
  String get wsCheckinTooEarly =>
      'Chưa đến giờ check-in (mở trước giờ bắt đầu 2 tiếng)';

  @override
  String get wsCheckinClosed => 'Đã hết giờ check-in';

  @override
  String get wsCheckinSuccess => 'Check-in thành công!';

  @override
  String get wsCheckinError => 'Check-in thất bại. Vui lòng thử lại.';

  @override
  String get wsLinkCopied => 'Đã sao chép liên kết';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonConfirm => 'Xác nhận';

  @override
  String get wsConsentTitle => 'Cho phép sử dụng hình ảnh';

  @override
  String get wsConsentBody =>
      'Bạn có đồng ý cho chúng tôi sử dụng hình ảnh có bạn trong workshop cho mục đích truyền thông không?';

  @override
  String get wsConsentAccept => 'Đồng ý';

  @override
  String get wsConsentDecline => 'Không đồng ý';

  @override
  String get wsMyTitle => 'Workshop của tôi';

  @override
  String get wsMyEmpty => 'Bạn chưa đăng ký workshop nào';

  @override
  String get wsSurveyCta => 'Đánh giá workshop';

  @override
  String get wsSurveyTitle => 'Đánh giá workshop';

  @override
  String get wsSurveySubmit => 'Gửi đánh giá';

  @override
  String get wsSurveyThanks => 'Cảm ơn bạn đã đánh giá!';

  @override
  String get wsSurveyDone => 'Đã đánh giá';

  @override
  String get wsSurveyNone => 'Chưa có khảo sát cho workshop này';

  @override
  String get wsSurveyError => 'Gửi đánh giá thất bại. Vui lòng thử lại.';

  @override
  String get wsSurveyViewResults => 'Xem kết quả';

  @override
  String get wsSurveyResultsTitle => 'Kết quả khảo sát';

  @override
  String get wsSurveyResultsNotFound => 'Không tìm thấy kết quả khảo sát.';

  @override
  String get wsSurveyResultsScore => 'Điểm trung bình';

  @override
  String wsSurveyResultsResponses(int count) {
    return '$count câu trả lời';
  }

  @override
  String wsSurveyResultsLayerScore(String layer, String score) {
    return '$layer: $score/5.0';
  }

  @override
  String get wsCancelReg => 'Huỷ đăng ký';

  @override
  String get wsCancelRegTitle => 'Huỷ đăng ký';

  @override
  String get wsCancelRegBody =>
      'Bạn có chắc muốn huỷ đăng ký workshop này không?';

  @override
  String get wsCancelRegSuccess => 'Đã huỷ đăng ký';

  @override
  String get wsCancelRegError => 'Huỷ đăng ký thất bại';

  @override
  String get coachTitle => 'Coaching';

  @override
  String get coachAudienceYoung => 'Người trẻ';

  @override
  String get coachAudienceManager => 'Quản lý';

  @override
  String coachSessionsFmt(int count, int minutes) {
    return '$count buổi × $minutes phút';
  }

  @override
  String get coachClaimFree => 'Nhận gói miễn phí';

  @override
  String get coachClaimConfirmTitle => 'Nhận gói coaching';

  @override
  String coachClaimConfirmBody(String name) {
    return 'Bạn muốn nhận gói \"$name\"?';
  }

  @override
  String get coachClaimSuccess => 'Đã kích hoạt gói coaching!';

  @override
  String get coachClaimError => 'Không thể kích hoạt gói. Vui lòng thử lại.';

  @override
  String get coachOurCoaches => 'Đội ngũ coach';

  @override
  String coachYearsExp(int years) {
    return '$years năm kinh nghiệm';
  }

  @override
  String get coachMyTitle => 'Lịch coaching của tôi';

  @override
  String get coachMyEmpty => 'Bạn chưa có buổi coaching nào';

  @override
  String get coachPending => 'Chờ xếp lịch';

  @override
  String get coachScheduled => 'Đã xếp lịch';

  @override
  String get coachCompleted => 'Hoàn thành';

  @override
  String get coachCancelledStatus => 'Đã hủy';

  @override
  String coachSessionOf(int n, int total) {
    return 'Buổi $n/$total';
  }

  @override
  String get coachMeetingLink => 'Link buổi học';

  @override
  String get coachWebNote => 'Đặt lịch và đánh giá thực hiện trên web';

  @override
  String get coachViewMy => 'Xem lịch của tôi';

  @override
  String get coachSchedButton => 'Đặt lịch';

  @override
  String get coachSchedTitle => 'Chọn lịch coaching';

  @override
  String get coachSchedChooseDate => 'Chọn ngày';

  @override
  String get coachSchedChooseTime => 'Chọn giờ';

  @override
  String get coachSchedNotes => 'Ghi chú (tuỳ chọn)';

  @override
  String get coachSchedNotesHint => 'Nhập ghi chú hoặc câu hỏi cho coach...';

  @override
  String get coachSchedSelectedDate => 'Ngày đã chọn:';

  @override
  String get coachSchedPickDate => 'Vui lòng chọn ngày trước';

  @override
  String get coachSchedPickTime => 'Vui lòng chọn giờ trước';

  @override
  String get coachSchedConfirmTitle => 'Xác nhận đặt lịch';

  @override
  String coachSchedConfirmBody(String date, String time) {
    return 'Đặt lịch buổi coaching vào ngày $date lúc $time?';
  }

  @override
  String get coachSchedSubmit => 'Xác nhận đặt lịch';

  @override
  String get coachSchedSuccess => 'Đặt lịch thành công!';

  @override
  String get coachSchedError => 'Không thể đặt lịch. Vui lòng thử lại.';

  @override
  String get coachSchedNotFound => 'Không tìm thấy buổi coaching này';

  @override
  String get coachReviewsTitle => 'Đánh giá từ khách hàng';

  @override
  String get profileMyWorkshops => 'Workshop của tôi';

  @override
  String get profileMyCoaching => 'Coaching của tôi';

  @override
  String get developWorkshopSection => 'Mở rộng offline';

  @override
  String get developViewWorkshops => 'Xem tất cả workshop';

  @override
  String get developViewCoaching => 'Khám phá coaching';

  @override
  String get authForgotPassword => 'Quên mật khẩu?';

  @override
  String get authForgotPasswordDialogTitle => 'Quên mật khẩu';

  @override
  String get authForgotPasswordDialogHint =>
      'Nhập email để nhận link đặt lại mật khẩu';

  @override
  String get authForgotPasswordSubmit => 'Gửi link đặt lại';

  @override
  String get authForgotPasswordSuccess =>
      'Kiểm tra email của bạn để đặt lại mật khẩu.';

  @override
  String get authForgotPasswordErrorInvalidEmail => 'Email không hợp lệ';

  @override
  String get authForgotPasswordError =>
      'Không thể gửi email. Vui lòng thử lại.';

  @override
  String get profileSettingEditProfile => 'Chỉnh sửa hồ sơ';

  @override
  String get profileSettingChangePassword => 'Đổi mật khẩu';

  @override
  String get changePasswordTitle => 'Đổi mật khẩu';

  @override
  String get changePasswordNewLabel => 'Mật khẩu mới';

  @override
  String get changePasswordConfirmLabel => 'Xác nhận mật khẩu mới';

  @override
  String get changePasswordSubmit => 'Cập nhật mật khẩu';

  @override
  String get changePasswordSuccess => 'Mật khẩu đã được cập nhật.';

  @override
  String get changePasswordErrorTooShort => 'Mật khẩu phải có ít nhất 6 ký tự';

  @override
  String get changePasswordErrorMismatch => 'Mật khẩu xác nhận không khớp';

  @override
  String get changePasswordErrorGeneric =>
      'Không thể đổi mật khẩu. Vui lòng thử lại.';

  @override
  String get changePasswordErrorSessionExpired =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get profileEditTitle => 'Chỉnh sửa hồ sơ';

  @override
  String get profileEditEyebrow => 'Thông tin cá nhân';

  @override
  String get profileEditFieldDisplayName => 'Tên hiển thị';

  @override
  String get profileEditFieldFullName => 'Họ và tên';

  @override
  String get profileEditFieldPhone => 'Số điện thoại';

  @override
  String get profileEditFieldCompanyName => 'Tên công ty';

  @override
  String get profileEditFieldPosition => 'Chức danh';

  @override
  String get profileEditFieldCompanySize => 'Quy mô công ty';

  @override
  String get profileEditFieldExperience => 'Thâm niên làm việc';

  @override
  String get profileEditFieldTenure => 'Thời gian tại công ty';

  @override
  String get profileEditFieldDepartment => 'Phòng ban';

  @override
  String get profileEditSave => 'Lưu thay đổi';

  @override
  String get profileEditSaveSuccess => 'Đã cập nhật hồ sơ.';

  @override
  String get profileEditSaveError => 'Không thể lưu. Vui lòng thử lại.';

  @override
  String get profileSetupTitle => 'Hoàn thiện hồ sơ';

  @override
  String get profileSetupComplete => 'Hoàn tất';

  @override
  String get profileSetupSkip => 'Bỏ qua';

  @override
  String get profileEditAvatarNote =>
      'Thay ảnh đại diện trên web tại workreflection.app';

  @override
  String get profileEditPositionStaff => 'Nhân viên';

  @override
  String get profileEditPositionTeamLead => 'Trưởng nhóm';

  @override
  String get profileEditPositionManager => 'Quản lý';

  @override
  String get profileEditPositionDirector => 'Giám đốc';

  @override
  String get profileEditPositionCLevel => 'C-Level';

  @override
  String get profileEditPositionIntern => 'Thực tập sinh';

  @override
  String get profileEditPositionFreelancer => 'Freelancer';

  @override
  String get profileEditPositionOther => 'Khác';

  @override
  String get profileEditCompanySize1to10 => '1–10 người';

  @override
  String get profileEditCompanySize11to50 => '11–50 người';

  @override
  String get profileEditCompanySize51to200 => '51–200 người';

  @override
  String get profileEditCompanySize201to500 => '201–500 người';

  @override
  String get profileEditCompanySize501to1000 => '501–1000 người';

  @override
  String get profileEditCompanySize1000Plus => 'Trên 1000 người';

  @override
  String get profileEditExpLess1 => 'Dưới 1 năm';

  @override
  String get profileEditExp1to3 => '1–3 năm';

  @override
  String get profileEditExp3to5 => '3–5 năm';

  @override
  String get profileEditExp5to10 => '5–10 năm';

  @override
  String get profileEditExp10Plus => 'Trên 10 năm';

  @override
  String get profileEditTenureLess6m => 'Dưới 6 tháng';

  @override
  String get profileEditTenure6mto1y => '6 tháng–1 năm';

  @override
  String get profileEditTenure1to2 => '1–2 năm';

  @override
  String get profileEditTenure2to5 => '2–5 năm';

  @override
  String get profileEditTenure5Plus => 'Trên 5 năm';

  @override
  String get profileEditDeptMarketing => 'Marketing';

  @override
  String get profileEditDeptAccounting => 'Kế toán';

  @override
  String get profileEditDeptSales => 'Kinh doanh';

  @override
  String get profileEditDeptPurchasing => 'Mua hàng';

  @override
  String get profileEditDeptHr => 'Nhân sự';

  @override
  String get profileEditDeptIt => 'IT';

  @override
  String get profileEditDeptProduction => 'Sản xuất';

  @override
  String get profileEditDeptAdmin => 'Hành chính';

  @override
  String get profileEditDeptOther => 'Khác';

  @override
  String get profileEditSelectHint => 'Chọn...';

  @override
  String get insightsTitle => 'Tất cả insight';

  @override
  String get insightsEmpty =>
      'Bạn chưa có insight nào. Hãy bắt đầu hành trình của bạn!';

  @override
  String insightSavedDate(String date) {
    return 'Lưu ngày $date';
  }

  @override
  String get understandViewAllInsights => 'Xem tất cả insight';

  @override
  String get profileCheckinHistory => '30 ngày gần đây';

  @override
  String get surveyGuideEyebrow => 'Hướng dẫn';

  @override
  String get surveyGuideFreeTitle =>
      'Work Reflection – Phản chiếu trải nghiệm công việc cá nhân';

  @override
  String get surveyGuideFreeIntro =>
      'Chào mừng bạn đến với hành trình nhìn lại trải nghiệm công việc cá nhân.';

  @override
  String get surveyGuideFreeDescription =>
      'Work Reflection là công cụ giúp người đi làm nhìn lại môi trường và trải nghiệm công việc của mình một cách có hệ thống.';

  @override
  String get surveyGuideFreeDetails =>
      'Phiên bản miễn phí gồm 15 câu hỏi cho phép bạn thực hiện khảo sát nhanh. Sau khi hoàn thành, bạn sẽ nhận được một báo cáo phản chiếu tổng quan, giúp bạn:';

  @override
  String get surveyGuideFreeBenefit1 => 'Nhìn thấy bức tranh chung.';

  @override
  String get surveyGuideFreeBenefit2 => 'Nhận diện những điểm cần điều chỉnh.';

  @override
  String get surveyGuideFreeBenefit3 =>
      'Có cơ sở rõ ràng hơn để suy nghĩ về bước đi tiếp theo trong công việc.';

  @override
  String get surveyGuideFreeNote =>
      'Work Reflection không nhằm đánh giá con người, mà giúp bạn hiểu cách hệ thống công việc đang vận hành xung quanh mình.';

  @override
  String get surveyGuideFreeClosing =>
      'Phiên bản miễn phí phù hợp khi bạn muốn bắt đầu nhìn lại công việc một cách nhẹ nhàng, trước khi đi sâu hơn với các phân tích nâng cao.';

  @override
  String get surveyGuidePremiumTitle =>
      'Work Reflection Premium – Phản chiếu sâu để định hướng rõ';

  @override
  String get surveyGuidePremiumIntro =>
      'Work Reflection Premium là phiên bản phân tích nâng cao dành cho người đi làm muốn nhìn lại công việc một cách toàn diện và có chiều sâu hơn.';

  @override
  String get surveyGuidePremiumDetails => 'Phiên bản Premium giúp bạn:';

  @override
  String get surveyGuidePremiumBenefit1 =>
      'Phân tích chi tiết mức độ rõ ràng trong vai trò, kỳ vọng và cơ chế phối hợp';

  @override
  String get surveyGuidePremiumBenefit2 =>
      'Nhận diện chất lượng đối thoại, phản hồi và an toàn tâm lý trong môi trường làm việc';

  @override
  String get surveyGuidePremiumBenefit3 =>
      'Đánh giá mức độ phát triển, động lực và sự phù hợp giữa cá nhân – công việc – tổ chức';

  @override
  String get surveyGuidePremiumBenefit4 =>
      'Xác định các điểm nghẽn cốt lõi thay vì chỉ thấy triệu chứng bề mặt';

  @override
  String get surveyGuidePremiumClosing =>
      'Work Reflection Premium giúp bạn có một khung nhìn rõ ràng hơn để tự đưa ra quyết định.';

  @override
  String get surveyGuidePremiumReportDesc =>
      'Sau khi hoàn thành, bạn nhận được báo cáo phản chiếu chuyên sâu với:';

  @override
  String get surveyGuidePremiumReport1 => 'Điểm số theo từng nhóm yếu tố';

  @override
  String get surveyGuidePremiumReport2 => 'Diễn giải ý nghĩa từng khu vực';

  @override
  String get surveyGuidePremiumReport3 =>
      'Gợi ý định hướng suy nghĩ và hành động cho giai đoạn tiếp theo';

  @override
  String get surveyGuideCta => 'Bắt đầu';

  @override
  String get layerDetailViewDetail => 'Xem chi tiết';

  @override
  String get layerDetailOverallScore => 'Điểm tổng thể';

  @override
  String get layerDetailNoData => 'Chưa có dữ liệu';

  @override
  String get layerDetailNoDataBody =>
      'Hoàn thành khảo sát để xem phân tích chi tiết.';

  @override
  String layerDetailResponses(int count) {
    return '$count phản hồi';
  }

  @override
  String get layerDetailScoreGood => 'Tốt';

  @override
  String get layerDetailScoreWarning => 'Cần cải thiện';

  @override
  String get layerDetailScoreCritical => 'Cần hành động';

  @override
  String get esiAnalysisTitle => 'Bức tranh hài lòng & trải nghiệm';

  @override
  String get esiAnalysisEsiScore => 'Điểm ESI';

  @override
  String get esiAnalysisEnpsScore => 'Điểm eNPS';

  @override
  String get esiAnalysisPillarsTitle => 'Phân tích ESI theo trụ cột';

  @override
  String get esiAnalysisNoData => 'Chưa có dữ liệu ESI chi tiết';

  @override
  String get esiAnalysisNoDataBody =>
      'Hoàn thành khảo sát Premium để xem phân tích ESI.';

  @override
  String get esiAnalysisEnpsPromoter => 'Ủng hộ viên';

  @override
  String get esiAnalysisEnpsPassive => 'Trung lập';

  @override
  String get esiAnalysisEnpsDetractor => 'Không ủng hộ';

  @override
  String get esiPillarCompensation => 'Đãi ngộ & phúc lợi';

  @override
  String get esiPillarGrowth => 'Cơ hội phát triển';

  @override
  String get esiPillarFairness => 'Minh bạch & Công bằng';

  @override
  String get esiPillarSupport => 'Hỗ trợ & ghi nhận từ cấp trên';

  @override
  String get esiPillarColleagues => 'Đồng nghiệp & môi trường làm việc';

  @override
  String get subCompRoleExpect => 'Kỳ vọng vai trò';

  @override
  String get subCompCollabRules => 'Quy tắc phối hợp';

  @override
  String get subCompCommChannels => 'Kênh giao tiếp';

  @override
  String get subCompTrust => 'Sự tin tưởng';

  @override
  String get subCompPsychSafety => 'An toàn tâm lý';

  @override
  String get subCompFeedbackDialogue => 'Đối thoại & Phản hồi';

  @override
  String get subCompGoalAlignment => 'Liên kết mục tiêu';

  @override
  String get subCompExecutionRhythm => 'Nhịp thực thi';

  @override
  String get subCompRetrospective => 'Thói quen nhìn lại';

  @override
  String get subCompContinuousImprove => 'Cải tiến liên tục';

  @override
  String get subCompCompensationIncome => 'Thu nhập';

  @override
  String get subCompCompensationBenefits => 'Phúc lợi';

  @override
  String get subCompGrowthCareer => 'Phát triển sự nghiệp';

  @override
  String get subCompFairnessEvaluation => 'Công bằng đánh giá';

  @override
  String get subCompSupportManagement => 'Hỗ trợ quản lý';

  @override
  String get subCompSupportFeedback => 'Hỗ trợ phản hồi';

  @override
  String get subCompSupportCollaboration => 'Hỗ trợ hợp tác';

  @override
  String get subCompSupportLeadership => 'Hỗ trợ lãnh đạo';

  @override
  String get roadmapTitle => 'Lộ trình hành động';

  @override
  String get roadmapSubtitle =>
      'Theo dõi và thực hiện kế hoạch phát triển của bạn';

  @override
  String get roadmapSelectReport => 'Chọn báo cáo...';

  @override
  String get roadmapNoPremiumReports => 'Bạn chưa có báo cáo Premium';

  @override
  String get roadmapNoPremiumReportsBody =>
      'Hoàn thành khảo sát Premium để mở lộ trình hành động cá nhân.';

  @override
  String get roadmapStartSurvey => 'Bắt đầu khảo sát';

  @override
  String get roadmapNoActionsForReport =>
      'Chưa có dữ liệu hành động cho báo cáo này.';

  @override
  String get roadmapProgressLabel => 'Tiến độ tổng thể';

  @override
  String get roadmapDayHeader7 => 'Nhập môn';

  @override
  String get roadmapDayHeader14 => 'Thử nghiệm';

  @override
  String get roadmapDayHeader30 => 'Chuyên hoá';

  @override
  String get roadmapLayerStructure => 'Cấu trúc';

  @override
  String get roadmapLayerCulture => 'Văn hoá';

  @override
  String get roadmapLayerActivity => 'Hoạt động';

  @override
  String get roadmapAddCustomTask => 'Thêm hành động';

  @override
  String get roadmapAddTaskTitle => 'Thêm hành động tự chọn';

  @override
  String get roadmapEditTaskTitle => 'Chỉnh sửa hành động';

  @override
  String get roadmapTaskTitleLabel => 'Tiêu đề';

  @override
  String get roadmapTaskDescLabel => 'Mô tả (tuỳ chọn)';

  @override
  String get roadmapTaskDueDateLabel => 'Ngày hoàn thành (tuỳ chọn)';

  @override
  String get roadmapTaskTitleHint => 'Ví dụ: 1:1 với quản lý';

  @override
  String get roadmapTaskDescHint => 'Ghi chú thêm...';

  @override
  String get roadmapTaskAdd => 'Thêm';

  @override
  String get roadmapTaskSave => 'Lưu';

  @override
  String get roadmapTaskAdded => 'Đã thêm hành động';

  @override
  String get roadmapTaskUpdated => 'Đã cập nhật hành động';

  @override
  String get roadmapTaskDeleted => 'Đã xoá hành động';

  @override
  String get roadmapErrorToggle => 'Không thể cập nhật. Vui lòng thử lại.';

  @override
  String get roadmapErrorAdd => 'Không thể thêm hành động. Vui lòng thử lại.';

  @override
  String get roadmapErrorEdit => 'Không thể chỉnh sửa. Vui lòng thử lại.';

  @override
  String get roadmapErrorDelete => 'Không thể xoá. Vui lòng thử lại.';

  @override
  String get roadmapCoachSectionTitle => 'Mời coach đồng hành';

  @override
  String get roadmapInviteCoach => 'Mời coach';

  @override
  String get roadmapChooseCoach => 'Chọn coach để mời';

  @override
  String get roadmapNoCoachesAvailable => 'Không có coach khả dụng';

  @override
  String get roadmapCoachPending => 'Đang chờ';

  @override
  String get roadmapCoachAccepted => 'Đã chấp nhận';

  @override
  String get roadmapCoachRevoked => 'Thu hồi';

  @override
  String get roadmapCoachInvited => 'Đã gửi lời mời';

  @override
  String get roadmapErrorInviteCoach => 'Không thể gửi lời mời.';

  @override
  String get roadmapNoCoachs => 'Bạn chưa mời coach nào.';

  @override
  String get roadmapActivityLog => 'Báo cáo hoạt động';

  @override
  String get roadmapActivityEmpty => 'Chưa có hoạt động nào.';

  @override
  String get roadmapActivityContent => 'Nội dung';

  @override
  String get roadmapActivityLayer => 'Tầng';

  @override
  String get roadmapActivityDate => 'Ngày';

  @override
  String get roadmapRenameReport => 'Đặt tên báo cáo';

  @override
  String get roadmapNicknameLabel => 'Tên báo cáo';

  @override
  String get roadmapNicknameHint => 'Ví dụ: Đánh giá tháng 7';

  @override
  String get roadmapNicknameSaved => 'Đã cập nhật tên.';

  @override
  String get roadmapNicknameError => 'Không thể lưu tên.';

  @override
  String get roadmapScoreHigh => 'Tốt – duy trì';

  @override
  String get roadmapScoreGood => 'Khá – cải thiện nhỏ';

  @override
  String get roadmapScoreWarning => 'Cần cải thiện';

  @override
  String get roadmapScoreCritical => 'Cần hành động ngay';

  @override
  String get roadmapEntryLink => 'Lộ trình phát triển';

  @override
  String get roadmapProfileLink => 'Lộ trình hành động';

  @override
  String get profileVouchers => 'Voucher của tôi';

  @override
  String get profileInvitations => 'Lời mời tổ chức';

  @override
  String get avatarUploadSuccess => 'Đã cập nhật ảnh đại diện.';

  @override
  String get avatarUploadError => 'Không thể tải ảnh lên. Vui lòng thử lại.';

  @override
  String get avatarPickerTitle => 'Chọn ảnh đại diện';

  @override
  String get avatarChangeBtn => 'Đổi ảnh';

  @override
  String get avatarUploading => 'Đang tải lên…';

  @override
  String get vouchersTitle => 'Voucher của tôi';

  @override
  String get vouchersSubtitle =>
      'Sao chép mã voucher và dùng khi thanh toán trên web';

  @override
  String get vouchersEmpty => 'Bạn chưa có voucher nào';

  @override
  String get vouchersEmptyBody => 'Hiện chưa có voucher nào dành cho bạn.';

  @override
  String get voucherWebNote => 'Áp dụng mã khi thanh toán trên web';

  @override
  String get voucherCopied => 'Đã sao chép';

  @override
  String get voucherCopy => 'Sao chép';

  @override
  String voucherCopiedToast(String code) {
    return 'Đã sao chép mã $code';
  }

  @override
  String get voucherExpired => 'Hết hạn';

  @override
  String get voucherFull => 'Hết lượt';

  @override
  String get voucherAvailable => 'Khả dụng';

  @override
  String voucherExpiry(String date) {
    return 'HSD: $date';
  }

  @override
  String voucherUsesLeft(int left, int max) {
    return 'Còn $left/$max lượt';
  }

  @override
  String voucherDiscountPercent(int percent) {
    return 'Giảm $percent%';
  }

  @override
  String voucherDiscountAmount(String amount) {
    return 'Giảm $amountđ';
  }

  @override
  String get voucherAppliesTo => 'Áp dụng cho';

  @override
  String get voucherProductPremium => 'Premium';

  @override
  String get voucherProductWorkshop => 'Workshop';

  @override
  String get voucherProductCoaching => 'Coaching';

  @override
  String get invitationsTitle => 'Lời mời tham gia tổ chức';

  @override
  String get invitationsSubtitle => 'Quản lý các lời mời từ tổ chức';

  @override
  String get invitationsEmpty => 'Bạn chưa nhận được lời mời nào';

  @override
  String get invitationsPending => 'Đang chờ';

  @override
  String get invitationsExpired => 'Hết hạn';

  @override
  String get invitationsProcessed => 'Đã xử lý';

  @override
  String get invitationsAccepted => 'Đã chấp nhận';

  @override
  String get invitationsDeclined => 'Đã từ chối';

  @override
  String get invitationsCancelled => 'Đã huỷ';

  @override
  String get invitationsAcceptBtn => 'Chấp nhận';

  @override
  String get invitationsDeclineBtn => 'Từ chối';

  @override
  String get invitationsAcceptTitle => 'Chấp nhận lời mời';

  @override
  String get invitationsDeclineTitle => 'Từ chối lời mời';

  @override
  String invitationsAcceptBody(String org, String role) {
    return 'Bạn sẽ trở thành thành viên của $org với vai trò $role.';
  }

  @override
  String invitationsDeclineBody(String org) {
    return 'Bạn có chắc muốn từ chối lời mời từ $org?';
  }

  @override
  String invitationsAcceptSuccess(String org) {
    return 'Đã tham gia $org.';
  }

  @override
  String get invitationsAcceptError => 'Không thể chấp nhận lời mời.';

  @override
  String get invitationsDeclineSuccess => 'Đã từ chối lời mời.';

  @override
  String get invitationsDeclineError => 'Không thể từ chối lời mời.';

  @override
  String invitationsExpiredAt(String date) {
    return 'Hết hạn: $date';
  }

  @override
  String invitationsExpiresAt(String date) {
    return 'Hết hạn lúc: $date';
  }

  @override
  String get invitationsNoPending => 'Không có lời mời đang chờ';

  @override
  String get invitationsNoExpired => 'Không có lời mời hết hạn';

  @override
  String get invitationsNoProcessed => 'Chưa có lời mời nào đã xử lý';

  @override
  String get invitationsStatPending => 'Đang chờ';

  @override
  String get invitationsStatAccepted => 'Đã chấp nhận';

  @override
  String get invitationsStatExpired => 'Hết hạn';

  @override
  String get voiceInputTapToSpeak => 'Nhấn để nói câu trả lời';

  @override
  String get voiceInputListening => 'Đang nghe…';

  @override
  String get voiceInputStopListening => 'Dừng nghe';

  @override
  String get voiceInputNoMatch => 'Không nhận diện được, hãy nhấn để thử lại';

  @override
  String get voiceInputUnavailable =>
      'Thiết bị không hỗ trợ nhập bằng giọng nói';

  @override
  String get reportPdfExport => 'Xuất PDF';

  @override
  String get reportPdfGenerating => 'Đang tạo PDF…';

  @override
  String get reportPdfError => 'Không thể tạo PDF. Vui lòng thử lại.';

  @override
  String get reportPdfCover => 'Báo cáo Work Reflection';

  @override
  String get reportPdfTotalScore => 'Điểm tổng';

  @override
  String get reportPdfBottleneck => 'Điểm cần cải thiện nhất';

  @override
  String get reportPdfEsiSection => 'Chỉ số hài lòng nhân viên (ESI)';

  @override
  String get reportPdfEnpsSection => 'Mức độ gắn kết (eNPS)';

  @override
  String get reportPdfFooter =>
      'Cloud & Coral  |  Nền tảng Work Reflection  |  www.cloudandcoral.com';

  @override
  String get reportPdfPreparedFor => 'Báo cáo dành cho';

  @override
  String get reportPdfDateLabel => 'Ngày báo cáo';

  @override
  String get reportPdfFreeTier => 'Báo cáo Miễn phí';

  @override
  String get reportPdfPremiumTier => 'Báo cáo Premium';

  @override
  String get wsCertificateDownload => 'Tải chứng nhận';

  @override
  String get wsCertificateGenerating => 'Đang tạo chứng nhận…';

  @override
  String get wsCertificateError =>
      'Không thể tạo chứng nhận. Vui lòng thử lại.';

  @override
  String get wsCertificateTitleLine1 => 'CERTIFICATE OF ATTENDANCE';

  @override
  String get wsCertificateTitleLine2 => 'Chứng nhận tham dự';

  @override
  String get wsCertificateCertifiesLine =>
      'This is to certify that / Chứng nhận rằng';

  @override
  String get wsCertificateAttendedLine =>
      'has successfully completed the workshop / Đã tham dự thành công';

  @override
  String get wsCertificateFacilitator => 'Facilitator';

  @override
  String get wsCertificateOrg => 'Cloud & Coral';

  @override
  String get wsCertificateFooter =>
      'Cloud & Coral  |  Nền tảng phát triển tổ chức  |  www.cloudandcoral.com';

  @override
  String get wsCertificateIssuedLabel => 'Ngày cấp';
}
