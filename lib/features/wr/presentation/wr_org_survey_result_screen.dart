// Khảo sát tổ chức — bản so sánh. Mockup Sprint 2, `screenEsiResult`.
//
// ---------------------------------------------------------------------------
// KHÁC MOCKUP MỘT CHỖ, CÓ CHỦ Ý
//
// Mockup ghi cứng mặt bằng chung {compensation:2.1, growth:2.6, fairness:2.4,
// support:2.8, enps:6.4}. Đó là số minh hoạ cho bản demo, không phải số đo được
// từ ai cả.
//
// Màn này nói với người dùng "Mặt bằng chung (ẩn danh)". Vẽ vạch đó bằng số bịa
// là nói một điều không có thật về hàng nghìn người không tồn tại, ngay trong
// màn hình vừa hứa với họ về tính trung thực của dữ liệu.
//
// Nên: vạch so sánh chỉ xuất hiện khi RPC `wr_org_survey_benchmark` trả về số
// thật (đủ mẫu) hoặc số tham chiếu ngành do người vận hành nhập. Chưa có gì thì
// hiện điểm của chính người dùng, kèm một dòng nói thẳng vì sao chưa so sánh
// được. Điểm của họ vẫn có nghĩa mà không cần một cái nền bịa ra để dựa vào.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_org_survey_repository.dart';
import '../../../core/logic/wr_org_survey_scoring.dart';
import '../../../core/models/wr_org_survey.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/widgets/eyebrow.dart';
import '../org_survey_providers.dart';

class WrOrgSurveyResultScreen extends ConsumerWidget {
  const WrOrgSurveyResultScreen({super.key, this.response});

  /// Bản vừa gửi xong, truyền thẳng từ luồng trả lời.
  ///
  /// Null khi mở từ màn Hồ sơ ("Xem lại kết quả") — lúc đó đọc bản gần nhất.
  /// Truyền tay được là để ngay sau khi bấm xong câu cuối không phải chờ thêm
  /// một vòng đọc lại mới thấy kết quả.
  final OrgSurveyResponse? response;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(wrOrgSurveyLatestProvider);
    final data = response ?? latestAsync.valueOrNull;

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        foregroundColor: WrColors.navy,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            key: const Key('wr_org_survey_result_close'),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/profile');
              }
            },
            child: const Text(
              'Đóng',
              style: TextStyle(fontSize: 14, color: WrColors.muted),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: data != null
            ? _Result(response: data)
            : latestAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : const _Empty(),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Chưa có câu trả lời nào để so sánh.',
          key: Key('wr_org_survey_result_empty'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: WrColors.muted),
        ),
      ),
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({required this.response});

  final OrgSurveyResponse response;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benchmark =
        ref.watch(wrOrgSurveyBenchmarkProvider).valueOrNull ?? const {};
    final enpsBenchmark = benchmark[null];
    final anyComparable = benchmark.values.any((b) => b.isComparable);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
      children: [
        const WrEyebrow('CẢM ƠN BẠN ĐÃ THAM GIA'),
        const SizedBox(height: 10),
        Text(
          anyComparable ? 'Bạn so với mặt bằng chung' : 'Kết quả của bạn',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: WrColors.navy,
          ),
        ),
        const SizedBox(height: 18),

        // --- Bốn mảng ---
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: WrColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: WrColors.line),
          ),
          child: Column(
            children: [
              for (final (i, area) in OrgSurveyArea.values.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i < OrgSurveyArea.values.length - 1 ? 16 : 0,
                  ),
                  child: _AreaBar(
                    area: area,
                    mine: response.areaAverages[area],
                    benchmark: benchmark[area],
                  ),
                ),
              if (anyComparable) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: WrColors.line),
                const SizedBox(height: 12),
                const _Legend(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- eNPS ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: WrColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: WrColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WrEyebrow('ENPS CỦA BẠN'),
              const SizedBox(height: 6),
              Text(
                response.enps == null
                    ? '– / $kEnpsMaxScore'
                    : '${response.enps} / $kEnpsMaxScore',
                key: const Key('wr_org_survey_result_enps'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: WrColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                enpsBenchmark != null && enpsBenchmark.isComparable
                    ? 'Mặt bằng chung ẩn danh: '
                        '${_fmt(enpsBenchmark.value!)} / $kEnpsMaxScore'
                    : 'Chưa đủ dữ liệu để so sánh phần này.',
                style: const TextStyle(fontSize: 13.5, color: WrColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (!anyComparable)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Bản so sánh với mặt bằng chung sẽ hiện khi đã có đủ người tham '
              'gia. Chúng tôi không vẽ một đường trung bình khi chưa đo được '
              'nó.',
              key: Key('wr_org_survey_no_benchmark'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: WrColors.muted,
              ),
            ),
          ),

        const Text(
          'Câu trả lời của bạn được gộp vào dữ liệu benchmark ẩn danh, không ảnh '
          'hưởng đến Reflection hay Career Memory cá nhân.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.6, color: WrColors.muted),
        ),
        const SizedBox(height: 20),

        // Lối giữ lời hứa "Có thể ngừng tham gia bất kỳ lúc nào".
        const _WithdrawButton(),
      ],
    );
  }
}

