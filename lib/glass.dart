import 'dart:ui';
import 'galaxy_background.dart';
import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool blur;
  final EdgeInsetsGeometry? margin;
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = false,
    this.margin,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .18 : .06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          enabled: blur,
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        const Color(0xFF382B4B).withValues(alpha: .78),
                        const Color(0xFF251C34).withValues(alpha: .65),
                      ]
                    : [
                        Colors.white.withValues(alpha: .82),
                        Colors.white.withValues(alpha: .52),
                      ],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? .16 : .85),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? margin;
  const GlassCard({super.key, this.child, this.margin});
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: GlassSurface(
      margin: margin ?? const EdgeInsets.all(4),
      child: child ?? const SizedBox(),
    ),
  );
}

class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF181222), Color(0xFF302144), Color(0xFF142B34)]
              : const [Color(0xFFF5F1FF), Color(0xFFE9E3FF), Color(0xFFE3F2F6)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (dark) const Positioned.fill(child: GalaxyBackground()),
          RepaintBoundary(child: child),
        ],
      ),
    );
  }
}

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  const GlassAppBar({super.key, required this.title});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
    title: title,
    flexibleSpace: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0x99251C34)
              : const Color(0x99FFFFFF),
        ),
      ),
    ),
  );
}

class GlassMenu extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<String> labels;
  final List<IconData> icons;
  const GlassMenu({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.labels,
    required this.icons,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(child: item(context, i)),
        ],
      ),
    ),
  );
  Widget item(BuildContext context, int i) {
    final active = i == selectedIndex;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = active
        ? (dark ? Colors.white : const Color(0xFF542398))
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: .75);
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onSelected(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 62,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? const [Color(0xFF9868E6), Color(0xFF774ED4)]
                        : const [Color(0xFFE5D2FF), Color(0xFFCBA8FF)],
                  )
                : null,
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: .7)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icons[i], size: 22, color: foreground),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
