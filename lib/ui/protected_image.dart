import 'package:flutter/material.dart';

import '../services/protected_assets.dart';

class ProtectedImage extends StatelessWidget {
  const ProtectedImage(
    this.asset, {
    this.width,
    this.height,
    this.fit,
    super.key,
  });

  final ProtectedImageAsset asset;
  final double? width;
  final double? height;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      ProtectedAssets.image(asset),
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
  }
}
