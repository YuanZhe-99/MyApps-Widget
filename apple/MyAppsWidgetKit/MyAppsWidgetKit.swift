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

/// One queued tap on an interactive widget control; mirrors Dart's `WidgetAction`.
public struct WidgetAction {
  public let id: String
  public let kind: String
  public let action: String
  /// Epoch milliseconds.
  public let at: Int64
  public let args: [String: Any]
  public let instanceId: String?

  /// Purpose: Return `at` as a date.
  /// Inputs: None.
  /// Returns: `Date`.
  /// Side effects: None.
  /// Notes: None.
  public var date: Date { Date(timeIntervalSince1970: TimeInterval(at) / 1000) }

  /// Purpose: Serialize to the stored JSON object.
  /// Inputs: None.
  /// Returns: A JSON-ready dictionary.
  /// Side effects: None.
  /// Notes: `instanceId` is written only when present.
  public func toJson() -> [String: Any] {
    var json: [String: Any] = ["id": id, "kind": kind, "action": action, "at": at, "args": args]
    if let instanceId = instanceId { json["instanceId"] = instanceId }
    return json
  }
}

/// The pending-action queue in the App Group, key `myapps_widget.actions`: a
/// JSON array shared by every kind of the app, oldest first.
public enum WidgetActionQueue {
  /// Queue key; must match `MyAppsWidgetPlugin.actionsKey`.
  public static let key = "myapps_widget.actions"

  /// Darwin notification posted after an append; the app's plugin observes it.
  public static let notificationName = "com.yuanzhe.myapps_widget.actions"

  /// Most entries kept; appending beyond it drops the oldest.
  public static let maxLength = 200

  /// Purpose: Decode stored queue text with the shared contract rules.
  /// Inputs: `raw` — the stored string or nil.
  /// Returns: The valid actions in stored order; empty for missing, invalid or non-array text.
  /// Side effects: None.
  /// Notes: Entries without non-empty string `id`, `kind`, `action` or a numeric
  /// `at` are skipped; a non-object `args` reads as `[:]` and a non-string
  /// `instanceId` as nil. Booleans are never numbers.
  public static func decode(_ raw: String?) -> [WidgetAction] {
    guard let raw = raw, !raw.isEmpty, let data = raw.data(using: .utf8),
      let array = (try? JSONSerialization.jsonObject(with: data)) as? [Any]
    else { return [] }
    return array.compactMap { value in
      guard let json = value as? [String: Any] else { return nil }
      func text(_ key: String) -> String? {
        guard let s = json[key] as? String, !s.isEmpty else { return nil }
        return s
      }
      guard let id = text("id"), let kind = text("kind"), let action = text("action"),
        let at = WidgetEnvelopeRead.number(json["at"])
      else { return nil }
      return WidgetAction(
        id: id, kind: kind, action: action, at: Int64(at),
        args: json["args"] as? [String: Any] ?? [:],
        instanceId: json["instanceId"] as? String)
    }
  }

  /// Purpose: Return the queued actions of one kind.
  /// Inputs: `kind`; `appGroupId`.
  /// Returns: Its actions, oldest first.
  /// Side effects: Reads the App Group `UserDefaults`.
  /// Notes: Timeline providers replay these over the envelope so a tap shows at once.
  public static func pending(kind: String, appGroupId: String) -> [WidgetAction] {
    decode(UserDefaults(suiteName: appGroupId)?.string(forKey: key)).filter { $0.kind == kind }
  }

  /// Purpose: Append one tap and tell a running app.
  /// Inputs: `kind`; `action`; `args`; optional `instanceId`; `appGroupId`.
  /// Returns: The appended action, or nil when the App Group cannot be opened.
  /// Side effects: Rewrites the queue (keeping at most `maxLength` newest) and
  /// posts `notificationName` on the Darwin notification center.
  /// Notes: Called from the widget extension, usually through
  /// `MyAppsWidgetActionIntent`.
  @discardableResult
  public static func append(
    kind: String, action: String, args: [String: Any] = [:], instanceId: String? = nil,
    appGroupId: String
  ) -> WidgetAction? {
    guard let defaults = UserDefaults(suiteName: appGroupId) else { return nil }
    let entry = WidgetAction(
      id: UUID().uuidString, kind: kind, action: action,
      at: Int64((Date().timeIntervalSince1970 * 1000).rounded()), args: args,
      instanceId: instanceId)
    let next = Array((decode(defaults.string(forKey: key)) + [entry]).suffix(maxLength))
    if let data = try? JSONSerialization.data(withJSONObject: next.map { $0.toJson() }),
      let text = String(data: data, encoding: .utf8)
    {
      defaults.set(text, forKey: key)
    }
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(notificationName as CFString), nil, nil, true)
    return entry
  }
}

#if canImport(AppIntents)
  import AppIntents

  /// The intent behind interactive widget controls (iOS 17+): queues one app
  /// action and lets WidgetKit redraw the widget.
  @available(iOS 17.0, macOS 14.0, *)
  public struct MyAppsWidgetActionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Widget action"
    public static let isDiscoverable = false

    @Parameter(title: "Kind") public var kind: String
    @Parameter(title: "Action") public var action: String
    @Parameter(title: "Arguments") public var argsJSON: String
    @Parameter(title: "App Group") public var appGroupId: String

    /// Purpose: Create an empty intent, as the AppIntents runtime requires.
    /// Inputs: None.
    /// Returns: None.
    /// Side effects: None.
    /// Notes: Use the other initializer in widget views.
    public init() {}

    /// Purpose: Create the intent for one control.
    /// Inputs: `kind`; `action`; `args` — JSON-serializable; `appGroupId`.
    /// Returns: None.
    /// Side effects: None.
    /// Notes: Arguments travel as JSON text because intent parameters are typed.
    public init(kind: String, action: String, args: [String: Any] = [:], appGroupId: String) {
      self.kind = kind
      self.action = action
      let data = (try? JSONSerialization.data(withJSONObject: args)) ?? Data("{}".utf8)
      self.argsJSON = String(data: data, encoding: .utf8) ?? "{}"
      self.appGroupId = appGroupId
    }

    /// Purpose: Queue the action.
    /// Inputs: None.
    /// Returns: An empty result.
    /// Side effects: Appends to `WidgetActionQueue` and notifies a running app.
    /// Notes: WidgetKit reloads the widget's timeline after `perform` returns.
    public func perform() async throws -> some IntentResult {
      let args =
        (try? JSONSerialization.jsonObject(with: Data(argsJSON.utf8))) as? [String: Any] ?? [:]
      WidgetActionQueue.append(kind: kind, action: action, args: args, appGroupId: appGroupId)
      return .result()
    }
  }
#endif
