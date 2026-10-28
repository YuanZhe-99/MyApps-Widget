# Architecture

## Scope

MyApps-Widget is the shared infrastructure behind the MyApps home-screen widgets on Android and
iOS. It moves data from a Flutter app to native widgets and defines how that data is stored. It
does not decide what a widget shows: payload contents, native layouts, SwiftUI views, wording and
the choice of widgets stay in each application.

## Packages and parts

| Part | Responsibility |
|---|---|
| `packages/myapps_widget_core` | Pure Dart: `WidgetEnvelope` and its tolerant reader, `WidgetKindDescriptor`, `WidgetPrivacy`, `WidgetTextScale`, `WidgetDeepLink`; no Flutter |
| `packages/myapps_widget` | Flutter plugin: `MyAppsWidgetBridge` (publish and clear per kind), `WidgetRefreshScheduler` (debounce); Android and iOS native halves |
| `packages/myapps_widget_ui` | Flutter UI: `WidgetPreviewSurface` and `WidgetTextScaleControl`; wording injected |
| Android half (`packages/myapps_widget/android`) | `MyAppsWidgetPlugin`, `EnvelopeStore`, `WidgetEnvelopeRead`, `EnvelopeWidgetProvider`, `setScaledTextSize`, `WidgetLaunch` |
| iOS half (`packages/myapps_widget/ios`) | `MyAppsWidgetPlugin`: writes the App Group and reloads WidgetKit timelines |
| `apple/MyAppsWidgetKit` | Reader for WidgetKit extensions, compiled into the app's extension target; no Flutter |
| `contract/` | Fixtures and expectations that the Dart, Kotlin and Swift readers must agree on |

Dependencies point one way: `myapps_widget → myapps_widget_core` and
`myapps_widget_ui → myapps_widget_core`. The UI package never depends on the plugin, so a preview
can be built and tested without native code.

## Data flow

1. The app builds its payload for a kind and wraps it with `MyAppsWidgetBridge.envelope`.
2. `MyAppsWidgetBridge.publish` sends the encoded envelope, the kind's Android provider class
   names, its WidgetKit kinds and the App Group over `com.yuanzhe.myapps_widget/bridge`.
3. Android: `EnvelopeStore.write` stores it under `envelope.<kind>` in the private `myapps_widget`
   preferences, then `EnvelopeStore.requestUpdate` broadcasts `ACTION_APPWIDGET_UPDATE` to each
   named provider that has placed instances. iOS: the plugin stores it under
   `myapps_widget.envelope.<kind>` in the App Group `UserDefaults` and calls
   `WidgetCenter.reloadTimelines(ofKind:)` for each WidgetKit kind.
4. The native widget reads its kind with `EnvelopeStore.read` (Android) or
   `WidgetEnvelopeStore.read` (iOS), checks the status and renders the payload.

One envelope per kind: publishing one kind never rewrites or redraws another kind's widgets.

## What stays in the application

- Building the payload, its own version (`pv`) and evaluating it natively.
- `AppWidgetProvider` subclasses (usually extending `EnvelopeWidgetProvider`), XML layouts,
  drawables, colors and the manifest receivers.
- The WidgetKit extension target, its views, its App Group entitlement and adding
  `MyAppsWidgetKit.swift` to it.
- Wording, settings storage (for example the text scale), and routing widget deep links.
- A facade in the app (for example MyAnime's `HomeWidgetService`) so call sites do not depend on
  this package directly.

## Extensibility rules

- **Two version layers.** The envelope `v` belongs to this package; the payload `pv` belongs to
  the app. Changing a payload never needs a new release of this package.
- **Tolerant readers.** Unknown fields are ignored (and kept by the Dart writer), missing fields
  take defaults, numbers are clamped, and a newer `v` reads as `tooNew` so the widget can ask the
  user to open the app instead of guessing.
- **Kinds are data.** A new widget is a new `WidgetKindDescriptor`, payload builder and native
  renderer; the package does not change.
- **Reserved fields.** `refreshAt`, `instanceId` and `privacy` are carried and read on all three
  platforms. Scheduling redraws from `refreshAt` on Android, configurable widgets and interactive
  actions are not implemented yet; see [the roadmap](#roadmap).
- **Namespaced storage.** Keys and the preferences file carry the `myapps_widget` prefix; the App
  Group comes from the app, and the package hard-codes no app identifier.

## Roadmap

| Item | State |
|---|---|
| Envelope, kinds, privacy field, text scale, deep links | Done in 0.1.0 |
| Android redraw from `refreshAt` (inexact alarms) | Reserved field only |
| Configurable widgets (`instanceId` from AppIntent or a configure activity) | Reserved field only |
| Interactive widgets (a pending-action queue the app drains on its next run) | Planned |
| Shared Android drawables and SwiftUI components | Planned |

See [the envelope format](envelope.md), [the public API](api.md),
[adding a widget](adding-a-widget.md) and [verification](verification.md).
