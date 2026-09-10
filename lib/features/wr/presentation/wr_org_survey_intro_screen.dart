// Khảo sát tổ chức — màn giới thiệu. Mockup Sprint 2, `screenEsiInfo`.
//
// Màn này tồn tại để người dùng ĐỒNG Ý CÓ HIỂU BIẾT trước khi trả lời, không
// phải để bán một tính năng. Ba khối theo đúng thứ tự của mockup:
//
//   1. được gì ngay      — bản so sánh cá nhân, khoảng 5 phút
//   2. vì sao rộng hơn   — dữ liệu benchmark ẩn danh, "phần thưởng thêm, không
//                          phải lý do chính để bạn tham gia"
//   3. được đảm bảo gì   — bốn cam kết
//
// Mỗi câu trong khối 3 là một lời hứa mà phần mềm phải giữ được. Đừng thêm câu
// nào vào đó nếu chưa có đoạn mã tương ứng.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/wr_tr.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../org_survey_providers.dart';

class WrOrgSurveyIntroScreen extends ConsumerWidget {
  const WrOrgSurveyIntroScreen({super.key});

  static List<dynamic> get _guarantees => [
    tr('Dữ liệu chỉ được dùng ở dạng tổng hợp, ẩn danh, không truy ngược về từng '
        'cá nhân.', 'The data is only ever used pooled and anonymous, never traced back to '
        'an individual.'),
    tr('Hoàn toàn không ảnh hưởng đến Reflection, Insight hay Career Memory cá '
        'nhân của bạn.', 'It has no effect at all on your own Reflection, Insight or Career '
        'Memory.'),
    tr('Không bắt buộc, không đổi lấy quyền lợi hay tính năng nào trong ứng dụng.', 'Not required, and it does not buy you any benefit or feature in the app.'),
    tr('Có thể ngừng tham gia và xoá câu trả lời bất kỳ lúc nào, ngay ở màn kết '
        'quả.', 'You can stop taking part and delete your answers at any time, right on '
        'the results screen.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(wrOrgSurveyQuestionsProvider);
    final latest = ref.watch(wrOrgSurveyLatestProvider).valueOrNull;
    final questions = questionsAsync.valueOrNull ?? const [];

    // Số câu đọc từ bảng chứ không ghi cứng "13": bảng câu hỏi là thứ người vận
    // hành sửa được, và một màn hứa 13 câu rồi hỏi 11 câu là màn nói dối.
    final total = questions.isEmpty ? null : questions.length + 1;

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        foregroundColor: WrColors.navy,
        title: Text(
          tr('Khảo sát tổ chức', 'Organisation survey'),
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
            WrEyebrow(tr('TUỲ CHỌN, TÁCH RIÊNG KHỎI REFLECTION', 'OPTIONAL, SEPARATE FROM REFLECTION')),
            const SizedBox(height: 10),
            Text(
              tr('Bạn đang ở đâu so với mặt bằng chung?', 'Where do you sit against the wider picture?'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: WrColors.navy,
              ),
            ),
            const SizedBox(height: 18),

            // --- 1 · Được gì ngay ---
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total == null
                        ? tr('Vài câu ngắn về đãi ngộ, phát triển, sự công bằng và '
                            'mức hỗ trợ nơi bạn làm việc.', 'A few short questions about pay, growth, fairness and '
                            'support where you work.')
                        : tr('Trả lời $total câu ngắn về đãi ngộ, phát triển, sự '
                            'công bằng và mức hỗ trợ nơi bạn làm việc.', '$total short questions about pay, growth, fairness '
                            'and support where you work.'),
                    style: _bodyStyle,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: WrColors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_outlined,
                            size: 14, color: WrColors.pillTealText),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr('Xong là có ngay bản so sánh của riêng bạn, khoảng '
                            '5 phút.', 'Finish and your own comparison is ready, about '
                            '5 minutes.'),
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                              color: WrColors.pillTealText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- 2 · Vì sao rộng hơn ---
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Vì sao câu trả lời của bạn cũng có giá trị rộng hơn', 'Why your answers matter more widely too'),
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    tr('Ngoài bản so sánh riêng cho bạn, câu trả lời khi gộp cùng '
                    'nhiều người khác ở dạng ẩn danh còn giúp xây dựng dữ liệu '
                    'benchmark ngành, phục vụ nghiên cứu và các công cụ chẩn '
                    'đoán tổ chức trong tương lai của Cloud & Coral. Đây là '
                    'phần thưởng thêm, không phải lý do chính để bạn tham gia.', 'Beyond your own comparison, answers pooled anonymously with '
                    'many others help build industry benchmark data for '
                    'research and for future organisational diagnostic tools at '
                    'Cloud & Coral. That is a bonus, not the main reason to '
                    'take part.'),
                    style: _bodyStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- 3 · Được đảm bảo gì ---
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Điều gì được đảm bảo', 'What is guaranteed'),
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: WrColors.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final g in _guarantees)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.check,
                                size: 14, color: WrColors.teal),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(g, style: _bodyStyle)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            if (questionsAsync.hasError || (questionsAsync.hasValue && questions.isEmpty))
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  tr('Chưa tải được bộ câu hỏi. Bạn thử lại sau nhé.', 'Could not load the questions. Please try again later.'),
                  key: Key('wr_org_survey_questions_error'),
                  style: TextStyle(fontSize: 14, color: WrColors.coral),
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('wr_org_survey_start'),
                // Không mở luồng khi chưa có câu hỏi: người dùng sẽ bấm vào một
                // màn trống và không hiểu mình vừa làm gì sai.
                onPressed: questions.isEmpty
                    ? null
                    : () => context.push('/wr/org-survey/flow'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.dark,
                  foregroundColor: WrColors.white,
                  disabledBackgroundColor: WrColors.line,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  questionsAsync.isLoading
                      ? tr('Đang tải…', 'Loading…')
                      : tr('Bắt đầu, khoảng 5 phút', 'Start, about 5 minutes'),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Đã làm rồi thì cho xem lại ngay từ đây — nếu không, người muốn mở
            // lại bản so sánh cũ buộc phải làm lại cả bài.
            if (latest != null) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('wr_org_survey_view_result'),
                onPressed: () => context.push('/wr/org-survey/result'),
                child: Text(
                  tr('Xem lại kết quả lần trước', 'See your previous results'),
                  style: TextStyle(fontSize: 14.5, color: WrColors.navy),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _bodyStyle = TextStyle(
  fontSize: 14.5,
  height: 1.65,
  color: WrColors.text2,
);

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WrColors.line),
      ),
      child: child,
    );
  }
}
