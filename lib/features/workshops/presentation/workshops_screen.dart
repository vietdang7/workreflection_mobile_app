import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class WorkshopsScreen extends StatelessWidget {
  const WorkshopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wsListTitle)),
      body: const SizedBox.shrink(),
    );
  }
}
