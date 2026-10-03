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
// Nên: vạch so sánh chỉ xuất hiện khi RPC `wr_org_survey_benchmark_v2` trả về số
// thật (đủ mẫu) hoặc số tham chiếu ngành do người vận hành nhập. Chưa có gì thì
// hiện điểm của chính người dùng, kèm một dòng nói thẳng vì sao chưa so sánh
// được. Điểm của họ vẫn có nghĩa mà không cần một cái nền bịa ra để dựa vào.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_org_survey_repository.dart';
import '../../../core/l10n/wr_tr.dart';
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
    // Có bản truyền tay thì khỏi đọc lại. Không có (mở từ Hồ sơ, hoặc tải lại
    // trang web) thì đọc bản gần nhất, và để lỗi đọc lộ ra thay vì thành "trống".
    final AsyncValue<OrgSurveyResponse?>? latestAsync = response == null
        ? ref.watch(wrOrgSurveyLatestOrThrowProvider)
        : null;
    final data = response ?? latestAsync?.valueOrNull;

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
            child: Text(
              tr('Đóng', 'Close'),
              style: TextStyle(fontSize: 14, color: WrColors.muted),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: data != null
            ? _Result(response: data)
            : latestAsync == null || latestAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : latestAsync.hasError
            ? _LoadError(
                message: tr(
                  'Chưa tải được kết quả của bạn.',
                  'Could not load your results.',
                ),
                onRetry: () => ref.invalidate(wrOrgSurveyLatestOrThrowProvider),
                retryKey: const Key('wr_org_survey_result_retry'),
              )
            : const _Empty(),
      ),
    );
  }
}

