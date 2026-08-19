import 'package:flutter/material.dart';

/// Official VIMES brand logo (symbol + wordmark + tagline).
class VimesLogo extends StatelessWidget {
  const VimesLogo({
    super.key,
    this.width = 240,
    this.height,
  });

  static const assetPath = 'lib/assets/image/vimes_logo.png';

  /// Display width. Height follows the asset aspect ratio when [height] is null.
  final double width;

  /// Optional fixed height. Prefer [width] for correct proportions (~2.86:1).
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'VIMES',
    );
  }
}
