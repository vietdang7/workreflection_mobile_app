// Tài liệu bối cảnh (JD · CV) — Hai Lớp v1.2 §III & §IV.
//
//   Tải lên  : Free (giới hạn số lượng — WrEntitlement.maxContextDocuments)
//   AI đọc và phân tích : Premium (Edge Function `wr-doc-analyze`)
//
// File nằm trong Supabase Storage bucket `context-docs`, đường dẫn lưu vào
// `wr_context_documents.file_path`. Từ 2026-08-04, `wr-doc-analyze` đọc file
// bằng model nhìn được hình, trích chữ vào `extracted_text` và bản phân tích có
// cấu trúc vào `analysis`.
//
// Nội dung đó chảy tiếp đi ba nơi, nên màn này không phải một kho lưu trữ chết:
//   • Trợ lý trò chuyện — `wr-chat/user_context.ts` đọc nguyên văn JD/CV.
//   • Đối chiếu kỹ năng — `wrSkillJdMatchProvider` qua `wrJobContextTextProvider`.
//   • Cơ hội phát triển — khoảng trống giữa công việc và kỹ năng đã hình thành.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/data/wr_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_premium_lock.dart';
import '../wr_providers.dart';

const _kDocTypes = <(String, String)>[
  ('jd', 'Mô tả công việc (JD)'),
  ('cv', 'Hồ sơ năng lực (CV)'),
  ('other', 'Tài liệu khác'),
];

String docTypeLabel(String? type) =>
    _kDocTypes.firstWhere((e) => e.$1 == type, orElse: () => _kDocTypes.last).$2;

/// Một file đã chọn. Tách khỏi `file_picker` để test bơm được file giả mà không
/// cần chạm vào trình chọn file của hệ điều hành.
typedef PickedDoc = ({String name, String ext, List<int> bytes});

/// Hàm chọn file — bơm được trong test.
typedef DocPicker = Future<PickedDoc?> Function();

Future<PickedDoc?> _pickWithFilePicker() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: kContextDocExtensions,
    withData: true,
  );
  final file = result?.files.firstOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return (
    name: file.name,
    ext: (file.extension ?? file.name.split('.').last).toLowerCase(),
    bytes: bytes,
  );
}

class WrContextDocScreen extends ConsumerStatefulWidget {
  const WrContextDocScreen({super.key, this.picker});

  /// Cho phép test bơm trình chọn file giả.
  final DocPicker? picker;

  @override
  ConsumerState<WrContextDocScreen> createState() => _WrContextDocScreenState();
}

class _WrContextDocScreenState extends ConsumerState<WrContextDocScreen> {
  bool _busy = false;
  String? _errorMsg;

  /// Id tài liệu đang được AI đọc — để đúng thẻ đó hiện vòng quay.
  String? _analyzingId;

  Future<void> _addDocument(String docType) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      final picked = await (widget.picker ?? _pickWithFilePicker)();
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw StateError('chưa đăng nhập');

      final path = await ref
          .read(wrRepositoryProvider)
          .uploadContextDocument(picked.bytes, picked.ext, docType);

      final id =
          await ref.read(wrIntelligenceRepositoryProvider).insertContextDocument(
                WrContextDocument(
                  userId: userId,
                  docType: docType,
                  filePath: path,
                ),
              );
      ref.invalidate(wrContextDocumentsProvider);

