import 'package:flutter/material.dart';

/// A fixed-size, rounded, tinted card that stands in for a launcher cell in
/// an in-app widget preview.
///
/// Apps draw their widget's content inside it with the same text sizes as
/// the native layout times the chosen text scale. Overflow is clipped, like
/// a real widget.
class WidgetPreviewSurface extends StatelessWidget {
  /// Purpose: Create a preview surface.
  /// Inputs: `width`, `height` — logical pixels; `child`; optional `padding`,
  /// `radius` (default 24, close to both platforms' widget corners) and
  /// `color` (default the theme's secondary container at 55%).
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Standard sizes: [smallSide] for 2×2, [stripHeight] for 2×1.
  const WidgetPreviewSurface({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 24,
    this.color,
  });

  /// Side of a 2×2 preview.
  static const double smallSide = 172;

  /// Height of a 2×1 strip preview (its width is [smallSide]).
  static const double stripHeight = 76;

  /// Width in logical pixels.
  final double width;

  /// Height in logical pixels.
  final double height;

  /// Inner padding.
  final EdgeInsets padding;

  /// Corner radius.
  final double radius;

  /// Fill color; null uses the theme.
  final Color? color;

  /// Content.
  final Widget child;

  /// Purpose: Draw the clipped surface.
  /// Inputs: `context`.
  /// Returns: The card.
  /// Side effects: None.
  /// Notes: None.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}
