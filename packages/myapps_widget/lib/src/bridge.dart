import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:myapps_widget_core/myapps_widget_core.dart';

/// Publishes widget envelopes to the native store and redraws the widgets.
///
/// One instance per app, created with every kind the app publishes. The
/// native side stores one envelope per kind (Android private preferences
/// `myapps_widget`, iOS App Group `UserDefaults`) and redraws only that
/// kind's widgets.
class MyAppsWidgetBridge {
  /// Purpose: Create the bridge.
  /// Inputs: `kinds` — every kind the app publishes; `appGroupId` — the iOS
  /// App Group shared with the widget extension (required on iOS);
  /// `channel` and `supported` — test seams.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Throws [ArgumentError] for duplicate kind ids.
  MyAppsWidgetBridge({
    required List<WidgetKindDescriptor> kinds,
    this.appGroupId,
    MethodChannel? channel,
    bool? supported,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _supported = supported,
       kinds = {for (final k in kinds) k.id: k} {
    if (this.kinds.length != kinds.length) {
      throw ArgumentError.value(kinds, 'kinds', 'duplicate kind id');
    }
  }

  /// The plugin's method channel, registered by `MyAppsWidgetPlugin`.
  static const channelName = 'com.yuanzhe.myapps_widget/bridge';

  /// Registered kinds by id.
  final Map<String, WidgetKindDescriptor> kinds;

  /// iOS App Group id; ignored on Android.
  final String? appGroupId;

  final MethodChannel _channel;
  final bool? _supported;

  /// Purpose: Whether this platform has home-screen widgets.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Android and iOS only; every other call no-ops elsewhere.
  bool get isSupported =>
      _supported ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// Purpose: Wrap an app payload in an envelope for a registered kind.
  /// Inputs: `kind`; `payload`; `generatedAt` (default now); optional
  /// `textScale`, `privacy` (default the kind's), `refreshAt`, `instanceId`.
  /// Returns: `WidgetEnvelope`.
  /// Side effects: None.
  /// Notes: Throws [ArgumentError] for an unregistered kind. Pure, so apps
  /// can build the exact envelope for previews and tests.
  WidgetEnvelope envelope(
    String kind,
    Map<String, dynamic> payload, {
    DateTime? generatedAt,
    double textScale = WidgetTextScale.defaultValue,
    WidgetPrivacy? privacy,
    List<DateTime> refreshAt = const [],
    String? instanceId,
  }) {
    final descriptor = _descriptor(kind);
    return WidgetEnvelope(
      kind: kind,
      payloadVersion: descriptor.payloadVersion,
      generatedAt: (generatedAt ?? DateTime.now()).toUtc(),
      textScale: WidgetTextScale.clamp(textScale),
      privacy: privacy ?? descriptor.defaultPrivacy,
      refreshAt: refreshAt,
      instanceId: instanceId,
      payload: payload,
    );
  }

  /// Purpose: Store an envelope and redraw its kind's widgets.
  /// Inputs: `envelope` — for a registered kind.
  /// Returns: Completes when the native side has stored it.
  /// Side effects: Writes the native store and asks the OS to redraw.
  /// Notes: No-op on unsupported platforms. Throws [ArgumentError] for an
  /// unregistered kind and [StateError] on iOS without [appGroupId].
  Future<void> publish(WidgetEnvelope envelope) async {
    final descriptor = _descriptor(envelope.kind);
    if (!isSupported) return;
    await _channel.invokeMethod<void>('publish', {
      ..._target(descriptor),
      'envelope': envelope.encode(),
    });
  }

  /// Purpose: Remove a kind's envelope and redraw its widgets empty.
  /// Inputs: `kind`.
  /// Returns: Completes when removed.
  /// Side effects: Deletes from the native store and asks the OS to redraw.
  /// Notes: Use when the user turns a widget's data source off.
  Future<void> clear(String kind) async {
    final descriptor = _descriptor(kind);
    if (!isSupported) return;
    await _channel.invokeMethod<void>('clear', _target(descriptor));
  }

  /// Purpose: Look up a registered kind.
  /// Inputs: `kind`.
  /// Returns: Its descriptor.
  /// Side effects: None.
  /// Notes: Throws [ArgumentError] when unregistered.
  WidgetKindDescriptor _descriptor(String kind) {
    final descriptor = kinds[kind];
    if (descriptor == null) {
      throw ArgumentError.value(kind, 'kind', 'not registered');
    }
    return descriptor;
  }

  /// Purpose: Build the channel arguments that name a kind and its widgets.
  /// Inputs: `descriptor`.
  /// Returns: The argument map.
  /// Side effects: None.
  /// Notes: Throws [StateError] on iOS when [appGroupId] is missing, since
  /// the extension could never read the envelope.
  Map<String, Object?> _target(WidgetKindDescriptor descriptor) {
    if (!kIsWeb && Platform.isIOS && appGroupId == null) {
      throw StateError('MyAppsWidgetBridge needs appGroupId on iOS');
    }
    return {
      'kind': descriptor.id,
      'androidProviders': descriptor.androidProviders,
      'iosKinds': descriptor.iosKinds,
      'appGroupId': appGroupId,
    };
  }
}
