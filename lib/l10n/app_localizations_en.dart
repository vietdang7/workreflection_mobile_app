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
}
