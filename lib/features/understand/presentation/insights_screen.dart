import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/wr_card.dart';
import '../../../l10n/app_localizations.dart';
import '../understand_providers.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final insightsAsync = ref.watch(understandInsightsProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.insightsTitle, style: WrTextStyles.hMedium),
        centerTitle: false,
      ),
      body: SafeArea(
        child: insightsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.homeErrorLoadData, style: WrTextStyles.body),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(understandInsightsProvider),
                  child: Text(l10n.homeRetry),
                ),
              ],
            ),
          ),
          data: (insights) {
            if (insights.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    key: const Key('insights_empty'),
                    l10n.insightsEmpty,
                    style: WrTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              key: const Key('insights_list'),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
              itemCount: insights.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final insight = insights[i];
                final dateStr =
                    DateFormat('dd/MM/yyyy').format(insight.savedAt);
                return WrCardMinimal(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (insight.source != null) ...[
                        WrEyebrow(insight.source!),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        '"${insight.content}"',
                        style: WrTextStyles.insightQuote.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.insightSavedDate(dateStr),
                        style: WrTextStyles.body.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
