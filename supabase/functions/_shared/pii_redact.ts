// Khử thông tin định danh cá nhân (PII) trước khi gửi chữ sang DeepSeek.
//
// ---------------------------------------------------------------------------
// VÌ SAO CÓ FILE NÀY
//
// JD/CV người dùng tải lên được bóc chữ rồi gửi sang DeepSeek (`wr-doc-analyze`
// để phân tích, `wr-chat` để trích nguyên văn khi trò chuyện). Với CV, mấy dòng
// đầu trang gần như luôn là họ tên · số điện thoại · email · địa chỉ nhà — đúng
// phần model không cần để hiểu năng lực của người đó. Guideline 5.1.1(i): gửi
// gì sang bên thứ ba thì phải tối thiểu.
//
// ---------------------------------------------------------------------------
// HAI LỚP, THEO THỨ TỰ ĐÁNG TIN
//
//   1. Danh tính THẬT của chính người dùng (`cc_profiles`: full_name · email ·
//      phone). Máy chủ biết sẵn mấy chuỗi này, nên xoá đúng chúng ở MỌI chỗ
//      trong văn bản — kể cả bản không dấu, viết hoa, số điện thoại có dấu
//      cách. Đây là lớp chắc nhất, không phải đoán.
//   2. Mẫu nhận diện: email, số điện thoại VN và quốc tế, số CCCD/CMND/hộ
//      chiếu, ngày sinh có nhãn, địa chỉ có nhãn, liên kết mạng xã hội cá nhân,
//      họ tên có nhãn hoặc ở dòng tiêu đề đầu CV, và tên NGƯỜI KHÁC viết lẫn
//      trong câu (sau xưng hô "anh/chị/sếp…", hoặc cụm Họ + Tên đệm + Tên).
//
// Lớp 2 là heuristic, KHÔNG hứa bắt được 100%: một địa chỉ không nhãn nằm giữa
// trang, hay tên người khác (người tham chiếu) viết trơn, có thể lọt. Vì thế
// chữ công bố cho người dùng chỉ được nói "loại bỏ các thông tin nhận diện
// được", không được nói "sạch hoàn toàn".
//
// Bản GỐC vẫn lưu nguyên ở `wr_context_documents.extracted_text` (của riêng
// người dùng, có RLS) — chỉ bản gửi đi mới đi qua đây.
// ---------------------------------------------------------------------------

// deno-lint-ignore-file no-explicit-any

export const PII_TAGS = {
  name: '[HỌ TÊN]',
  email: '[EMAIL]',
  phone: '[SỐ ĐIỆN THOẠI]',
  id: '[SỐ ĐỊNH DANH]',
  dob: '[NGÀY SINH]',
  address: '[ĐỊA CHỈ]',
  link: '[LIÊN KẾT CÁ NHÂN]',
} as const;

export type PiiKind = keyof typeof PII_TAGS;

export interface PiiIdentity {
  fullName?: string | null;
  email?: string | null;
  phone?: string | null;
}

export interface RedactOptions {
  /// Tài liệu là CV: bật thêm heuristic đầu trang (dòng họ tên, dòng địa chỉ
  /// không nhãn). JD không bật — dòng đầu JD là chức danh, không phải tên người.
  isCv?: boolean;
  identity?: PiiIdentity;
}

export interface RedactResult {
  text: string;
  /// Số chỗ đã thay theo từng loại — để ghi log, KHÔNG kèm nội dung.
  counts: Record<PiiKind, number>;
}

/// Bỏ dấu tiếng Việt (kể cả đ/Đ) để so khớp bản "Nguyen Van An".
export function stripDiacritics(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D');
}

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/// Ranh giới chữ có tính chữ Việt: `\b` của JS không hiểu "Ă", "ệ"...
const L = '\\p{L}\\p{N}';
const before = `(?<![${L}])`;
const after = `(?![${L}])`;

function emptyCounts(): Record<PiiKind, number> {
  return { name: 0, email: 0, phone: 0, id: 0, dob: 0, address: 0, link: 0 };
}

