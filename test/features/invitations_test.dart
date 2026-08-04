import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workreflection_mobile/core/theme/wr_text_scale.dart';
import 'package:workreflection_mobile/core/data/wr_repository.dart';
import 'package:workreflection_mobile/features/profile/presentation/invitations_screen.dart';
import 'package:workreflection_mobile/l10n/app_localizations.dart';

import '../support/fake_repository.dart';

Widget _wrap(Widget child, WrRepository repo) {
  return ProviderScope(
    overrides: [wrRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      builder: wrTextScaleBuilder,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: child,
    ),
  );
}

Map<String, dynamic> _pendingInv({String id = 'inv1', String token = 'tok1'}) => {
      'id': id,
      'org_id': 'org1',
      'org_name': 'ACME Corp',
      'email': 'user@test.com',
      'role': 'member',
      'department': 'IT',
      'status': 'pending',
      'expires_at':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'token': token,
    };

Map<String, dynamic> _acceptedInv({String id = 'inv2'}) => {
      'id': id,
      'org_id': 'org2',
      'org_name': 'Beta Inc',
      'email': 'user@test.com',
      'role': 'admin',
      'department': null,
      'status': 'accepted',
      'expires_at':
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'token': 'tok2',
    };

void main() {
  group('InvitationsScreen', () {
    testWidgets('shows empty state when no invitations', (tester) async {
      final repo = FakeWrRepository();
      await tester.pumpWidget(_wrap(const InvitationsScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tab_pending')), findsOneWidget);
    });

    testWidgets('shows pending invitation with Accept/Decline buttons',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeWrRepository();
      repo.seedInvitations([_pendingInv()]);
      await tester.pumpWidget(_wrap(const InvitationsScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invitation_inv1')), findsOneWidget);
      expect(find.byKey(const Key('accept_inv1')), findsOneWidget);
      expect(find.byKey(const Key('decline_inv1')), findsOneWidget);
    });

    testWidgets('accept button calls acceptInvitation with correct token',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeWrRepository();
      repo.seedInvitations([_pendingInv(token: 'secret-token')]);
      repo.setAcceptInvitationResult(orgName: 'ACME Corp');

      await tester.pumpWidget(_wrap(const InvitationsScreen(), repo));
      await tester.pumpAndSettle();

      // Tap accept
      await tester.tap(find.byKey(const Key('accept_inv1')));
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.byKey(const Key('invitations_confirm_accept')));
      await tester.pumpAndSettle();

      expect(repo.acceptInvitationCalls, contains('secret-token'));
    });

    testWidgets('decline button calls declineInvitation with correct id',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeWrRepository();
      repo.seedInvitations([_pendingInv(id: 'inv-xyz')]);

      await tester.pumpWidget(_wrap(const InvitationsScreen(), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('decline_inv-xyz')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('invitations_confirm_decline')));
      await tester.pumpAndSettle();

      expect(repo.declineInvitationCalls, contains('inv-xyz'));
    });

    testWidgets('processed tab shows accepted invitation', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = FakeWrRepository();
      repo.seedInvitations([_acceptedInv()]);

      await tester.pumpWidget(_wrap(const InvitationsScreen(), repo));
      await tester.pumpAndSettle();

      // Tap the "Đã xử lý" tab by its text
      await tester.tap(find.text('Đã xử lý'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invitation_inv2')), findsOneWidget);
      // No action buttons for accepted invitations
      expect(find.byKey(const Key('accept_inv2')), findsNothing);
    });
  });

  group('FakeWrRepository invitation contract', () {
    test('getInvitations returns seeded data', () async {
      final repo = FakeWrRepository();
      repo.seedInvitations([_pendingInv()]);
      final list = await repo.getInvitations();
      expect(list, hasLength(1));
      expect(list.first['org_name'], 'ACME Corp');
    });

    test('acceptInvitation records call and updates status', () async {
      final repo = FakeWrRepository();
      repo.seedInvitations([_pendingInv(token: 'my-token')]);
      repo.setAcceptInvitationResult(orgName: 'ACME Corp');

      final orgName = await repo.acceptInvitation('my-token');
      expect(orgName, 'ACME Corp');
      expect(repo.acceptInvitationCalls, contains('my-token'));

      final list = await repo.getInvitations();
      expect(list.first['status'], 'accepted');
    });

    test('declineInvitation records call and updates status', () async {
      final repo = FakeWrRepository();
      repo.seedInvitations([_pendingInv(id: 'inv99')]);

      await repo.declineInvitation('inv99');
      expect(repo.declineInvitationCalls, contains('inv99'));

      final list = await repo.getInvitations();
      expect(list.first['status'], 'declined');
    });

    test('acceptInvitation throws when error is set', () async {
      final repo = FakeWrRepository();
      repo.seedInvitations([_pendingInv(token: 'bad-token')]);
      repo.setAcceptInvitationResult(
          error: Exception('already accepted'));

      expect(
        () => repo.acceptInvitation('bad-token'),
        throwsException,
      );
    });
  });
}
