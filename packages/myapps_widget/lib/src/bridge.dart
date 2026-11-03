import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:myapps_widget_core/myapps_widget_core.dart';

import 'placed_size.dart';

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

  /// Purpose: Report the launcher-given size of every placed instance of a
  /// kind's Android widgets.
  /// Inputs: `kind`.
  /// Returns: One [PlacedWidgetSize] per placed instance, in provider order;
  /// empty when none is placed, on iOS, or on unsupported platforms.
  /// Side effects: None.
  /// Notes: Throws [ArgumentError] for an unregistered kind. iOS has no
  /// equivalent query, so it never reaches the native side there. Channel
  /// errors read as empty, so callers can always fall back to a default size.
  Future<List<PlacedWidgetSize>> placedSizes(String kind) async {
    final descriptor = _descriptor(kind);
    if (!isSupported || (!kIsWeb && Platform.isIOS)) return const [];
    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'placedSizes',
        _target(descriptor),
      );
      return [
        for (final entry in raw ?? const [])
          if (entry is Map) ?PlacedWidgetSize.fromMap(entry),
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Purpose: Read the taps queued by interactive widget controls.
  /// Inputs: Optional `kind` to keep only that kind's actions.
  /// Returns: The queued actions of registered kinds, oldest first; empty on
  /// unsupported platforms, on channel errors, or when nothing is queued.
  /// Side effects: Reads the native queue; does not remove anything.
  /// Notes: Apply each action, publish the updated envelope, then call
  /// [acknowledgeActions] with the applied ids, so a crash in between
  /// re-delivers instead of losing a tap. Throws [StateError] on iOS without
  /// [appGroupId]. See `doc/en-us/actions.md`.
  Future<List<WidgetAction>> pendingActions({String? kind}) async {
    if (kind != null) _descriptor(kind);
    if (!isSupported) return const [];
    final target = _queueTarget();
    try {
      final raw = await _channel.invokeMethod<String>('pendingActions', target);
      return [
        for (final action in WidgetActionQueue.decode(raw))
          if (kinds.containsKey(action.kind) &&
              (kind == null || action.kind == kind))
            action,
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Purpose: Remove applied actions from the native queue.
  /// Inputs: `ids` — [WidgetAction.id] values.
  /// Returns: Completes when removed.
  /// Side effects: Rewrites the native queue without those ids.
  /// Notes: Unknown ids are ignored; an empty list sends nothing.
  Future<void> acknowledgeActions(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty || !isSupported) return;
    await _channel.invokeMethod<void>('acknowledgeActions', {
      ..._queueTarget(),
      'ids': list,
    });
  }

  /// Purpose: Be told when a widget control queues an action while the app
  /// is running.
  /// Inputs: `listener`, or null to stop listening.
  /// Returns: None.
  /// Side effects: Installs (or removes) the channel's incoming-call handler.
  /// Notes: The native side calls `actionsQueued` after appending; the app
  /// should then call [pendingActions]. A suspended iOS app is not woken, so
  /// also drain on start and resume.
  void setActionsQueuedListener(void Function()? listener) {
    if (!isSupported) return;
    _channel.setMethodCallHandler(
      listener == null
          ? null
          : (call) async {
              if (call.method == 'actionsQueued') listener();
              return null;
            },
    );
  }

  /// Purpose: Build the channel arguments for queue calls.
  /// Inputs: None.
  /// Returns: The argument map with [appGroupId].
  /// Side effects: None.
  /// Notes: Throws [StateError] on iOS without [appGroupId].
  Map<String, Object?> _queueTarget() {
    if (!kIsWeb && Platform.isIOS && appGroupId == null) {
      throw StateError('MyAppsWidgetBridge needs appGroupId on iOS');
    }
    return {'appGroupId': appGroupId};
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