function replaceCount(
  text: string,
  re: RegExp,
  kind: PiiKind,
  counts: Record<PiiKind, number>,
  replacer?: (m: string, ...g: any[]) => string | null,
): string {
  return text.replace(re, (m: string, ...g: any[]) => {
    const out = replacer ? replacer(m, ...g) : PII_TAGS[kind];
    if (out === null || out === m) return m;
    counts[kind]++;
    return out;
  });
}

// ── Lớp 1: danh tính thật ────────────────────────────────────────────────

/// Regex khớp một họ tên ở mọi biến thể dấu cách / hoa thường, cả bản có dấu
/// lẫn không dấu. Null khi tên quá ngắn để thay an toàn (một chữ "An" sẽ xoá
/// nhầm cả "An toàn").
function nameRegex(fullName: string): RegExp | null {
  const tokens = fullName.normalize('NFC').trim().split(/\s+/).filter(Boolean);
  if (tokens.length < 2 || tokens.join('').length < 4) return null;
  const variants = new Set<string>([
    tokens.map(escapeRe).join('\\s+'),
    tokens.map((t) => escapeRe(stripDiacritics(t))).join('\\s+'),
  ]);
  return new RegExp(`${before}(?:${[...variants].join('|')})${after}`, 'giu');
}

/// Regex khớp đúng một số điện thoại dù viết liền, có dấu cách, chấm, gạch,
/// hay đổi đầu 0 ↔ +84.
function phoneRegex(phone: string): RegExp | null {
  let digits = phone.replace(/\D/g, '');
  if (digits.startsWith('84') && digits.length >= 11) digits = digits.slice(2);
  if (digits.startsWith('0')) digits = digits.slice(1);
  if (digits.length < 8) return null;
  const sep = '[\\s.\\-()]*';
  const body = digits.split('').join(sep);
  return new RegExp(`(?<!\\d)(?:(?:\\+?\\(?84\\)?${sep})|0${sep})?${body}(?!\\d)`, 'g');
}

function redactIdentity(
  text: string,
  id: PiiIdentity,
  counts: Record<PiiKind, number>,
): string {
  let t = text;
  const email = id.email?.trim();
  if (email && email.includes('@')) {
    t = replaceCount(t, new RegExp(escapeRe(email), 'gi'), 'email', counts);
  }
  const phone = id.phone?.trim();
  if (phone) {
    const re = phoneRegex(phone);
    if (re) t = replaceCount(t, re, 'phone', counts);
  }
  const name = id.fullName?.trim();
  if (name) {
    const re = nameRegex(name);
    if (re) t = replaceCount(t, re, 'name', counts);
  }
  return t;
}

// ── Lớp 2: mẫu nhận diện ─────────────────────────────────────────────────

const EMAIL_RE = /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/g;

/// Liên kết tới hồ sơ cá nhân. Trang công ty trong JD (abc.com.vn) giữ nguyên.
const PERSONAL_LINK_RE = new RegExp(
  '(?:https?:\\/\\/)?(?:www\\.|m\\.|vn\\.)?' +
    '(?:facebook\\.com|fb\\.com|fb\\.me|linkedin\\.com\\/in|zalo\\.me|t\\.me|' +
    'telegram\\.me|instagram\\.com|tiktok\\.com|twitter\\.com|x\\.com|' +
    'github\\.com|gitlab\\.com|behance\\.net|dribbble\\.com|medium\\.com\\/@|' +
    'youtube\\.com\\/(?:@|c\\/|channel\\/|user\\/))' +
    '[^\\s,;)\\]>"\']*',
  'gi',
);

