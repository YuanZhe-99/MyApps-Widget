import 'dart:convert';

import 'privacy.dart';
import 'text_scale.dart';

/// Envelope format version this package writes and fully understands.
///
/// Bump only together with the Kotlin and Swift readers and new contract
/// fixtures; readers treat a higher value as [WidgetEnvelopeStatus.tooNew].
const int widgetEnvelopeVersion = 1;

/// The stored unit of widget data: package-owned metadata around an
/// app-owned `payload`. See `doc/en-us/envelope.md`.
class WidgetEnvelope {
  /// Purpose: Create an envelope.
  /// Inputs: `kind`; `generatedAt` (stored as UTC epoch milliseconds);
  /// `payload` — the app's JSON object; optional `payloadVersion`,
  /// `textScale`, `privacy`, `refreshAt`, `instanceId`, `extraJson`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: `textScale` is clamped and `refreshAt` sorted on output, not here.
  const WidgetEnvelope({
    required this.kind,
    required this.generatedAt,
    required this.payload,
    this.version = widgetEnvelopeVersion,
    this.payloadVersion = 1,
    this.textScale = WidgetTextScale.defaultValue,
    this.privacy = WidgetPrivacy.normal,
    this.refreshAt = const [],
    this.instanceId,
    this.extraJson = const {},
  });

  /// Envelope format version (`v`).
  final int version;

  /// Widget kind id (`kind`).
  final String kind;

  /// The app's payload format version (`pv`).
  final int payloadVersion;

  /// When the app built this envelope (`generatedAt`).
  final DateTime generatedAt;

  /// Widget text size multiplier (`textScale`).
  final double textScale;

  /// Privacy level (`privacy`).
  final WidgetPrivacy privacy;

  /// Instants at which the widget should redraw without the app (`refreshAt`).
  final List<DateTime> refreshAt;

  /// Configured widget instance, for configurable widgets (`instanceId`).
  final String? instanceId;

  /// App-owned content (`payload`); the package never interprets it.
  final Map<String, dynamic> payload;

  /// Unknown top-level fields, kept so a rewrite never drops newer data.
  final Map<String, dynamic> extraJson;

  static const _known = {
    'v',
    'kind',
    'pv',
    'generatedAt',
    'textScale',
    'privacy',
    'refreshAt',
    'instanceId',
    'payload',
  };

  /// Purpose: Serialize to the stored JSON object.
  /// Inputs: None.
  /// Returns: A JSON-ready map.
  /// Side effects: None.
  /// Notes: Clamps `textScale`, sorts `refreshAt` and omits a null
  /// `instanceId`; unknown fields from [extraJson] are written back first so
  /// known fields always win.
  Map<String, dynamic> toJson() {
    final refresh =
        refreshAt.map((t) => t.toUtc().millisecondsSinceEpoch).toList()..sort();
    return {
      ...extraJson,
      'v': version,
      'kind': kind,
      'pv': payloadVersion,
      'generatedAt': generatedAt.toUtc().millisecondsSinceEpoch,
      'textScale': WidgetTextScale.clamp(textScale),
      'privacy': privacy.wire,
      'refreshAt': refresh,
      if (instanceId != null) 'instanceId': instanceId,
      'payload': payload,
    };
  }

  /// Purpose: Encode to the string handed to the native store.
  /// Inputs: None.
  /// Returns: Compact JSON.
  /// Side effects: None.
  /// Notes: Compact, not pretty-printed: the store is device-local and never
  /// synced, so the raw-equality rule for synced files does not apply.
  String encode() => jsonEncode(toJson());

