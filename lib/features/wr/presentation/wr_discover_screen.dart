import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/wr_intelligence_repository.dart';
import '../../../core/logic/wr_entitlement.dart';
import '../../../core/logic/wr_self_check_questions.dart';
import '../../../core/models/wr_intelligence.dart';
import '../../../core/theme/wr_colors.dart';
import '../wr_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local providers
// ─────────────────────────────────────────────────────────────────────────────

final selfCheckHistoryProvider =
    FutureProvider<List<ScaSelfCheckResponse>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(wrIntelligenceRepositoryProvider);
  return repo.fetchSelfCheckHistory(userId);
});

// ─────────────────────────────────────────────────────────────────────────────
// WrDiscoverScreen
// ─────────────────────────────────────────────────────────────────────────────

class WrDiscoverScreen extends ConsumerWidget {
  const WrDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(selfCheckHistoryProvider);
    final entitlementAsync = ref.watch(wrEntitlementProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _buildEmpty(context),
          data: (history) {
            final entitlement = entitlementAsync.valueOrNull ??
                WrEntitlement(plan: WrPlan.free);
            if (history.isEmpty) {
              return _buildEmpty(context);
            }
            return _buildWithData(context, history, entitlement);
          },
        ),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) {
    final steps = [
      'Đọc câu chuyện đầu tiên',
      'Trả lời câu hỏi phản chiếu',
      'Nhận Aha Moment đầu tiên',
      'Bức tranh bắt đầu xuất hiện',
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Bức tranh của tôi',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFA3A3A3),
                    letterSpacing: 0.02,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Chưa có dữ liệu',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: WrColors.dark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sau khi phản chiếu, bức tranh về môi trường làm việc của bạn sẽ hiện ra tại đây.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF737373),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: Container(
              decoration: BoxDecoration(
                color: WrColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x0F000000)),
              ),
              child: Column(
                children: List.generate(steps.length, (i) {
                  return Container(
                    decoration: BoxDecoration(
                      border: i < steps.length - 1
                          ? const Border(
                              bottom: BorderSide(color: Color(0x0D000000)))
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0x0D000000),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFA3A3A3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          steps[i],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF737373),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/wr/self-check'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrColors.dark,
                  foregroundColor: WrColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Làm 15 câu phản chiếu',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Has data view ────────────────────────────────────────────────────────

  Widget _buildWithData(
    BuildContext context,
    List<ScaSelfCheckResponse> history,
    WrEntitlement entitlement,
  ) {
    final latest = history.first;
    final isPremium = entitlement.isPremium;

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bức tranh của tôi',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFA3A3A3),
                          letterSpacing: 0.02,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Kết quả phản chiếu',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: WrColors.dark,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/wr/self-check'),
                  child: const Text(
                    'Làm lại',
                    style: TextStyle(fontSize: 12, color: WrColors.dark),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3 score bars
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
            child: Column(
              children: [
                _ScoreBar(
                  label: SelfCheckPillar.s.displayName,
                  score: latest.structureScore ?? 0,
                  color: const Color(0xFF5B8CC9),
                ),
                const SizedBox(height: 8),
                _ScoreBar(
                  label: SelfCheckPillar.c.displayName,
                  score: latest.cultureScore ?? 0,
                  color: WrColors.teal,
                ),
                const SizedBox(height: 8),
                _ScoreBar(
                  label: SelfCheckPillar.a.displayName,
                  score: latest.activityScore ?? 0,
                  color: const Color(0xFF5E7A5A),
                ),
              ],
            ),
          ),
        ),

        // Premium cards (free) or history (premium)
        if (!isPremium) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Text(
                'MỞ KHOÁ VỚI PREMIUM',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFA3A3A3),
                  letterSpacing: 0.08,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: _LockedFeatureCard(
                icon: '📈',
                title: 'Diễn giải sâu & xu hướng theo thời gian',
                onTap: () => context.push('/wr/paywall?trigger=report'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: _LockedFeatureCard(
                icon: '📊',
                title: 'Báo cáo chuyên sâu 49 câu',
                onTap: () => context.push('/wr/paywall?trigger=report'),
              ),
            ),
          ),
        ] else ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 4),
              child: Text(
                'LỊCH SỬ ĐO',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFA3A3A3),
                  letterSpacing: 0.08,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                child: _HistoryRow(response: history[i]),
              ),
              childCount: history.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.score,
    required this.color,
  });

  final String label;
  final double score; // 1.0–5.0
  final Color color;

  double get _percent =>
      score <= 0 ? 0 : ((score - 1) / 4).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WrColors.dark,
                ),
              ),
              const Spacer(),
              Text(
                '${(score * 20).round()}%',
                style: const TextStyle(fontSize: 12, color: Color(0xFFA3A3A3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _percent,
              minHeight: 4,
              backgroundColor: const Color(0x0F000000),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedFeatureCard extends StatelessWidget {
  const _LockedFeatureCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final String icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 0.6,
        child: Container(
          decoration: BoxDecoration(
            color: WrColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x0F000000)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: WrColors.dark,
                  ),
                ),
              ),
              const Text(
                '⭐ Premium',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD4A017),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.response});
  final ScaSelfCheckResponse response;

  @override
  Widget build(BuildContext context) {
    final d = response.takenAt;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final s = response.structureScore ?? 0;
    final c = response.cultureScore ?? 0;
    final a = response.activityScore ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: WrColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 12,
              color: WrColors.dark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _MiniScore(label: 'Rõ', value: s, color: const Color(0xFF5B8CC9)),
          const SizedBox(width: 8),
          _MiniScore(label: 'Qh', value: c, color: WrColors.teal),
          const SizedBox(width: 8),
          _MiniScore(label: 'Cv', value: a, color: const Color(0xFF5E7A5A)),
        ],
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  const _MiniScore({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(fontSize: 11, color: WrColors.dark),
        ),
      ],
    );
  }
}
