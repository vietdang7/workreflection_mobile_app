import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// App name
  ///
  /// In vi, this message translates to:
  /// **'WorkReflection'**
  String get appName;

  /// No description provided for @onb1Tag.
  ///
  /// In vi, this message translates to:
  /// **'Reflection'**
  String get onb1Tag;

  /// No description provided for @onb1Title.
  ///
  /// In vi, this message translates to:
  /// **'Hành trình bắt đầu\ntừ một câu hỏi nhỏ.'**
  String get onb1Title;

  /// No description provided for @onb1Body.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi ngày một khoảnh khắc dừng lại.\nĐể nhìn rõ hơn — không phán xét.'**
  String get onb1Body;

  /// No description provided for @onb1Cta.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get onb1Cta;

  /// No description provided for @onb2Tag.
  ///
  /// In vi, this message translates to:
  /// **'Understand'**
  String get onb2Tag;

  /// No description provided for @onb2Title.
  ///
  /// In vi, this message translates to:
  /// **'Điều gì đang khiến\nbạn trăn trở nhất?'**
  String get onb2Title;

  /// No description provided for @onb2Body.
  ///
  /// In vi, this message translates to:
  /// **'Hãy gọi tên nó.\nSự rõ ràng là bước đầu tiên\nđể thay đổi.'**
  String get onb2Body;

  /// No description provided for @onb2Opt1.
  ///
  /// In vi, this message translates to:
  /// **'Mệt nhưng không biết tại sao'**
  String get onb2Opt1;

  /// No description provided for @onb2Opt2.
  ///
  /// In vi, this message translates to:
  /// **'Cố gắng nhưng không thấy tiến'**
  String get onb2Opt2;

  /// No description provided for @onb2Opt3.
  ///
  /// In vi, this message translates to:
  /// **'Muốn thay đổi, chưa biết bắt đầu từ đâu'**
  String get onb2Opt3;

  /// No description provided for @onb2Opt4.
  ///
  /// In vi, this message translates to:
  /// **'Đang khá ổn, muốn hiểu mình hơn'**
  String get onb2Opt4;

  /// No description provided for @onb2Cta.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu ngay'**
  String get onb2Cta;

  /// No description provided for @onb3Tag.
  ///
  /// In vi, this message translates to:
  /// **'Grow'**
  String get onb3Tag;

  /// No description provided for @onb3Title.
  ///
  /// In vi, this message translates to:
  /// **'Đồng hành cùng\nsự nghiệp của bạn.'**
  String get onb3Title;

  /// No description provided for @onb3Body.
  ///
  /// In vi, this message translates to:
  /// **'WorkReflection ghi nhớ hành trình,\ntích lũy insight thành\ncareer intelligence của riêng bạn.'**
  String get onb3Body;

  /// No description provided for @onb3Promise1Title.
  ///
  /// In vi, this message translates to:
  /// **'5–15 phút mỗi ngày'**
  String get onb3Promise1Title;

  /// No description provided for @onb3Promise1Sub.
  ///
  /// In vi, this message translates to:
  /// **'Đủ để tạo ra sự khác biệt'**
  String get onb3Promise1Sub;

  /// No description provided for @onb3Promise2Title.
  ///
  /// In vi, this message translates to:
  /// **'Riêng tư hoàn toàn'**
  String get onb3Promise2Title;

  /// No description provided for @onb3Promise2Sub.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ bạn mới thấy hành trình của mình'**
  String get onb3Promise2Sub;

  /// No description provided for @onb3Promise3Title.
  ///
  /// In vi, this message translates to:
  /// **'Không phán xét'**
  String get onb3Promise3Title;

  /// No description provided for @onb3Promise3Sub.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ lắng nghe và phản chiếu'**
  String get onb3Promise3Sub;

  /// No description provided for @onb3Cta.
  ///
  /// In vi, this message translates to:
  /// **'Vào WorkReflection'**
  String get onb3Cta;

  /// No description provided for @authLoginTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng trở lại'**
  String get authLoginTitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản'**
  String get authRegisterTitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get authPasswordLabel;

  /// No description provided for @authNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên của bạn'**
  String get authNameLabel;

  /// No description provided for @authLoginBtn.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get authLoginBtn;

  /// No description provided for @authRegisterBtn.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký'**
  String get authRegisterBtn;

  /// No description provided for @authSwitchToRegister.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản? Đăng ký'**
  String get authSwitchToRegister;

  /// No description provided for @authSwitchToLogin.
  ///
  /// In vi, this message translates to:
  /// **'Đã có tài khoản? Đăng nhập'**
  String get authSwitchToLogin;

  /// No description provided for @authOrDivider.
  ///
  /// In vi, this message translates to:
  /// **'hoặc'**
  String get authOrDivider;

  /// No description provided for @authGoogleBtn.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục với Google'**
  String get authGoogleBtn;

  /// No description provided for @homeGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Chào {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeCheckinQuestion.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang trải qua điều gì?'**
  String get homeCheckinQuestion;

  /// No description provided for @homeMoodStressed.
  ///
  /// In vi, this message translates to:
  /// **'Tôi đang căng thẳng'**
  String get homeMoodStressed;

  /// No description provided for @homeMoodTired.
  ///
  /// In vi, this message translates to:
  /// **'Tôi mệt mỏi cần nghỉ ngơi'**
  String get homeMoodTired;

  /// No description provided for @homeMoodOkay.
  ///
  /// In vi, this message translates to:
  /// **'Tôi khá ổn'**
  String get homeMoodOkay;

  /// No description provided for @homeMoodHappy.
  ///
  /// In vi, this message translates to:
  /// **'Tôi đang vui'**
  String get homeMoodHappy;

  /// No description provided for @homeEyebrowSystem.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống nhận ra'**
  String get homeEyebrowSystem;

  /// No description provided for @homeEyebrowSuggestion.
  ///
  /// In vi, this message translates to:
  /// **'Gợi ý khi mệt mỏi'**
  String get homeEyebrowSuggestion;

  /// No description provided for @homeEyebrowInsight.
  ///
  /// In vi, this message translates to:
  /// **'Insight gần nhất'**
  String get homeEyebrowInsight;

  /// No description provided for @homeLinkLearnMore.
  ///
  /// In vi, this message translates to:
  /// **'Tìm hiểu thêm'**
  String get homeLinkLearnMore;

  /// No description provided for @homeSuggestionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khi bạn muốn nói nhưng chọn im lặng'**
  String get homeSuggestionTitle;

  /// No description provided for @homeSuggestionMeta.
  ///
  /// In vi, this message translates to:
  /// **'VOICE · 5 phút đọc'**
  String get homeSuggestionMeta;

  /// No description provided for @homeSuggestionProgress.
  ///
  /// In vi, this message translates to:
  /// **'3/8 phút'**
  String get homeSuggestionProgress;

  /// No description provided for @homeSuggestionStatus.
  ///
  /// In vi, this message translates to:
  /// **'Đang đọc'**
  String get homeSuggestionStatus;

  /// No description provided for @homeInsightSavedDate.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ngày {date}'**
  String homeInsightSavedDate(String date);

  /// No description provided for @understandGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Career Snapshot'**
  String get understandGreeting;

  /// No description provided for @understandTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hiểu mình'**
  String get understandTitle;

  /// No description provided for @understandEyebrowNeed.
  ///
  /// In vi, this message translates to:
  /// **'Điều bạn đang tìm kiếm'**
  String get understandEyebrowNeed;

  /// No description provided for @understandEyebrowSituations.
  ///
  /// In vi, this message translates to:
  /// **'Tình huống lặp lại'**
  String get understandEyebrowSituations;

  /// No description provided for @understandEyebrowSca.
  ///
  /// In vi, this message translates to:
  /// **'Trải nghiệm hiện tại (SCA)'**
  String get understandEyebrowSca;

  /// No description provided for @understandEyebrowHealth.
  ///
  /// In vi, this message translates to:
  /// **'Career Health Check'**
  String get understandEyebrowHealth;

  /// No description provided for @understandScaRole.
  ///
  /// In vi, this message translates to:
  /// **'Minh bạch vai trò'**
  String get understandScaRole;

  /// No description provided for @understandScaVoice.
  ///
  /// In vi, this message translates to:
  /// **'An toàn khi lên tiếng'**
  String get understandScaVoice;

  /// No description provided for @understandScaMeaning.
  ///
  /// In vi, this message translates to:
  /// **'Định hướng ý nghĩa'**
  String get understandScaMeaning;

  /// No description provided for @understandStatusStable.
  ///
  /// In vi, this message translates to:
  /// **'Ổn định'**
  String get understandStatusStable;

  /// No description provided for @understandStatusImproving.
  ///
  /// In vi, this message translates to:
  /// **'Đang cải thiện'**
  String get understandStatusImproving;

  /// No description provided for @understandStatusUnrated.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đánh giá'**
  String get understandStatusUnrated;

  /// No description provided for @understandHealthReady.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã có đủ {n} reflection.'**
  String understandHealthReady(int n);

  /// No description provided for @understandHealthPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Sẵn sàng xem bức tranh tổng thể chưa?'**
  String get understandHealthPrompt;

  /// No description provided for @understandHealthCta.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu kiểm tra'**
  String get understandHealthCta;

  /// No description provided for @understandSituationCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} lần'**
  String understandSituationCount(int n);

  /// No description provided for @developGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Development Map'**
  String get developGreeting;

  /// No description provided for @developTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phát triển'**
  String get developTitle;

  /// No description provided for @developEyebrowFocus.
  ///
  /// In vi, this message translates to:
  /// **'Trọng tâm hiện tại'**
  String get developEyebrowFocus;

  /// No description provided for @developEyebrowPractices.
  ///
  /// In vi, this message translates to:
  /// **'Practices hôm nay'**
  String get developEyebrowPractices;

  /// No description provided for @developEyebrowOpportunity.
  ///
  /// In vi, this message translates to:
  /// **'Cơ hội phát triển'**
  String get developEyebrowOpportunity;

  /// No description provided for @developStage.
  ///
  /// In vi, this message translates to:
  /// **'Giai đoạn {x} / {y}'**
  String developStage(int x, int y);

  /// No description provided for @developStatusDone.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get developStatusDone;

  /// No description provided for @developStatusDoing.
  ///
  /// In vi, this message translates to:
  /// **'Đang thực hiện'**
  String get developStatusDoing;

  /// No description provided for @developStatusTodo.
  ///
  /// In vi, this message translates to:
  /// **'Chưa bắt đầu'**
  String get developStatusTodo;

  /// No description provided for @developWorkshopTag.
  ///
  /// In vi, this message translates to:
  /// **'Workshop'**
  String get developWorkshopTag;

  /// No description provided for @developWorkshopLink.
  ///
  /// In vi, this message translates to:
  /// **'Tại sao bây giờ?'**
  String get developWorkshopLink;

  /// No description provided for @journeyGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Career Memory'**
  String get journeyGreeting;

  /// No description provided for @journeyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hành trình'**
  String get journeyTitle;

  /// No description provided for @journeyEyebrowStory.
  ///
  /// In vi, this message translates to:
  /// **'Câu chuyện của bạn'**
  String get journeyEyebrowStory;

  /// No description provided for @journeyEyebrowMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng {m}'**
  String journeyEyebrowMonth(int m);

  /// No description provided for @journeyCaption.
  ///
  /// In vi, this message translates to:
  /// **'Career Companion · Tháng {m}, {yyyy}'**
  String journeyCaption(int m, int yyyy);

  /// No description provided for @journeyTypeMilestone.
  ///
  /// In vi, this message translates to:
  /// **'MILESTONE'**
  String get journeyTypeMilestone;

  /// No description provided for @journeyTypeStory.
  ///
  /// In vi, this message translates to:
  /// **'STORY'**
  String get journeyTypeStory;

  /// No description provided for @journeyTypeTheme.
  ///
  /// In vi, this message translates to:
  /// **'THEME'**
  String get journeyTypeTheme;

  /// No description provided for @profileGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get profileGreeting;

  /// No description provided for @profileBadgePremium.
  ///
  /// In vi, this message translates to:
  /// **'PREMIUM MEMBER'**
  String get profileBadgePremium;

  /// No description provided for @profileBadgeMember.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên'**
  String get profileBadgeMember;

  /// No description provided for @profileStatStreak.
  ///
  /// In vi, this message translates to:
  /// **'Ngày streak'**
  String get profileStatStreak;

  /// No description provided for @profileStatInsights.
  ///
  /// In vi, this message translates to:
  /// **'Insight lưu'**
  String get profileStatInsights;

  /// No description provided for @profileStatMilestones.
  ///
  /// In vi, this message translates to:
  /// **'Milestone'**
  String get profileStatMilestones;

  /// No description provided for @profileEyebrowSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get profileEyebrowSettings;

  /// No description provided for @profileSettingReminder.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc nhở hằng ngày'**
  String get profileSettingReminder;

  /// No description provided for @profileSettingLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get profileSettingLanguage;

  /// No description provided for @profileSettingExport.
  ///
  /// In vi, this message translates to:
  /// **'Xuất dữ liệu'**
  String get profileSettingExport;

  /// No description provided for @profileSettingLogout.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get profileSettingLogout;

  /// No description provided for @profileLanguageValue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get profileLanguageValue;

  /// No description provided for @understandStatusNeedsAttention.
  ///
  /// In vi, this message translates to:
  /// **'Cần chú ý'**
  String get understandStatusNeedsAttention;

  /// No description provided for @understandNeedSuffix.
  ///
  /// In vi, this message translates to:
  /// **'· Nhu cầu chủ đạo'**
  String get understandNeedSuffix;

  /// No description provided for @understandNoSituations.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tình huống nào được ghi nhận.'**
  String get understandNoSituations;

  /// No description provided for @homeInsightEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có insight nào. Hãy bắt đầu hành trình của bạn!'**
  String get homeInsightEmpty;

  /// No description provided for @homeErrorLoadData.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải dữ liệu.'**
  String get homeErrorLoadData;

  /// No description provided for @homeRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get homeRetry;

  /// No description provided for @homeCtaSurveyEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Phản chiếu công việc'**
  String get homeCtaSurveyEyebrow;

  /// No description provided for @homeCtaSurveyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Làm bài phản chiếu'**
  String get homeCtaSurveyTitle;

  /// No description provided for @homeCtaSurveySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhìn lại trải nghiệm công việc của bạn để hiểu rõ hơn.'**
  String get homeCtaSurveySubtitle;

  /// No description provided for @homeCtaSurveyButton.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu ngay'**
  String get homeCtaSurveyButton;

  /// No description provided for @homeCtaReportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xem báo cáo mới nhất'**
  String get homeCtaReportTitle;

  /// No description provided for @homeCtaReportSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã hoàn thành bài phản chiếu. Xem kết quả của mình.'**
  String get homeCtaReportSubtitle;

  /// No description provided for @homeCtaReportButton.
  ///
  /// In vi, this message translates to:
  /// **'Xem báo cáo'**
  String get homeCtaReportButton;

  /// No description provided for @homeCtaRetakeSurvey.
  ///
  /// In vi, this message translates to:
  /// **'Làm lại bài phản chiếu'**
  String get homeCtaRetakeSurvey;

  /// No description provided for @homeSystemNoticeQuote.
  ///
  /// In vi, this message translates to:
  /// **'\"Đây là lần thứ {n} bạn gặp tình huống {label}.\"'**
  String homeSystemNoticeQuote(int n, String label);

  /// No description provided for @developNoTheme.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có trọng tâm phát triển nào. Hãy bắt đầu hành trình của bạn!'**
  String get developNoTheme;

  /// No description provided for @developNoPractices.
  ///
  /// In vi, this message translates to:
  /// **'Không có practice nào hôm nay.'**
  String get developNoPractices;

  /// No description provided for @developErrorLoadData.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải dữ liệu.'**
  String get developErrorLoadData;

  /// No description provided for @authValidatorName.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên'**
  String get authValidatorName;

  /// No description provided for @authValidatorEmail.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập email'**
  String get authValidatorEmail;

  /// No description provided for @authValidatorPassword.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập mật khẩu'**
  String get authValidatorPassword;

  /// No description provided for @languageDialogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get languageDialogTitle;

  /// No description provided for @languageOptionVietnamese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get languageOptionVietnamese;

  /// No description provided for @languageOptionEnglish.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get languageOptionEnglish;

  /// No description provided for @tabToday.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay'**
  String get tabToday;

  /// No description provided for @tabUnderstand.
  ///
  /// In vi, this message translates to:
  /// **'Hiểu mình'**
  String get tabUnderstand;

  /// No description provided for @tabDevelop.
  ///
  /// In vi, this message translates to:
  /// **'Phát triển'**
  String get tabDevelop;

  /// No description provided for @tabJourney.
  ///
  /// In vi, this message translates to:
  /// **'Hành trình'**
  String get tabJourney;

  /// No description provided for @tabProfile.
  ///
  /// In vi, this message translates to:
  /// **'Tôi'**
  String get tabProfile;

  /// No description provided for @surveyIntroEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Career Health Check'**
  String get surveyIntroEyebrow;

  /// No description provided for @surveyIntroBadgeFree.
  ///
  /// In vi, this message translates to:
  /// **'FREE'**
  String get surveyIntroBadgeFree;

  /// No description provided for @surveyIntroBadgePremium.
  ///
  /// In vi, this message translates to:
  /// **'PREMIUM'**
  String get surveyIntroBadgePremium;

  /// No description provided for @surveyIntroTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra sức khỏe nghề nghiệp'**
  String get surveyIntroTitle;

  /// No description provided for @surveyIntroBody.
  ///
  /// In vi, this message translates to:
  /// **'Trả lời thành thật để nhận báo cáo cá nhân chính xác nhất.'**
  String get surveyIntroBody;

  /// No description provided for @surveyIntroFieldPosition.
  ///
  /// In vi, this message translates to:
  /// **'Chức danh'**
  String get surveyIntroFieldPosition;

  /// No description provided for @surveyIntroFieldExperience.
  ///
  /// In vi, this message translates to:
  /// **'Thâm niên'**
  String get surveyIntroFieldExperience;

  /// No description provided for @surveyIntroFieldCompanyTenure.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian tại công ty'**
  String get surveyIntroFieldCompanyTenure;

  /// No description provided for @surveyIntroFieldCompanySize.
  ///
  /// In vi, this message translates to:
  /// **'Quy mô công ty'**
  String get surveyIntroFieldCompanySize;

  /// No description provided for @surveyIntroFieldDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get surveyIntroFieldDepartment;

  /// No description provided for @surveyIntroCta.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu khảo sát'**
  String get surveyIntroCta;

  /// No description provided for @surveyLayerStructure.
  ///
  /// In vi, this message translates to:
  /// **'Cấu trúc'**
  String get surveyLayerStructure;

  /// No description provided for @surveyLayerCulture.
  ///
  /// In vi, this message translates to:
  /// **'Văn hoá'**
  String get surveyLayerCulture;

  /// No description provided for @surveyLayerActivity.
  ///
  /// In vi, this message translates to:
  /// **'Hoạt động'**
  String get surveyLayerActivity;

  /// No description provided for @surveyLayerEsi.
  ///
  /// In vi, this message translates to:
  /// **'Sự hài lòng nhân viên'**
  String get surveyLayerEsi;

  /// No description provided for @surveyLayerEnps.
  ///
  /// In vi, this message translates to:
  /// **'Gắn kết nhân viên'**
  String get surveyLayerEnps;

  /// No description provided for @surveyProgress.
  ///
  /// In vi, this message translates to:
  /// **'{current}/{total}'**
  String surveyProgress(int current, int total);

  /// No description provided for @surveyCompleteCta.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get surveyCompleteCta;

  /// No description provided for @surveyProcessingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đang tạo báo cáo của bạn…'**
  String get surveyProcessingTitle;

  /// No description provided for @surveyProcessingRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get surveyProcessingRetry;

  /// No description provided for @surveyProcessingError.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra. Vui lòng thử lại.'**
  String get surveyProcessingError;

  /// No description provided for @reportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo của bạn'**
  String get reportTitle;

  /// No description provided for @reportScoreLevelHigh.
  ///
  /// In vi, this message translates to:
  /// **'Xuất sắc'**
  String get reportScoreLevelHigh;

  /// No description provided for @reportScoreLevelGood.
  ///
  /// In vi, this message translates to:
  /// **'Tốt'**
  String get reportScoreLevelGood;

  /// No description provided for @reportScoreLevelWarning.
  ///
  /// In vi, this message translates to:
  /// **'Cần chú ý'**
  String get reportScoreLevelWarning;

  /// No description provided for @reportScoreLevelCritical.
  ///
  /// In vi, this message translates to:
  /// **'Cần cải thiện'**
  String get reportScoreLevelCritical;

  /// No description provided for @reportLayerStructure.
  ///
  /// In vi, this message translates to:
  /// **'Cấu trúc tổ chức'**
  String get reportLayerStructure;

  /// No description provided for @reportLayerCulture.
  ///
  /// In vi, this message translates to:
  /// **'Văn hoá làm việc'**
  String get reportLayerCulture;

  /// No description provided for @reportLayerActivity.
  ///
  /// In vi, this message translates to:
  /// **'Hoạt động hàng ngày'**
  String get reportLayerActivity;

  /// No description provided for @reportBottleneckTitle.
  ///
  /// In vi, this message translates to:
  /// **'Điểm cần cải thiện nhất'**
  String get reportBottleneckTitle;

  /// No description provided for @reportEsiTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ số hài lòng nhân viên (ESI)'**
  String get reportEsiTitle;

  /// No description provided for @reportEnpsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mức độ gắn kết (eNPS)'**
  String get reportEnpsTitle;

  /// No description provided for @reportEnpsPromoter.
  ///
  /// In vi, this message translates to:
  /// **'Người ủng hộ'**
  String get reportEnpsPromoter;

  /// No description provided for @reportEnpsPassive.
  ///
  /// In vi, this message translates to:
  /// **'Trung lập'**
  String get reportEnpsPassive;

  /// No description provided for @reportEnpsDetractor.
  ///
  /// In vi, this message translates to:
  /// **'Người phản đối'**
  String get reportEnpsDetractor;

  /// No description provided for @reportPremiumUpsell.
  ///
  /// In vi, this message translates to:
  /// **'Nâng cấp Premium để xem ESI, eNPS và phân tích chuyên sâu hơn.'**
  String get reportPremiumUpsell;

  /// No description provided for @reportActionPlanCta.
  ///
  /// In vi, this message translates to:
  /// **'Kế hoạch 30 ngày'**
  String get reportActionPlanCta;

  /// No description provided for @reportViewLatest.
  ///
  /// In vi, this message translates to:
  /// **'Xem báo cáo gần nhất'**
  String get reportViewLatest;

  /// No description provided for @reportViewHistory.
  ///
  /// In vi, this message translates to:
  /// **'Xem lịch sử khảo sát'**
  String get reportViewHistory;

  /// No description provided for @reportScaChartTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bức tranh S-C-A'**
  String get reportScaChartTitle;

  /// No description provided for @reportAiPersonalizingLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đang cá nhân hóa báo cáo…'**
  String get reportAiPersonalizingLabel;

  /// No description provided for @reportAiModelSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mô hình làm việc của bạn'**
  String get reportAiModelSectionTitle;

  /// No description provided for @reportAiReflectionSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phản chiếu cá nhân'**
  String get reportAiReflectionSectionTitle;

  /// No description provided for @reportAiRelationshipSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mối quan hệ trong công việc'**
  String get reportAiRelationshipSectionTitle;

  /// No description provided for @surveyHistoryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử khảo sát'**
  String get surveyHistoryTitle;

  /// No description provided for @surveyHistoryScoreLabel.
  ///
  /// In vi, this message translates to:
  /// **'Điểm'**
  String get surveyHistoryScoreLabel;

  /// No description provided for @surveyHistoryTypeFree.
  ///
  /// In vi, this message translates to:
  /// **'Free'**
  String get surveyHistoryTypeFree;

  /// No description provided for @surveyHistoryTypePremium.
  ///
  /// In vi, this message translates to:
  /// **'Premium'**
  String get surveyHistoryTypePremium;

  /// No description provided for @surveyHistoryEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khảo sát nào'**
  String get surveyHistoryEmptyTitle;

  /// No description provided for @surveyHistoryEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành khảo sát đầu tiên để xem lịch sử tại đây.'**
  String get surveyHistoryEmptyBody;

  /// No description provided for @surveyHistoryEmptyCta.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu khảo sát'**
  String get surveyHistoryEmptyCta;

  /// No description provided for @profileSurveyHistory.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử khảo sát'**
  String get profileSurveyHistory;

  /// No description provided for @actionPlanTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kế hoạch 30 ngày'**
  String get actionPlanTitle;

  /// No description provided for @actionPlanDay.
  ///
  /// In vi, this message translates to:
  /// **'Ngày {day}'**
  String actionPlanDay(int day);

  /// No description provided for @actionPlanReflection.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi phản chiếu'**
  String get actionPlanReflection;

  /// No description provided for @surveyTtsToggle.
  ///
  /// In vi, this message translates to:
  /// **'Đọc câu hỏi'**
  String get surveyTtsToggle;

  /// No description provided for @journeyErrorCard.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải hành trình.'**
  String get journeyErrorCard;

  /// No description provided for @wsListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Workshop'**
  String get wsListTitle;

  /// No description provided for @wsEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có workshop nào sắp diễn ra'**
  String get wsEmpty;

  /// No description provided for @wsFree.
  ///
  /// In vi, this message translates to:
  /// **'Miễn phí'**
  String get wsFree;

  /// No description provided for @wsFullBadge.
  ///
  /// In vi, this message translates to:
  /// **'Đã đầy'**
  String get wsFullBadge;

  /// No description provided for @wsRegister.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký'**
  String get wsRegister;

  /// No description provided for @wsRegistered.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng ký'**
  String get wsRegistered;

  /// No description provided for @wsAttended.
  ///
  /// In vi, this message translates to:
  /// **'Đã tham dự'**
  String get wsAttended;

  /// No description provided for @wsCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy'**
  String get wsCancelled;

  /// No description provided for @wsCheckin.
  ///
  /// In vi, this message translates to:
  /// **'Check-in'**
  String get wsCheckin;

  /// No description provided for @wsCheckedInAt.
  ///
  /// In vi, this message translates to:
  /// **'Đã check-in lúc {time}'**
  String wsCheckedInAt(String time);

  /// No description provided for @wsResources.
  ///
  /// In vi, this message translates to:
  /// **'Tài liệu'**
  String get wsResources;

  /// No description provided for @wsResourcesLocked.
  ///
  /// In vi, this message translates to:
  /// **'Tài liệu dành cho người đã đăng ký'**
  String get wsResourcesLocked;

  /// No description provided for @wsParticipants.
  ///
  /// In vi, this message translates to:
  /// **'{current}/{max} người tham gia'**
  String wsParticipants(int current, int max);

  /// No description provided for @wsLocation.
  ///
  /// In vi, this message translates to:
  /// **'Địa điểm'**
  String get wsLocation;

  /// No description provided for @wsPaidDialogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán trên web'**
  String get wsPaidDialogTitle;

  /// No description provided for @wsPaidDialogBody.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng hoàn tất thanh toán trên trang web WorkReflection để đăng ký.'**
  String get wsPaidDialogBody;

  /// No description provided for @wsPaidDialogOk.
  ///
  /// In vi, this message translates to:
  /// **'Đã hiểu'**
  String get wsPaidDialogOk;

  /// No description provided for @wsRegisterSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký thành công!'**
  String get wsRegisterSuccess;

  /// No description provided for @wsRegisterError.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký thất bại. Vui lòng thử lại.'**
  String get wsRegisterError;

  /// No description provided for @wsCheckinTitle.
  ///
  /// In vi, this message translates to:
  /// **'Check-in workshop'**
  String get wsCheckinTitle;

  /// No description provided for @wsCheckinScanHint.
  ///
  /// In vi, this message translates to:
  /// **'Quét mã QR của workshop'**
  String get wsCheckinScanHint;

  /// No description provided for @wsCheckinManualLabel.
  ///
  /// In vi, this message translates to:
  /// **'Hoặc nhập mã check-in'**
  String get wsCheckinManualLabel;

  /// No description provided for @wsCheckinSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get wsCheckinSubmit;

  /// No description provided for @wsCheckinInvalidCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã không hợp lệ'**
  String get wsCheckinInvalidCode;

  /// No description provided for @wsCheckinNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy workshop với mã này'**
  String get wsCheckinNotFound;

  /// No description provided for @wsCheckinNotRegistered.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa đăng ký workshop này'**
  String get wsCheckinNotRegistered;

  /// No description provided for @wsCheckinTooEarly.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đến giờ check-in (mở trước giờ bắt đầu 2 tiếng)'**
  String get wsCheckinTooEarly;

  /// No description provided for @wsCheckinClosed.
  ///
  /// In vi, this message translates to:
  /// **'Đã hết giờ check-in'**
  String get wsCheckinClosed;

  /// No description provided for @wsCheckinSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Check-in thành công!'**
  String get wsCheckinSuccess;

  /// No description provided for @wsCheckinError.
  ///
  /// In vi, this message translates to:
  /// **'Check-in thất bại. Vui lòng thử lại.'**
  String get wsCheckinError;

  /// No description provided for @wsLinkCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép liên kết'**
  String get wsLinkCopied;

  /// No description provided for @commonCancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get commonConfirm;

  /// No description provided for @wsConsentTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép sử dụng hình ảnh'**
  String get wsConsentTitle;

  /// No description provided for @wsConsentBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có đồng ý cho chúng tôi sử dụng hình ảnh có bạn trong workshop cho mục đích truyền thông không?'**
  String get wsConsentBody;

  /// No description provided for @wsConsentAccept.
  ///
  /// In vi, this message translates to:
  /// **'Đồng ý'**
  String get wsConsentAccept;

  /// No description provided for @wsConsentDecline.
  ///
  /// In vi, this message translates to:
  /// **'Không đồng ý'**
  String get wsConsentDecline;

  /// No description provided for @wsMyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Workshop của tôi'**
  String get wsMyTitle;

  /// No description provided for @wsMyEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa đăng ký workshop nào'**
  String get wsMyEmpty;

  /// No description provided for @wsSurveyCta.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá workshop'**
  String get wsSurveyCta;

  /// No description provided for @wsSurveyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá workshop'**
  String get wsSurveyTitle;

  /// No description provided for @wsSurveySubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi đánh giá'**
  String get wsSurveySubmit;

  /// No description provided for @wsSurveyThanks.
  ///
  /// In vi, this message translates to:
  /// **'Cảm ơn bạn đã đánh giá!'**
  String get wsSurveyThanks;

  /// No description provided for @wsSurveyDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã đánh giá'**
  String get wsSurveyDone;

  /// No description provided for @wsSurveyNone.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khảo sát cho workshop này'**
  String get wsSurveyNone;

  /// No description provided for @wsSurveyError.
  ///
  /// In vi, this message translates to:
  /// **'Gửi đánh giá thất bại. Vui lòng thử lại.'**
  String get wsSurveyError;

  /// No description provided for @coachTitle.
  ///
  /// In vi, this message translates to:
  /// **'Coaching'**
  String get coachTitle;

  /// No description provided for @coachAudienceYoung.
  ///
  /// In vi, this message translates to:
  /// **'Người trẻ'**
  String get coachAudienceYoung;

  /// No description provided for @coachAudienceManager.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý'**
  String get coachAudienceManager;

  /// No description provided for @coachSessionsFmt.
  ///
  /// In vi, this message translates to:
  /// **'{count} buổi × {minutes} phút'**
  String coachSessionsFmt(int count, int minutes);

  /// No description provided for @coachClaimFree.
  ///
  /// In vi, this message translates to:
  /// **'Nhận gói miễn phí'**
  String get coachClaimFree;

  /// No description provided for @coachClaimConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhận gói coaching'**
  String get coachClaimConfirmTitle;

  /// No description provided for @coachClaimConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn muốn nhận gói \"{name}\"?'**
  String coachClaimConfirmBody(String name);

  /// No description provided for @coachClaimSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã kích hoạt gói coaching!'**
  String get coachClaimSuccess;

  /// No description provided for @coachClaimError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể kích hoạt gói. Vui lòng thử lại.'**
  String get coachClaimError;

  /// No description provided for @coachOurCoaches.
  ///
  /// In vi, this message translates to:
  /// **'Đội ngũ coach'**
  String get coachOurCoaches;

  /// No description provided for @coachYearsExp.
  ///
  /// In vi, this message translates to:
  /// **'{years} năm kinh nghiệm'**
  String coachYearsExp(int years);

  /// No description provided for @coachMyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch coaching của tôi'**
  String get coachMyTitle;

  /// No description provided for @coachMyEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa có buổi coaching nào'**
  String get coachMyEmpty;

  /// No description provided for @coachPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ xếp lịch'**
  String get coachPending;

  /// No description provided for @coachScheduled.
  ///
  /// In vi, this message translates to:
  /// **'Đã xếp lịch'**
  String get coachScheduled;

  /// No description provided for @coachCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get coachCompleted;

  /// No description provided for @coachCancelledStatus.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy'**
  String get coachCancelledStatus;

  /// No description provided for @coachSessionOf.
  ///
  /// In vi, this message translates to:
  /// **'Buổi {n}/{total}'**
  String coachSessionOf(int n, int total);

  /// No description provided for @coachMeetingLink.
  ///
  /// In vi, this message translates to:
  /// **'Link buổi học'**
  String get coachMeetingLink;

  /// No description provided for @coachWebNote.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch và đánh giá thực hiện trên web'**
  String get coachWebNote;

  /// No description provided for @coachViewMy.
  ///
  /// In vi, this message translates to:
  /// **'Xem lịch của tôi'**
  String get coachViewMy;

  /// No description provided for @coachSchedButton.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch'**
  String get coachSchedButton;

  /// No description provided for @coachSchedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn lịch coaching'**
  String get coachSchedTitle;

  /// No description provided for @coachSchedChooseDate.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày'**
  String get coachSchedChooseDate;

  /// No description provided for @coachSchedChooseTime.
  ///
  /// In vi, this message translates to:
  /// **'Chọn giờ'**
  String get coachSchedChooseTime;

  /// No description provided for @coachSchedNotes.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú (tuỳ chọn)'**
  String get coachSchedNotes;

  /// No description provided for @coachSchedNotesHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập ghi chú hoặc câu hỏi cho coach...'**
  String get coachSchedNotesHint;

  /// No description provided for @coachSchedSelectedDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày đã chọn:'**
  String get coachSchedSelectedDate;

  /// No description provided for @coachSchedPickDate.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn ngày trước'**
  String get coachSchedPickDate;

  /// No description provided for @coachSchedPickTime.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn giờ trước'**
  String get coachSchedPickTime;

  /// No description provided for @coachSchedConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đặt lịch'**
  String get coachSchedConfirmTitle;

  /// No description provided for @coachSchedConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch buổi coaching vào ngày {date} lúc {time}?'**
  String coachSchedConfirmBody(String date, String time);

  /// No description provided for @coachSchedSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đặt lịch'**
  String get coachSchedSubmit;

  /// No description provided for @coachSchedSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch thành công!'**
  String get coachSchedSuccess;

  /// No description provided for @coachSchedError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể đặt lịch. Vui lòng thử lại.'**
  String get coachSchedError;

  /// No description provided for @coachSchedNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy buổi coaching này'**
  String get coachSchedNotFound;

  /// No description provided for @coachReviewsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá từ khách hàng'**
  String get coachReviewsTitle;

  /// No description provided for @profileMyWorkshops.
  ///
  /// In vi, this message translates to:
  /// **'Workshop của tôi'**
  String get profileMyWorkshops;

  /// No description provided for @profileMyCoaching.
  ///
  /// In vi, this message translates to:
  /// **'Coaching của tôi'**
  String get profileMyCoaching;

  /// No description provided for @developWorkshopSection.
  ///
  /// In vi, this message translates to:
  /// **'Cơ hội phát triển'**
  String get developWorkshopSection;

  /// No description provided for @developViewWorkshops.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả workshop'**
  String get developViewWorkshops;

  /// No description provided for @developViewCoaching.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá coaching'**
  String get developViewCoaching;

  /// No description provided for @authForgotPassword.
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu?'**
  String get authForgotPassword;

  /// No description provided for @authForgotPasswordDialogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu'**
  String get authForgotPasswordDialogTitle;

  /// No description provided for @authForgotPasswordDialogHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập email để nhận link đặt lại mật khẩu'**
  String get authForgotPasswordDialogHint;

  /// No description provided for @authForgotPasswordSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi link đặt lại'**
  String get authForgotPasswordSubmit;

  /// No description provided for @authForgotPasswordSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra email của bạn để đặt lại mật khẩu.'**
  String get authForgotPasswordSuccess;

  /// No description provided for @authForgotPasswordErrorInvalidEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ'**
  String get authForgotPasswordErrorInvalidEmail;

  /// No description provided for @authForgotPasswordError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể gửi email. Vui lòng thử lại.'**
  String get authForgotPasswordError;

  /// No description provided for @profileSettingEditProfile.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hồ sơ'**
  String get profileSettingEditProfile;

  /// No description provided for @profileSettingChangePassword.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu'**
  String get profileSettingChangePassword;

  /// No description provided for @changePasswordTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordNewLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới'**
  String get changePasswordNewLabel;

  /// No description provided for @changePasswordConfirmLabel.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận mật khẩu mới'**
  String get changePasswordConfirmLabel;

  /// No description provided for @changePasswordSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật mật khẩu'**
  String get changePasswordSubmit;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu đã được cập nhật.'**
  String get changePasswordSuccess;

  /// No description provided for @changePasswordErrorTooShort.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu phải có ít nhất 6 ký tự'**
  String get changePasswordErrorTooShort;

  /// No description provided for @changePasswordErrorMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu xác nhận không khớp'**
  String get changePasswordErrorMismatch;

  /// No description provided for @changePasswordErrorGeneric.
  ///
  /// In vi, this message translates to:
  /// **'Không thể đổi mật khẩu. Vui lòng thử lại.'**
  String get changePasswordErrorGeneric;

  /// No description provided for @changePasswordErrorSessionExpired.
  ///
  /// In vi, this message translates to:
  /// **'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'**
  String get changePasswordErrorSessionExpired;

  /// No description provided for @profileEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hồ sơ'**
  String get profileEditTitle;

  /// No description provided for @profileEditEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cá nhân'**
  String get profileEditEyebrow;

  /// No description provided for @profileEditFieldDisplayName.
  ///
  /// In vi, this message translates to:
  /// **'Tên hiển thị'**
  String get profileEditFieldDisplayName;

  /// No description provided for @profileEditFieldFullName.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get profileEditFieldFullName;

  /// No description provided for @profileEditFieldPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get profileEditFieldPhone;

  /// No description provided for @profileEditFieldCompanyName.
  ///
  /// In vi, this message translates to:
  /// **'Tên công ty'**
  String get profileEditFieldCompanyName;

  /// No description provided for @profileEditFieldPosition.
  ///
  /// In vi, this message translates to:
  /// **'Chức danh'**
  String get profileEditFieldPosition;

  /// No description provided for @profileEditFieldCompanySize.
  ///
  /// In vi, this message translates to:
  /// **'Quy mô công ty'**
  String get profileEditFieldCompanySize;

  /// No description provided for @profileEditFieldExperience.
  ///
  /// In vi, this message translates to:
  /// **'Thâm niên làm việc'**
  String get profileEditFieldExperience;

  /// No description provided for @profileEditFieldTenure.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian tại công ty'**
  String get profileEditFieldTenure;

  /// No description provided for @profileEditFieldDepartment.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ban'**
  String get profileEditFieldDepartment;

  /// No description provided for @profileEditSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get profileEditSave;

  /// No description provided for @profileEditSaveSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật hồ sơ.'**
  String get profileEditSaveSuccess;

  /// No description provided for @profileEditSaveError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu. Vui lòng thử lại.'**
  String get profileEditSaveError;

  /// No description provided for @profileEditAvatarNote.
  ///
  /// In vi, this message translates to:
  /// **'Thay ảnh đại diện trên web tại workreflection.app'**
  String get profileEditAvatarNote;

  /// No description provided for @profileEditPositionStaff.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên'**
  String get profileEditPositionStaff;

  /// No description provided for @profileEditPositionTeamLead.
  ///
  /// In vi, this message translates to:
  /// **'Trưởng nhóm'**
  String get profileEditPositionTeamLead;

  /// No description provided for @profileEditPositionManager.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý'**
  String get profileEditPositionManager;

  /// No description provided for @profileEditPositionDirector.
  ///
  /// In vi, this message translates to:
  /// **'Giám đốc'**
  String get profileEditPositionDirector;

  /// No description provided for @profileEditPositionCLevel.
  ///
  /// In vi, this message translates to:
  /// **'C-Level'**
  String get profileEditPositionCLevel;

  /// No description provided for @profileEditPositionIntern.
  ///
  /// In vi, this message translates to:
  /// **'Thực tập sinh'**
  String get profileEditPositionIntern;

  /// No description provided for @profileEditPositionFreelancer.
  ///
  /// In vi, this message translates to:
  /// **'Freelancer'**
  String get profileEditPositionFreelancer;

  /// No description provided for @profileEditPositionOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get profileEditPositionOther;

  /// No description provided for @profileEditCompanySize1to10.
  ///
  /// In vi, this message translates to:
  /// **'1–10 người'**
  String get profileEditCompanySize1to10;

  /// No description provided for @profileEditCompanySize11to50.
  ///
  /// In vi, this message translates to:
  /// **'11–50 người'**
  String get profileEditCompanySize11to50;

  /// No description provided for @profileEditCompanySize51to200.
  ///
  /// In vi, this message translates to:
  /// **'51–200 người'**
  String get profileEditCompanySize51to200;

  /// No description provided for @profileEditCompanySize201to500.
  ///
  /// In vi, this message translates to:
  /// **'201–500 người'**
  String get profileEditCompanySize201to500;

  /// No description provided for @profileEditCompanySize501to1000.
  ///
  /// In vi, this message translates to:
  /// **'501–1000 người'**
  String get profileEditCompanySize501to1000;

  /// No description provided for @profileEditCompanySize1000Plus.
  ///
  /// In vi, this message translates to:
  /// **'Trên 1000 người'**
  String get profileEditCompanySize1000Plus;

  /// No description provided for @profileEditExpLess1.
  ///
  /// In vi, this message translates to:
  /// **'Dưới 1 năm'**
  String get profileEditExpLess1;

  /// No description provided for @profileEditExp1to3.
  ///
  /// In vi, this message translates to:
  /// **'1–3 năm'**
  String get profileEditExp1to3;

  /// No description provided for @profileEditExp3to5.
  ///
  /// In vi, this message translates to:
  /// **'3–5 năm'**
  String get profileEditExp3to5;

  /// No description provided for @profileEditExp5to10.
  ///
  /// In vi, this message translates to:
  /// **'5–10 năm'**
  String get profileEditExp5to10;

  /// No description provided for @profileEditExp10Plus.
  ///
  /// In vi, this message translates to:
  /// **'Trên 10 năm'**
  String get profileEditExp10Plus;

  /// No description provided for @profileEditTenureLess6m.
  ///
  /// In vi, this message translates to:
  /// **'Dưới 6 tháng'**
  String get profileEditTenureLess6m;

  /// No description provided for @profileEditTenure6mto1y.
  ///
  /// In vi, this message translates to:
  /// **'6 tháng–1 năm'**
  String get profileEditTenure6mto1y;

  /// No description provided for @profileEditTenure1to2.
  ///
  /// In vi, this message translates to:
  /// **'1–2 năm'**
  String get profileEditTenure1to2;

  /// No description provided for @profileEditTenure2to5.
  ///
  /// In vi, this message translates to:
  /// **'2–5 năm'**
  String get profileEditTenure2to5;

  /// No description provided for @profileEditTenure5Plus.
  ///
  /// In vi, this message translates to:
  /// **'Trên 5 năm'**
  String get profileEditTenure5Plus;

  /// No description provided for @profileEditDeptMarketing.
  ///
  /// In vi, this message translates to:
  /// **'Marketing'**
  String get profileEditDeptMarketing;

  /// No description provided for @profileEditDeptAccounting.
  ///
  /// In vi, this message translates to:
  /// **'Kế toán'**
  String get profileEditDeptAccounting;

  /// No description provided for @profileEditDeptSales.
  ///
  /// In vi, this message translates to:
  /// **'Kinh doanh'**
  String get profileEditDeptSales;

  /// No description provided for @profileEditDeptPurchasing.
  ///
  /// In vi, this message translates to:
  /// **'Mua hàng'**
  String get profileEditDeptPurchasing;

  /// No description provided for @profileEditDeptHr.
  ///
  /// In vi, this message translates to:
  /// **'Nhân sự'**
  String get profileEditDeptHr;

  /// No description provided for @profileEditDeptIt.
  ///
  /// In vi, this message translates to:
  /// **'IT'**
  String get profileEditDeptIt;

  /// No description provided for @profileEditDeptProduction.
  ///
  /// In vi, this message translates to:
  /// **'Sản xuất'**
  String get profileEditDeptProduction;

  /// No description provided for @profileEditDeptAdmin.
  ///
  /// In vi, this message translates to:
  /// **'Hành chính'**
  String get profileEditDeptAdmin;

  /// No description provided for @profileEditDeptOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get profileEditDeptOther;

  /// No description provided for @profileEditSelectHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn...'**
  String get profileEditSelectHint;

  /// No description provided for @insightsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả insight'**
  String get insightsTitle;

  /// No description provided for @insightsEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa có insight nào. Hãy bắt đầu hành trình của bạn!'**
  String get insightsEmpty;

  /// No description provided for @insightSavedDate.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ngày {date}'**
  String insightSavedDate(String date);

  /// No description provided for @understandViewAllInsights.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả insight'**
  String get understandViewAllInsights;

  /// No description provided for @profileCheckinHistory.
  ///
  /// In vi, this message translates to:
  /// **'30 ngày gần đây'**
  String get profileCheckinHistory;

  /// No description provided for @surveyGuideEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn'**
  String get surveyGuideEyebrow;

  /// No description provided for @surveyGuideFreeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Work Reflection – Phản chiếu trải nghiệm công việc cá nhân'**
  String get surveyGuideFreeTitle;

  /// No description provided for @surveyGuideFreeIntro.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng bạn đến với hành trình nhìn lại trải nghiệm công việc cá nhân.'**
  String get surveyGuideFreeIntro;

  /// No description provided for @surveyGuideFreeDescription.
  ///
  /// In vi, this message translates to:
  /// **'Work Reflection là công cụ giúp người đi làm nhìn lại môi trường và trải nghiệm công việc của mình một cách có hệ thống.'**
  String get surveyGuideFreeDescription;

  /// No description provided for @surveyGuideFreeDetails.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản miễn phí gồm 15 câu hỏi cho phép bạn thực hiện khảo sát nhanh. Sau khi hoàn thành, bạn sẽ nhận được một báo cáo phản chiếu tổng quan, giúp bạn:'**
  String get surveyGuideFreeDetails;

  /// No description provided for @surveyGuideFreeBenefit1.
  ///
  /// In vi, this message translates to:
  /// **'Nhìn thấy bức tranh chung.'**
  String get surveyGuideFreeBenefit1;

  /// No description provided for @surveyGuideFreeBenefit2.
  ///
  /// In vi, this message translates to:
  /// **'Nhận diện những điểm cần điều chỉnh.'**
  String get surveyGuideFreeBenefit2;

  /// No description provided for @surveyGuideFreeBenefit3.
  ///
  /// In vi, this message translates to:
  /// **'Có cơ sở rõ ràng hơn để suy nghĩ về bước đi tiếp theo trong công việc.'**
  String get surveyGuideFreeBenefit3;

  /// No description provided for @surveyGuideFreeNote.
  ///
  /// In vi, this message translates to:
  /// **'Work Reflection không nhằm đánh giá con người, mà giúp bạn hiểu cách hệ thống công việc đang vận hành xung quanh mình.'**
  String get surveyGuideFreeNote;

  /// No description provided for @surveyGuideFreeClosing.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản miễn phí phù hợp khi bạn muốn bắt đầu nhìn lại công việc một cách nhẹ nhàng, trước khi đi sâu hơn với các phân tích nâng cao.'**
  String get surveyGuideFreeClosing;

  /// No description provided for @surveyGuidePremiumTitle.
  ///
  /// In vi, this message translates to:
  /// **'Work Reflection Premium – Phản chiếu sâu để định hướng rõ'**
  String get surveyGuidePremiumTitle;

  /// No description provided for @surveyGuidePremiumIntro.
  ///
  /// In vi, this message translates to:
  /// **'Work Reflection Premium là phiên bản phân tích nâng cao dành cho người đi làm muốn nhìn lại công việc một cách toàn diện và có chiều sâu hơn.'**
  String get surveyGuidePremiumIntro;

  /// No description provided for @surveyGuidePremiumDetails.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản Premium giúp bạn:'**
  String get surveyGuidePremiumDetails;

  /// No description provided for @surveyGuidePremiumBenefit1.
  ///
  /// In vi, this message translates to:
  /// **'Phân tích chi tiết mức độ rõ ràng trong vai trò, kỳ vọng và cơ chế phối hợp'**
  String get surveyGuidePremiumBenefit1;

  /// No description provided for @surveyGuidePremiumBenefit2.
  ///
  /// In vi, this message translates to:
  /// **'Nhận diện chất lượng đối thoại, phản hồi và an toàn tâm lý trong môi trường làm việc'**
  String get surveyGuidePremiumBenefit2;

  /// No description provided for @surveyGuidePremiumBenefit3.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá mức độ phát triển, động lực và sự phù hợp giữa cá nhân – công việc – tổ chức'**
  String get surveyGuidePremiumBenefit3;

  /// No description provided for @surveyGuidePremiumBenefit4.
  ///
  /// In vi, this message translates to:
  /// **'Xác định các điểm nghẽn cốt lõi thay vì chỉ thấy triệu chứng bề mặt'**
  String get surveyGuidePremiumBenefit4;

  /// No description provided for @surveyGuidePremiumClosing.
  ///
  /// In vi, this message translates to:
  /// **'Work Reflection Premium giúp bạn có một khung nhìn rõ ràng hơn để tự đưa ra quyết định.'**
  String get surveyGuidePremiumClosing;

  /// No description provided for @surveyGuidePremiumReportDesc.
  ///
  /// In vi, this message translates to:
  /// **'Sau khi hoàn thành, bạn nhận được báo cáo phản chiếu chuyên sâu với:'**
  String get surveyGuidePremiumReportDesc;

  /// No description provided for @surveyGuidePremiumReport1.
  ///
  /// In vi, this message translates to:
  /// **'Điểm số theo từng nhóm yếu tố'**
  String get surveyGuidePremiumReport1;

  /// No description provided for @surveyGuidePremiumReport2.
  ///
  /// In vi, this message translates to:
  /// **'Diễn giải ý nghĩa từng khu vực'**
  String get surveyGuidePremiumReport2;

  /// No description provided for @surveyGuidePremiumReport3.
  ///
  /// In vi, this message translates to:
  /// **'Gợi ý định hướng suy nghĩ và hành động cho giai đoạn tiếp theo'**
  String get surveyGuidePremiumReport3;

  /// No description provided for @surveyGuideCta.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get surveyGuideCta;

  /// No description provided for @layerDetailViewDetail.
  ///
  /// In vi, this message translates to:
  /// **'Xem chi tiết'**
  String get layerDetailViewDetail;

  /// No description provided for @layerDetailOverallScore.
  ///
  /// In vi, this message translates to:
  /// **'Điểm tổng thể'**
  String get layerDetailOverallScore;

  /// No description provided for @layerDetailNoData.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu'**
  String get layerDetailNoData;

  /// No description provided for @layerDetailNoDataBody.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành khảo sát để xem phân tích chi tiết.'**
  String get layerDetailNoDataBody;

  /// No description provided for @layerDetailResponses.
  ///
  /// In vi, this message translates to:
  /// **'{count} phản hồi'**
  String layerDetailResponses(int count);

  /// No description provided for @layerDetailScoreGood.
  ///
  /// In vi, this message translates to:
  /// **'Tốt'**
  String get layerDetailScoreGood;

  /// No description provided for @layerDetailScoreWarning.
  ///
  /// In vi, this message translates to:
  /// **'Cần cải thiện'**
  String get layerDetailScoreWarning;

  /// No description provided for @layerDetailScoreCritical.
  ///
  /// In vi, this message translates to:
  /// **'Cần hành động'**
  String get layerDetailScoreCritical;

  /// No description provided for @esiAnalysisTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bức tranh hài lòng & trải nghiệm'**
  String get esiAnalysisTitle;

  /// No description provided for @esiAnalysisEsiScore.
  ///
  /// In vi, this message translates to:
  /// **'Điểm ESI'**
  String get esiAnalysisEsiScore;

  /// No description provided for @esiAnalysisEnpsScore.
  ///
  /// In vi, this message translates to:
  /// **'Điểm eNPS'**
  String get esiAnalysisEnpsScore;

  /// No description provided for @esiAnalysisPillarsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phân tích ESI theo trụ cột'**
  String get esiAnalysisPillarsTitle;

  /// No description provided for @esiAnalysisNoData.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu ESI chi tiết'**
  String get esiAnalysisNoData;

  /// No description provided for @esiAnalysisNoDataBody.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành khảo sát Premium để xem phân tích ESI.'**
  String get esiAnalysisNoDataBody;

  /// No description provided for @esiAnalysisEnpsPromoter.
  ///
  /// In vi, this message translates to:
  /// **'Ủng hộ viên'**
  String get esiAnalysisEnpsPromoter;

  /// No description provided for @esiAnalysisEnpsPassive.
  ///
  /// In vi, this message translates to:
  /// **'Trung lập'**
  String get esiAnalysisEnpsPassive;

  /// No description provided for @esiAnalysisEnpsDetractor.
  ///
  /// In vi, this message translates to:
  /// **'Không ủng hộ'**
  String get esiAnalysisEnpsDetractor;

  /// No description provided for @esiPillarCompensation.
  ///
  /// In vi, this message translates to:
  /// **'Đãi ngộ & phúc lợi'**
  String get esiPillarCompensation;

  /// No description provided for @esiPillarGrowth.
  ///
  /// In vi, this message translates to:
  /// **'Cơ hội phát triển'**
  String get esiPillarGrowth;

  /// No description provided for @esiPillarFairness.
  ///
  /// In vi, this message translates to:
  /// **'Minh bạch & Công bằng'**
  String get esiPillarFairness;

  /// No description provided for @esiPillarSupport.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ & ghi nhận từ cấp trên'**
  String get esiPillarSupport;

  /// No description provided for @esiPillarColleagues.
  ///
  /// In vi, this message translates to:
  /// **'Đồng nghiệp & môi trường làm việc'**
  String get esiPillarColleagues;

  /// No description provided for @subCompRoleExpect.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ vọng vai trò'**
  String get subCompRoleExpect;

  /// No description provided for @subCompCollabRules.
  ///
  /// In vi, this message translates to:
  /// **'Quy tắc phối hợp'**
  String get subCompCollabRules;

  /// No description provided for @subCompCommChannels.
  ///
  /// In vi, this message translates to:
  /// **'Kênh giao tiếp'**
  String get subCompCommChannels;

  /// No description provided for @subCompTrust.
  ///
  /// In vi, this message translates to:
  /// **'Sự tin tưởng'**
  String get subCompTrust;

  /// No description provided for @subCompPsychSafety.
  ///
  /// In vi, this message translates to:
  /// **'An toàn tâm lý'**
  String get subCompPsychSafety;

  /// No description provided for @subCompFeedbackDialogue.
  ///
  /// In vi, this message translates to:
  /// **'Đối thoại & Phản hồi'**
  String get subCompFeedbackDialogue;

  /// No description provided for @subCompGoalAlignment.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết mục tiêu'**
  String get subCompGoalAlignment;

  /// No description provided for @subCompExecutionRhythm.
  ///
  /// In vi, this message translates to:
  /// **'Nhịp thực thi'**
  String get subCompExecutionRhythm;

  /// No description provided for @subCompRetrospective.
  ///
  /// In vi, this message translates to:
  /// **'Thói quen nhìn lại'**
  String get subCompRetrospective;

  /// No description provided for @subCompContinuousImprove.
  ///
  /// In vi, this message translates to:
  /// **'Cải tiến liên tục'**
  String get subCompContinuousImprove;

  /// No description provided for @subCompCompensationIncome.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhập'**
  String get subCompCompensationIncome;

  /// No description provided for @subCompCompensationBenefits.
  ///
  /// In vi, this message translates to:
  /// **'Phúc lợi'**
  String get subCompCompensationBenefits;

  /// No description provided for @subCompGrowthCareer.
  ///
  /// In vi, this message translates to:
  /// **'Phát triển sự nghiệp'**
  String get subCompGrowthCareer;

  /// No description provided for @subCompFairnessEvaluation.
  ///
  /// In vi, this message translates to:
  /// **'Công bằng đánh giá'**
  String get subCompFairnessEvaluation;

  /// No description provided for @subCompSupportManagement.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ quản lý'**
  String get subCompSupportManagement;

  /// No description provided for @subCompSupportFeedback.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ phản hồi'**
  String get subCompSupportFeedback;

  /// No description provided for @subCompSupportCollaboration.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ hợp tác'**
  String get subCompSupportCollaboration;

  /// No description provided for @subCompSupportLeadership.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ lãnh đạo'**
  String get subCompSupportLeadership;

  /// No description provided for @roadmapTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lộ trình hành động'**
  String get roadmapTitle;

  /// No description provided for @roadmapSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi và thực hiện kế hoạch phát triển của bạn'**
  String get roadmapSubtitle;

  /// No description provided for @roadmapSelectReport.
  ///
  /// In vi, this message translates to:
  /// **'Chọn báo cáo...'**
  String get roadmapSelectReport;

  /// No description provided for @roadmapNoPremiumReports.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa có báo cáo Premium'**
  String get roadmapNoPremiumReports;

  /// No description provided for @roadmapNoPremiumReportsBody.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành khảo sát Premium để mở lộ trình hành động cá nhân.'**
  String get roadmapNoPremiumReportsBody;

  /// No description provided for @roadmapStartSurvey.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu khảo sát'**
  String get roadmapStartSurvey;

  /// No description provided for @roadmapNoActionsForReport.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu hành động cho báo cáo này.'**
  String get roadmapNoActionsForReport;

  /// No description provided for @roadmapProgressLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiến độ tổng thể'**
  String get roadmapProgressLabel;

  /// No description provided for @roadmapDayHeader7.
  ///
  /// In vi, this message translates to:
  /// **'Nhập môn'**
  String get roadmapDayHeader7;

  /// No description provided for @roadmapDayHeader14.
  ///
  /// In vi, this message translates to:
  /// **'Thử nghiệm'**
  String get roadmapDayHeader14;

  /// No description provided for @roadmapDayHeader30.
  ///
  /// In vi, this message translates to:
  /// **'Chuyên hoá'**
  String get roadmapDayHeader30;

  /// No description provided for @roadmapLayerStructure.
  ///
  /// In vi, this message translates to:
  /// **'Cấu trúc'**
  String get roadmapLayerStructure;

  /// No description provided for @roadmapLayerCulture.
  ///
  /// In vi, this message translates to:
  /// **'Văn hoá'**
  String get roadmapLayerCulture;

  /// No description provided for @roadmapLayerActivity.
  ///
  /// In vi, this message translates to:
  /// **'Hoạt động'**
  String get roadmapLayerActivity;

  /// No description provided for @roadmapAddCustomTask.
  ///
  /// In vi, this message translates to:
  /// **'Thêm hành động'**
  String get roadmapAddCustomTask;

  /// No description provided for @roadmapAddTaskTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm hành động tự chọn'**
  String get roadmapAddTaskTitle;

  /// No description provided for @roadmapEditTaskTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hành động'**
  String get roadmapEditTaskTitle;

  /// No description provided for @roadmapTaskTitleLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiêu đề'**
  String get roadmapTaskTitleLabel;

  /// No description provided for @roadmapTaskDescLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả (tuỳ chọn)'**
  String get roadmapTaskDescLabel;

  /// No description provided for @roadmapTaskDueDateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày hoàn thành (tuỳ chọn)'**
  String get roadmapTaskDueDateLabel;

  /// No description provided for @roadmapTaskTitleHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: 1:1 với quản lý'**
  String get roadmapTaskTitleHint;

  /// No description provided for @roadmapTaskDescHint.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú thêm...'**
  String get roadmapTaskDescHint;

  /// No description provided for @roadmapTaskAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm'**
  String get roadmapTaskAdd;

  /// No description provided for @roadmapTaskSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get roadmapTaskSave;

  /// No description provided for @roadmapTaskAdded.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm hành động'**
  String get roadmapTaskAdded;

  /// No description provided for @roadmapTaskUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật hành động'**
  String get roadmapTaskUpdated;

  /// No description provided for @roadmapTaskDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã xoá hành động'**
  String get roadmapTaskDeleted;

  /// No description provided for @roadmapErrorToggle.
  ///
  /// In vi, this message translates to:
  /// **'Không thể cập nhật. Vui lòng thử lại.'**
  String get roadmapErrorToggle;

  /// No description provided for @roadmapErrorAdd.
  ///
  /// In vi, this message translates to:
  /// **'Không thể thêm hành động. Vui lòng thử lại.'**
  String get roadmapErrorAdd;

  /// No description provided for @roadmapErrorEdit.
  ///
  /// In vi, this message translates to:
  /// **'Không thể chỉnh sửa. Vui lòng thử lại.'**
  String get roadmapErrorEdit;

  /// No description provided for @roadmapErrorDelete.
  ///
  /// In vi, this message translates to:
  /// **'Không thể xoá. Vui lòng thử lại.'**
  String get roadmapErrorDelete;

  /// No description provided for @roadmapCoachSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mời coach đồng hành'**
  String get roadmapCoachSectionTitle;

  /// No description provided for @roadmapInviteCoach.
  ///
  /// In vi, this message translates to:
  /// **'Mời coach'**
  String get roadmapInviteCoach;

  /// No description provided for @roadmapChooseCoach.
  ///
  /// In vi, this message translates to:
  /// **'Chọn coach để mời'**
  String get roadmapChooseCoach;

  /// No description provided for @roadmapNoCoachesAvailable.
  ///
  /// In vi, this message translates to:
  /// **'Không có coach khả dụng'**
  String get roadmapNoCoachesAvailable;

  /// No description provided for @roadmapCoachPending.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ'**
  String get roadmapCoachPending;

  /// No description provided for @roadmapCoachAccepted.
  ///
  /// In vi, this message translates to:
  /// **'Đã chấp nhận'**
  String get roadmapCoachAccepted;

  /// No description provided for @roadmapCoachRevoked.
  ///
  /// In vi, this message translates to:
  /// **'Thu hồi'**
  String get roadmapCoachRevoked;

  /// No description provided for @roadmapCoachInvited.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi lời mời'**
  String get roadmapCoachInvited;

  /// No description provided for @roadmapErrorInviteCoach.
  ///
  /// In vi, this message translates to:
  /// **'Không thể gửi lời mời.'**
  String get roadmapErrorInviteCoach;

  /// No description provided for @roadmapNoCoachs.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa mời coach nào.'**
  String get roadmapNoCoachs;

  /// No description provided for @roadmapActivityLog.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo hoạt động'**
  String get roadmapActivityLog;

  /// No description provided for @roadmapActivityEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có hoạt động nào.'**
  String get roadmapActivityEmpty;

  /// No description provided for @roadmapActivityContent.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung'**
  String get roadmapActivityContent;

  /// No description provided for @roadmapActivityLayer.
  ///
  /// In vi, this message translates to:
  /// **'Tầng'**
  String get roadmapActivityLayer;

  /// No description provided for @roadmapActivityDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get roadmapActivityDate;

  /// No description provided for @roadmapRenameReport.
  ///
  /// In vi, this message translates to:
  /// **'Đặt tên báo cáo'**
  String get roadmapRenameReport;

  /// No description provided for @roadmapNicknameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên báo cáo'**
  String get roadmapNicknameLabel;

  /// No description provided for @roadmapNicknameHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Đánh giá tháng 7'**
  String get roadmapNicknameHint;

  /// No description provided for @roadmapNicknameSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật tên.'**
  String get roadmapNicknameSaved;

  /// No description provided for @roadmapNicknameError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu tên.'**
  String get roadmapNicknameError;

  /// No description provided for @roadmapScoreHigh.
  ///
  /// In vi, this message translates to:
  /// **'Tốt – duy trì'**
  String get roadmapScoreHigh;

  /// No description provided for @roadmapScoreGood.
  ///
  /// In vi, this message translates to:
  /// **'Khá – cải thiện nhỏ'**
  String get roadmapScoreGood;

  /// No description provided for @roadmapScoreWarning.
  ///
  /// In vi, this message translates to:
  /// **'Cần cải thiện'**
  String get roadmapScoreWarning;

  /// No description provided for @roadmapScoreCritical.
  ///
  /// In vi, this message translates to:
  /// **'Cần hành động ngay'**
  String get roadmapScoreCritical;

  /// No description provided for @roadmapEntryLink.
  ///
  /// In vi, this message translates to:
  /// **'Lộ trình phát triển'**
  String get roadmapEntryLink;

  /// No description provided for @roadmapProfileLink.
  ///
  /// In vi, this message translates to:
  /// **'Lộ trình hành động'**
  String get roadmapProfileLink;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
