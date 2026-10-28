import Foundation

// MyAppsWidgetKit: the reader half of MyApps-Widget for WidgetKit extensions.
// Add this file to the app's widget extension target (it does not use Flutter).
// The rules mirror packages/myapps_widget_core/lib/src/envelope.dart and the
// fixtures in contract/; see doc/en-us/envelope.md.

/// Envelope format version this reader fully understands.
public let widgetEnvelopeVersion = 1

/// Privacy level of an envelope; unknown wire values read as `.normal`.
public enum WidgetPrivacy: String {
  case normal
  case sensitive
  case hidden

  /// Purpose: Read a level from its wire name.
  /// Inputs: `value` — any JSON value.
  /// Returns: The matching level, or `.normal`.
  /// Side effects: None.
  /// Notes: Mirrors `WidgetPrivacy.fromWire` in Dart.
  public static func fromWire(_ value: Any?) -> WidgetPrivacy {
    (value as? String).flatMap(WidgetPrivacy.init(rawValue:)) ?? .normal
  }
}

/// The widget text size multiplier range, shared with Dart and Kotlin.
public enum WidgetTextScale {
  public static let min = 0.9
  public static let max = 1.5
  public static let defaultValue = 1.0

  /// Purpose: Keep a text scale inside the supported range.
  /// Inputs: `scale`.
  /// Returns: The value clamped and rounded to one decimal; 1.0 for NaN or infinity.
  /// Side effects: None.
  /// Notes: Mirrors `WidgetTextScale.clamp` in Dart.
  public static func clamp(_ scale: Double) -> Double {
    guard scale.isFinite else { return defaultValue }
    return (Swift.min(Swift.max(scale, min), max) * 10).rounded() / 10
  }
}

/// A decoded envelope. `payload` is the app's own object.
public struct WidgetEnvelope {
  public let version: Int
  public let kind: String
  public let payloadVersion: Int
  /// Epoch milliseconds.
  public let generatedAt: Int64
  public let textScale: Double
  public let privacy: WidgetPrivacy
  /// Sorted epoch milliseconds.
  public let refreshAt: [Int64]
  public let instanceId: String?
  public let payload: [String: Any]

  /// Purpose: Return `generatedAt` as a date.
  /// Inputs: None.
  /// Returns: `Date`.
  /// Side effects: None.
  /// Notes: None.
  public var generatedDate: Date { Date(timeIntervalSince1970: TimeInterval(generatedAt) / 1000) }

  /// Purpose: Return `refreshAt` as dates, for timeline entries.
  /// Inputs: None.
  /// Returns: `[Date]`, ascending.
  /// Side effects: None.
  /// Notes: None.
  public var refreshDates: [Date] {
    refreshAt.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
  }

  /// Purpose: Scale a font size by the envelope's text scale.
  /// Inputs: `size` — points at 100%.
  /// Returns: The scaled size.
  /// Side effects: None.
  /// Notes: None.
  public func pt(_ size: Double) -> Double { size * textScale }

  /// Purpose: Decode the payload into the app's own type.
  /// Inputs: `type`.
  /// Returns: The decoded payload, or nil when it does not match.
  /// Side effects: None.
  /// Notes: Unknown payload keys are ignored by `JSONDecoder`, so a newer app
  /// payload still decodes in an older extension when its fields are optional.
  public func decodePayload<T: Decodable>(_ type: T.Type) -> T? {
    guard JSONSerialization.isValidJSONObject(payload),
      let data = try? JSONSerialization.data(withJSONObject: payload)
    else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
}

/// Outcome of reading a stored envelope; the check order matches Dart.
public enum WidgetEnvelopeStatus {
  case missing
  case invalid
  case tooNew
  case ok
}

/// A read result: the status and, for `.ok`, the envelope.
public struct WidgetEnvelopeRead {
  public let status: WidgetEnvelopeStatus
  public let envelope: WidgetEnvelope?

  /// Purpose: Decode stored text with the shared contract rules.
  /// Inputs: `raw` — the stored string or nil; `expectedKind` — the kind being rendered, or nil.
  /// Returns: The read result.
  /// Side effects: None.
  /// Notes: missing → invalid JSON or payload → tooNew → kind mismatch → ok.
  public static func decode(_ raw: String?, expectedKind: String? = nil) -> WidgetEnvelopeRead {
    guard let raw = raw, !raw.isEmpty else { return WidgetEnvelopeRead(status: .missing, envelope: nil) }
    guard let data = raw.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data),
      let json = object as? [String: Any],
      let payload = json["payload"] as? [String: Any]
    else { return WidgetEnvelopeRead(status: .invalid, envelope: nil) }
    let version = number(json["v"]).map { Int($0) } ?? 0
    if version > widgetEnvelopeVersion { return WidgetEnvelopeRead(status: .tooNew, envelope: nil) }
    let kind = json["kind"] as? String ?? ""
    if let expectedKind = expectedKind, kind != expectedKind {
      return WidgetEnvelopeRead(status: .invalid, envelope: nil)
    }
    let refresh = (json["refreshAt"] as? [Any] ?? []).compactMap { number($0).map { Int64($0) } }.sorted()
    let envelope = WidgetEnvelope(
      version: version,
      kind: kind,
      payloadVersion: number(json["pv"]).map { Int($0) } ?? 1,
      generatedAt: number(json["generatedAt"]).map { Int64($0) } ?? 0,
      textScale: WidgetTextScale.clamp(number(json["textScale"]) ?? WidgetTextScale.defaultValue),
      privacy: WidgetPrivacy.fromWire(json["privacy"]),
      refreshAt: refresh,
      instanceId: json["instanceId"] as? String,
      payload: payload)
    return WidgetEnvelopeRead(status: .ok, envelope: envelope)
  }

  /// Purpose: Read a finite JSON number, excluding booleans.
  /// Inputs: `value`.
  /// Returns: The number as `Double`, or nil.
  /// Side effects: None.
  /// Notes: `JSONSerialization` returns booleans as `NSNumber` too.
  static func number(_ value: Any?) -> Double? {
    guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
    let d = n.doubleValue
    return d.isFinite ? d : nil
  }
}

/// Reads envelopes from the App Group the app's `MyAppsWidgetPlugin` writes.
public enum WidgetEnvelopeStore {
  /// Key prefix; must match `MyAppsWidgetPlugin.keyPrefix`.
  public static let keyPrefix = "myapps_widget.envelope."

  /// Purpose: Read and decode a kind's envelope.
  /// Inputs: `kind`; `appGroupId` — the App Group shared with the app.
  /// Returns: The read result, checked against `kind`.
  /// Side effects: Reads the App Group `UserDefaults`.
  /// Notes: An App Group that cannot be opened reads as `.missing`.
  public static func read(kind: String, appGroupId: String) -> WidgetEnvelopeRead {
    let raw = UserDefaults(suiteName: appGroupId)?.string(forKey: keyPrefix + kind)
    return WidgetEnvelopeRead.decode(raw, expectedKind: kind)
  }
}