      // Tải lên xong thì ĐỌC LUÔN, không bắt người dùng bấm thêm một nút nữa.
      // Họ vừa chọn file JD của mình; không ai làm việc đó rồi lại muốn nó nằm
      // im. Bấm tay chỉ còn dành cho lần đọc lại khi hỏng.
      if (id != null && mounted) {
        setState(() => _busy = false);
        await _analyze(id);
        return;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMsg = 'Chưa tải lên được. Bạn thử lại giúp nhé.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Nhờ máy chủ đọc tài liệu. Dùng cho cả lần đầu lẫn nút "Đọc lại".
  Future<void> _analyze(String documentId) async {
    if (_analyzingId != null) return;
    setState(() {
      _analyzingId = documentId;
      _errorMsg = null;
    });
    try {
      await ref
          .read(wrIntelligenceRepositoryProvider)
          .analyzeContextDocument(documentId);
      ref.invalidate(wrContextDocumentsProvider);
      // Bối cảnh công việc vừa đổi: phần đối chiếu kỹ năng và Cơ hội phát triển
      // đang đọc chính nguồn này, để nguyên thì hai màn kia còn nói theo dữ
      // liệu cũ cho tới lần mở app sau.
      ref.invalidate(wrJobContextTextProvider);
    } on WrDocAnalysisException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
      ref.invalidate(wrContextDocumentsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMsg = 'Chưa đọc được tài liệu này. Bạn thử lại nhé.');
      }
    } finally {
      if (mounted) setState(() => _analyzingId = null);
    }
  }

  Future<void> _delete(WrContextDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá tài liệu này?'),
        content: Text(
          'Nội dung đã đọc từ ${docTypeLabel(doc.docType).toLowerCase()} cũng '
          'sẽ không còn được dùng cho gợi ý nữa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            key: const Key('wr_context_doc_delete_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(wrIntelligenceRepositoryProvider).deleteContextDocument(doc);
    ref.invalidate(wrContextDocumentsProvider);
    ref.invalidate(wrJobContextTextProvider);
  }

  Future<void> _pickType() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in _kDocTypes)
              ListTile(
                title: Text(label),
                onTap: () => Navigator.of(ctx).pop(value),
              ),
          ],
        ),
      ),
    );
    if (type != null) await _addDocument(type);
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final docs = ref.watch(wrContextDocumentsProvider).valueOrNull ?? const [];
    final canUpload = entitlement.canUploadContextDocument(docs.length);
    final maxDocs = entitlement.maxContextDocuments;
    final canAnalyze =
        entitlement.canUseFeature(WrPremiumFeature.contextDocAnalysis);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        foregroundColor: WrColors.dark,
        title: const Text(
          'Tài liệu bối cảnh',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          children: [
            const Text(
              'Thêm JD hoặc CV để WorkReflection đọc và hiểu công việc của bạn. '
              'Nội dung đọc được sẽ dùng cho phần trò chuyện, gợi ý chủ đề thực '
              'hành và đối chiếu kỹ năng.',
              style: TextStyle(
                fontSize: 13,
                height: 1.65,
                color: WrColors.muted,
              ),
            ),
            const SizedBox(height: 18),

            const WrEyebrow('TÀI LIỆU CỦA BẠN'),
            const SizedBox(height: 10),

            if (docs.isEmpty)
              const _EmptyDocs()
            else
              for (final d in docs) ...[
                _DocRow(
                  doc: d,
                  isAnalyzing: _analyzingId != null && _analyzingId == d.id,
                  canAnalyze: canAnalyze,
                  onAnalyze: d.id == null ? null : () => _analyze(d.id!),
                  onDelete: () => _delete(d),
                ),
                const SizedBox(height: 8),
              ],

            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMsg!,
                key: const Key('wr_context_doc_error'),
                style: const TextStyle(fontSize: 12, color: WrColors.coral),
              ),
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_busy || !canUpload) ? null : _pickType,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.navy,
                  foregroundColor: WrColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _busy ? 'Đang tải lên…' : 'Thêm tài liệu',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhận file PDF hoặc ảnh chụp (PNG, JPG, WEBP).',
              style: TextStyle(fontSize: 12, height: 1.55, color: WrColors.muted),
            ),

            if (!canUpload && maxDocs != null) ...[
              const SizedBox(height: 10),
              Text(
                'Bản miễn phí lưu được $maxDocs tài liệu. Nâng cấp để thêm '
                'không giới hạn.',
                style: const TextStyle(fontSize: 12, color: WrColors.muted),
              ),
            ],

            const SizedBox(height: 26),
            const WrEyebrow('AI ĐỌC TÀI LIỆU'),
            const SizedBox(height: 10),
            if (!canAnalyze)
              const WrPremiumLock(
                key: Key('wr_context_doc_lock'),
                description:
                    'Bản đầy đủ đọc kỹ tài liệu của bạn, rút ra trách nhiệm và '
                    'yêu cầu của vai trò, rồi chỉ ra khoảng cách giữa những gì '
                    'công việc đòi hỏi và những gì bạn đang có.',
                ctaLabel: 'Mở phân tích tài liệu',
                paywallTrigger: 'context_doc',
              )
            else
              const _WhatAiDoes(),
          ],
        ),
      ),
    );
  }
}

/// Nói rõ nội dung đọc được đi đâu.
///
/// Người dùng đưa JD của mình cho một phần mềm thì có quyền biết nó được dùng
/// vào việc gì. Đây cũng là chỗ duy nhất trong app trả lời câu đó.
class _WhatAiDoes extends StatelessWidget {
  const _WhatAiDoes();

