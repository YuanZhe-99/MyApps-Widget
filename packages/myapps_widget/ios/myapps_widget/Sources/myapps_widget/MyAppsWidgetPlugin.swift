import Flutter
import UIKit
import WidgetKit

/// Answers `com.yuanzhe.myapps_widget/bridge`: stores one envelope per kind in
/// the app's App Group and reloads that kind's WidgetKit timelines.
public class MyAppsWidgetPlugin: NSObject, FlutterPlugin {
  /// Matches `MyAppsWidgetBridge.channelName` in Dart.
  static let channelName = "com.yuanzhe.myapps_widget/bridge"

  /// Key prefix in the App Group `UserDefaults`; must match
  /// `apple/MyAppsWidgetKit/WidgetEnvelopeStore.swift`.
  static let keyPrefix = "myapps_widget.envelope."

  /// Purpose: Register the bridge channel.
  /// Inputs: `registrar`.
  /// Returns: None.
  /// Side effects: Installs the method-channel handler.
  /// Notes: Called by the generated plugin registrant.
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(MyAppsWidgetPlugin(), channel: channel)
  }

  /// Purpose: Handle `publish` and `clear`.
  /// Inputs: `call` — `kind`, `appGroupId`, `iosKinds`, and for `publish` the
  /// `envelope` string; `result`.
  /// Returns: None; answers `result`.
  /// Side effects: Writes or removes the App Group value and reloads timelines.
  /// Notes: A missing `kind` or an App Group that cannot be opened is a
  /// `bad_args` error, so a misconfigured entitlement shows up in Dart.
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "publish" || call.method == "clear" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    guard let kind = args["kind"] as? String, !kind.isEmpty else {
      result(FlutterError(code: "bad_args", message: "kind is required", details: nil))
      return
    }
    guard let group = args["appGroupId"] as? String,
      let defaults = UserDefaults(suiteName: group)
    else {
      result(FlutterError(code: "bad_args", message: "appGroupId is missing or unusable", details: nil))
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
}
