import 'privacy.dart';

/// Describes one widget data stream an app publishes.
///
/// A kind is the unit of storage and refresh: one envelope per kind, and
/// publishing a kind redraws only the native widgets listed here. Several
/// native widgets (sizes, families) may render the same kind.
class WidgetKindDescriptor {
  /// Purpose: Describe a widget kind.
  /// Inputs: `id` — a dotted lower-camel id such as `myanime.upNext`;
  /// `androidProviders` — fully qualified `AppWidgetProvider` class names;
  /// `iosKinds` — WidgetKit `kind` strings; `payloadVersion` — the app's own
  /// payload format version; `defaultPrivacy`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Throws [ArgumentError] for an id that [isValidId] rejects.
  WidgetKindDescriptor({
    required this.id,
    this.androidProviders = const [],
    this.iosKinds = const [],
    this.payloadVersion = 1,
    this.defaultPrivacy = WidgetPrivacy.normal,
  }) {
    if (!isValidId(id)) {
      throw ArgumentError.value(id, 'id', 'must look like app.widgetName');
    }
    if (payloadVersion < 1) {
      throw ArgumentError.value(
        payloadVersion,
        'payloadVersion',
        'must be >= 1',
      );
    }
  }

  /// Envelope `kind` and storage key suffix.
  final String id;

  /// Android providers to redraw after a publish, fully qualified.
  final List<String> androidProviders;

  /// WidgetKit kinds to reload after a publish.
  final List<String> iosKinds;

  /// Written as the envelope's `pv`.
  final int payloadVersion;

  /// Privacy used when a publish does not pass one.
  final WidgetPrivacy defaultPrivacy;

  static final _idPattern = RegExp(
    r'^[a-z][a-zA-Z0-9]*(\.[a-z][a-zA-Z0-9]*)+$',
  );

  /// Purpose: Check a kind id's shape.
  /// Inputs: `id`.
  /// Returns: `true` for at least two dot-separated lower-camel segments.
  /// Side effects: None.
  /// Notes: The first segment names the app, which keeps kinds unique when
  /// several apps' envelopes are inspected together.
  static bool isValidId(String id) => _idPattern.hasMatch(id);
}
