import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class WorkshopDetailScreen extends StatelessWidget {
  final String workshopId;
  const WorkshopDetailScreen({super.key, required this.workshopId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wsListTitle)),
      body: const SizedBox.shrink(),
    );
  }
}