/// Nhãn đứng trước một số định danh. Có nhãn thì bắt cả số ngắn (CMND 9 số,
/// hộ chiếu chữ + số).
const ID_LABELLED_RE = new RegExp(
  `${before}(CCCD|CMND|CMT|CCCD\\/CMND|CMND\\/CCCD|Căn cước(?: công dân)?|` +
    `Chứng minh(?: nhân dân| thư)?|Số định danh(?: cá nhân)?|Hộ chiếu|Passport(?: No\\.?)?|` +
    `ID card|National ID|ID No\\.?|Mã số thuế cá nhân|MST cá nhân|` +
    `Số BHXH|Số sổ BHXH|Social security(?: number)?)` +
    `(\\s*(?:số|No\\.?|number|#)?\\s*[:：.\\-]?\\s*)([A-Z]{0,2}\\d[\\d\\s.]{5,16}\\d)`,
  'giu',
);

/// 12 số liền không nhãn: số CCCD gắn chip. Không ai viết doanh số hay năm
/// thành 12 chữ số dính nhau.
const ID_BARE_RE = /(?<![\d.,])\d{12}(?![\d.,])/g;

/// Số điện thoại Việt Nam: 0 / 84 / +84 / (+84), rồi 9–10 số, cho phép dấu
/// cách · chấm · gạch giữa các nhóm.
const VN_PHONE_RE =
  /(?<![\d\w])(?:\(?\+?84\)?[\s.\-]?(?:\(0\))?|0)[\s.\-]?[1-9](?:[\s.\-]?\d){7,9}(?![\d])/g;

/// Số quốc tế phải có dấu "+" đầu — không có "+" thì là năm, mã, doanh số.
const INTL_PHONE_RE = /(?<![\w+])\+\d{1,3}(?:[\s.\-]?\(?\d{1,4}\)?){2,5}(?![\d])/g;

function digitCount(s: string): number {
  return s.replace(/\D/g, '').length;
}

const DATE_VALUE =
  '(?:\\d{1,2}\\s*[\\/\\-.]\\s*\\d{1,2}\\s*[\\/\\-.]\\s*\\d{2,4}' +
  '|\\d{1,2}\\s+tháng\\s+\\d{1,2}(?:\\s*,?\\s*năm\\s+\\d{4})?' +
  '|\\d{1,2}(?:st|nd|rd|th)?\\s+[A-Za-z]{3,9}\\.?,?\\s+\\d{4}' +
  '|[A-Za-z]{3,9}\\.?\\s+\\d{1,2}(?:st|nd|rd|th)?,?\\s+\\d{4}' +
  '|\\d{4}\\s*[\\/\\-.]\\s*\\d{1,2}\\s*[\\/\\-.]\\s*\\d{1,2}' +
  '|\\d{4})';

const DOB_RE = new RegExp(
  `${before}(Ngày(?:,? tháng,?)? (?:năm )?sinh|Sinh ngày|Năm sinh|NS|DOB|D\\.O\\.B\\.?|` +
    `Date of birth|Birth ?date|Birthday|Born(?: on)?)` +
    `(\\s*[:：\\-]?\\s*)(${DATE_VALUE})`,
  'giu',
);

/// Nhãn địa chỉ cá nhân. "Địa chỉ làm việc / công ty / văn phòng" KHÔNG phải
/// địa chỉ người, giữ lại (JD cần nó để nói nơi làm việc).
const ADDRESS_LABEL_RE = new RegExp(
  `^([\\t >•*\\-–]*)(Địa chỉ(?! (?:làm việc|công ty|văn phòng|cơ quan|nơi làm))` +
    `(?: (?:thường trú|tạm trú|liên hệ|nhà|hiện tại|cư trú|liên lạc))?|` +
    `Thường trú|Tạm trú|Nơi ở(?: hiện (?:tại|nay))?|Chỗ ở(?: hiện (?:tại|nay))?|` +
    `Hộ khẩu(?: thường trú)?|Quê quán|Nguyên quán|Nơi sinh|` +
    `(?:Home |Permanent |Current |Residential |Mailing )?Address|Hometown|Place of birth)` +
    `(\\s*[:：]\\s*)(.+)$`,
  'gimu',
);

