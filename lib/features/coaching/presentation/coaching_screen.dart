import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class CoachingScreen extends StatelessWidget {
  const CoachingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.coachTitle)),
      body: const SizedBox.shrink(),
    );
  }
}
