// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'WorkReflection';

  @override
  String get onb1Tag => 'Reflection';

  @override
  String get onb1Title => 'The journey starts\nwith a small question.';

  @override
  String get onb1Body =>
      'A moment to pause each day.\nTo see more clearly — without judgment.';

  @override
  String get onb1Cta => 'Continue';

  @override
  String get onb2Tag => 'Understand';

  @override
  String get onb2Title => 'What is weighing\non your mind most?';

  @override
  String get onb2Body => 'Name it.\nClarity is the first step\nto change.';

  @override
  String get onb2Opt1 => 'Tired but don\'t know why';

  @override
  String get onb2Opt2 => 'Trying hard but not progressing';

  @override
  String get onb2Opt3 => 'Want to change, unsure where to start';

  @override
  String get onb2Opt4 => 'Doing okay, want to know myself better';

  @override
  String get onb2Cta => 'Get started';

  @override
  String get onb3Tag => 'Grow';

  @override
  String get onb3Title => 'Walking alongside\nyour career.';

  @override
  String get onb3Body =>
      'WorkReflection remembers your journey,\naccumulating insights into\nyour own career intelligence.';

  @override
  String get onb3Promise1Title => '5–15 minutes a day';

  @override
  String get onb3Promise1Sub => 'Enough to make a difference';

  @override
  String get onb3Promise2Title => 'Completely private';

  @override
  String get onb3Promise2Sub => 'Only you can see your journey';

  @override
  String get onb3Promise3Title => 'No judgment';

  @override
  String get onb3Promise3Sub => 'Just listening and reflecting';

  @override
  String get onb3Cta => 'Enter WorkReflection';

  @override
  String get authLoginTitle => 'Welcome back';

  @override
  String get authRegisterTitle => 'Create account';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authNameLabel => 'Your name';

  @override
  String get authLoginBtn => 'Log in';

  @override
  String get authRegisterBtn => 'Register';

  @override
  String get authSwitchToRegister => 'No account? Register';

  @override
  String get authSwitchToLogin => 'Already have an account? Log in';

  @override
  String get authOrDivider => 'or';

  @override
  String get authGoogleBtn => 'Continue with Google';

  @override
  String homeGreeting(String name) {
    return 'Hi $name';
  }

  @override
  String get homeCheckinQuestion => 'What are you experiencing?';

  @override
  String get homeMoodStressed => 'I\'m stressed';

  @override
  String get homeMoodTired => 'I\'m tired and need rest';

  @override
  String get homeMoodOkay => 'I\'m doing okay';

  @override
  String get homeMoodHappy => 'I\'m happy';

  @override
  String get homeEyebrowSystem => 'System noticed';

  @override
  String get homeEyebrowSuggestion => 'Suggestion when tired';

  @override
  String get homeEyebrowInsight => 'Latest insight';

  @override
  String get homeLinkLearnMore => 'Learn more';

  @override
  String get homeSuggestionTitle => 'When you want to speak but choose silence';

  @override
  String get homeSuggestionMeta => 'VOICE · 5 min read';

  @override
  String get homeSuggestionProgress => '3/8 min';

  @override
  String get homeSuggestionStatus => 'Reading';

  @override
  String homeInsightSavedDate(String date) {
    return 'Saved $date';
  }

  @override
  String get understandGreeting => 'Career Snapshot';

  @override
  String get understandTitle => 'Understand';

  @override
  String get understandEyebrowNeed => 'What you\'re looking for';

  @override
  String get understandEyebrowSituations => 'Recurring situations';

  @override
  String get understandEyebrowSca => 'Current experience (SCA)';

  @override
  String get understandEyebrowHealth => 'Career Health Check';

  @override
  String get understandScaRole => 'Role clarity';

  @override
  String get understandScaVoice => 'Safety to speak up';

  @override
  String get understandScaMeaning => 'Sense of direction';

  @override
  String get understandStatusStable => 'Stable';

  @override
  String get understandStatusImproving => 'Improving';

  @override
  String get understandStatusUnrated => 'Unrated';

  @override
  String understandHealthReady(int n) {
    return 'You have $n reflections.';
  }

  @override
  String get understandHealthPrompt => 'Ready to see the big picture?';

  @override
  String get understandHealthCta => 'Start check';

  @override
  String understandSituationCount(int n) {
    return '$n times';
  }

  @override
  String get developGreeting => 'Development Map';

  @override
  String get developTitle => 'Develop';

  @override
  String get developEyebrowFocus => 'Current focus';

  @override
  String get developEyebrowPractices => 'Today\'s practices';

  @override
  String get developEyebrowOpportunity => 'Growth opportunity';

  @override
  String developStage(int x, int y) {
    return 'Stage $x / $y';
  }

  @override
  String get developStatusDone => 'Done';

  @override
  String get developStatusDoing => 'In progress';

  @override
  String get developStatusTodo => 'Not started';

  @override
  String get developWorkshopTag => 'Workshop';

  @override
  String get developWorkshopLink => 'Why now?';

  @override
  String get journeyGreeting => 'Career Memory';

  @override
  String get journeyTitle => 'Journey';

  @override
  String get journeyEyebrowStory => 'Your story';

  @override
  String journeyEyebrowMonth(int m) {
    return 'Month $m';
  }

  @override
  String journeyCaption(int m, int yyyy) {
    return 'Career Companion · Month $m, $yyyy';
  }

  @override
  String get journeyTypeMilestone => 'MILESTONE';

  @override
  String get journeyTypeStory => 'STORY';

  @override
  String get journeyTypeTheme => 'THEME';

  @override
  String get profileGreeting => 'Account';

  @override
  String get profileBadgePremium => 'PREMIUM MEMBER';

  @override
  String get profileBadgeMember => 'Member';

  @override
  String get profileStatStreak => 'Streak days';

  @override
  String get profileStatInsights => 'Saved insights';

  @override
  String get profileStatMilestones => 'Milestones';

  @override
  String get profileEyebrowSettings => 'Settings';

  @override
  String get profileSettingReminder => 'Daily reminder';

  @override
  String get profileSettingLanguage => 'Language';

  @override
  String get profileSettingExport => 'Export data';

  @override
  String get profileSettingLogout => 'Log out';

  @override
  String get profileLanguageValue => 'English';

  @override
  String get understandStatusNeedsAttention => 'Needs attention';

  @override
  String get understandNeedSuffix => '· Dominant need';

  @override
  String get understandNoSituations => 'No situations recorded yet.';

  @override
  String get homeInsightEmpty => 'No insights yet. Start your journey!';

  @override
  String get homeErrorLoadData => 'Could not load data.';

  @override
  String get homeRetry => 'Retry';

  @override
  String get homeCtaSurveyEyebrow => 'Work Reflection';

  @override
  String get homeCtaSurveyTitle => 'Take reflection survey';

  @override
  String get homeCtaSurveySubtitle =>
      'Look back at your work experience to understand yourself better.';

  @override
  String get homeCtaSurveyButton => 'Start now';

  @override
  String get homeCtaReportTitle => 'View latest report';

  @override
  String get homeCtaReportSubtitle =>
      'You have completed the reflection survey. View your results.';

  @override
  String get homeCtaReportButton => 'View report';

  @override
  String get homeCtaRetakeSurvey => 'Retake survey';

  @override
  String homeSystemNoticeQuote(int n, String label) {
    return '\"This is the ${n}th time you\'ve encountered a $label situation.\"';
  }

  @override
  String get developNoTheme => 'No development focus yet. Start your journey!';

  @override
  String get developNoPractices => 'No practices for today.';

  @override
  String get developErrorLoadData => 'Could not load data.';

  @override
  String get authValidatorName => 'Please enter your name';

  @override
  String get authValidatorEmail => 'Please enter your email';

  @override
  String get authValidatorPassword => 'Please enter your password';

  @override
  String get languageDialogTitle => 'Language';

  @override
  String get languageOptionVietnamese => 'Tiếng Việt';

  @override
  String get languageOptionEnglish => 'English';

  @override
  String get tabToday => 'Today';

  @override
  String get tabUnderstand => 'Understand';

  @override
  String get tabDevelop => 'Develop';

  @override
  String get tabJourney => 'Journey';

  @override
  String get tabProfile => 'Me';

  @override
  String get surveyIntroEyebrow => 'Career Health Check';

  @override
  String get surveyIntroBadgeFree => 'FREE';

  @override
  String get surveyIntroBadgePremium => 'PREMIUM';

  @override
  String get surveyIntroTitle => 'Career Health Check';

  @override
  String get surveyIntroBody =>
      'Answer honestly for the most accurate personal report.';

  @override
  String get surveyIntroFieldPosition => 'Job title';

  @override
  String get surveyIntroFieldExperience => 'Years of experience';

  @override
  String get surveyIntroFieldCompanyTenure => 'Time at company';

  @override
  String get surveyIntroFieldCompanySize => 'Company size';

  @override
  String get surveyIntroFieldDepartment => 'Department';

  @override
  String get surveyIntroCta => 'Start survey';

  @override
  String get surveyLayerStructure => 'Structure';

  @override
  String get surveyLayerCulture => 'Culture';

  @override
  String get surveyLayerActivity => 'Activity';

  @override
  String get surveyLayerEsi => 'Employee Satisfaction';

  @override
  String get surveyLayerEnps => 'Employee Engagement';

  @override
  String surveyProgress(int current, int total) {
    return '$current/$total';
  }

  @override
  String get surveyCompleteCta => 'Complete';

  @override
  String get surveyProcessingTitle => 'Creating your report…';

  @override
  String get surveyProcessingRetry => 'Retry';

  @override
  String get surveyProcessingError => 'An error occurred. Please try again.';

  @override
  String get reportTitle => 'Your Report';

  @override
  String get reportScoreLevelHigh => 'Excellent';

  @override
  String get reportScoreLevelGood => 'Good';

  @override
  String get reportScoreLevelWarning => 'Needs Attention';

  @override
  String get reportScoreLevelCritical => 'Needs Improvement';

  @override
  String get reportLayerStructure => 'Organisational Structure';

  @override
  String get reportLayerCulture => 'Work Culture';

  @override
  String get reportLayerActivity => 'Daily Activity';

  @override
  String get reportBottleneckTitle => 'Area needing most improvement';

  @override
  String get reportEsiTitle => 'Employee Satisfaction Index (ESI)';

  @override
  String get reportEnpsTitle => 'Employee Engagement (eNPS)';

  @override
  String get reportEnpsPromoter => 'Promoter';

  @override
  String get reportEnpsPassive => 'Passive';

  @override
  String get reportEnpsDetractor => 'Detractor';

  @override
  String get reportPremiumUpsell =>
      'Upgrade to Premium to see ESI, eNPS and deeper analysis.';

  @override
  String get reportActionPlanCta => '30-day plan';

  @override
  String get reportViewLatest => 'View latest report';

  @override
  String get reportViewHistory => 'View survey history';

  @override
  String get reportScaChartTitle => 'S-C-A Overview';

  @override
  String get reportAiPersonalizingLabel => 'Personalising your report…';

  @override
  String get reportAiModelSectionTitle => 'Your Work Model';

  @override
  String get reportAiReflectionSectionTitle => 'Personal Reflection';

  @override
  String get reportAiRelationshipSectionTitle => 'Work Relationships';

  @override
  String get surveyHistoryTitle => 'Survey History';

  @override
  String get surveyHistoryScoreLabel => 'Score';

  @override
  String get surveyHistoryTypeFree => 'Free';

  @override
  String get surveyHistoryTypePremium => 'Premium';

  @override
  String get surveyHistoryEmptyTitle => 'No surveys yet';

  @override
  String get surveyHistoryEmptyBody =>
      'Complete your first survey to see your history here.';

  @override
  String get surveyHistoryEmptyCta => 'Start survey';

  @override
  String get profileSurveyHistory => 'Survey History';

  @override
  String get actionPlanTitle => '30-day Plan';

  @override
  String actionPlanDay(int day) {
    return 'Day $day';
  }

  @override
  String get actionPlanReflection => 'Reflection question';

  @override
  String get surveyTtsToggle => 'Read question';

  @override
  String get journeyErrorCard => 'Could not load journey.';

  @override
  String get wsListTitle => 'Workshop';

  @override
  String get wsEmpty => 'No upcoming workshops';

  @override
  String get wsFree => 'Free';

  @override
  String get wsFullBadge => 'Full';

  @override
  String get wsRegister => 'Register';

  @override
  String get wsRegistered => 'Registered';

  @override
  String get wsAttended => 'Attended';

  @override
  String get wsCancelled => 'Cancelled';

  @override
  String get wsCheckin => 'Check-in';

  @override
  String wsCheckedInAt(String time) {
    return 'Checked in at $time';
  }

  @override
  String get wsResources => 'Resources';

  @override
  String get wsResourcesLocked =>
      'Resources available for registered attendees';

  @override
  String wsParticipants(int current, int max) {
    return '$current/$max participants';
  }

  @override
  String get wsLocation => 'Location';

  @override
  String get wsPaidDialogTitle => 'Complete payment on web';

  @override
  String get wsPaidDialogBody =>
      'Please complete payment on the WorkReflection website to register.';

  @override
  String get wsPaidDialogOk => 'Got it';

  @override
  String get wsRegisterSuccess => 'Registration successful!';

  @override
  String get wsRegisterError => 'Registration failed. Please try again.';

  @override
  String get wsCheckinTitle => 'Workshop check-in';

  @override
  String get wsCheckinScanHint => 'Scan the workshop QR code';

  @override
  String get wsCheckinManualLabel => 'Or enter check-in code';

  @override
  String get wsCheckinSubmit => 'Confirm';

  @override
  String get wsCheckinInvalidCode => 'Invalid code';

  @override
  String get wsCheckinNotFound => 'Workshop not found with this code';

  @override
  String get wsCheckinNotRegistered =>
      'You have not registered for this workshop';

  @override
  String get wsCheckinTooEarly =>
      'Check-in not open yet (opens 2 hours before start)';

  @override
  String get wsCheckinClosed => 'Check-in is closed';

  @override
  String get wsCheckinSuccess => 'Check-in successful!';

  @override
  String get wsCheckinError => 'Check-in failed. Please try again.';

  @override
  String get wsLinkCopied => 'Link copied';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get wsConsentTitle => 'Consent to image use';

  @override
  String get wsConsentBody =>
      'Do you consent to us using images of you from the workshop for communication purposes?';

  @override
  String get wsConsentAccept => 'Agree';

  @override
  String get wsConsentDecline => 'Decline';

  @override
  String get wsMyTitle => 'My Workshops';

  @override
  String get wsMyEmpty => 'You have not registered for any workshops';

  @override
  String get wsSurveyCta => 'Rate workshop';

  @override
  String get wsSurveyTitle => 'Rate workshop';

  @override
  String get wsSurveySubmit => 'Submit rating';

  @override
  String get wsSurveyThanks => 'Thank you for your rating!';

  @override
  String get wsSurveyDone => 'Rated';

  @override
  String get wsSurveyNone => 'No survey available for this workshop';

  @override
  String get wsSurveyError => 'Failed to submit. Please try again.';

  @override
  String get coachTitle => 'Coaching';

  @override
  String get coachAudienceYoung => 'Young professionals';

  @override
  String get coachAudienceManager => 'Managers';

  @override
  String coachSessionsFmt(int count, int minutes) {
    return '$count sessions × $minutes minutes';
  }

  @override
  String get coachClaimFree => 'Claim free package';

  @override
  String get coachClaimConfirmTitle => 'Claim coaching package';

  @override
  String coachClaimConfirmBody(String name) {
    return 'Do you want to claim the \"$name\" package?';
  }

  @override
  String get coachClaimSuccess => 'Coaching package activated!';

  @override
  String get coachClaimError => 'Unable to activate package. Please try again.';

  @override
  String get coachOurCoaches => 'Our coaches';

  @override
  String coachYearsExp(int years) {
    return '$years years of experience';
  }

  @override
  String get coachMyTitle => 'My coaching schedule';

  @override
  String get coachMyEmpty => 'You have no coaching sessions yet';

  @override
  String get coachPending => 'Pending scheduling';

  @override
  String get coachScheduled => 'Scheduled';

  @override
  String get coachCompleted => 'Completed';

  @override
  String get coachCancelledStatus => 'Cancelled';

  @override
  String coachSessionOf(int n, int total) {
    return 'Session $n/$total';
  }

  @override
  String get coachMeetingLink => 'Meeting link';

  @override
  String get coachWebNote => 'Scheduling and reviews are done on the web';

  @override
  String get coachViewMy => 'View my schedule';

  @override
  String get profileMyWorkshops => 'My Workshops';

  @override
  String get profileMyCoaching => 'My Coaching';

  @override
  String get developWorkshopSection => 'Development opportunities';

  @override
  String get developViewWorkshops => 'View all workshops';

  @override
  String get developViewCoaching => 'Explore coaching';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authForgotPasswordDialogTitle => 'Forgot password';

  @override
  String get authForgotPasswordDialogHint =>
      'Enter your email to receive a password reset link';

  @override
  String get authForgotPasswordSubmit => 'Send reset link';

  @override
  String get authForgotPasswordSuccess =>
      'Check your email to reset your password.';

  @override
  String get authForgotPasswordErrorInvalidEmail => 'Invalid email';

  @override
  String get authForgotPasswordError =>
      'Could not send email. Please try again.';

  @override
  String get profileSettingEditProfile => 'Edit Profile';

  @override
  String get profileSettingChangePassword => 'Change password';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordNewLabel => 'New password';

  @override
  String get changePasswordConfirmLabel => 'Confirm new password';

  @override
  String get changePasswordSubmit => 'Update password';

  @override
  String get changePasswordSuccess => 'Password updated successfully.';

  @override
  String get changePasswordErrorTooShort =>
      'Password must be at least 6 characters';

  @override
  String get changePasswordErrorMismatch => 'Passwords do not match';

  @override
  String get changePasswordErrorGeneric =>
      'Could not change password. Please try again.';

  @override
  String get changePasswordErrorSessionExpired =>
      'Session expired. Please log in again.';

  @override
  String get profileEditTitle => 'Edit Profile';

  @override
  String get profileEditEyebrow => 'Personal Information';

  @override
  String get profileEditFieldDisplayName => 'Display name';

  @override
  String get profileEditFieldFullName => 'Full name';

  @override
  String get profileEditFieldPhone => 'Phone number';

  @override
  String get profileEditFieldCompanyName => 'Company name';

  @override
  String get profileEditFieldPosition => 'Job title';

  @override
  String get profileEditFieldCompanySize => 'Company size';

  @override
  String get profileEditFieldExperience => 'Work experience';

  @override
  String get profileEditFieldTenure => 'Time at company';

  @override
  String get profileEditFieldDepartment => 'Department';

  @override
  String get profileEditSave => 'Save changes';

  @override
  String get profileEditSaveSuccess => 'Profile updated.';

  @override
  String get profileEditSaveError => 'Could not save. Please try again.';

  @override
  String get profileEditAvatarNote =>
      'Change your avatar on the web at workreflection.app';

  @override
  String get profileEditPositionStaff => 'Staff';

  @override
  String get profileEditPositionTeamLead => 'Team Lead';

  @override
  String get profileEditPositionManager => 'Manager';

  @override
  String get profileEditPositionDirector => 'Director';

  @override
  String get profileEditPositionCLevel => 'C-Level';

  @override
  String get profileEditPositionIntern => 'Intern';

  @override
  String get profileEditPositionFreelancer => 'Freelancer';

  @override
  String get profileEditPositionOther => 'Other';

  @override
  String get profileEditCompanySize1to10 => '1–10 people';

  @override
  String get profileEditCompanySize11to50 => '11–50 people';

  @override
  String get profileEditCompanySize51to200 => '51–200 people';

  @override
  String get profileEditCompanySize201to500 => '201–500 people';

  @override
  String get profileEditCompanySize501to1000 => '501–1000 people';

  @override
  String get profileEditCompanySize1000Plus => '1000+ people';

  @override
  String get profileEditExpLess1 => 'Under 1 year';

  @override
  String get profileEditExp1to3 => '1–3 years';

  @override
  String get profileEditExp3to5 => '3–5 years';

  @override
  String get profileEditExp5to10 => '5–10 years';

  @override
  String get profileEditExp10Plus => '10+ years';

  @override
  String get profileEditTenureLess6m => 'Under 6 months';

  @override
  String get profileEditTenure6mto1y => '6 months–1 year';

  @override
  String get profileEditTenure1to2 => '1–2 years';

  @override
  String get profileEditTenure2to5 => '2–5 years';

  @override
  String get profileEditTenure5Plus => '5+ years';

  @override
  String get profileEditDeptMarketing => 'Marketing';

  @override
  String get profileEditDeptAccounting => 'Accounting';

  @override
  String get profileEditDeptSales => 'Sales';

  @override
  String get profileEditDeptPurchasing => 'Purchasing';

  @override
  String get profileEditDeptHr => 'HR';

  @override
  String get profileEditDeptIt => 'IT';

  @override
  String get profileEditDeptProduction => 'Production';

  @override
  String get profileEditDeptAdmin => 'Admin';

  @override
  String get profileEditDeptOther => 'Other';

  @override
  String get profileEditSelectHint => 'Select...';

  @override
  String get insightsTitle => 'All insights';

  @override
  String get insightsEmpty => 'No insights yet. Start your journey!';

  @override
  String insightSavedDate(String date) {
    return 'Saved $date';
  }

  @override
  String get understandViewAllInsights => 'View all insights';

  @override
  String get profileCheckinHistory => 'Last 30 days';

  @override
  String get surveyGuideEyebrow => 'Guide';

  @override
  String get surveyGuideFreeTitle =>
      'Work Reflection – Reflect on your personal work experience';

  @override
  String get surveyGuideFreeIntro =>
      'Welcome to the journey of looking back at your personal work experience.';

  @override
  String get surveyGuideFreeDescription =>
      'Work Reflection is a tool that helps professionals systematically look back at their work environment and experience.';

  @override
  String get surveyGuideFreeDetails =>
      'The free version includes 15 questions for a quick survey. Upon completion, you will receive an overview reflection report, helping you:';

  @override
  String get surveyGuideFreeBenefit1 => 'See the big picture.';

  @override
  String get surveyGuideFreeBenefit2 => 'Identify areas for adjustment.';

  @override
  String get surveyGuideFreeBenefit3 =>
      'Have a clearer basis for thinking about the next step in your career.';

  @override
  String get surveyGuideFreeNote =>
      'Work Reflection is not intended to evaluate people, but to help you understand how the work system operates around you.';

  @override
  String get surveyGuideFreeClosing =>
      'The free version is suitable when you want to start looking back at your work gently, before going deeper with advanced analysis.';

  @override
  String get surveyGuidePremiumTitle =>
      'Work Reflection Premium – Deep reflection for clear orientation';

  @override
  String get surveyGuidePremiumIntro =>
      'Work Reflection Premium is an advanced analysis version for professionals who want to look back at their work comprehensively and in depth.';

  @override
  String get surveyGuidePremiumDetails => 'The Premium version helps you:';

  @override
  String get surveyGuidePremiumBenefit1 =>
      'Analyze in detail the clarity of roles, expectations, and coordination mechanisms';

  @override
  String get surveyGuidePremiumBenefit2 =>
      'Identify the quality of dialogue, feedback, and psychological safety in the work environment';

  @override
  String get surveyGuidePremiumBenefit3 =>
      'Evaluate the level of development, motivation, and fit between individual – work – organization';

  @override
  String get surveyGuidePremiumBenefit4 =>
      'Identify core bottlenecks rather than just seeing surface symptoms';

  @override
  String get surveyGuidePremiumClosing =>
      'Work Reflection Premium gives you a clearer framework to make your own decisions.';

  @override
  String get surveyGuidePremiumReportDesc =>
      'Upon completion, you will receive an in-depth reflection report with:';

  @override
  String get surveyGuidePremiumReport1 => 'Scores for each group of factors';

  @override
  String get surveyGuidePremiumReport2 =>
      'Interpretation of the meaning of each area';

  @override
  String get surveyGuidePremiumReport3 =>
      'Suggestions for thinking and action orientation for the next phase';

  @override
  String get surveyGuideCta => 'Start';

  @override
  String get layerDetailViewDetail => 'View details';

  @override
  String get layerDetailOverallScore => 'Overall Score';

  @override
  String get layerDetailNoData => 'No data available';

  @override
  String get layerDetailNoDataBody =>
      'Complete a survey to see sub-component breakdown.';

  @override
  String layerDetailResponses(int count) {
    return '$count responses';
  }

  @override
  String get layerDetailScoreGood => 'Good';

  @override
  String get layerDetailScoreWarning => 'Needs improvement';

  @override
  String get layerDetailScoreCritical => 'Needs action';

  @override
  String get esiAnalysisTitle => 'Satisfaction & Experience Picture';

  @override
  String get esiAnalysisEsiScore => 'ESI Score';

  @override
  String get esiAnalysisEnpsScore => 'eNPS Score';

  @override
  String get esiAnalysisPillarsTitle => 'ESI Pillars Breakdown';

  @override
  String get esiAnalysisNoData => 'No detailed ESI data yet';

  @override
  String get esiAnalysisNoDataBody =>
      'Complete a Premium survey to see ESI pillar breakdown.';

  @override
  String get esiAnalysisEnpsPromoter => 'Promoter';

  @override
  String get esiAnalysisEnpsPassive => 'Passive';

  @override
  String get esiAnalysisEnpsDetractor => 'Detractor';

  @override
  String get esiPillarCompensation => 'Compensation & benefits';

  @override
  String get esiPillarGrowth => 'Growth opportunities';

  @override
  String get esiPillarFairness => 'Fairness & transparency';

  @override
  String get esiPillarSupport => 'Manager support & recognition';

  @override
  String get esiPillarColleagues => 'Colleagues & work environment';

  @override
  String get subCompRoleExpect => 'Role expectations';

  @override
  String get subCompCollabRules => 'Collaboration rules';

  @override
  String get subCompCommChannels => 'Communication channels';

  @override
  String get subCompTrust => 'Trust';

  @override
  String get subCompPsychSafety => 'Psychological safety';

  @override
  String get subCompFeedbackDialogue => 'Feedback & dialogue';

  @override
  String get subCompGoalAlignment => 'Goal alignment';

  @override
  String get subCompExecutionRhythm => 'Execution rhythm';

  @override
  String get subCompRetrospective => 'Retrospective habit';

  @override
  String get subCompContinuousImprove => 'Continuous improvement';

  @override
  String get subCompCompensationIncome => 'Income';

  @override
  String get subCompCompensationBenefits => 'Benefits';

  @override
  String get subCompGrowthCareer => 'Career growth';

  @override
  String get subCompFairnessEvaluation => 'Fair evaluation';

  @override
  String get subCompSupportManagement => 'Management support';

  @override
  String get subCompSupportFeedback => 'Feedback support';

  @override
  String get subCompSupportCollaboration => 'Collaboration support';

  @override
  String get subCompSupportLeadership => 'Leadership support';

  @override
  String get roadmapTitle => 'Action Roadmap';

  @override
  String get roadmapSubtitle =>
      'Track and execute your personal development plan';

  @override
  String get roadmapSelectReport => 'Select report...';

  @override
  String get roadmapNoPremiumReports => 'No Premium reports yet';

  @override
  String get roadmapNoPremiumReportsBody =>
      'Complete a Premium survey to unlock your personal action roadmap.';

  @override
  String get roadmapStartSurvey => 'Start survey';

  @override
  String get roadmapNoActionsForReport => 'No action data for this report yet.';

  @override
  String get roadmapProgressLabel => 'Overall progress';

  @override
  String get roadmapDayHeader7 => 'Initiation';

  @override
  String get roadmapDayHeader14 => 'Experimentation';

  @override
  String get roadmapDayHeader30 => 'Specialisation';

  @override
  String get roadmapLayerStructure => 'Structure';

  @override
  String get roadmapLayerCulture => 'Culture';

  @override
  String get roadmapLayerActivity => 'Activity';

  @override
  String get roadmapAddCustomTask => 'Add action';

  @override
  String get roadmapAddTaskTitle => 'Add custom action';

  @override
  String get roadmapEditTaskTitle => 'Edit action';

  @override
  String get roadmapTaskTitleLabel => 'Title';

  @override
  String get roadmapTaskDescLabel => 'Description (optional)';

  @override
  String get roadmapTaskDueDateLabel => 'Due date (optional)';

  @override
  String get roadmapTaskTitleHint => 'e.g. 1:1 with manager';

  @override
  String get roadmapTaskDescHint => 'Additional notes...';

  @override
  String get roadmapTaskAdd => 'Add';

  @override
  String get roadmapTaskSave => 'Save';

  @override
  String get roadmapTaskAdded => 'Action added';

  @override
  String get roadmapTaskUpdated => 'Action updated';

  @override
  String get roadmapTaskDeleted => 'Action deleted';

  @override
  String get roadmapErrorToggle => 'Could not update. Please try again.';

  @override
  String get roadmapErrorAdd => 'Could not add action. Please try again.';

  @override
  String get roadmapErrorEdit => 'Could not edit. Please try again.';

  @override
  String get roadmapErrorDelete => 'Could not delete. Please try again.';

  @override
  String get roadmapCoachSectionTitle => 'Invite a coaching partner';

  @override
  String get roadmapInviteCoach => 'Invite coach';

  @override
  String get roadmapChooseCoach => 'Choose a coach to invite';

  @override
  String get roadmapNoCoachesAvailable => 'No coaches available';

  @override
  String get roadmapCoachPending => 'Pending';

  @override
  String get roadmapCoachAccepted => 'Accepted';

  @override
  String get roadmapCoachRevoked => 'Revoked';

  @override
  String get roadmapCoachInvited => 'Invitation sent';

  @override
  String get roadmapErrorInviteCoach => 'Could not send invitation.';

  @override
  String get roadmapNoCoachs => 'You have not invited any coaches yet.';

  @override
  String get roadmapActivityLog => 'Activity log';

  @override
  String get roadmapActivityEmpty => 'No completed activities yet.';

  @override
  String get roadmapActivityContent => 'Content';

  @override
  String get roadmapActivityLayer => 'Layer';

  @override
  String get roadmapActivityDate => 'Date';

  @override
  String get roadmapRenameReport => 'Name this report';

  @override
  String get roadmapNicknameLabel => 'Report name';

  @override
  String get roadmapNicknameHint => 'e.g. July assessment';

  @override
  String get roadmapNicknameSaved => 'Name updated.';

  @override
  String get roadmapNicknameError => 'Could not save name.';

  @override
  String get roadmapScoreHigh => 'High – maintain';

  @override
  String get roadmapScoreGood => 'Good – small improvements';

  @override
  String get roadmapScoreWarning => 'Needs improvement';

  @override
  String get roadmapScoreCritical => 'Needs immediate action';

  @override
  String get roadmapEntryLink => 'Development roadmap';

  @override
  String get roadmapProfileLink => 'Action roadmap';
}
