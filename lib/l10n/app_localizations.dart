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
