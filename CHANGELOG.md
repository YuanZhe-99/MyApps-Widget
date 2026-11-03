# Changelog

## 0.2.0 - 2026-11-03

Adds interactive widgets through a pending-action queue. Native controls append a `WidgetAction`
(`id`, `kind`, `action`, `at`, `args`, `instanceId`) to one device-local JSON array (Android
preferences key `actions`, iOS App Group key `myapps_widget.actions`): on Android with
`WidgetActions.pendingIntent` and the plugin's `WidgetActionReceiver`, on iOS 17+ with
`MyAppsWidgetActionIntent`. The app reads them with `MyAppsWidgetBridge.pendingActions`, removes
applied ones with `acknowledgeActions`, and hears about new ones through
`setActionsQueuedListener`. Renderers can replay pending actions with `WidgetActionQueue.pending`.
The queue reading rules are checked in Dart, Kotlin and Swift against the new
`contract/actions/` fixtures. The envelope contract is unchanged.

## 0.1.1 - 2026-11-02

Adds `MyAppsWidgetBridge.placedSizes(kind)` and `PlacedWidgetSize`: on Android, the dp size options
the launcher gives every placed instance of a kind's providers (Kotlin
`EnvelopeStore.placedSizes`, channel method `placedSizes`), so in-app previews can lay out at the
real size. iOS has no equivalent and returns empty. The envelope contract is unchanged.

## 0.1.0 - 2026-10-28

First release, extracted from MyAnime 1.9.4's home-screen widgets. Adds the envelope format
(`v` 1) with tolerant readers in Dart, Kotlin and Swift checked against shared fixtures in
`contract/`; `WidgetKindDescriptor`, `WidgetPrivacy`, `WidgetTextScale` and `WidgetDeepLink`;
the `myapps_widget` plugin (`MyAppsWidgetBridge`, `WidgetRefreshScheduler`, Android
`EnvelopeStore` and `EnvelopeWidgetProvider`, iOS App Group writer); `MyAppsWidgetKit` for
WidgetKit extensions; and `myapps_widget_ui` (`WidgetPreviewSurface`, `WidgetTextScaleControl`).
`refreshAt` and `instanceId` are carried and read but not yet acted on.
