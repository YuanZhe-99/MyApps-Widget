# Envelope format

## Shape

Each widget kind stores one JSON object, the envelope. The package owns every top-level field
except `payload`, which belongs to the app.

```json
{
  "v": 1,
  "kind": "myday.todoToday",
  "pv": 1,
  "generatedAt": 1767225600000,
  "textScale": 1.0,
  "privacy": "normal",
  "refreshAt": [1767229200000],
  "instanceId": "list-7",
  "payload": {}
}
```

| Field | Type | Default when missing | Meaning |
|---|---|---|---|
| `v` | integer | `0` (read as current) | Envelope format version; this package writes `1` |
| `kind` | string | `""` | Kind id, `app.widgetName` in lower camel case |
| `pv` | integer | `1` | The app's payload version |
| `generatedAt` | integer, UTC epoch ms | `0` | When the app built the envelope |
| `textScale` | number | `1.0` | Text size multiplier, clamped to 0.9–1.5 and rounded to 0.1 |
| `privacy` | string | `normal` | `normal`, `sensitive` or `hidden`; unknown values read as `normal` |
| `refreshAt` | array of UTC epoch ms | `[]` | Instants to redraw without the app; non-numbers skipped, sorted |
| `instanceId` | string | absent | Configured instance, for configurable widgets; non-strings ignored |
| `payload` | object | required | App-owned content |

The Dart writer keeps unknown top-level fields (`extraJson`) when it rewrites an envelope it read,
so a newer field survives an older writer. Native readers ignore unknown fields.

## Reading rules

Every reader (Dart `WidgetEnvelopeRead.decode`, Kotlin `WidgetEnvelopeRead.decode`, Swift
`WidgetEnvelopeRead.decode`) applies the same checks in the same order:

1. Nothing stored → `missing`.
2. Not a JSON object, or `payload` is not an object → `invalid`.
3. `v` greater than the reader's version → `tooNew`.
4. `kind` differs from the kind being rendered → `invalid`.
5. Otherwise → `ok`, with defaults and clamping as in the table above.

Numbers may arrive as integers or doubles; booleans are never numbers. A widget should render
`missing` as its empty state, `tooNew` as "open the app to update", and `invalid` like `missing`.

## Storage

| Platform | Location | Key |
|---|---|---|
| Android | Private `SharedPreferences` file `myapps_widget` | `envelope.<kind>` |
| iOS | App Group `UserDefaults` (`appGroupId` from the app) | `myapps_widget.envelope.<kind>` |

The store is device-local. It is never synced, backed up or exported by the apps, so it is written
as compact JSON rather than pretty-printed.

## Compatibility

`v`, the field names, the privacy wire names, the storage keys and the reading order are a
compatibility contract with widgets already placed on devices. Change them only together with all
three readers and new fixtures in `contract/`, and bump `v` for anything an older reader would
misread.