/// Một dòng báo lỗi kèm nút "Thử lại". Dùng cho cả lỗi đọc bản gần nhất lẫn lỗi
/// đọc phần so sánh, để hai trường hợp này không bao giờ giống "chưa đủ người".
class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.onRetry,
    required this.retryKey,
  });

  final String message;
  final VoidCallback onRetry;
  final Key retryKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: WrColors.muted),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: retryKey,
              onPressed: onRetry,
              child: Text(tr('Thử lại', 'Try again')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          tr(
            'Chưa có câu trả lời nào để so sánh.',
            'No answers to compare yet.',
          ),
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
    // Hai phạm vi: `all` (mọi người) và `industry` (cùng lĩnh vực với bản này).
    final benchAsync = ref.watch(
      wrOrgSurveyBenchmarkProvider(response.industry),
    );
    final loadFailed = benchAsync.hasError;
    // Lỗi thì KHÔNG vẽ thanh so sánh từ giá trị cũ còn sót cạnh dòng báo lỗi.
    final benchmarks = loadFailed ? null : benchAsync.valueOrNull;
    final all = benchmarks?.all ?? const <OrgSurveyArea?, OrgSurveyBenchmark>{};
    final industry =
        benchmarks?.industry ?? const <OrgSurveyArea?, OrgSurveyBenchmark>{};
    final enpsBenchmark = all[null];
    final anyComparable = all.values.any((b) => b.isComparable);

    // Chưa có gì để so sánh (đã đọc xong, không lỗi): nói MỘT lần còn thiếu bao
    // nhiêu người, thay vì lặp "chưa đủ" ở từng mảng. RPC không trả riêng số
    // người, nên lấy mẫu lớn nhất trong các phần làm số người đã tham gia.
    final nothingToCompare = benchmarks != null && !anyComparable;
    final people = all.values.fold<int>(
      0,
      (m, b) => b.sampleSize > m ? b.sampleSize : m,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
      children: [
        WrEyebrow(tr('CẢM ƠN BẠN ĐÃ THAM GIA', 'THANK YOU FOR TAKING PART')),
        const SizedBox(height: 10),
        Text(
          anyComparable
              ? tr('Bạn so với mặt bằng chung', 'You against the wider picture')
              : tr('Kết quả của bạn', 'Your results'),
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
                    benchmark: all[area],
                    industryBenchmark: industry[area],
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
              WrEyebrow(tr('ENPS CỦA BẠN', 'YOUR ENPS')),
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
              if (enpsBenchmark != null && enpsBenchmark.isComparable) ...[
                const SizedBox(height: 4),
                Text(
                  tr(
                    'Mặt bằng chung ẩn danh: '
                        '${_fmt(enpsBenchmark.value!)} / $kEnpsMaxScore',
                    'Anonymous wider picture: '
                        '${_fmt(enpsBenchmark.value!)} / $kEnpsMaxScore',
                  ),
                  style: const TextStyle(fontSize: 13.5, color: WrColors.muted),
                ),
              ] else if (anyComparable) ...[
                // Một số mảng đã so sánh được, riêng phần này thì chưa.
                const SizedBox(height: 4),
                Text(
                  tr(
                    'Chưa đủ dữ liệu để so sánh phần này.',
                    'Not enough data to compare this part yet.',
                  ),
                  style: const TextStyle(fontSize: 13.5, color: WrColors.muted),
                ),
              ],
              if (industry[null] case final ib?
                  when ib.source == BenchmarkSource.live && ib.value != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${tr('Cùng lĩnh vực', 'Same field')}: '
                    '${_fmt(ib.value!)} / $kEnpsMaxScore',
                    key: const Key('wr_org_survey_industry_row_enps'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: WrColors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (loadFailed)
          _LoadError(
            message: tr(
              'Chưa tải được phần so sánh.',
              'Could not load the comparison.',
            ),
            onRetry: () =>
                ref.invalidate(wrOrgSurveyBenchmarkProvider(response.industry)),
            retryKey: const Key('wr_org_survey_benchmark_retry'),
          )
        else if (nothingToCompare)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              tr(
                'Mặt bằng chung sẽ hiện khi có đủ $kOrgSurveyMinSample người '
                    'tham gia. Hiện đã có $people người.',
                'The overall comparison appears once $kOrgSurveyMinSample '
                    'people have taken part. So far: $people.',
              ),
              key: const Key('wr_org_survey_no_benchmark'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: WrColors.muted,
              ),
            ),
          ),
        const SizedBox(height: 4),

        Text(
          tr(
            'Câu trả lời của bạn được gộp vào dữ liệu benchmark ẩn danh, không ảnh '
                'hưởng đến Reflection hay Career Memory cá nhân.',
            'Your answers are pooled into anonymous benchmark data. They do not '
                'affect your own Reflection or Career Memory.',
          ),
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
    this.industryBenchmark,
  });

  final OrgSurveyArea area;
  final double? mine;
  final OrgSurveyBenchmark? benchmark;
  final OrgSurveyBenchmark? industryBenchmark;

  @override
  Widget build(BuildContext context) {
    final benchValue = benchmark?.isComparable == true
        ? benchmark!.value
        : null;
    final standing = orgSurveyStanding(mine: mine, benchmark: benchValue);
    final industryValue = industryBenchmark?.source == BenchmarkSource.live
        ? industryBenchmark!.value
        : null;
    // Chưa có mặt bằng chung thì nhãn chỉ nói điểm của chính người dùng; lý do
    // chưa so sánh được đã có ở MỘT khối riêng bên dưới.
    final standingText = benchValue == null && mine != null
        ? '${_fmt(mine!)} / $kOrgSurveyMaxScore'
        : standing.label;
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
              standingText,
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
        if (industryValue != null) ...[
          const SizedBox(height: 6),
          Row(
            key: Key('wr_org_survey_industry_row_${area.code}'),
            children: [
              Expanded(
                child: Text(
                  tr('Cùng lĩnh vực', 'Same field'),
                  style: const TextStyle(fontSize: 12.5, color: WrColors.muted),
                ),
              ),
              Text(
                '${_fmt(industryValue)} / $kOrgSurveyMaxScore',
                style: const TextStyle(fontSize: 12.5, color: WrColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: WrColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 4,
                  width: c.maxWidth * orgSurveyPercent(industryValue) / 100,
                  decoration: BoxDecoration(
                    color: WrColors.navy.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        Text(
          tr('Bạn', 'You'),
          style: TextStyle(fontSize: 12.5, color: WrColors.muted),
        ),
        const SizedBox(width: 16),
        _dot(WrColors.navy.withValues(alpha: 0.25)),
        const SizedBox(width: 6),
        // Flexible: cỡ chữ đã tăng theo brand identity mới, hàng chú giải này
        // chạm mép ở màn hẹp nếu để Text tự do.
        Flexible(
          child: Text(
            tr('Mặt bằng chung (ẩn danh)', 'Wider picture (anonymous)'),
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
        title: Text(tr('Ngừng tham gia?', 'Stop taking part?')),
        content: Text(
          tr(
            'Mọi câu trả lời khảo sát tổ chức của bạn sẽ bị xoá và không còn được '
                'tính vào dữ liệu tổng hợp. Reflection của bạn không bị ảnh hưởng.',
            'All your organisation survey answers will be deleted and no longer '
                'counted in the pooled data. Your Reflections are unaffected.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Giữ lại', 'Keep them')),
          ),
          TextButton(
            key: const Key('wr_org_survey_withdraw_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Xoá', 'Delete')),
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
        SnackBar(
          content: Text(
            tr(
              'Chưa xoá được. Bạn thử lại sau nhé.',
              'Could not delete. Please try again later.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('wr_org_survey_withdraw'),
      onPressed: _busy ? null : _withdraw,
      child: Text(
        _busy
            ? tr('Đang xoá…', 'Deleting…')
            : tr(
                'Ngừng tham gia và xoá câu trả lời',
                'Stop taking part and delete my answers',
              ),
        style: const TextStyle(fontSize: 14, color: WrColors.destructive),
      ),
    );
  }
}