  /// Purpose: Read a decoded JSON object as an envelope, tolerantly.
  /// Inputs: `json`.
  /// Returns: The envelope.
  /// Side effects: None.
  /// Notes: Missing fields take defaults, `textScale` is clamped, unknown
  /// privacy reads as normal, non-numeric `refreshAt` items are skipped and
  /// unknown fields go to [extraJson]. Does not check `v` or `kind`; use
  /// [WidgetEnvelopeRead.decode] for that.
  factory WidgetEnvelope.fromJson(Map<String, dynamic> json) {
    final generated = json['generatedAt'];
    final scale = json['textScale'];
    final refresh = json['refreshAt'];
    final payload = json['payload'];
    final instance = json['instanceId'];
    return WidgetEnvelope(
      version: _int(json['v']) ?? 0,
      kind: json['kind'] is String ? json['kind'] as String : '',
      payloadVersion: _int(json['pv']) ?? 1,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(
        _int(generated) ?? 0,
        isUtc: true,
      ),
      textScale: WidgetTextScale.clamp(
        scale is num ? scale.toDouble() : WidgetTextScale.defaultValue,
      ),
      privacy: WidgetPrivacy.fromWire(json['privacy']),
      refreshAt: [
        if (refresh is List)
          for (final item in refresh)
            if (_int(item) != null)
              DateTime.fromMillisecondsSinceEpoch(_int(item)!, isUtc: true),
      ]..sort(),
      instanceId: instance is String ? instance : null,
      payload: payload is Map ? Map<String, dynamic>.from(payload) : const {},
      extraJson: {
        for (final entry in json.entries)
          if (!_known.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  /// Purpose: Read an integer that JSON may have stored as a double.
  /// Inputs: `value`.
  /// Returns: The integer, or null when `value` is not a finite number.
  /// Side effects: None.
  /// Notes: None.
  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is double && value.isFinite) return value.toInt();
    return null;
  }
}

/// Outcome of reading a stored envelope.
enum WidgetEnvelopeStatus {
  /// Nothing stored yet for the kind.
  missing,

  /// Stored text is not a JSON object, has no payload object, or belongs to
  /// another kind.
  invalid,

  /// Written by a newer envelope format; the reader should ask the user to
  /// open (update) the app rather than guess.
  tooNew,

  /// Readable.
  ok,
}

/// A read result: the status and, when [WidgetEnvelopeStatus.ok], the envelope.
class WidgetEnvelopeRead {
  /// Purpose: Hold one read result.
  /// Inputs: `status`, optional `envelope`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  const WidgetEnvelopeRead(this.status, [this.envelope]);

  /// What happened.
  final WidgetEnvelopeStatus status;

  /// The envelope, only for [WidgetEnvelopeStatus.ok].
  final WidgetEnvelope? envelope;

  /// Purpose: Decode stored text with the same rules as the native readers.
  /// Inputs: `raw` — the stored string or null; `expectedKind` — the kind
  /// the caller renders, or null to accept any.
  /// Returns: The read result.
  /// Side effects: None.
  /// Notes: Order of checks is part of the contract (see
  /// `contract/expectations.json`): missing → invalid JSON or payload →
  /// tooNew → kind mismatch → ok.
  static WidgetEnvelopeRead decode(String? raw, {String? expectedKind}) {
    if (raw == null || raw.isEmpty) {
      return const WidgetEnvelopeRead(WidgetEnvelopeStatus.missing);
    }
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return const WidgetEnvelopeRead(WidgetEnvelopeStatus.invalid);
    }
    if (json is! Map<String, dynamic> || json['payload'] is! Map) {
      return const WidgetEnvelopeRead(WidgetEnvelopeStatus.invalid);
    }
    final envelope = WidgetEnvelope.fromJson(json);
    if (envelope.version > widgetEnvelopeVersion) {
      return const WidgetEnvelopeRead(WidgetEnvelopeStatus.tooNew);
    }
    if (expectedKind != null && envelope.kind != expectedKind) {
      return const WidgetEnvelopeRead(WidgetEnvelopeStatus.invalid);
    }
    return WidgetEnvelopeRead(WidgetEnvelopeStatus.ok, envelope);
  }
}
