# Interactive actions

## Model

A control on a widget (a checkbox, a start button) cannot run Flutter code: the app may not be
running. Instead the native side appends one **action** to a device-local queue, redraws the widget,
and tells a running app. The app applies queued actions to its own data on its next run, publishes
a new envelope, and acknowledges them.

```text
tap → native queue (+ redraw, + "actionsQueued") → app drains → app data → publish → acknowledge
```

Actions are app-owned: the package stores and delivers them but never interprets `action` or
`args`.

## Queue format

The queue is one JSON array, oldest first, shared by every kind of the app.

```json
[
  {
    "id": "6f1c9d2e-4b5a-4f0e-9a51-0c2f3c1d7e88",
    "kind": "myday.todo",
    "action": "setDone",
    "at": 1767225600000,
    "args": {"id": "task-1", "done": true},
    "instanceId": "list-7"
  }
]
```

| Field | Type | Meaning |
|---|---|---|
| `id` | non-empty string | Unique per tap; used to acknowledge |
| `kind` | non-empty string | Widget kind the control belongs to |
| `action` | non-empty string | App-owned action name |
| `at` | number, UTC epoch ms | When the control was tapped |
| `args` | object | App-owned arguments; anything else reads as `{}` |
| `instanceId` | string | Optional; anything else reads as absent |

## Reading rules

Every reader (Dart, Kotlin and Swift `WidgetActionQueue.decode`) applies the same rules, checked
against `contract/actions/` and `contract/action_expectations.json`:

1. Nothing stored, invalid JSON, or a value that is not an array → an empty queue.
2. An entry that is not an object, or lacks a non-empty string `id`, `kind` or `action`, or a
   numeric `at`, is skipped. Booleans and numeric strings are not numbers.
3. Unknown entry fields are ignored.

Appending keeps at most 200 entries, dropping the oldest.

## Storage

| Platform | Location | Key |
|---|---|---|
| Android | Private `SharedPreferences` file `myapps_widget` | `actions` |
| iOS | App Group `UserDefaults` | `myapps_widget.actions` |

Like envelopes, the queue is device-local and never synced, backed up or exported.

## Producing actions

- **Android** — `WidgetActions.pendingIntent(context, kind, action, args, providers, requestCode)`
  is a broadcast to the plugin's `WidgetActionReceiver`, which appends the action, redraws the
  given providers and calls `actionsQueued` on every attached Flutter engine. It works on every
  Android version and without a running app.
- **iOS 17+** — `Button(intent: MyAppsWidgetActionIntent(kind:action:args:appGroupId:))` in a
  widget view. The intent appends with `WidgetActionQueue.append`, posts the Darwin notification
  `com.yuanzhe.myapps_widget.actions` (which the app's plugin turns into `actionsQueued`), and
  WidgetKit reloads the widget. Earlier iOS versions have no interactive widgets: use a deep link
  instead.

## Draining in the app

```dart
final actions = await bridge.pendingActions();
for (final a in actions) {
  // apply a to the app's data
}
await bridge.publish(updatedEnvelope);
await bridge.acknowledgeActions(actions.map((a) => a.id));
```

Drain on start, on resume and from `setActionsQueuedListener`. Acknowledge only after the data
write and the publish, so a crash re-delivers rather than loses a tap. Because a tap may be
delivered twice in that case, prefer idempotent actions (set a state rather than toggle it).

## Showing a tap at once

Between the tap and the app's next publish, the widget still reads the old envelope. Renderers
replay the kind's pending actions over it (`WidgetActionQueue.pending` on Android and iOS). To
avoid replaying an action the envelope already contains, the app should list the ids it applied
in its payload and the renderer should skip those.
