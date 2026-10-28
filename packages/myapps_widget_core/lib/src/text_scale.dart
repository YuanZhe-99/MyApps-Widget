/// The widget text size multiplier shared by every app and both platforms.
///
/// The native readers clamp to the same range, so a value written by a
/// newer or misbehaving writer can never blow a widget layout apart.
abstract final class WidgetTextScale {
  /// Smallest supported multiplier.
  static const double min = 0.9;

  /// Largest supported multiplier.
  static const double max = 1.5;

  /// Multiplier used when nothing is stored.
  static const double defaultValue = 1.0;

  /// Slider step; [clamp] rounds to it.
  static const double step = 0.1;

  /// Number of slider divisions between [min] and [max].
  static const int divisions = 6;

  /// Purpose: Keep a text scale inside the supported range.
  /// Inputs: `scale`.
  /// Returns: The value clamped to [min]..[max] and rounded to one decimal;
  /// [defaultValue] for NaN or infinity.
  /// Side effects: None.
  /// Notes: Rounding keeps stored slider steps exact when compared.
  static double clamp(double scale) {
    if (!scale.isFinite) return defaultValue;
    final clamped = scale.clamp(min, max).toDouble();
    return (clamped * 10).roundToDouble() / 10;
  }
}