/// Địa chỉ có nhãn nằm GIỮA dòng ("Email: … | Địa chỉ: …") hoặc trong chữ bị
/// bóc thành một dòng dài (PDF không đánh dấu xuống dòng — lỗi thật 20/10/2026).
/// Giá trị dừng ở dấu "|", xuống dòng, hoặc ngay trước nhãn kế tiếp
/// ("SĐT:", "Ngày sinh:", "MỤC TIÊU …"), tối đa 140 ký tự.
/// Nhãn địa chỉ cá nhân, dài trước ngắn sau để "Địa chỉ thường trú" thắng
/// "Địa chỉ". Không gồm "Địa chỉ làm việc / công ty" — đó là nơi làm việc.
const ADDRESS_LABELS = [
  'Địa chỉ thường trú', 'Địa chỉ tạm trú', 'Địa chỉ liên hệ', 'Địa chỉ liên lạc',
  'Địa chỉ hiện tại', 'Địa chỉ cư trú', 'Địa chỉ nhà', 'Địa chỉ',
  'Hộ khẩu thường trú', 'Hộ khẩu', 'Thường trú', 'Tạm trú',
  'Nơi ở hiện tại', 'Nơi ở hiện nay', 'Nơi ở', 'Chỗ ở hiện tại', 'Chỗ ở',
  'Quê quán', 'Nguyên quán', 'Nơi sinh',
  'Residential Address', 'Permanent Address', 'Current Address', 'Mailing Address',
  'Home Address', 'Address', 'Hometown', 'Place of birth',
];

/// Ba cách viết thường gặp của một nhãn: "Địa chỉ", "ĐỊA CHỈ", "địa chỉ".
///
/// KHÔNG dùng cờ `i` cho cả regex: dưới `iu`, `\p{Lu}` khớp cả chữ thường, và
/// luật "dừng trước tiêu đề viết hoa" sẽ dừng ngay ở "Hai Bà Trưng".
const ADDRESS_LABEL_ALT = ADDRESS_LABELS
  .flatMap((l) => [l, l.toUpperCase(), l[0].toLowerCase() + l.slice(1)])
  .map(escapeRe)
  .join('|');

const ADDRESS_INLINE_RE = new RegExp(
  `${before}(${ADDRESS_LABEL_ALT})` +
    `(?!\\s+(?:làm việc|công ty|văn phòng|cơ quan|nơi làm|LÀM VIỆC|CÔNG TY))` +
    `(\\s*[:：]\\s*)` +
    // Dừng trước nhãn kế tiếp ("Ngày sinh:", "SĐT:") hoặc tiêu đề viết hoa
    // ("MỤC TIÊU NGHỀ NGHIỆP"), trước "|", "[" và xuống dòng.
    `((?:(?!\\s+\\p{Lu}[\\p{L}.]*(?:\\s+[\\p{L}.]+){0,3}\\s*[:：])` +
    `(?!\\s+\\p{Lu}{2,}\\s+\\p{Lu}{2,})[^\\n|\\[]){4,140})`,
  'gu',
);

/// Từ hành chính để nhận ra một dòng địa chỉ KHÔNG nhãn ở đầu CV.
const ADMIN_WORDS_RE =
  /(?<![\p{L}])(?:số nhà|đường|phố|ngõ|ngách|hẻm|kiệt|phường|xã|thị trấn|quận|huyện|thị xã|tỉnh|thành phố|tp\.?|q\.\s?\d+|p\.\s?\d+|street|st\.|road|ward|district|city|province)(?![\p{L}])/giu;

/// Nhãn họ tên. Không gồm "Tên" trơn: "Tên dự án:", "Tên công ty:" rất hay gặp.
const NAME_LABEL_RE = new RegExp(
  `^([\\t >•*\\-–]*)(Họ và tên|Họ tên|Họ & tên|Tên ứng viên|Ứng viên|` +
    `Full name|Name|Candidate(?: name)?|Applicant(?: name)?)` +
    `(\\s*[:：]\\s*)([^\\n,;|]{2,60})$`,
  'gimu',
);

