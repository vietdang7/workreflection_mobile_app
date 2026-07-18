import '../../l10n/app_localizations.dart';

typedef ProfileOption = ({String value, String label});

List<ProfileOption> positionOptions(AppLocalizations l10n) => [
  (value: 'staff', label: l10n.profileEditPositionStaff),
  (value: 'team_lead', label: l10n.profileEditPositionTeamLead),
  (value: 'manager', label: l10n.profileEditPositionManager),
  (value: 'director', label: l10n.profileEditPositionDirector),
  (value: 'c_level', label: l10n.profileEditPositionCLevel),
  (value: 'intern', label: l10n.profileEditPositionIntern),
  (value: 'freelancer', label: l10n.profileEditPositionFreelancer),
  (value: 'other', label: l10n.profileEditPositionOther),
];

List<ProfileOption> workExperienceOptions(AppLocalizations l10n) => [
  (value: 'less_1', label: l10n.profileEditExpLess1),
  (value: '1_3', label: l10n.profileEditExp1to3),
  (value: '3_5', label: l10n.profileEditExp3to5),
  (value: '5_10', label: l10n.profileEditExp5to10),
  (value: '10_plus', label: l10n.profileEditExp10Plus),
];

List<ProfileOption> companyTenureOptions(AppLocalizations l10n) => [
  (value: 'less_6m', label: l10n.profileEditTenureLess6m),
  (value: '6m_1y', label: l10n.profileEditTenure6mto1y),
  (value: '1_2', label: l10n.profileEditTenure1to2),
  (value: '2_5', label: l10n.profileEditTenure2to5),
  (value: '5_plus', label: l10n.profileEditTenure5Plus),
];

List<ProfileOption> companySizeOptions(AppLocalizations l10n) => [
  (value: '1_10', label: l10n.profileEditCompanySize1to10),
  (value: '11_50', label: l10n.profileEditCompanySize11to50),
  (value: '51_200', label: l10n.profileEditCompanySize51to200),
  (value: '201_500', label: l10n.profileEditCompanySize201to500),
  (value: '501_1000', label: l10n.profileEditCompanySize501to1000),
  (value: '1000_plus', label: l10n.profileEditCompanySize1000Plus),
];

List<ProfileOption> departmentOptions(AppLocalizations l10n) => [
  (value: 'marketing', label: l10n.profileEditDeptMarketing),
  (value: 'accounting', label: l10n.profileEditDeptAccounting),
  (value: 'sales', label: l10n.profileEditDeptSales),
  (value: 'purchasing', label: l10n.profileEditDeptPurchasing),
  (value: 'hr', label: l10n.profileEditDeptHr),
  (value: 'it', label: l10n.profileEditDeptIt),
  (value: 'production', label: l10n.profileEditDeptProduction),
  (value: 'admin', label: l10n.profileEditDeptAdmin),
  (value: 'other', label: l10n.profileEditDeptOther),
];
