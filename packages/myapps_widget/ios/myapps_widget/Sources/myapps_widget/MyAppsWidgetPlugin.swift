import Flutter
import UIKit
import WidgetKit

/// Answers `com.yuanzhe.myapps_widget/bridge`: stores one envelope per kind in
/// the app's App Group and reloads that kind's WidgetKit timelines, and hands
/// the app the pending-action queue that interactive widget controls append to.
public class MyAppsWidgetPlugin: NSObject, FlutterPlugin {
  /// Matches `MyAppsWidgetBridge.channelName` in Dart.
  static let channelName = "com.yuanzhe.myapps_widget/bridge"

  /// Key prefix in the App Group `UserDefaults`; must match
  /// `apple/MyAppsWidgetKit/MyAppsWidgetKit.swift`.
  static let keyPrefix = "myapps_widget.envelope."

  /// Key of the pending-action queue; must match `WidgetActionQueue.key`.
  static let actionsKey = "myapps_widget.actions"

  /// Darwin notification the widget extension posts after queuing an action;
  /// must match `WidgetActionQueue.notificationName`.
  static let actionsNotification = "com.yuanzhe.myapps_widget.actions"

  private let channel: FlutterMethodChannel

  /// Purpose: Create the plugin for one channel.
  /// Inputs: `channel`.
  /// Returns: None.
  /// Side effects: Observes the Darwin notification for queued actions.
  /// Notes: The observer lives as long as the plugin (the engine).
  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    let observer = Unmanaged.passUnretained(self).toOpaque()
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(), observer,
      { _, observer, _, _, _ in
        guard let observer = observer else { return }
        let plugin = Unmanaged<MyAppsWidgetPlugin>.fromOpaque(observer).takeUnretainedValue()
        DispatchQueue.main.async { plugin.channel.invokeMethod("actionsQueued", arguments: nil) }
      },
      MyAppsWidgetPlugin.actionsNotification as CFString, nil, .deliverImmediately)
  }

  /// Purpose: Stop observing queued actions.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Removes the Darwin observer.
  /// Notes: None.
  deinit {
    CFNotificationCenterRemoveEveryObserver(
      CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())
  }

  /// Purpose: Register the bridge channel.
  /// Inputs: `registrar`.
  /// Returns: None.
  /// Side effects: Installs the method-channel handler.
  /// Notes: Called by the generated plugin registrant.
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(MyAppsWidgetPlugin(channel: channel), channel: channel)
  }

  /// Purpose: Handle `publish`, `clear`, `pendingActions` and `acknowledgeActions`.
  /// Inputs: `call` — `kind`, `appGroupId`, `iosKinds`, for `publish` the
  /// `envelope` string and for `acknowledgeActions` the `ids`; `result`.
  /// Returns: None; answers `result` (`pendingActions` with the raw queue text).
  /// Side effects: Writes or removes the App Group values and reloads timelines.
  /// Notes: A missing `kind` or an App Group that cannot be opened is a
  /// `bad_args` error, so a misconfigured entitlement shows up in Dart.
  /// `placedSizes` is answered by Dart without reaching iOS.
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let queueCall = call.method == "pendingActions" || call.method == "acknowledgeActions"
    guard queueCall || call.method == "publish" || call.method == "clear" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    guard let group = args["appGroupId"] as? String,
      let defaults = UserDefaults(suiteName: group)
    else {
      result(FlutterError(code: "bad_args", message: "appGroupId is missing or unusable", details: nil))
      return
    }
    if call.method == "pendingActions" {
      result(defaults.string(forKey: MyAppsWidgetPlugin.actionsKey))
      return
    }
    if call.method == "acknowledgeActions" {
      MyAppsWidgetPlugin.removeActions(ids: Set(args["ids"] as? [String] ?? []), defaults: defaults)
      result(nil)
      return
    }
    guard let kind = args["kind"] as? String, !kind.isEmpty else {
      result(FlutterError(code: "bad_args", message: "kind is required", details: nil))
      return
    }
    let key = MyAppsWidgetPlugin.keyPrefix + kind
    if call.method == "publish" {
      defaults.set(args["envelope"] as? String ?? "", forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
    let widgetKinds = args["iosKinds"] as? [String] ?? []
    if #available(iOS 14.0, *) {
      for widgetKind in widgetKinds {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
      }
    }
    result(nil)
  }

  /// Purpose: Remove applied actions from the queue.
  /// Inputs: `ids`; `defaults` — the App Group store.
  /// Returns: None.
  /// Side effects: Rewrites or removes the queue value.
  /// Notes: Entries that are not objects with a string `id` are dropped too.
  static func removeActions(ids: Set<String>, defaults: UserDefaults) {
    guard !ids.isEmpty,
      let raw = defaults.string(forKey: actionsKey),
      let data = raw.data(using: .utf8),
      let array = (try? JSONSerialization.jsonObject(with: data)) as? [Any]
    else { return }
    let kept = array.compactMap { $0 as? [String: Any] }.filter {
      guard let id = $0["id"] as? String else { return false }
      return !ids.contains(id)
    }
    if kept.isEmpty {
      defaults.removeObject(forKey: actionsKey)
    } else if let out = try? JSONSerialization.data(withJSONObject: kept),
      let text = String(data: out, encoding: .utf8)
    {
      defaults.set(text, forKey: actionsKey)
    }
  }
}