/// Họ phổ biến ở Việt Nam (bỏ dấu, chữ thường). Đủ cho ~95% dân số; dùng để
/// tăng độ chắc khi đoán dòng đầu CV là họ tên.
const VN_SURNAMES = new Set([
  'nguyen', 'tran', 'le', 'pham', 'hoang', 'huynh', 'phan', 'vu', 'vo', 'dang',
  'bui', 'do', 'ho', 'ngo', 'duong', 'ly', 'dinh', 'trinh', 'doan', 'lam',
  'mai', 'truong', 'ha', 'cao', 'luong', 'luu', 'ta', 'chu', 'trieu', 'quach',
  'lai', 'kieu', 'thai', 'tong', 'van', 'au', 'la', 'khuc', 'tang', 'thach',
  'hua', 'giang', 'nong', 'diep', 'phung', 'quan', 'tieu', 'to', 'luc', 'ung',
  'vuong', 'ton', 'nghiem', 'dao', 'thieu', 'ninh', 'khong', 'kim', 'mac',
  'dam', 'lo', 'cu', 'han', 'bach', 'tat', 'hong',
]);

/// Tên đệm phổ biến (bỏ dấu, chữ thường). Một cụm "Họ + Tên đệm + Tên" viết
/// hoa là dấu hiệu rất mạnh của tên người: "Trần Văn Bình", "Nguyễn Thị Lan".
/// Nhờ đòi chữ thứ hai nằm trong danh sách này mà "Phòng Đào Tạo", "Hồ Sơ Năng
/// Lực", "Lý Thường Kiệt", "Trưởng Nhóm Kinh Doanh" KHÔNG bị nhận nhầm — họ
/// "Đào", "Hồ", "Lý", "Trương" trùng mặt chữ với danh từ thường.
const VN_MIDDLE_NAMES = new Set([
  'van', 'thi', 'huu', 'duc', 'minh', 'ngoc', 'thanh', 'quoc', 'hoang', 'gia',
  'anh', 'thanh', 'cong', 'xuan', 'thu', 'kim', 'manh', 'tuan', 'hai', 'hong',
  'bao', 'quang', 'trung', 'dinh', 'duy', 'tien', 'the', 'ba', 'phuong', 'nhu',
  'my', 'dieu', 'khanh', 'nhat', 'tan', 'trong', 'huy', 'thuy', 'hoai', 'phuc',
  'vinh', 'dang', 'dac', 'khac', 'viet', 'ha', 'lan', 'mai', 'bich', 'cam',
  'thao', 'tuong', 'van', 'tu', 'hieu', 'nam', 'son', 'long', 'chi', 'kieu',
  'tuyet', 'hue', 'an', 'binh', 'cuong', 'dung', 'hung', 'khoa', 'linh', 'loan',
  'nga', 'nguyet', 'phu', 'quynh', 'tam', 'thien', 'trieu', 'uyen', 'yen',
]);

/// Địa danh / cụm quen thuộc có dáng "Họ + Tên đệm" — không phải người.
const NOT_PERSON_PHRASES = new Set([
  'ho chi minh', 'ha noi', 'ha nam', 'ha tinh', 'ha giang', 'ha dong',
  'thai binh', 'thai nguyen', 'ninh binh', 'ninh thuan', 'cao bang',
  'lam dong', 'kim ma', 'han quoc', 'thai lan', 'mai linh', 'hong kong',
]);

/// Xưng hô đứng trước tên người: "anh Bình", "sếp Trần Văn Bình", "Ms Lan".
const HONORIFIC_NAME_RE = new RegExp(
  `${before}(anh|chị|em|ông|bà|cô|chú|bác|sếp|bạn|thầy|Mr\\.?|Mrs\\.?|Ms\\.?|Miss)` +
    `(\\s+)((?:\\p{Lu}[\\p{L}'’]*)(?:\\s+\\p{Lu}[\\p{L}'’]*){0,3})${after}`,
  'gu',
);

