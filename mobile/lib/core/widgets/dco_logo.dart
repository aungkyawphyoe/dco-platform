import 'package:flutter/material.dart';

class DcoLogo extends StatelessWidget {
  const DcoLogo({super.key, this.size = 240});

  static const assetPath = 'assets/branding/autox-logo-cb.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'AutoX',
    );
  }
}
