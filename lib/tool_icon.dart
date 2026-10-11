import 'package:flutter/material.dart';
import 'models.dart';

/// Tool artwork is stored as transparent PNGs; native navigation icons stay crisp.
class ToolGlyph extends StatelessWidget {
  final DocTool tool;
  final double height;
  const ToolGlyph({super.key, required this.tool, this.height = 88});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Image.asset(
      tool.assetPath,
      height: height,
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
          .ceil()
          .clamp(1, 512),
      filterQuality: FilterQuality.low,
      fit: BoxFit.contain,
      semanticLabel: tool.name,
    ),
  );
}
