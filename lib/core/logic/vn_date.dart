// Shared Vietnam-timezone date helpers.
// Vietnam is UTC+7 and does not observe DST, so we add 7 hours to UTC.

/// Returns today's date in Vietnam time (Asia/Ho_Chi_Minh) as a date-only
/// [DateTime] (midnight local, no time component).
DateTime todayVn() => todayVnFrom(DateTime.now().toUtc());

/// Returns the Vietnam-local date for [utcNow] as a date-only [DateTime].
/// Exposed separately so tests can pass a fixed UTC instant.
DateTime todayVnFrom(DateTime utcNow) {
  final vn = utcNow.toUtc().add(const Duration(hours: 7));
  return DateTime(vn.year, vn.month, vn.day);
}

/// Giờ hiện tại ở Việt Nam, CÒN NGUYÊN phần giờ phút.
///
/// [todayVn] cắt về nửa đêm nên `.hour` của nó luôn bằng 0 — ai dùng nó để đọc
/// khung giờ sẽ luôn nhận về "khuya". Minh hoạ mở đầu Home (§5) đọc giờ, nên nó
/// phải dùng hàm này.
DateTime nowVn() => nowVnFrom(DateTime.now().toUtc());

/// Bản nhận mốc UTC cố định, để test không phụ thuộc đồng hồ máy.
DateTime nowVnFrom(DateTime utcNow) =>
    utcNow.toUtc().add(const Duration(hours: 7));

/// Số NGÀY LỊCH (giờ Việt Nam) giữa [at] và bây giờ. Cùng ngày = 0, hôm qua = 1.
///
/// Đếm theo ngày lịch chứ không theo số giờ trôi qua: 23h tối qua và 1h sáng nay
/// cách nhau hai giờ nhưng là hai ngày khác nhau, và người dùng cũng đọc nó như
/// hai ngày khác nhau. Mọi khối "hôm nay / hôm qua" trên Home đều nghĩ như vậy.
int daysAgoVn(DateTime at, {DateTime? now}) {
  final then = todayVnFrom(at.toUtc());
  final today = now == null ? todayVn() : todayVnFrom(now.toUtc());
  return today.difference(then).inDays;
}
