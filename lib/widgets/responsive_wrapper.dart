import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool fillHeight;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 650.0,
    this.fillHeight = true,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
