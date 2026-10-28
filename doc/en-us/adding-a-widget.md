# Adding a widget

## First widget in an app

1. Add this repository as a submodule at `packages/myapps_widget` with the relative URL
   `../MyApps-Widget.git`, and depend on
   `packages/myapps_widget/packages/myapps_widget` (and `myapps_widget_ui` for previews).
2. Create one `MyAppsWidgetBridge` with every kind and, for iOS, the App Group id. Keep it behind
   an app facade.
3. Android: add the providers to the manifest as usual. In `android/app`, the plugin's classes are
   on the classpath, so providers can extend `EnvelopeWidgetProvider`.
4. iOS: create the WidgetKit extension target, give the app and the extension the same App Group
   entitlement, and add `../packages/myapps_widget/apple/MyAppsWidgetKit/MyAppsWidgetKit.swift`
   to the extension target's sources (a file reference; do not copy it).

## Each new kind

1. Pick an id `app.widgetName`, for example `myday.todoToday`.
2. Register a `WidgetKindDescriptor` with the fully qualified Android provider class names, the
   WidgetKit `kind` strings, `payloadVersion` and `defaultPrivacy`.
3. Write the payload builder in Dart and a `WidgetRefreshScheduler` that publishes it; schedule it
   from the module's save paths.
4. Write the native renderers: read with `EnvelopeStore.read` or `WidgetEnvelopeStore.read`,
   handle `missing`, `invalid` and `tooNew`, apply `textScale`, and honour `privacy`.
5. Document the payload in the app's own docs; this repository never describes app payloads.

```dart
final bridge = MyAppsWidgetBridge(
  appGroupId: 'group.com.example.app',
  kinds: [
    WidgetKindDescriptor(
      id: 'example.today',
      androidProviders: ['com.example.app.widget.TodayProvider'],
      iosKinds: ['ExampleToday'],
    ),
  ],
);

await bridge.publish(bridge.envelope('example.today', {'items': []}));
```

## Privacy

`sensitive` content should be redacted while the device is locked and marked `privacySensitive()`
on iOS; `hidden` should draw a neutral placeholder. Do not offer lock-screen families for kinds
whose default privacy is not `normal`.
