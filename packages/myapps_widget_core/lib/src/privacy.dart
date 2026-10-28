/// How much of a widget's content may be shown where others can see it.
///
/// Native renderers decide what each level hides; the envelope only carries
/// the level. Unknown wire values read as [normal] so an older reader keeps
/// drawing a newer writer's widget.
enum WidgetPrivacy {
  /// Content may be shown anywhere, including the lock screen.
  normal('normal'),

  /// Content is personal; renderers redact it while the device is locked and
  /// on iOS mark it `privacySensitive`.
  sensitive('sensitive'),

  /// Content must not be shown at all; renderers draw a neutral placeholder.
  hidden('hidden');

  /// Purpose: Bind a level to its wire name.
  /// Inputs: `wire` — the string stored in the envelope.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Wire names are a compatibility contract; never rename them.
  const WidgetPrivacy(this.wire);

  /// The string stored in the envelope's `privacy` field.
  final String wire;

  /// Purpose: Read a level from its wire name.
  /// Inputs: `value` — any JSON value.
  /// Returns: The matching level, or [normal] for anything unknown.
  /// Side effects: None.
  /// Notes: Tolerant by design; see `doc/en-us/envelope.md`.
  static WidgetPrivacy fromWire(Object? value) {
    for (final level in values) {
      if (level.wire == value) return level;
    }
    return normal;
  }
}
