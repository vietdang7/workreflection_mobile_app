import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/wr_repository.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final invitationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(wrRepositoryProvider).getInvitations();
});

class InvitationActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> accept(String token) async {
    state = const AsyncLoading();
    try {
      final orgName =
          await ref.read(wrRepositoryProvider).acceptInvitation(token);
      ref.invalidate(invitationsProvider);
      state = const AsyncData(null);
      return orgName;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> decline(String invitationId) async {
    state = const AsyncLoading();
    try {
      await ref.read(wrRepositoryProvider).declineInvitation(invitationId);
      ref.invalidate(invitationsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final invitationActionProvider =
    AsyncNotifierProvider<InvitationActionNotifier, void>(
  InvitationActionNotifier.new,
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _formatDate(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleAccept(Map<String, dynamic> inv) async {
    final l10n = AppLocalizations.of(context)!;
    final orgName = inv['org_name'] as String? ?? '';
    final role = inv['role'] as String? ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.invitationsAcceptTitle),
        content: Text(l10n.invitationsAcceptBody(orgName, role)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('invitations_confirm_accept'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.invitationsAcceptBtn,
              style: const TextStyle(color: WrColors.coral),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final joinedOrg = await ref
          .read(invitationActionProvider.notifier)
          .accept(inv['token'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invitationsAcceptSuccess(joinedOrg))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invitationsAcceptError)),
        );
      }
    }
  }

  Future<void> _handleDecline(Map<String, dynamic> inv) async {
    final l10n = AppLocalizations.of(context)!;
    final orgName = inv['org_name'] as String? ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.invitationsDeclineTitle),
        content: Text(l10n.invitationsDeclineBody(orgName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('invitations_confirm_decline'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.invitationsDeclineBtn,
              style: const TextStyle(color: WrColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(invitationActionProvider.notifier)
          .decline(inv['id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invitationsDeclineSuccess)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invitationsDeclineError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invAsync = ref.watch(invitationsProvider);
    final actionState = ref.watch(invitationActionProvider);

    return Scaffold(
      backgroundColor: WrColors.pageBg,
      appBar: AppBar(
        backgroundColor: WrColors.pageBg,
        elevation: 0,
        leading: const BackButton(color: WrColors.navy),
        title: Text(l10n.invitationsTitle, style: WrTextStyles.hMedium),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabs,
          labelColor: WrColors.coral,
          unselectedLabelColor: WrColors.muted,
          indicatorColor: WrColors.coral,
          labelStyle: WrTextStyles.body.copyWith(fontSize: 14.5),
          tabs: [
            Tab(text: l10n.invitationsPending),
            Tab(text: l10n.invitationsExpired),
            Tab(text: l10n.invitationsProcessed),
          ],
        ),
      ),
      body: invAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: WrColors.coral)),
        error: (_, __) => Center(
          child: Text(l10n.invitationsEmpty, style: WrTextStyles.body),
        ),
        data: (invitations) {
          final now = DateTime.now();

          final pending = invitations.where((i) {
            final exp = DateTime.tryParse(i['expires_at'] as String? ?? '');
            return i['status'] == 'pending' &&
                (exp == null || exp.isAfter(now));
          }).toList();

          final expired = invitations.where((i) {
            final exp = DateTime.tryParse(i['expires_at'] as String? ?? '');
            return i['status'] == 'pending' &&
                exp != null &&
                exp.isBefore(now);
          }).toList();

          final processed = invitations
              .where((i) => ['accepted', 'declined', 'cancelled']
                  .contains(i['status']))
              .toList();

          return Stack(
            children: [
              TabBarView(
                controller: _tabs,
                children: [
                  _InvitationTab(
                    key: const Key('tab_pending'),
                    invitations: pending,
                    emptyMessage: l10n.invitationsNoPending,
                    showActions: true,
                    onAccept: _handleAccept,
                    onDecline: _handleDecline,
                    formatDate: _formatDate,
                    l10n: l10n,
                  ),
                  _InvitationTab(
                    key: const Key('tab_expired'),
                    invitations: expired,
                    emptyMessage: l10n.invitationsNoExpired,
                    showActions: false,
                    onAccept: _handleAccept,
                    onDecline: _handleDecline,
                    formatDate: _formatDate,
                    l10n: l10n,
                  ),
                  _InvitationTab(
                    key: const Key('tab_processed'),
                    invitations: processed,
                    emptyMessage: l10n.invitationsNoProcessed,
                    showActions: false,
                    onAccept: _handleAccept,
                    onDecline: _handleDecline,
                    formatDate: _formatDate,
                    l10n: l10n,
                  ),
                ],
              ),
              if (actionState.isLoading)
                const ColoredBox(
                  color: Colors.black26,
                  child: Center(
                      child:
                          CircularProgressIndicator(color: WrColors.coral)),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab content
// ---------------------------------------------------------------------------

class _InvitationTab extends StatelessWidget {
  const _InvitationTab({
    super.key,
    required this.invitations,
    required this.emptyMessage,
    required this.showActions,
    required this.onAccept,
    required this.onDecline,
    required this.formatDate,
    required this.l10n,
  });

  final List<Map<String, dynamic>> invitations;
  final String emptyMessage;
  final bool showActions;
  final Future<void> Function(Map<String, dynamic>) onAccept;
  final Future<void> Function(Map<String, dynamic>) onDecline;
  final String Function(String) formatDate;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (invitations.isEmpty) {
      return Center(
        child: Text(emptyMessage,
            style: WrTextStyles.body.copyWith(color: WrColors.muted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invitations.length,
      itemBuilder: (ctx, i) => _InvitationCard(
        key: Key('invitation_${invitations[i]['id']}'),
        invitation: invitations[i],
        showActions: showActions,
        onAccept: onAccept,
        onDecline: onDecline,
        formatDate: formatDate,
        l10n: l10n,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invitation card
// ---------------------------------------------------------------------------

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    super.key,
    required this.invitation,
    required this.showActions,
    required this.onAccept,
    required this.onDecline,
    required this.formatDate,
    required this.l10n,
  });

  final Map<String, dynamic> invitation;
  final bool showActions;
  final Future<void> Function(Map<String, dynamic>) onAccept;
  final Future<void> Function(Map<String, dynamic>) onDecline;
  final String Function(String) formatDate;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final orgName = invitation['org_name'] as String? ?? '';
    final role = invitation['role'] as String? ?? '';
    final department = invitation['department'] as String?;
    final status = invitation['status'] as String? ?? '';
    final expiresAt = invitation['expires_at'] as String? ?? '';

    final now = DateTime.now();
    final expDt = DateTime.tryParse(expiresAt);
    final isExpired = expDt != null && expDt.isBefore(now);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Org icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: WrColors.navy.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_outlined,
                      color: WrColors.navy, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(orgName,
                          style: WrTextStyles.hMedium
                              .copyWith(color: WrColors.navy)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Chip(role),
                          if (department != null && department.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('• $department',
                                style: WrTextStyles.body.copyWith(
                                    fontSize: 13.5, color: WrColors.muted)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 12, color: WrColors.muted),
                          const SizedBox(width: 4),
                          Text(
                            isExpired
                                ? l10n.invitationsExpiredAt(
                                    formatDate(expiresAt))
                                : l10n.invitationsExpiresAt(
                                    formatDate(expiresAt)),
                            style: WrTextStyles.body.copyWith(
                                fontSize: 12.5, color: WrColors.text3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status, isExpired: isExpired, l10n: l10n),
              ],
            ),
            if (showActions && status == 'pending' && !isExpired) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    key: Key('decline_${invitation['id']}'),
                    onPressed: () => onDecline(invitation),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WrColors.destructive,
                      side:
                          const BorderSide(color: WrColors.destructive),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(l10n.invitationsDeclineBtn),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: Key('accept_${invitation['id']}'),
                    onPressed: () => onAccept(invitation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WrColors.coral,
                      foregroundColor: WrColors.navy,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text(l10n.invitationsAcceptBtn),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: WrColors.navy.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: WrTextStyles.body
              .copyWith(fontSize: 12.5, color: WrColors.navy)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.isExpired,
    required this.l10n,
  });

  final String status;
  final bool isExpired;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'accepted':
        bg = Colors.green.withValues(alpha: 0.1);
        fg = Colors.green.shade700;
        label = l10n.invitationsAccepted;
      case 'declined':
        bg = WrColors.muted.withValues(alpha: 0.1);
        fg = WrColors.muted;
        label = l10n.invitationsDeclined;
      case 'cancelled':
        bg = WrColors.destructive.withValues(alpha: 0.1);
        fg = WrColors.destructive;
        label = l10n.invitationsCancelled;
      default:
        if (isExpired) {
          bg = WrColors.destructive.withValues(alpha: 0.1);
          fg = WrColors.destructive;
          label = l10n.invitationsExpired;
        } else {
          bg = WrColors.coral.withValues(alpha: 0.1);
          fg = WrColors.coral;
          label = l10n.invitationsPending;
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: WrTextStyles.body.copyWith(fontSize: 12.5, color: fg)),
    );
  }
}
