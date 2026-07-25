// Tài liệu bối cảnh (JD · CV) — Hai Lớp v1.2 §III & §IV.
//
//   Tải lên : Free (giới hạn số lượng — WrEntitlement.maxContextDocuments)
//   Phân tích sâu : Paid
//
// PDF, DOC, DOCX hoặc ảnh được đưa lên Supabase Storage bucket `context-docs`,
// đường dẫn lưu vào wr_context_documents.file_path.

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

String docTypeLabel(String? type) => _kDocTypes
    .firstWhere((e) => e.$1 == type, orElse: () => _kDocTypes.last)
    .$2;

const _kMaxContextDocumentBytes = 10 * 1024 * 1024;
const _kContextDocumentExtensions = [
  'pdf',
  'doc',
  'docx',
  'png',
  'jpg',
  'jpeg',
];

class WrPickedDocument {
  const WrPickedDocument({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

abstract class WrDocumentPicker {
  Future<WrPickedDocument?> pick();
}

class PlatformWrDocumentPicker implements WrDocumentPicker {
  const PlatformWrDocumentPicker();

  @override
  Future<WrPickedDocument?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kContextDocumentExtensions,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const FormatException('Không đọc được nội dung tệp đã chọn.');
    }
    return WrPickedDocument(name: file.name, bytes: bytes);
  }
}

class WrContextDocScreen extends ConsumerStatefulWidget {
  const WrContextDocScreen({super.key, this.picker});

  /// Cho phép test bơm picker giả.
  final WrDocumentPicker? picker;

  @override
  ConsumerState<WrContextDocScreen> createState() => _WrContextDocScreenState();
}

class _WrContextDocScreenState extends ConsumerState<WrContextDocScreen> {
  bool _busy = false;
  String? _errorMsg;

  Future<void> _addDocument(String docType) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      final picker = widget.picker ?? const PlatformWrDocumentPicker();
      final picked = await picker.pick();
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final dot = picked.name.lastIndexOf('.');
      if (dot <= 0 || dot == picked.name.length - 1) {
        throw const FormatException(
          'Tệp chưa có định dạng PDF, DOC, DOCX, PNG hoặc JPG.',
        );
      }
      final ext = picked.name.substring(dot + 1).toLowerCase();
      if (!_kContextDocumentExtensions.contains(ext)) {
        throw const FormatException('Chỉ hỗ trợ PDF, DOC, DOCX, PNG và JPG.');
      }
      if (picked.bytes.length > _kMaxContextDocumentBytes) {
        throw const FormatException('Tệp cần nhỏ hơn hoặc bằng 10 MB.');
      }
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw StateError('chưa đăng nhập');

      final path = await ref
          .read(wrRepositoryProvider)
          .uploadContextDocument(picked.bytes, ext, docType);

      await ref
          .read(wrIntelligenceRepositoryProvider)
          .insertContextDocument(
            WrContextDocument(userId: userId, docType: docType, filePath: path),
          );
      ref.invalidate(wrContextDocumentsProvider);
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorMsg = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMsg = 'Chưa tải lên được. Bạn thử lại giúp nhé.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final entitlement =
        ref.watch(wrEntitlementProvider).valueOrNull ??
        WrEntitlement(plan: WrPlan.free);
    final docs = ref.watch(wrContextDocumentsProvider).valueOrNull ?? const [];
    final canUpload = entitlement.canUploadContextDocument(docs.length);
    final maxDocs = entitlement.maxContextDocuments;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBF9),
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
              'Thêm JD hoặc CV để WorkReflection hiểu đúng bối cảnh công việc '
              'của bạn khi gợi ý câu chuyện và thực hành. Hỗ trợ PDF, DOC, '
              'DOCX, PNG, JPG (tối đa 10 MB).',
              style: TextStyle(
                fontSize: 13,
                height: 1.65,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 18),

            const WrEyebrow('TÀI LIỆU CỦA BẠN'),
            const SizedBox(height: 10),

            if (docs.isEmpty)
              const _EmptyDocs()
            else
              for (final d in docs) ...[
                _DocRow(doc: d),
                const SizedBox(height: 8),
              ],

            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMsg!,
                style: const TextStyle(fontSize: 12, color: WrColors.coral),
              ),
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_busy || !canUpload) ? null : _pickType,
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
                  _busy ? 'Đang tải lên…' : 'Thêm tài liệu',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
            const WrEyebrow('PHÂN TÍCH SÂU'),
            const SizedBox(height: 10),
            if (!entitlement.canUseFeature(WrPremiumFeature.contextDocAnalysis))
              const WrPremiumLock(
                description:
                    'Bản đầy đủ đọc kỹ tài liệu của bạn và chỉ ra khoảng cách '
                    'giữa những gì vai trò đòi hỏi và những gì bạn đang có.',
                ctaLabel: 'Mở phân tích sâu',
                paywallTrigger: 'context_doc',
              )
            else if (docs.isEmpty)
              const Text(
                'Thêm một tài liệu để WorkReflection bắt đầu phân tích.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.65,
                  color: Color(0xFF6B7280),
                ),
              )
            else
              const Text(
                'Phân tích sẽ xuất hiện trong Hiểu mình sau khi tài liệu được '
                'xử lý.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.65,
                  color: Color(0xFF6B7280),
                ),
              ),
          ],
        ),
      ),
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
  const _DocRow({required this.doc});

  final WrContextDocument doc;

  @override
  Widget build(BuildContext context) {
    final at = doc.uploadedAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 18,
            color: WrColors.muted,
          ),
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
                    style: const TextStyle(fontSize: 11, color: WrColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
