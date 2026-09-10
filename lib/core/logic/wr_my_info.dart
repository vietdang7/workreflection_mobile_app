// "Thông tin của bạn" — mockup Sprint 2 bản (4), `MY_INFO_FIELDS`/`screenMyInfo`.
//
// Bảy trường người dùng đã rải ra ba chỗ khác nhau (Sửa hồ sơ, Khảo sát tổ
// chức, Thông tin công việc). Màn "Thông tin của bạn" chỉ GỘP chúng lại để xem
// và sửa ở một chỗ — nó KHÔNG phải chỗ lưu thứ tám.
//
// Vì thế mỗi trường phải nói rõ nó nằm ở bảng nào ([MyInfoStore]): bốn trường
// dùng chung cột với web ở `cc_profiles`, ba trường còn lại là của riêng app ở
// `wr_mobile_profiles`. Ghi nhầm bảng thì màn Sửa hồ sơ và màn này hiện hai giá
// trị khác nhau cho cùng một câu hỏi.
//
// ⚠ Danh sách lựa chọn của bốn trường chung LẤY NGUYÊN từ `profile_options.dart`,
//   không lấy theo mockup. Mockup rút gọn (ví dụ "Vị trí" chỉ còn ba mức), mà
//   dữ liệu đang lưu là mã tám mức của web — đổi danh sách là làm mồ côi giá trị
//   của những người đã điền, và họ sẽ thấy "Chưa có" ở một trường mình đã khai.

import '../../l10n/app_localizations.dart';
import '../l10n/wr_tr.dart';
import 'profile_options.dart';

/// Trường này lưu ở bảng nào. Quyết định luôn đường ghi: [ccProfile] đi qua
/// `updateCcProfile`, [mobileProfile] đi qua `saveMyInfo`.
enum MyInfoStore { ccProfile, mobileProfile }

typedef MyInfoField = ({
  /// Tên CỘT trong bảng, không phải nhãn. Dùng thẳng làm khoá khi ghi.
  String column,
  String label,
  String group,
  MyInfoStore store,
  List<ProfileOption> options,
});

// Ba nhóm, đúng thứ tự của mockup.
String get kMyInfoGroupAboutYou => tr('Về bạn', 'About you');
String get kMyInfoGroupCompany => tr('Công ty của bạn', 'Your company');
String get kMyInfoGroupWork => tr('Công việc hiện tại', 'Your current role');

/// Thành phố đang làm việc. Trường của riêng app.
List<ProfileOption> myInfoCityOptions() => [
  (value: 'hcm', label: 'TP.HCM'),
  (value: 'hanoi', label: tr('Hà Nội', 'Hanoi')),
  (value: 'other', label: tr('Tỉnh thành khác', 'Another province or city')),
];

/// Ngành của công ty — nguyên văn tám lựa chọn của mockup (`ORG_QUESTIONS[0]`).
List<ProfileOption> myInfoIndustryOptions() => [
  (value: 'tech', label: tr('Công nghệ', 'Technology')),
  (value: 'finance', label: tr('Tài chính, ngân hàng', 'Finance and banking')),
  (value: 'manufacturing', label: tr('Sản xuất', 'Manufacturing')),
  (value: 'retail', label: tr('Bán lẻ, dịch vụ', 'Retail and services')),
  (value: 'education', label: tr('Giáo dục', 'Education')),
  (value: 'healthcare', label: tr('Y tế', 'Healthcare')),
  (value: 'construction', label: tr('Xây dựng, bất động sản', 'Construction and property')),
  (value: 'other', label: tr('Khác', 'Other')),
];

/// Loại hình công ty (`ORG_QUESTIONS[2]`).
List<ProfileOption> myInfoCompanyTypeOptions() => [
  (value: 'vn', label: tr('Doanh nghiệp Việt Nam', 'Vietnamese company')),
  (value: 'fdi', label: tr('Công ty nước ngoài (FDI)', 'Foreign-invested company (FDI)')),
  (value: 'startup', label: 'Startup'),
  (value: 'state', label: tr('Nhà nước', 'State-owned')),
];

/// Bảy trường, đúng thứ tự và đúng nhóm của mockup.
List<MyInfoField> myInfoFields(AppLocalizations l10n) => [
  (
    column: 'total_work_experience',
    label: tr('Số năm kinh nghiệm', 'Years of experience'),
    group: kMyInfoGroupAboutYou,
    store: MyInfoStore.ccProfile,
    options: workExperienceOptions(l10n),
  ),
  (
    column: 'city',
    label: tr('Thành phố', 'City'),
    group: kMyInfoGroupAboutYou,
    store: MyInfoStore.mobileProfile,
    options: myInfoCityOptions(),
  ),
  (
    column: 'org_industry',
    label: tr('Ngành', 'Industry'),
    group: kMyInfoGroupCompany,
    store: MyInfoStore.mobileProfile,
    options: myInfoIndustryOptions(),
  ),
  (
    column: 'company_size',
    label: tr('Quy mô công ty', 'Company size'),
    group: kMyInfoGroupCompany,
    store: MyInfoStore.ccProfile,
    options: companySizeOptions(l10n),
  ),
  (
    column: 'org_company_type',
    label: tr('Loại hình công ty', 'Company type'),
    group: kMyInfoGroupCompany,
    store: MyInfoStore.mobileProfile,
    options: myInfoCompanyTypeOptions(),
  ),
  (
    column: 'department',
    label: tr('Mảng công việc', 'Function'),
    group: kMyInfoGroupWork,
    store: MyInfoStore.ccProfile,
    options: departmentOptions(l10n),
  ),
  (
    column: 'position',
    label: tr('Vị trí', 'Position'),
    group: kMyInfoGroupWork,
    store: MyInfoStore.ccProfile,
    options: positionOptions(l10n),
  ),
];

/// Các nhóm theo thứ tự xuất hiện, không lặp.
List<String> myInfoGroups(List<MyInfoField> fields) {
  final seen = <String>[];
  for (final f in fields) {
    if (!seen.contains(f.group)) seen.add(f.group);
  }
  return seen;
}

/// Nhãn hiện ra cho giá trị đang lưu.
///
/// Trả về null khi trường còn trống. Giá trị lạ (mã cũ đã bỏ khỏi danh sách,
/// hoặc chữ người dùng gõ tay bên web) được trả về NGUYÊN VĂN chứ không coi là
/// trống: người đó có khai, chỉ là app không biết dịch mã — nói "Chưa có" là
/// nói sai và còn xui họ khai đè lên.
String? myInfoLabelFor(MyInfoField field, String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  for (final o in field.options) {
    if (o.value == value) return o.label;
  }
  return value;
}

/// Số trường đã điền. Dùng cho dòng "n/7" ở màn Hồ sơ.
int myInfoFilledCount(
  List<MyInfoField> fields,
  String? Function(MyInfoField) read,
) {
  var n = 0;
  for (final f in fields) {
    final v = read(f);
    if (v != null && v.trim().isNotEmpty) n++;
  }
  return n;
}