  @override
  Widget build(BuildContext context) {
    const items = [
      'Trợ lý trò chuyện đọc được nội dung tài liệu và bàn cùng bạn về nó.',
      'Gợi ý chủ đề thực hành bám theo điều công việc của bạn đòi hỏi.',
      'Đối chiếu kỹ năng bạn đã hình thành với những gì vai trò đó cần.',
    ];
    return Column(
      key: const Key('wr_context_doc_what_ai_does'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, size: 15, color: WrColors.teal),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: WrColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyDocs extends StatelessWidget {
  const _EmptyDocs();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x1A2C335D),
          style: BorderStyle.solid,
        ),
      ),
      child: const Text(
        'Chưa có tài liệu nào.',
        style: TextStyle(fontSize: 13, color: WrColors.muted),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.doc,
    required this.isAnalyzing,
    required this.canAnalyze,
    required this.onAnalyze,
    required this.onDelete,
  });

  final WrContextDocument doc;
  final bool isAnalyzing;
  final bool canAnalyze;
  final VoidCallback? onAnalyze;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final at = doc.uploadedAt;
    final a = doc.analysis;

    return Container(
      key: Key('wr_context_doc_${doc.id ?? doc.filePath}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 18, color: WrColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docTypeLabel(doc.docType),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: WrColors.dark,
                      ),
                    ),
                    if (at != null)
                      Text(
                        '${at.day}/${at.month}/${at.year}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: WrColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              _StatusChip(status: doc.analysisStatus, isAnalyzing: isAnalyzing),
              IconButton(
                key: Key('wr_context_doc_delete_${doc.id ?? doc.filePath}'),
                icon: const Icon(Icons.close, size: 17),
                color: WrColors.muted,
                onPressed: onDelete,
                tooltip: 'Xoá tài liệu',
              ),
            ],
          ),

          // Đã đọc xong: cho thấy đúng thứ máy đã hiểu. Người dùng phải kiểm
          // được — OCR đọc nhầm một dòng thì mọi gợi ý phía sau lệch theo, mà
          // không nhìn thấy bản đọc thì không ai biết vì sao lệch.
          if (doc.isReady && a != null && !a.isEmpty) ...[
            const SizedBox(height: 12),
            if (a.title != null)
              Text(
                a.title!,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                  height: 1.4,
                ),
              ),
            if (a.organization != null)
              Text(
                a.organization!,
                style: const TextStyle(fontSize: 12.5, color: WrColors.muted),
              ),
            if (a.summary.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                a.summary,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: WrColors.muted,
                ),
              ),
            ],
            if (a.responsibilities.isNotEmpty)
              _MiniList(label: 'Trách nhiệm chính', items: a.responsibilities),
            if (a.requirements.isNotEmpty)
              _MiniList(label: 'Yêu cầu', items: a.requirements),
            if (a.skills.isNotEmpty)
              _MiniList(label: 'Kỹ năng được nêu', items: a.skills),
            const SizedBox(height: 10),
            _TextButtonRow(
              label: 'Đọc lại tài liệu này',
              keyValue: 'wr_context_doc_reanalyze_${doc.id ?? ''}',
              onTap: canAnalyze ? onAnalyze : null,
            ),
          ],

          if (doc.analysisStatus == DocAnalysisStatus.failed) ...[
            const SizedBox(height: 10),
            const Text(
              'Chưa đọc được tài liệu này.',
              style: TextStyle(fontSize: 12.5, color: WrColors.coral),
            ),
            const SizedBox(height: 6),
            _TextButtonRow(
              label: 'Thử đọc lại',
              keyValue: 'wr_context_doc_retry_${doc.id ?? ''}',
              onTap: canAnalyze ? onAnalyze : null,
            ),
          ],

          if (doc.analysisStatus == DocAnalysisStatus.pending && !isAnalyzing) ...[
            const SizedBox(height: 10),
            _TextButtonRow(
              label: canAnalyze ? 'Đọc tài liệu này' : 'Đọc tài liệu (Premium)',
              keyValue: 'wr_context_doc_analyze_${doc.id ?? ''}',
              onTap: canAnalyze ? onAnalyze : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniList extends StatelessWidget {
  const _MiniList({required this.label, required this.items});

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: WrColors.muted,
            ),
          ),
          const SizedBox(height: 5),
          // Cắt 4 dòng: đây là bản xem lại để kiểm, không phải chỗ đọc cả JD.
          for (final t in items.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '· $t',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  color: WrColors.dark,
                ),
              ),
            ),
          if (items.length > 4)
            Text(
              '… và ${items.length - 4} mục nữa',
              style: const TextStyle(fontSize: 11.5, color: WrColors.muted),
            ),
        ],
      ),
    );
  }
}

class _TextButtonRow extends StatelessWidget {
  const _TextButtonRow({
    required this.label,
    required this.keyValue,
    required this.onTap,
  });

  final String label;
  final String keyValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key(keyValue),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: onTap == null ? WrColors.muted : WrColors.navy,
            ),
          ),
          const SizedBox(width: 5),
          Icon(
            Icons.arrow_forward,
            size: 13,
            color: onTap == null ? WrColors.muted : WrColors.navy,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isAnalyzing});

  final DocAnalysisStatus status;
  final bool isAnalyzing;

  @override
  Widget build(BuildContext context) {
    if (isAnalyzing || status == DocAnalysisStatus.processing) {
      return const Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 7),
          Text(
            'Đang đọc',
            style: TextStyle(fontSize: 11.5, color: WrColors.muted),
          ),
        ],
      );
    }

    final (label, color) = switch (status) {
      DocAnalysisStatus.ready => ('Đã đọc', WrColors.teal),
      DocAnalysisStatus.failed => ('Chưa đọc được', WrColors.coral),
      _ => ('Chưa đọc', WrColors.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