/// Xưng hô viết hoa chỉ tính khi đứng ĐẦU CÂU ("Chị Lan bảo..."). Ở giữa câu,
/// "Anh" viết hoa thường là tiếng Anh ("học tiếng Anh Mỹ"), không phải người.
const SENTENCE_HONORIFIC_RE = new RegExp(
  `((?:^|[.!?…:\\n])\\s*)(Anh|Chị|Em|Ông|Bà|Cô|Chú|Bác|Sếp|Thầy)` +
    `(\\s+)((?:\\p{Lu}[\\p{L}'’]*)(?:\\s+\\p{Lu}[\\p{L}'’]*){0,3})${after}`,
  'gu',
);

/// Cụm 3–4 chữ viết hoa đầu (hoặc hoa toàn bộ) — ứng viên họ tên trong câu.
const CAPITALISED_RUN_RE = new RegExp(
  `${before}\\p{Lu}[\\p{L}'’]*(?:\\s+\\p{Lu}[\\p{L}'’]*){2,3}${after}`,
  'gu',
);

/// Trước cụm là số nhà hay "đường/phố" thì đó là TÊN ĐƯỜNG ("123 Lê Văn Sỹ").
const STREET_CONTEXT_RE = /(?:\d+[A-Za-z]?[\/,]?\s*|(?:đường|phố|đ\.|street|st\.)\s+)$/iu;

function looksLikeFullName(words: string[]): boolean {
  const norm = words.map((w) => stripDiacritics(w).toLowerCase());
  if (!VN_SURNAMES.has(norm[0]) || !VN_MIDDLE_NAMES.has(norm[1])) return false;
  for (let n = 2; n <= norm.length; n++) {
    if (NOT_PERSON_PHRASES.has(norm.slice(0, n).join(' '))) return false;
  }
  return true;
}

/// Tên NGƯỜI KHÁC viết lẫn trong câu chữ tự do ("góp ý cho sếp Trần Văn Bình",
/// "anh Bình bảo..."). Lớp danh tính chỉ biết tên của chính người dùng, còn
/// nhãn "Họ tên:" thì người ta chẳng bao giờ gõ khi kể chuyện.
function redactFreeTextNames(
  text: string,
  counts: Record<PiiKind, number>,
  foundNames: string[],
): string {
  let t = text.replace(HONORIFIC_NAME_RE, (m, hon, sp, name) => {
    counts.name++;
    if (name.split(/\s+/).length >= 2) foundNames.push(name);
    return `${hon}${sp}${PII_TAGS.name}`;
  });
  t = t.replace(SENTENCE_HONORIFIC_RE, (m, lead, hon, sp, name) => {
    counts.name++;
    if (name.split(/\s+/).length >= 2) foundNames.push(name);
    return `${lead}${hon}${sp}${PII_TAGS.name}`;
  });
  t = t.replace(CAPITALISED_RUN_RE, (m: string, offset: number, whole: string) => {
    const words = m.split(/\s+/);
    // Cụm dài hơn tên (tiêu đề viết hoa từng chữ) thì chỉ xét phần đầu.
    for (let n = Math.min(4, words.length); n >= 3; n--) {
      const head = words.slice(0, n);
      if (!looksLikeFullName(head)) continue;
      if (STREET_CONTEXT_RE.test(whole.slice(Math.max(0, offset - 12), offset))) return m;
      counts.name++;
      foundNames.push(head.join(' '));
      return [PII_TAGS.name, ...words.slice(n)].join(' ');
    }
    return m;
  });
  return t;
}

/// Chữ cho biết một dòng là tiêu đề / chức danh chứ không phải tên người.
const HEADER_STOPWORDS_RE =
  /(?<![\p{L}])(?:cv|resume|résumé|curriculum|vitae|profile|hồ sơ|sơ yếu|lý lịch|thông tin|information|contact|liên hệ|mục tiêu|objective|summary|kinh nghiệm|experience|kỹ năng|skills?|học vấn|education|developer|engineer|manager|executive|specialist|designer|analyst|intern|chuyên viên|nhân viên|kỹ sư|trưởng|phó|giám đốc|thực tập|công ty|company|ltd|jsc|corp)(?![\p{L}])/iu;

