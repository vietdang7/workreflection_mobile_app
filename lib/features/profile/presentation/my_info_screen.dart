// "Thông tin của bạn" — mockup Sprint 2 bản (4), `screenMyInfo`.
//
// Một chỗ để XEM và SỬA lại bảy trường người dùng đã khai rải rác. Không phải
// một biểu mẫu mới: mỗi dòng ghi thẳng vào đúng cột mà màn gốc vẫn dùng
// (`wr_my_info.dart` giữ bản đồ đó), nên sửa ở đây và sửa ở Sửa hồ sơ là cùng
// một sự thật.
//
// Cách dùng đúng như mockup: chạm một dòng để mở danh sách lựa chọn ngay dưới
// nó, chạm một lựa chọn là ghi và đóng lại. Không có nút Lưu — mỗi lần chỉ đổi
// một trường, giữ thêm một nút xác nhận chỉ tạo chỗ để bỏ dở.
//
// Mọi trường đều TUỲ CHỌN. Màn này không được ép, không được chặn, và không
// được nói "còn thiếu" — dòng cuối chỉ đếm, và nói rõ là tuỳ chọn.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/wr_my_info.dart';
import '../../../core/logic/profile_options.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../l10n/app_localizations.dart';
import '../profile_providers.dart';

class MyInfoScreen extends ConsumerStatefulWidget {
  const MyInfoScreen({super.key});

