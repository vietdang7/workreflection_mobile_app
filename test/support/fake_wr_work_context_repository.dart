import 'package:workreflection_mobile/core/data/wr_work_context_repository.dart';

/// Bản giả của `wr_work_context_history` trong bộ nhớ.
///
/// Mô phỏng đúng các check constraint của bảng thật (migration
/// 20261013140000): `field` chỉ nhận ba giá trị, `value` sau khi cắt khoảng
/// trắng phải dài 1–4000 ký tự. Không có sửa/xoá — bảng thật cũng không cho.
class FakeWrWorkContextRepository implements WrWorkContextRepository {
  FakeWrWorkContextRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final List<WrWorkContextEntry> rows = [];
  int _seq = 0;

  void seed(List<WrWorkContextEntry> entries) => rows.addAll(entries);

  @override
  Future<List<WrWorkContextEntry>> listHistory() async {
    final out = [...rows]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<WrWorkContextEntry> addEntry(
    WrWorkContextField field,
    String value,
  ) async {
    final v = value.trim();
    if (v.isEmpty || v.length > 4000) {
      throw StateError('check constraint wr_work_context_history.value');
    }
    final entry = WrWorkContextEntry(
      id: 'wch-${++_seq}',
      field: field,
      value: v,
      // Mỗi dòng mới hơn dòng trước ít nhất một mili giây, để thứ tự "mới
      // nhất trước" không phụ thuộc độ phân giải đồng hồ.
      createdAt: _clock().add(Duration(milliseconds: _seq)),
    );
    rows.add(entry);
    return entry;
  }
}