String _fmt(double v) => v.toStringAsFixed(1);

// ---------------------------------------------------------------------------

class _AreaBar extends StatelessWidget {
  const _AreaBar({
    required this.area,
    required this.mine,
    required this.benchmark,
  });

  final OrgSurveyArea area;
  final double? mine;
  final OrgSurveyBenchmark? benchmark;

  @override
  Widget build(BuildContext context) {
    final benchValue = benchmark?.isComparable == true ? benchmark!.value : null;
    final standing = orgSurveyStanding(mine: mine, benchmark: benchValue);
    final minePct = mine == null ? 0 : orgSurveyPercent(mine!);
    final benchPct = benchValue == null ? 0 : orgSurveyPercent(benchValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                area.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WrColors.navy,
                ),
              ),
            ),
            Text(
              standing.label,
              key: Key('wr_org_survey_standing_${area.code}'),
              style: const TextStyle(fontSize: 12.5, color: WrColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: WrColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Vạch mặt bằng chung nằm DƯỚI vạch của người dùng, đúng thứ tự
                // mockup: khi hai bên bằng nhau thì cái nhìn thấy là điểm của
                // chính họ.
                if (benchValue != null)
                  Container(
                    width: c.maxWidth * benchPct / 100,
                    decoration: BoxDecoration(
                      color: WrColors.navy.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                if (mine != null)
                  Container(
                    width: c.maxWidth * minePct / 100,
                    decoration: BoxDecoration(
                      color: WrColors.teal,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(WrColors.teal),
        const SizedBox(width: 6),
        const Text('Bạn',
            style: TextStyle(fontSize: 12.5, color: WrColors.muted)),
        const SizedBox(width: 16),
        _dot(WrColors.navy.withValues(alpha: 0.25)),
        const SizedBox(width: 6),
        // Flexible: cỡ chữ đã tăng theo brand identity mới, hàng chú giải này
        // chạm mép ở màn hẹp nếu để Text tự do.
        const Flexible(
          child: Text(
            'Mặt bằng chung (ẩn danh)',
            style: TextStyle(fontSize: 12.5, color: WrColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ---------------------------------------------------------------------------

class _WithdrawButton extends ConsumerStatefulWidget {
  const _WithdrawButton();

  @override
  ConsumerState<_WithdrawButton> createState() => _WithdrawButtonState();
}

class _WithdrawButtonState extends ConsumerState<_WithdrawButton> {
  bool _busy = false;

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ngừng tham gia?'),
        content: const Text(
          'Mọi câu trả lời khảo sát tổ chức của bạn sẽ bị xoá và không còn được '
          'tính vào dữ liệu tổng hợp. Reflection của bạn không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            key: const Key('wr_org_survey_withdraw_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(wrOrgSurveyRepositoryProvider).withdraw();
      ref.invalidate(wrOrgSurveyLatestProvider);
      ref.invalidate(wrOrgSurveyBenchmarkProvider);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa xoá được. Bạn thử lại sau nhé.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('wr_org_survey_withdraw'),
      onPressed: _busy ? null : _withdraw,
      child: Text(
        _busy ? 'Đang xoá…' : 'Ngừng tham gia và xoá câu trả lời',
        style: const TextStyle(fontSize: 14, color: WrColors.destructive),
      ),
    );
  }
}
