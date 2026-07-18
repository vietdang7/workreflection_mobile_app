import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class MyWorkshopsScreen extends StatelessWidget {
  const MyWorkshopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wsMyTitle)),
      body: const SizedBox.shrink(),
    );
  }
}
