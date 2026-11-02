import 'dart:ui' show Size;

/// The size the launcher gives one placed Android widget instance, in dp.
///
/// Read from `AppWidgetManager.getAppWidgetOptions`; these are the dp the
/// RemoteViews are laid out in. A launcher may still draw the result scaled,
/// which the app cannot observe.
class PlacedWidgetSize {
  /// Purpose: Create a placed size.
  /// Inputs: `provider` — the provider class name; `widgetId`; the four
  /// option bounds in dp.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  const PlacedWidgetSize({
    required this.provider,
    required this.widgetId,
    required this.minWidth,
    required this.minHeight,
    required this.maxWidth,
    required this.maxHeight,
  });

  /// Purpose: Read one entry of the native `placedSizes` answer.
  /// Inputs: `map` — `provider`, `widgetId` and the four bounds.
  /// Returns: `PlacedWidgetSize`, or null when a field is missing or the
  /// instance has no size yet (all bounds zero).
  /// Side effects: None.
  /// Notes: Tolerant, so a malformed entry is skipped rather than thrown.
  static PlacedWidgetSize? fromMap(Map<Object?, Object?> map) {
    final provider = map['provider'];
    final widgetId = map['widgetId'];
    double? dp(String key) => (map[key] as num?)?.toDouble();
    final minWidth = dp('minWidth');
    final minHeight = dp('minHeight');
    final maxWidth = dp('maxWidth');
    final maxHeight = dp('maxHeight');
    if (provider is! String ||
        widgetId is! int ||
        minWidth == null ||
        minHeight == null ||
        maxWidth == null ||
        maxHeight == null ||
        (minWidth <= 0 && minHeight <= 0 && maxWidth <= 0 && maxHeight <= 0)) {
      return null;
    }
    return PlacedWidgetSize(
      provider: provider,
      widgetId: widgetId,
      minWidth: minWidth,
      minHeight: minHeight,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  /// Provider class name, as listed in the kind's `androidProviders`.
  final String provider;

  /// The instance's app widget id.
  final int widgetId;

  /// `OPTION_APPWIDGET_MIN_WIDTH` in dp (the portrait width).
  final double minWidth;

  /// `OPTION_APPWIDGET_MIN_HEIGHT` in dp (the landscape height).
  final double minHeight;

  /// `OPTION_APPWIDGET_MAX_WIDTH` in dp (the landscape width).
  final double maxWidth;

  /// `OPTION_APPWIDGET_MAX_HEIGHT` in dp (the portrait height).
  final double maxHeight;

  /// Purpose: The instance's size in portrait.
  /// Inputs: None.
  /// Returns: `minWidth × maxHeight`.
  /// Side effects: None.
  /// Notes: The Android convention for widget size options.
  Size get portrait => Size(minWidth, maxHeight);

  /// Purpose: The instance's size in landscape.
  /// Inputs: None.
  /// Returns: `maxWidth × minHeight`.
  /// Side effects: None.
  /// Notes: The Android convention for widget size options.
  Size get landscape => Size(maxWidth, minHeight);
}
