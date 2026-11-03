# Public API

## myapps_widget_core

| Declaration | Purpose |
|---|---|
| `widgetEnvelopeVersion` | Envelope `v` this package writes and fully reads (`1`) |
| `WidgetEnvelope` | The envelope; `toJson`, `encode`, `fromJson` (tolerant), `extraJson` keeps unknown fields |
| `WidgetEnvelopeStatus` | `missing`, `invalid`, `tooNew`, `ok` |
| `WidgetEnvelopeRead.decode(raw, {expectedKind})` | Read stored text with the contract rules |
| `WidgetKindDescriptor` | `id`, `androidProviders`, `iosKinds`, `payloadVersion`, `defaultPrivacy`; `isValidId` |
| `WidgetPrivacy` | `normal`, `sensitive`, `hidden`; `wire`, `fromWire` |
| `WidgetTextScale` | `min` 0.9, `max` 1.5, `defaultValue` 1.0, `step` 0.1, `divisions` 6, `clamp` |
| `WidgetDeepLink` | `<scheme>://widget/<kind>?instance=<id>`; `toUri`, `tryParse` |
| `WidgetAction` | One queued tap: `id`, `kind`, `action`, `at`, `args`, `instanceId`; `toJson`, `fromJson` (tolerant) |
| `WidgetActionQueue` | `decode(raw)`, `encode(actions)`, `maxLength` 200; see [interactive actions](actions.md) |

## myapps_widget

`package:myapps_widget/myapps_widget.dart` re-exports the core package.

| Declaration | Purpose |
|---|---|
| `MyAppsWidgetBridge({kinds, appGroupId})` | One per app; rejects duplicate kind ids |
| `MyAppsWidgetBridge.channelName` | `com.yuanzhe.myapps_widget/bridge` |
| `isSupported` | Android and iOS only; every call no-ops elsewhere |
| `envelope(kind, payload, {...})` | Build an envelope with the kind's `pv` and default privacy; pure |
| `publish(envelope)` | Store and redraw the kind's widgets |
| `clear(kind)` | Remove the kind's envelope and redraw |
| `placedSizes(kind)` | Android: launcher-given dp bounds of every placed instance of the kind's providers; empty on iOS, elsewhere, or on a channel error |
| `PlacedWidgetSize` | `provider`, `widgetId`, `minWidth`, `minHeight`, `maxWidth`, `maxHeight` (dp); `portrait` (min width × max height), `landscape` (max width × min height); `fromMap` skips malformed or unsized entries |
| `pendingActions({kind})` | Queued actions of registered kinds, oldest first; empty elsewhere or on a channel error |
| `acknowledgeActions(ids)` | Remove applied actions from the queue |
| `setActionsQueuedListener(listener)` | Called when a widget control queues an action while the app runs |
| `WidgetRefreshScheduler({onRefresh, delay, onError})` | `schedule`, `flush`, `cancel`, `isPending` |

`publish` and `clear` throw `ArgumentError` for an unregistered kind, and `StateError` on iOS
without `appGroupId`. The native side answers `bad_args` when the kind is missing or, on iOS, the
App Group cannot be opened.

## myapps_widget_ui

| Declaration | Purpose |
|---|---|
| `WidgetPreviewSurface({width, height, child, padding, radius, color})` | Fixed-size, rounded, tinted, clipped preview card; `smallSide` 172, `stripHeight` 76 |
| `WidgetTextScaleControl({value, onChanged, title, subtitle, leading})` | Title row with the percentage and a slider over `WidgetTextScale`; `percent` |

## Android (Kotlin, package `com.yuanzhe.myapps_widget`)

| Declaration | Purpose |
|---|---|
| `EnvelopeStore.read(context, kind)` | Read and decode a kind's envelope |
| `EnvelopeStore.write`, `clear`, `key`, `prefs` | Store access; used by the plugin |
| `EnvelopeStore.requestUpdate(context, providers)` | Broadcast `ACTION_APPWIDGET_UPDATE` to placed instances |
| `EnvelopeStore.placedSizes(context, providers)` | Size options (dp) of every placed instance; answers the `placedSizes` channel call |
| `WidgetEnvelopeRead.decode(raw, expectedKind)` | Same rules as Dart |
| `WidgetEnvelope` | Decoded envelope; `payload` is a `JSONObject`; `sp(base)` |
| `WidgetTextScale.clamp`, `WidgetPrivacy.fromWire` | Same rules as Dart |
| `EnvelopeWidgetProvider` | Base provider: implement `render(context, appWidgetId, options)` |
| `RemoteViews.setScaledTextSize(viewId, baseSp, scale)` | Scaled sp text size |
| `WidgetLaunch.pendingIntent(context, link, requestCode)` | Tap action opening the app, optionally on a deep link |
| `WidgetActions.pendingIntent(context, kind, action, args, providers, requestCode, instanceId)` | Tap action queuing an app action without opening the app |
| `WidgetActionQueue.pending(context, kind)`, `append`, `remove`, `raw`, `decode` | The pending-action queue; same reading rules as Dart |
| `WidgetActionReceiver` | Declared by the plugin manifest; queues taps, redraws and notifies a running app |

## iOS extension (`apple/MyAppsWidgetKit/MyAppsWidgetKit.swift`)

| Declaration | Purpose |
|---|---|
| `WidgetEnvelopeStore.read(kind:appGroupId:)` | Read and decode a kind's envelope |
| `WidgetEnvelopeRead.decode(_:expectedKind:)` | Same rules as Dart |
| `WidgetEnvelope` | `generatedDate`, `refreshDates`, `pt(_:)`, `decodePayload(_:)` |
| `WidgetTextScale.clamp`, `WidgetPrivacy.fromWire` | Same rules as Dart |
| `WidgetActionQueue.pending(kind:appGroupId:)`, `append(...)`, `decode(_:)` | The pending-action queue; same reading rules as Dart |
| `MyAppsWidgetActionIntent(kind:action:args:appGroupId:)` | iOS 17+ intent for `Button(intent:)`; queues the action and notifies a running app |
