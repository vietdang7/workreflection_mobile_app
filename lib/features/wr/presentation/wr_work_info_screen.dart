// Thông tin công việc hiện tại — Hai Lớp v1.6 §XI.
//
// §XI cần biết người dùng đang làm gì để Cơ hội phát triển nói được điều cụ
// thể thay vì một câu chung cho mọi vai trò. Hai nguồn, cùng một chỗ:
//
//   • Một dòng tự viết (`wr_mobile_profiles.role_text`) — nhanh, ai cũng làm
//     được, và là nguồn duy nhất mà luật suy diễn trên máy đọc được.
//   • JD/CV đã có sẵn ở màn Tài liệu bối cảnh — chi tiết hơn nhưng cần đối tác
//     xử lý phía server, nên ở đây chỉ dẫn sang.
//
// Cả hai đều tuỳ chọn. Không có thông tin nào thì Cơ hội phát triển vẫn chạy,
// chỉ nói ở mức trụ SCA thay vì neo vào vai trò cụ thể.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/l10n/wr_tr.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_link_row.dart';
import '../../../core/logic/wr_jd_builder.dart';
import '../wr_providers.dart';
import 'wr_jd_builder_screen.dart' show wrJdDraftProvider;
import '../../../core/widgets/wr_paragraph.dart';

class WrWorkInfoScreen extends ConsumerStatefulWidget {
  const WrWorkInfoScreen({super.key});

  @override
  ConsumerState<WrWorkInfoScreen> createState() => _WrWorkInfoScreenState();
}

class _WrWorkInfoScreenState extends ConsumerState<WrWorkInfoScreen> {
  final _controller = TextEditingController();
  bool _prefilled = false;
  bool _busy = false;
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _saved = false;
    });
    try {
      final text = _controller.text.trim();
      await ref.read(wrRepositoryProvider).saveRoleText(text);
      ref.invalidate(wrRoleTextProvider);
      // Gợi ý đang hiện được dựng từ role_text cũ — bỏ đi để lần đọc sau tính lại.
      ref.invalidate(wrGrowthOpportunityProvider);
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) setState(() => _error = tr('Không lưu được. Thử lại.', 'Could not save. Try again.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(wrRoleTextProvider);

    // Chỉ điền một lần, và chỉ khi dữ liệu đã về — điền lúc còn loading sẽ khoá
    // ô ở chuỗi rỗng và người dùng tưởng mình chưa từng viết gì.
    if (!_prefilled && !roleAsync.isLoading) {
      _controller.text = roleAsync.valueOrNull ?? '';
      _prefilled = true;
    }

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        foregroundColor: WrColors.navy,
        title: Text(
          tr('Thông tin công việc', 'Work details'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: WrColors.navy,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          children: [
            WrParagraph(
              tr('Chia sẻ vai trò hiện tại của bạn. Dựa vào đây, các bài thực hành '
              'sẽ được phác thảo riêng cho công việc của bạn.', 'Tell us about your current role. From this, the practice exercises '
              'are shaped around the job you actually do.'),
              style: TextStyle(
                fontSize: 14.5,
                height: 1.65,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 20),

            WrEyebrow(tr('VỊ TRÍ / CHỨC DANH HIỆN TẠI', 'CURRENT ROLE / JOB TITLE')),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: WrColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WrColors.line),
              ),
              child: TextField(
                key: const Key('wr_work_info_field'),
                controller: _controller,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(
                  fontSize: 16.5,
                  color: WrColors.navy,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText:
                      tr('Ví dụ: trưởng nhóm nội dung, quản lý 4 bạn, làm việc '
                      'nhiều với phòng kinh doanh', 'For example: content team lead, managing 4 people, '
                      'working closely with sales'),
                  hintStyle: TextStyle(fontSize: 15.5, color: WrColors.muted),
                ),
                onChanged: (_) => setState(() => _saved = false),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('wr_work_info_save'),
                onPressed: _busy ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.dark,
                  foregroundColor: WrColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _busy ? tr('Đang lưu…', 'Saving…') : tr('Lưu', 'Save'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (_saved) ...[
              const SizedBox(height: 10),
              Text(
                tr('Đã lưu.', 'Saved.'),
                key: Key('wr_work_info_saved'),
                style: TextStyle(fontSize: 13.5, color: WrColors.teal),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13.5, color: WrColors.coral),
              ),
            ],

            const SizedBox(height: 28),
            WrEyebrow(tr('TÀI LIỆU CHI TIẾT', 'DETAILED DOCUMENTS')),
            const SizedBox(height: 6),
            Text(
              tr('Tải lên file JD (Mô tả công việc) hoặc CV để hệ thống có thêm dữ '
              'liệu phân tích. (Không bắt buộc)', 'Upload a JD (job description) or CV so the app has more to work '
              'with. (Optional)'),
              style: TextStyle(
                fontSize: 14.5,
                height: 1.65,
                color: WrColors.muted,
              ),
            ),
            WrLinkRow(
              key: const Key('wr_work_info_context_docs_row'),
              label: tr('Tải lên JD hoặc CV của bạn', 'Upload your JD or CV'),
              onTap: () => context.push('/wr/context-docs'),
            ),

            // Lối vào DUY NHẤT của "Cùng tạo JD của bạn" (changelog 24/08 §6).
            //
            // Đặt ngay dưới ô tải tài liệu là có chủ đích: hai thẻ này trả lời
            // cùng một câu hỏi ("làm sao app biết công việc thật của tôi"), chỉ
            // khác ở chỗ người dùng đã có sẵn JD hay chưa. Tách xa nhau thì ai
            // không có JD sẽ dừng lại ở thẻ tải lên và nghĩ mình không dùng
            // được phần này.
            const SizedBox(height: 18),
            const _JdBuilderCard(),
          ],
        ),
      ),
    );
  }
}

