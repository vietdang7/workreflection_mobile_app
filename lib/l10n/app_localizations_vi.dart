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
  String get profileMyWorkshops => 'Workshop của tôi';

  @override
  String get profileMyCoaching => 'Coaching của tôi';

  @override
  String get developWorkshopSection => 'Cơ hội phát triển';

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
  String get notificationsTitle => 'Thông báo';

  @override
  String get notificationsEmpty => 'Chưa có thông báo nào';

  @override
  String get notificationsMarkAllRead => 'Đánh dấu tất cả đã đọc';

  @override
  String get notificationsUnread => 'Chưa đọc';
}
