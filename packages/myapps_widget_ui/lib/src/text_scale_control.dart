import 'package:flutter/material.dart';
import 'package:myapps_widget_core/myapps_widget_core.dart';

/// The "widget text size" setting: a title row with the current percentage
/// and a slider over the shared [WidgetTextScale] range.
///
/// Put the app's preview right below it so the user sees the result.
class WidgetTextScaleControl extends StatelessWidget {
  /// Purpose: Create the control.
  /// Inputs: `value`; `onChanged` — receives clamped values; `title`;
  /// optional `subtitle` and `leading` (default a text-size icon).
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Wording is injected; the percentage is locale-neutral.
  const WidgetTextScaleControl({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.leading = const Icon(Icons.format_size),
  });

  /// Current multiplier.
  final double value;

  /// Called with each new clamped multiplier.
  final ValueChanged<double> onChanged;

  /// Row title.
  final String title;

  /// Row subtitle.
  final String? subtitle;

  /// Row leading widget.
  final Widget? leading;

  /// Purpose: Format a multiplier as a percentage.
  /// Inputs: `scale`.
  /// Returns: For example `120%`.
  /// Side effects: None.
  /// Notes: None.
  static String percent(double scale) => '${(scale * 100).round()}%';

  /// Purpose: Build the title row and slider.
  /// Inputs: `context`.
  /// Returns: A column.
  /// Side effects: None.
  /// Notes: Out-of-range values are shown clamped.
  @override
  Widget build(BuildContext context) {
    final shown = WidgetTextScale.clamp(value);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: leading,
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: Text(
            percent(shown),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Slider(
          value: shown,
          min: WidgetTextScale.min,
          max: WidgetTextScale.max,
          divisions: WidgetTextScale.divisions,
          label: percent(shown),
          onChanged: (v) => onChanged(WidgetTextScale.clamp(v)),
        ),
      ],
    );
  }
}