  @override
  ConsumerState<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends ConsumerState<MyInfoScreen> {
  /// Cột đang mở danh sách lựa chọn. Chỉ một cột mở tại một thời điểm — đúng
  /// `state.myInfoExpanded` của mockup, và cũng để màn không dài ra thành một
  /// bảng bảy danh sách bung hết.
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fields = myInfoFields(l10n);

    final cc = ref.watch(ccProfileProvider).valueOrNull ?? const {};
    final profile = ref.watch(mobileProfileProvider).valueOrNull;

    String? read(MyInfoField f) => switch (f.store) {
      MyInfoStore.ccProfile => cc[f.column] as String?,
      MyInfoStore.mobileProfile => switch (f.column) {
        'city' => profile?.city,
        'org_industry' => profile?.orgIndustry,
        'org_company_type' => profile?.orgCompanyType,
        _ => null,
      },
    };

    final filled = myInfoFilledCount(fields, read);
    final groups = myInfoGroups(fields);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            if (GoRouter.maybeOf(context) != null && context.canPop())
              GestureDetector(
                key: const Key('my_info_back'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.pop(),
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_new,
                          size: 14, color: WrColors.muted),
                      SizedBox(width: 6),
                      Text(
                        'Quay lại',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: WrColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const WrEyebrow('HỒ SƠ'),
            const SizedBox(height: 8),
            const Text(
              'Thông tin của bạn',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: WrColors.navy,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gộp lại toàn bộ thông tin bạn đã chia sẻ ở Hồ sơ, Khảo sát tổ '
              'chức, và Thông tin công việc, để xem hoặc sửa lại ở đúng một chỗ.',
              style: TextStyle(
                fontSize: 14.5,
                color: WrColors.text2,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            // Lý do người dùng nên điền, nói bằng lợi ích chứ không bằng bổn
            // phận. Đây là chỗ duy nhất trong màn dùng sắc teal — một điểm
            // nhấn, đúng brand identity 04/8.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: WrColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      size: 16, color: WrColors.pillTealText),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đây cũng là thứ giúp trợ lý trò chuyện AI hiểu đúng '
                      'hoàn cảnh của bạn hơn, thay vì trả lời chung chung.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: WrColors.pillTealText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final group in groups) ...[
              const SizedBox(height: 20),
              Text(
                group,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: WrColors.text3,
                ),
              ),
              const SizedBox(height: 8),
              _GroupCard(
                fields: fields.where((f) => f.group == group).toList(),
                read: read,
                expanded: _expanded,
                onToggle: (column) => setState(
                  () => _expanded = _expanded == column ? null : column,
                ),
                onPick: _pick,
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Công việc hiện tại (chi tiết)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: WrColors.text3,
              ),
            ),
            const SizedBox(height: 8),
            _WorkInfoRow(hasRoleText: (profile?.roleText ?? '').isNotEmpty),
            const SizedBox(height: 16),
            Text(
              '$filled/${fields.length} mục đã điền. Tất cả đều tuỳ chọn, sửa '
              'lại bất cứ lúc nào.',
              key: const Key('my_info_filled_count'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: WrColors.text3,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(MyInfoField field, String value) async {
    setState(() => _expanded = null);
    await ref.read(myInfoSaveProvider.notifier).save(field, value);
    if (!mounted) return;
    final err = ref.read(myInfoSaveProvider);
    if (err.hasError) {
      // Ghi hỏng mà im lặng thì dòng vẫn hiện giá trị cũ và người dùng tưởng
      // mình bấm trượt, bấm lại lần nữa.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa lưu được, thử lại giúp mình nhé.')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Một nhóm — thẻ trắng, các dòng ngăn nhau bằng vạch mảnh.
// ---------------------------------------------------------------------------

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.fields,
    required this.read,
    required this.expanded,
    required this.onToggle,
    required this.onPick,
  });

  final List<MyInfoField> fields;
  final String? Function(MyInfoField) read;
  final String? expanded;
  final void Function(String column) onToggle;
  final void Function(MyInfoField field, String value) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WrColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < fields.length; i++)
            _FieldRow(
              field: fields[i],
              value: read(fields[i]),
              open: expanded == fields[i].column,
              showDivider: i < fields.length - 1,
              onToggle: () => onToggle(fields[i].column),
              onPick: (v) => onPick(fields[i], v),
            ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.value,
    required this.open,
    required this.showDivider,
    required this.onToggle,
    required this.onPick,
  });

  final MyInfoField field;
  final String? value;
  final bool open;
  final bool showDivider;
  final VoidCallback onToggle;
  final void Function(String value) onPick;

  @override
  Widget build(BuildContext context) {
    final label = myInfoLabelFor(field, value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: WrColors.lineSoft)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: Key('my_info_row_${field.column}'),
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    field.label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: WrColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    // "Chưa có" chứ không phải để trống: một dòng trống trông
                    // như lỗi tải, còn chữ này nói rõ đây là chỗ chờ người dùng.
                    label ?? 'Chưa có',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          label == null ? FontWeight.w400 : FontWeight.w600,
                      color: label == null ? WrColors.text3 : WrColors.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  open ? Icons.expand_less : Icons.chevron_right,
                  size: 18,
                  color: WrColors.text3,
                ),
              ],
            ),
          ),
          if (open) ...[
            const SizedBox(height: 12),
            for (final o in field.options) ...[
              _OptionTile(
                option: o,
                selected: o.value == value,
                onTap: () => onPick(o.value),
              ),
              if (o != field.options.last) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

/// Ô lựa chọn — cùng khuôn với ô chọn ở luồng phản tư: nền trắng viền mảnh, ô
/// đang chọn tô đặc coral và chữ vẫn NAVY (spec §03).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ProfileOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('my_info_option_${option.value}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? WrColors.coral : WrColors.pageBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WrColors.line),
        ),
        child: Text(
          option.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: WrColors.navy,
          ),
        ),
      ),
    );
  }
}

/// Lối sang màn Thông tin công việc — vai trò tự viết và JD/CV. Để nguyên ở màn
/// riêng vì nó có ô nhập chữ và tải tệp, không rút được thành một danh sách chọn.
class _WorkInfoRow extends StatelessWidget {
  const _WorkInfoRow({required this.hasRoleText});

  final bool hasRoleText;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('my_info_work_info_row'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/wr/work-info'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: WrColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vai trò, và JD hoặc CV',
                    style: TextStyle(fontSize: 14.5, color: WrColors.navy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasRoleText
                        ? 'Đã có, chạm để xem hoặc sửa'
                        : 'Chưa có, chạm để thêm',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WrColors.text3,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: WrColors.text3),
          ],
        ),
      ),
    );
  }
}
