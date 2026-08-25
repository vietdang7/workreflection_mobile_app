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
      if (mounted) setState(() => _error = 'Không lưu được. Thử lại.');
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
        title: const Text(
          'Thông tin công việc',
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
            const WrParagraph(
              'Bạn đang làm công việc gì? Một dòng thôi cũng đủ để những gợi ý '
              'phát triển bám sát hơn vào việc thật của bạn.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.65,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 20),

            const WrEyebrow('MÔ TẢ CỦA BẠN'),
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
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText:
                      'Ví dụ: trưởng nhóm nội dung, quản lý 4 bạn, làm việc '
                      'nhiều với phòng kinh doanh',
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
                  _busy ? 'Đang lưu…' : 'Lưu',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (_saved) ...[
              const SizedBox(height: 10),
              const Text(
                'Đã lưu.',
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
            const WrEyebrow('TÀI LIỆU CHI TIẾT'),
            const SizedBox(height: 6),
            const Text(
              'Có JD hoặc CV thì tải lên để bối cảnh đầy đủ hơn. Tuỳ chọn.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.65,
                color: WrColors.muted,
              ),
            ),
            WrLinkRow(
              key: const Key('wr_work_info_context_docs_row'),
              label: 'Tài liệu bối cảnh (JD · CV)',
              onTap: () => context.push('/wr/context-docs'),
            ),

            // Lối vào DUY NHẤT của "Viết JD cùng app" (changelog 24/08 §6).
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
      (true, _) => 'JD bạn đã viết',
      (_, 0) => 'Công ty chưa có JD? Cùng viết trong 5 buổi ngắn',
      _ => 'Viết tiếp JD của bạn',
    };
    final hint = switch ((complete, done)) {
      (true, _) => 'Đã xong cả 5 buổi. Mở lại để đọc và sửa.',
      (_, 0) => 'Mỗi buổi khoảng 2-3 phút, không cần làm hết trong một lần',
      _ => 'Đã xong $done trên $kJdDayCount buổi',
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
