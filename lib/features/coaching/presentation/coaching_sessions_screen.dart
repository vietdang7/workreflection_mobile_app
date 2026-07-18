import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class CoachingSessionsScreen extends StatelessWidget {
  const CoachingSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.coachMyTitle)),
      body: const SizedBox.shrink(),
    );
  }
}
