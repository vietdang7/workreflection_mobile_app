// Check-in screen — Phase 3 Task 12.
// Supports QR scan (via MobileScanner) + manual text entry.
// checkinScannerEnabledProvider is overridden to false in tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/data/workshop_repository.dart';
import '../../../core/logic/checkin_rules.dart';
import '../../../core/models/workshop_models.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../workshops_providers.dart';

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  final _controller = TextEditingController();
  bool _processing = false;
  String? _errorMessage;
  bool _success = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String raw) async {
    if (_processing || _success) return;

    // Capture l10n synchronously before any await.
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _processing = true;
      _errorMessage = null;
      _success = false;
    });

    try {
      // 1. Parse / validate the code.
      final code = parseCheckinCode(raw);
      if (code == null) {
        setState(() {
          _errorMessage = l10n.wsCheckinInvalidCode;
          _processing = false;
        });
        return;
      }

      final repo = ref.read(workshopRepositoryProvider);

      // 2. Look up the workshop by check-in code.
      final workshop = await repo.getWorkshopByCheckinCode(code);
      if (workshop == null) {
        setState(() {
          _errorMessage = l10n.wsCheckinNotFound;
          _processing = false;
        });
        return;
      }

      // 3. Check registration.
      final registration = await repo.getMyRegistration(workshop.id);
      if (registration == null) {
        setState(() {
          _errorMessage = l10n.wsCheckinNotRegistered;
          _processing = false;
        });
        return;
      }

      // 4. Already checked in — idempotent success (no repeat checkIn call).
      if (registration.checkedInAt != null) {
        setState(() {
          _success = true;
          _processing = false;
        });
        await _maybeShowConsentDialog(registration, workshop.id, l10n);
        return;
      }

      // 5. Check time window.
      final window = checkinWindow(workshop.startsAt, DateTime.now());
      if (window == CheckinWindow.tooEarly) {
        setState(() {
          _errorMessage = l10n.wsCheckinTooEarly;
          _processing = false;
        });
        return;
      }
      if (window == CheckinWindow.closed) {
        setState(() {
          _errorMessage = l10n.wsCheckinClosed;
          _processing = false;
        });
        return;
      }

      // 6. Perform check-in (open or unknown window).
      await repo.checkIn(registration.id);
      setState(() {
        _success = true;
        _processing = false;
      });

      await _maybeShowConsentDialog(registration, workshop.id, l10n);
    } catch (_) {
      setState(() {
        _errorMessage = l10n.wsCheckinError;
        _processing = false;
      });
    }
  }

  Future<void> _maybeShowConsentDialog(
    WorkshopRegistration registration,
    String workshopId,
    AppLocalizations l10n,
  ) async {
    if (registration.imageConsent != null) return;
    if (!mounted) return;

    Future<void> record(bool consent) async {
      try {
        await ref
            .read(workshopRepositoryProvider)
            .setImageConsent(registration.id, consent);
      } catch (_) {
        // Consent recording is best-effort — never surface an error after a
        // successful check-in.
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.wsConsentTitle),
        content: Text(l10n.wsConsentBody),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              record(false);
            },
            child: Text(l10n.wsConsentDecline),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              record(true);
            },
            child: Text(l10n.wsConsentAccept),
          ),
        ],
      ),
    );

    // Invalidate so detail screens refresh.
    ref.invalidate(myRegistrationProvider(workshopId));
    ref.invalidate(hasSubmittedSurveyProvider(workshopId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scannerEnabled = ref.watch(checkinScannerEnabledProvider);

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        title: Text(l10n.wsCheckinTitle, style: WrTextStyles.hMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // QR scanner area.
            if (scannerEnabled)
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final raw = barcode.rawValue;
                        if (raw != null && raw.isNotEmpty) {
                          _handleCode(raw);
                          break;
                        }
                      }
                    },
                  ),
                ),
              )
            else
              const SizedBox(key: Key('scanner_placeholder'), height: 0),

            if (scannerEnabled) const SizedBox(height: 24),

            // Hint text.
            Text(
              l10n.wsCheckinScanHint,
              style: WrTextStyles.hMedium.copyWith(color: WrColors.dark),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Manual entry label.
            Text(
              l10n.wsCheckinManualLabel,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 8),

            // Manual entry field.
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'AB12CD34',
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: _handleCode,
            ),

            const SizedBox(height: 16),

            // Submit button.
            ElevatedButton(
              onPressed: _processing
                  ? null
                  : () => _handleCode(_controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: WrColors.coral,
                foregroundColor: WrColors.white,
              ),
              child: Text(l10n.wsCheckinSubmit),
            ),

            const SizedBox(height: 16),

            // Inline error.
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                key: const Key('checkin_error'),
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),

            // Inline success.
            if (_success)
              Text(
                l10n.wsCheckinSuccess,
                key: const Key('checkin_success'),
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
