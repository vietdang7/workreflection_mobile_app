import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class CheckinScreen extends StatelessWidget {
  const CheckinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wsCheckinTitle)),
      body: const SizedBox.shrink(),
    );
  }
}
