import 'package:flutter/material.dart';

class WrSectionDivider extends StatelessWidget {
  const WrSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      thickness: 1,
      color: Color.fromRGBO(255, 104, 89, 0.10), // coral 10%
    );
  }
}
