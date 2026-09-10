/// 15 câu Self-Check, chép đúng nguyên văn từ `SCA_QUESTIONS` trong tài liệu
/// khách: FileTam/workreflection/WorkReflection_Sprint2_Mockup (2).html.
/// scq-01..scq-15 khớp 1-1 theo thứ tự id 1..15 của bản gốc.
/// KHÔNG tự biên tập lại chữ: mọi khác biệt so với mockup đều là lỗi.
/// Pillar: S = Sự rõ ràng, C = Mối quan hệ, A = Cách làm việc.
/// Likert 1-5: 1=Hoàn toàn không đúng … 5=Hoàn toàn đúng.
library;

import '../l10n/wr_tr.dart';

enum SelfCheckPillar {
  s,
  c,
  a;

  /// Tên thân thiện hiển thị cho người dùng — KHÔNG dùng mã kỹ thuật.
  String get displayName => switch (this) {
        SelfCheckPillar.s => tr('Sự rõ ràng', 'Clarity'),
        SelfCheckPillar.c => tr('Mối quan hệ', 'Relationships'),
        SelfCheckPillar.a => tr('Cách làm việc', 'Ways of working'),
      };
}

class WrSelfCheckQuestion {
  const WrSelfCheckQuestion({
    required this.id,
    required this.pillar,
    required this.text,
  });

  /// ID khớp với question_id trong DB (scq-01 … scq-15).
  final String id;
  final SelfCheckPillar pillar;
  final String text;
}

List<WrSelfCheckQuestion> get kSelfCheckQuestions => <WrSelfCheckQuestion>[
  // ── Pillar S (Sự rõ ràng) ── gốc SCA_QUESTIONS id: 1, 2, 3, 4, 5
  WrSelfCheckQuestion(
    id: 'scq-01',
    pillar: SelfCheckPillar.s,
    text:
        tr('Trước khi bắt đầu một công việc mới, bạn thường được làm rõ về trách nhiệm của mình và người phối hợp cùng.', 'Before you start something new, your responsibilities and who you work with are usually made clear.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-02',
    pillar: SelfCheckPillar.s,
    text:
        tr('Với các công việc quan trọng, bạn có quy trình và hướng dẫn cụ thể trước khi bắt đầu triển khai.', 'For work that matters, you have a concrete process and guidance before you begin.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-03',
    pillar: SelfCheckPillar.s,
    text:
        tr('Các nguyên tắc phối hợp trong đội ngũ của bạn được thống nhất rõ ràng và cập nhật đầy đủ đến mọi người liên quan.', 'How your team works together is agreed clearly, and everyone involved is kept up to date.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-04',
    pillar: SelfCheckPillar.s,
    text:
        tr('Bạn biết rõ thông tin nào cần chia sẻ qua kênh nào, không bị lạc trong quá nhiều nhóm chat hay email chồng chéo.', 'You know what to share through which channel, without getting lost across too many chats or overlapping emails.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-05',
    pillar: SelfCheckPillar.s,
    text:
        tr('Khi có thay đổi trong công việc, nhìn chung bạn không bị bất ngờ hay phải tự tìm hiểu thêm.', 'When work changes, you are generally not caught off guard or left to find out on your own.'),
  ),
  // ── Pillar C (Mối quan hệ) ── gốc SCA_QUESTIONS id: 6, 7, 8, 9, 10
  WrSelfCheckQuestion(
    id: 'scq-06',
    pillar: SelfCheckPillar.c,
    text:
        tr('Bạn nhận thấy cấp quản lý của mình nhất quán giữa những gì nói và những gì làm trong thực tế công việc.', 'You find your manager consistent between what they say and what they actually do.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-07',
    pillar: SelfCheckPillar.c,
    text:
        tr('Những người bạn làm việc cùng thể hiện sự nhất quán giữa lời nói và hành động, bạn có thể tin vào cam kết của họ.', 'The people you work with are consistent between word and action, so you can rely on what they commit to.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-08',
    pillar: SelfCheckPillar.c,
    text:
        tr('Bạn cảm thấy thoải mái khi nêu ý kiến khác biệt với số đông, kể cả khi điều đó tạo ra tranh luận.', 'You are comfortable voicing a view that differs from the majority, even when it starts an argument.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-09',
    pillar: SelfCheckPillar.c,
    text:
        tr('Khi bạn nhận thấy rủi ro hoặc vấn đề tiềm ẩn, bạn sẵn sàng lên tiếng, kể cả khi chưa có giải pháp.', 'When you spot a risk or a problem forming, you are willing to say so, even without a solution yet.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-10',
    pillar: SelfCheckPillar.c,
    text:
        tr('Khi có bất đồng quan điểm, cuộc trao đổi của bạn tập trung vào tìm giải pháp thay vì tranh luận về ai đúng.', 'When people disagree, your conversations focus on finding a way forward rather than on who is right.'),
  ),
  // ── Pillar A (Cách làm việc) ── gốc SCA_QUESTIONS id: 11, 12, 13, 14, 15
  WrSelfCheckQuestion(
    id: 'scq-11',
    pillar: SelfCheckPillar.a,
    text:
        tr('Trong công việc hàng ngày, bạn hiểu rõ công việc của mình kết nối với mục tiêu chung của đội nhóm như thế nào.', 'In day-to-day work, you understand how your own work connects to what the team is aiming for.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-12',
    pillar: SelfCheckPillar.a,
    text:
        tr('Khi mục tiêu thay đổi, bạn được thông báo kịp thời và rõ lý do, không phải tự đoán hay phát hiện muộn.', 'When goals change, you are told in time and told why, rather than guessing or finding out late.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-13',
    pillar: SelfCheckPillar.a,
    text:
        tr('Nhịp phối hợp của đội nhóm bạn rõ ràng và ổn định, có check-in đều đặn, không bị lạc nhịp.', 'Your team has a clear, steady rhythm for working together, with regular check-ins and nothing falling out of step.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-14',
    pillar: SelfCheckPillar.a,
    text:
        tr('Sau mỗi giai đoạn hoặc dự án, nhóm của bạn có thời gian chính thức để nhìn lại và đánh giá những gì đã làm.', 'After each phase or project, your team has proper time set aside to look back at what was done.'),
  ),
  WrSelfCheckQuestion(
    id: 'scq-15',
    pillar: SelfCheckPillar.a,
    text:
        tr('Những điểm cần điều chỉnh sau khi nhìn lại được chuyển thành hành động cụ thể, có người theo dõi.', 'What comes out of looking back turns into concrete actions with someone following through.'),
  ),
];

/// Tính điểm trung bình (1.0–5.0) cho một pillar từ map {questionId → score (1-5)}.
double computePillarScore(
  SelfCheckPillar pillar,
  Map<String, int> answers,
) {
  final questions =
      kSelfCheckQuestions.where((q) => q.pillar == pillar).toList();
  if (questions.isEmpty) return 0;
  double total = 0;
  int count = 0;
  for (final q in questions) {
    final v = answers[q.id];
    if (v != null) {
      total += v;
      count++;
    }
  }
  if (count == 0) return 0;
  return total / count;
}

/// Chuyển điểm 1-5 sang phần trăm (0-100) để vẽ thanh.
double scoreToPercent(double score) => ((score - 1) / 4) * 100;
