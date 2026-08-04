/// 15 câu Self-Check, chép đúng nguyên văn từ `SCA_QUESTIONS` trong tài liệu
/// khách: FileTam/workreflection/WorkReflection_Sprint2_Mockup (2).html.
/// scq-01..scq-15 khớp 1-1 theo thứ tự id 1..15 của bản gốc.
/// KHÔNG tự biên tập lại chữ: mọi khác biệt so với mockup đều là lỗi.
/// Pillar: S = Sự rõ ràng, C = Mối quan hệ, A = Cách làm việc.
/// Likert 1-5: 1=Hoàn toàn không đúng … 5=Hoàn toàn đúng.
library;

enum SelfCheckPillar {
  s,
  c,
  a;

  /// Tên thân thiện hiển thị cho người dùng — KHÔNG dùng mã kỹ thuật.
  String get displayName => switch (this) {
        SelfCheckPillar.s => 'Sự rõ ràng',
        SelfCheckPillar.c => 'Mối quan hệ',
        SelfCheckPillar.a => 'Cách làm việc',
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

const kSelfCheckQuestions = <WrSelfCheckQuestion>[
  // ── Pillar S (Sự rõ ràng) ── gốc SCA_QUESTIONS id: 1, 2, 3, 4, 5
  WrSelfCheckQuestion(
    id: 'scq-01',
    pillar: SelfCheckPillar.s,
    text:
        'Trước khi bắt đầu một công việc mới, bạn thường được làm rõ về trách nhiệm của mình và người phối hợp cùng.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-02',
    pillar: SelfCheckPillar.s,
    text:
        'Với các công việc quan trọng, bạn có quy trình và hướng dẫn cụ thể trước khi bắt đầu triển khai.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-03',
    pillar: SelfCheckPillar.s,
    text:
        'Các nguyên tắc phối hợp trong đội ngũ của bạn được thống nhất rõ ràng và cập nhật đầy đủ đến mọi người liên quan.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-04',
    pillar: SelfCheckPillar.s,
    text:
        'Bạn biết rõ thông tin nào cần chia sẻ qua kênh nào, không bị lạc trong quá nhiều nhóm chat hay email chồng chéo.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-05',
    pillar: SelfCheckPillar.s,
    text:
        'Khi có thay đổi trong công việc, nhìn chung bạn không bị bất ngờ hay phải tự tìm hiểu thêm.',
  ),
  // ── Pillar C (Mối quan hệ) ── gốc SCA_QUESTIONS id: 6, 7, 8, 9, 10
  WrSelfCheckQuestion(
    id: 'scq-06',
    pillar: SelfCheckPillar.c,
    text:
        'Bạn nhận thấy cấp quản lý của mình nhất quán giữa những gì nói và những gì làm trong thực tế công việc.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-07',
    pillar: SelfCheckPillar.c,
    text:
        'Những người bạn làm việc cùng thể hiện sự nhất quán giữa lời nói và hành động, bạn có thể tin vào cam kết của họ.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-08',
    pillar: SelfCheckPillar.c,
    text:
        'Bạn cảm thấy thoải mái khi nêu ý kiến khác biệt với số đông, kể cả khi điều đó tạo ra tranh luận.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-09',
    pillar: SelfCheckPillar.c,
    text:
        'Khi bạn nhận thấy rủi ro hoặc vấn đề tiềm ẩn, bạn sẵn sàng lên tiếng, kể cả khi chưa có giải pháp.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-10',
    pillar: SelfCheckPillar.c,
    text:
        'Khi có bất đồng quan điểm, cuộc trao đổi của bạn tập trung vào tìm giải pháp thay vì tranh luận về ai đúng.',
  ),
  // ── Pillar A (Cách làm việc) ── gốc SCA_QUESTIONS id: 11, 12, 13, 14, 15
  WrSelfCheckQuestion(
    id: 'scq-11',
    pillar: SelfCheckPillar.a,
    text:
        'Trong công việc hàng ngày, bạn hiểu rõ công việc của mình kết nối với mục tiêu chung của đội nhóm như thế nào.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-12',
    pillar: SelfCheckPillar.a,
    text:
        'Khi mục tiêu thay đổi, bạn được thông báo kịp thời và rõ lý do, không phải tự đoán hay phát hiện muộn.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-13',
    pillar: SelfCheckPillar.a,
    text:
        'Nhịp phối hợp của đội nhóm bạn rõ ràng và ổn định, có check-in đều đặn, không bị lạc nhịp.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-14',
    pillar: SelfCheckPillar.a,
    text:
        'Sau mỗi giai đoạn hoặc dự án, nhóm của bạn có thời gian chính thức để nhìn lại và đánh giá những gì đã làm.',
  ),
  WrSelfCheckQuestion(
    id: 'scq-15',
    pillar: SelfCheckPillar.a,
    text:
        'Những điểm cần điều chỉnh sau khi nhìn lại được chuyển thành hành động cụ thể, có người theo dõi.',
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
