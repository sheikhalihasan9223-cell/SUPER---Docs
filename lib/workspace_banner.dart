import 'package:flutter/material.dart';
import 'models.dart';

const heroEyebrowFontSize = 20.0;

class WorkspaceBanner extends StatelessWidget {
  final bool images;
  final bool compact;
  final double? availableWidth;
  final VoidCallback onStart;
  final String? heading, caption, actionLabel, eyebrow, assetPath;
  const WorkspaceBanner({
    super.key,
    required this.images,
    this.compact = false,
    this.availableWidth,
    this.heading,
    this.caption,
    this.actionLabel,
    this.eyebrow,
    this.assetPath,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final width = availableWidth ?? MediaQuery.sizeOf(context).width;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final wide = width >= 650;
    final artworkWidth = (width * (compact ? .34 : .38)).clamp(
      compact ? 80.0 : 104.0,
      compact ? 260.0 : 260.0,
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact
            ? 16
            : wide
            ? 34
            : 20,
        vertical: compact
            ? 16
            : wide
            ? 30
            : 24,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 18 : 24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF302044), Color(0xFF3D275B)]
              : const [Color(0xFFF2EDFF), Color(0xFFE8DEFC)],
        ),
        border: Border.all(
          color: dark ? const Color(0xFF513773) : const Color(0xFFE3D8FA),
        ),
        boxShadow: [
          BoxShadow(
            color: brandPurple.withValues(alpha: dark ? .08 : .04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow ?? (images ? 'IMAGE WORKSPACE' : 'PDF WORKSPACE'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: heroEyebrowFontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: dark
                        ? const Color(0xFFCEAFFA)
                        : const Color(0xFF7142AE),
                  ),
                ),
                SizedBox(height: compact ? 6 : 10),
                Text(
                  heading ??
                      (images
                          ? 'All-in-one\nImage Workspace'
                          : 'All-in-one\nPDF Workspace'),
                  style: TextStyle(
                    fontSize: compact
                        ? (wide ? 28 : 16)
                        : wide
                        ? 36
                        : (images ? 19 : 20),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                    height: 1.18,
                    color: dark
                        ? const Color(0xFFF6EFFF)
                        : const Color(0xFF28173F),
                  ),
                ),
                SizedBox(height: compact ? 6 : 12),
                Text(
                  caption ??
                      (images
                          ? 'Compress, convert and resize.\nMade simple, on your device.'
                          : 'Convert, organize and secure.\nOne place for your documents.'),
                  style: TextStyle(
                    fontSize: compact
                        ? (wide ? 12 : 9)
                        : wide
                        ? 14
                        : 11,
                    height: compact ? 1.4 : 1.6,
                    color: dark
                        ? const Color(0xFFC9BBD9)
                        : const Color(0xFF6C5B80),
                  ),
                ),
                SizedBox(height: compact ? 10 : 20),
                FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: brandPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact
                          ? 12
                          : wide
                          ? 22
                          : 14,
                      vertical: compact ? 10 : 14,
                    ),
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          actionLabel ??
                              (images ? 'Resize an image' : 'Create a PDF'),
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: compact
                ? 8
                : wide
                ? 24
                : 10,
          ),
          SizedBox(
            width: artworkWidth,
            height: compact
                ? (wide ? 190 : 144)
                : wide
                ? 260
                : 200,
            child: ClipRect(
              child: Transform.scale(
                scale: compact ? 1.0 : 1.2,
                child: Image.asset(
                  assetPath ?? 'assets/illustrations/workspace-hero.png',
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeHeroCarousel extends StatefulWidget {
  final double width;
  final VoidCallback onCreatePdf, onEnhance;
  const HomeHeroCarousel({
    super.key,
    required this.width,
    required this.onCreatePdf,
    required this.onEnhance,
  });
  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  final controller = PageController();
  int selected = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pdfHeight = measureHero(context, widget.width - 4, false);
    final photoHeight = measureHero(context, widget.width - 4, true);
    final height = pdfHeight > photoHeight ? pdfHeight : photoHeight;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView(
            key: const ValueKey('home-hero-pages'),
            controller: controller,
            onPageChanged: (index) => setState(() => selected = index),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: WorkspaceBanner(
                  compact: true,
                  images: false,
                  availableWidth: widget.width - 4,
                  onStart: widget.onCreatePdf,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: WorkspaceBanner(
                  compact: true,
                  images: true,
                  availableWidth: widget.width - 4,
                  heading: 'Enhance your\nphotos',
                  eyebrow: 'AI ENHANCEMENT',
                  caption:
                      'Brighter color. Clearer contrast.\nEnhance with on-device AI.',
                  actionLabel: 'Enhance a photo',
                  assetPath: 'assets/tool_icons_3d/image_enhance.png',
                  onStart: widget.onEnhance,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 2; i++)
              Semantics(
                button: true,
                selected: selected == i,
                label: i == 0
                    ? 'PDF workspace banner'
                    : 'Photo enhancement banner',
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 6,
                      width: selected == i ? 22 : 6,
                      decoration: BoxDecoration(
                        color: selected == i
                            ? brandPurple
                            : brandPurple.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

double measureHero(BuildContext context, double width, bool photo) {
  final wide = width >= 650;
  final artworkWidth = (width * .34).clamp(80.0, 260.0);
  final textWidth = (width - 34 - 8 - artworkWidth).clamp(1.0, 2000.0);
  final inherited = DefaultTextStyle.of(context).style;
  double measure(
    String value,
    TextStyle style,
    double available, {
    int? lines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: lines,
      ellipsis: lines == null ? null : '?',
    )..layout(maxWidth: available);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final labelHeight = measure(
    photo ? 'AI ENHANCEMENT' : 'PDF WORKSPACE',
    inherited.merge(
      const TextStyle(
        fontSize: heroEyebrowFontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    ),
    textWidth,
    lines: 1,
  );
  final titleHeight = measure(
    photo ? 'Enhance your\nphotos' : 'All-in-one\nPDF Workspace',
    inherited.merge(
      TextStyle(
        fontSize: wide ? 28 : 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -.8,
        height: 1.18,
      ),
    ),
    textWidth,
  );
  final captionHeight = measure(
    photo
        ? 'Brighter color. Clearer contrast.\nEnhance with on-device AI.'
        : 'Convert, organize and secure.\nOne place for your documents.',
    inherited.merge(TextStyle(fontSize: wide ? 12 : 9, height: 1.4)),
    textWidth,
  );
  final buttonLabelHeight = measure(
    photo ? 'Enhance a photo' : 'Create a PDF',
    (Theme.of(context).textTheme.labelLarge ?? inherited).merge(
      const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
    (textWidth - 48).clamp(1.0, 2000.0),
  );
  final buttonHeight = (buttonLabelHeight + 20).clamp(48.0, 1000.0);
  final contentHeight =
      labelHeight + titleHeight + captionHeight + buttonHeight + 22;
  final artHeight = wide ? 190.0 : 144.0;
  return (contentHeight > artHeight ? contentHeight : artHeight) + 38;
}