/// Một dòng có dáng họ tên người: 2–5 chữ, không số, không ký hiệu lạ, mỗi chữ
/// viết hoa đầu (hoặc cả dòng viết hoa).
function looksLikePersonName(line: string): boolean {
  const s = line.trim();
  if (s.length < 4 || s.length > 45) return false;
  if (/[\d@:/|•,;()]/.test(s)) return false;
  if (HEADER_STOPWORDS_RE.test(s)) return false;
  const words = s.split(/\s+/);
  if (words.length < 2 || words.length > 5) return false;
  if (!words.every((w) => /^\p{Lu}[\p{L}'’.-]*$/u.test(w))) return false;
  const first = stripDiacritics(words[0]).toLowerCase();
  const last = stripDiacritics(words[words.length - 1]).toLowerCase();
  // Họ đứng đầu (kiểu Việt) hoặc đứng cuối (CV viết kiểu Tây "An Nguyen").
  return VN_SURNAMES.has(first) || VN_SURNAMES.has(last) ||
    // Tên không phải gốc Việt: chỉ tin khi cả dòng viết hoa, kiểu đầu trang CV.
    s === s.toUpperCase();
}

/// Tiêu đề mục của CV: một dòng ngắn viết hoa toàn bộ, hoặc tên mục quen.
const SECTION_HEADING_RE =
  /^(?:[\p{Lu}\s&/]{6,40}|(?:mục tiêu|kinh nghiệm|học vấn|kỹ năng|objective|summary|experience|education|skills)\b.{0,30})$/u;

/// Dấu hiệu một dòng là nơi làm việc: có năm, hoặc có tên loại hình công ty.
const WORKPLACE_HINT_RE =
  /(?<!\d)(?:19|20)\d{2}(?!\d)|(?<![\p{L}])(?:công ty|cty|tnhh|cổ phần|tập đoàn|ngân hàng|trường|ltd|jsc|corp|inc|co\.)(?![\p{L}])/iu;

/// Số dòng đầu CV được soi để tìm họ tên / địa chỉ không nhãn.
const CV_HEADER_LINES = 12;

function redactCvHeader(
  text: string,
  counts: Record<PiiKind, number>,
  foundNames: string[],
): string {
  const lines = text.split('\n');
  let seen = 0;
  let nameDone = false;
  for (let i = 0; i < lines.length && seen < CV_HEADER_LINES; i++) {
    const raw = lines[i];
    if (!raw.trim()) continue;
    seen++;
    if (!nameDone && seen <= 4 && looksLikePersonName(raw)) {
      foundNames.push(raw.trim());
      lines[i] = raw.replace(raw.trim(), PII_TAGS.name);
      counts.name++;
      nameDone = true;
      continue;
    }
    // Gặp tiêu đề mục ("KINH NGHIỆM LÀM VIỆC") là hết phần đầu trang: từ đây
    // trở đi các dòng có "Quận 1, TP.HCM" là nơi làm việc, không phải nhà ở.
    if (nameDone && SECTION_HEADING_RE.test(raw.trim())) break;
    // Dòng địa chỉ không nhãn: có số và ít nhất hai từ hành chính, nhưng không
    // có năm hay tên công ty (đó là dòng kinh nghiệm).
    const admin = raw.match(ADMIN_WORDS_RE) ?? [];
    if (/\d/.test(raw) && admin.length >= 2 && raw.length <= 160 &&
        !raw.includes('[') && !WORKPLACE_HINT_RE.test(raw)) {
      lines[i] = raw.replace(raw.trim(), PII_TAGS.address);
      counts.address++;
    }
  }
  return lines.join('\n');
}

// ── Hàm chính ────────────────────────────────────────────────────────────

export function redactPiiDetailed(input: string, opts: RedactOptions = {}): RedactResult {
  const counts = emptyCounts();
  if (!input) return { text: input ?? '', counts };
  // PDF/Word hay trả chữ dạng tổ hợp (NFD); regex có dấu chỉ khớp dạng dựng sẵn.
  let t = input.normalize('NFC');

  // Lớp 1 — danh tính thật, chắc chắn nhất, chạy trước để lớp 2 không cắt vụn.
  if (opts.identity) t = redactIdentity(t, opts.identity, counts);

  // Lớp 2 — thứ tự có chủ ý: liên kết và email trước (chúng chứa số và chữ
  // dễ bị mẫu điện thoại / tên cắn nhầm), rồi số có nhãn, rồi số trơn.
  t = replaceCount(t, PERSONAL_LINK_RE, 'link', counts);
  t = replaceCount(t, EMAIL_RE, 'email', counts);
  t = replaceCount(t, DOB_RE, 'dob', counts, (_m, label, sep) => `${label}${sep}${PII_TAGS.dob}`);
  t = replaceCount(
    t,
    ID_LABELLED_RE,
    'id',
    counts,
    (_m, label, sep, num) => digitCount(num) >= 7 ? `${label}${sep}${PII_TAGS.id}` : null,
  );
  t = replaceCount(t, VN_PHONE_RE, 'phone', counts, (m) => {
    const d = digitCount(m);
    const intl = /^\(?\+?84/.test(m.trim());
    return (intl ? d >= 11 && d <= 12 : d >= 10 && d <= 11) ? PII_TAGS.phone : null;
  });
  t = replaceCount(t, INTL_PHONE_RE, 'phone', counts, (m) => {
    const d = digitCount(m);
    return d >= 8 && d <= 15 ? PII_TAGS.phone : null;
  });
  t = replaceCount(t, ID_BARE_RE, 'id', counts);
  t = replaceCount(
    t,
    ADDRESS_LABEL_RE,
    'address',
    counts,
    (_m, lead, label, sep) => `${lead}${label}${sep}${PII_TAGS.address}`,
  );

  t = replaceCount(
    t,
    ADDRESS_INLINE_RE,
    'address',
    counts,
    (_m, label, sep) => `${label}${sep}${PII_TAGS.address}`,
  );

  // Họ tên: có nhãn thì thay giá trị; CV thì soi thêm đầu trang. Tên nào tìm ra
  // được thì xoá luôn mọi chỗ nó xuất hiện lại (chân trang, "Tôi, Nguyễn Văn
  // An, cam đoan...").
  const foundNames: string[] = [];
  t = replaceCount(t, NAME_LABEL_RE, 'name', counts, (_m, lead, label, sep, value) => {
    const v = String(value).trim();
    if (v.startsWith('[')) return null;
    foundNames.push(v);
    return `${lead}${label}${sep}${PII_TAGS.name}`;
  });
  if (opts.isCv) t = redactCvHeader(t, counts, foundNames);
  t = redactFreeTextNames(t, counts, foundNames);
  for (const n of foundNames) {
    const re = nameRegex(n);
    if (re) t = replaceCount(t, re, 'name', counts);
  }

  return { text: t, counts };
}

/// Bản gọn: chỉ trả chữ đã khử.
export function redactPii(input: string, opts: RedactOptions = {}): string {
  return redactPiiDetailed(input, opts).text;
}

/// Dòng log không kèm nội dung: "name=1 email=1 phone=2".
export function describeCounts(counts: Record<PiiKind, number>): string {
  const parts = Object.entries(counts).filter(([, n]) => n > 0).map(([k, n]) => `${k}=${n}`);
  return parts.length ? parts.join(' ') : 'none';
}

/// Đọc danh tính thật của người dùng để lớp 1 xoá đúng chuỗi.
///
/// Hỏng thì trả rỗng chứ không ném: lớp 2 vẫn chạy, và chặn cả lượt AI chỉ vì
/// không đọc được hồ sơ là đổi một rủi ro nhỏ lấy một tính năng chết.
export async function loadPiiIdentity(db: any, userId: string): Promise<PiiIdentity> {
  try {
    const { data } = await db
      .from('cc_profiles')
      .select('full_name, email, phone')
      .eq('id', userId)
      .limit(1);
    const row = (Array.isArray(data) ? data[0] : data) ?? {};
    return {
      fullName: row.full_name ?? null,
      email: row.email ?? null,
      phone: row.phone ?? null,
    };
  } catch (_) {
    return {};
  }
}