/// Thẻ dẫn sang luồng viết JD 5 buổi.
///
/// Câu mời đổi theo tiến độ đang có: chưa viết gì thì "Cùng viết trong 5 buổi
/// ngắn" (nguyên văn mockup), viết dở rồi thì mời viết tiếp và nói rõ đang ở
/// buổi nào. Giữ nguyên câu mời ban đầu cho người đã viết ba buổi là để họ tự
/// hỏi mình đã làm hay chưa.
class _JdBuilderCard extends ConsumerWidget {
  const _JdBuilderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(wrJdDraftProvider).valueOrNull;
    final done = draft?.completedDays.length ?? 0;
    final complete = draft?.isComplete ?? false;

    final title = switch ((complete, done)) {
      (true, _) => tr('JD bạn đã viết', 'The JD you wrote'),
      (_, 0) => tr('Nếu chưa có sẵn JD, bạn có thể tự phác thảo nhanh theo 5 bước '
          'hướng dẫn', 'No JD to hand? You can sketch one quickly in 5 guided steps'),
      _ => tr('Viết tiếp JD của bạn', 'Carry on writing your JD'),
    };
    final hint = switch ((complete, done)) {
      (true, _) => tr('Đã xong cả 5 bước. Mở lại để đọc và sửa.', 'All 5 steps done. Reopen it to read and edit.'),
      (_, 0) => tr('Mỗi bước chỉ mất 2–3 phút, bạn có thể dừng lại và quay lại làm '
          'tiếp bất cứ lúc nào.', 'Each step takes 2–3 minutes, and you can stop and come back at '
          'any time.'),
      _ => tr('Đã xong $done trên $kJdDayCount bước', '$done of $kJdDayCount steps done'),
    };

    return GestureDetector(
      key: const Key('wr_work_info_jd_builder_card'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/wr/jd-builder'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: WrColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WrColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: WrColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.auto_awesome_outlined,
                size: 19,
                color: WrColors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WrParagraph(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: WrColors.navy,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 3),
                  WrParagraph(
                    hint,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: WrColors.muted,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: WrColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
