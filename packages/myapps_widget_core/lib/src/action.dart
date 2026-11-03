import 'dart:convert';

/// One tap on an interactive widget control, queued by the native side for
/// the app to apply on its next run. See `doc/en-us/actions.md`.
class WidgetAction {
  /// Purpose: Create a queued action.
  /// Inputs: `id` — unique per tap; `kind` — the widget kind it belongs to;
  /// `action` — the app's action name; `at` — when it was tapped; optional
  /// `args` and `instanceId`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: `at` is stored as UTC epoch milliseconds.
  const WidgetAction({
    required this.id,
    required this.kind,
    required this.action,
    required this.at,
    this.args = const {},
    this.instanceId,
  });

  /// Unique id, used to acknowledge the action once applied.
  final String id;

  /// Widget kind id the action belongs to.
  final String kind;

  /// App-owned action name, such as `setDone`.
  final String action;

  /// When the user tapped the control.
  final DateTime at;

  /// App-owned arguments; never interpreted by the package.
  final Map<String, dynamic> args;

  /// Configured widget instance, for configurable widgets.
  final String? instanceId;

  /// Purpose: Serialize to the stored JSON object.
  /// Inputs: None.
  /// Returns: A JSON-ready map.
  /// Side effects: None.
  /// Notes: `instanceId` is written only when present.
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'action': action,
    'at': at.toUtc().millisecondsSinceEpoch,
    'args': args,
    if (instanceId != null) 'instanceId': instanceId,
  };

  /// Purpose: Read one stored entry with the contract rules.
  /// Inputs: `json` — any decoded JSON value.
  /// Returns: The action, or null when `json` is not an object or `id`,
  /// `kind`, `action` (non-empty strings) or `at` (a number) is missing.
  /// Side effects: None.
  /// Notes: A non-object `args` reads as `{}` and a non-string `instanceId`
  /// as null, so one malformed field never drops the tap.
  static WidgetAction? fromJson(Object? json) {
    if (json is! Map) return null;
    String? text(String key) {
      final value = json[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final id = text('id');
    final kind = text('kind');
    final action = text('action');
    final at = json['at'];
    if (id == null || kind == null || action == null || at is! num) {
      return null;
    }
    if (at is double && !at.isFinite) return null;
    final args = json['args'];
    final instanceId = json['instanceId'];
    return WidgetAction(
      id: id,
      kind: kind,
      action: action,
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt(), isUtc: true),
      args: args is Map ? Map<String, dynamic>.from(args) : const {},
      instanceId: instanceId is String ? instanceId : null,
    );
  }
}

/// The stored pending-action queue: a JSON array of [WidgetAction] objects,
/// oldest first, shared by every kind of one app.
abstract final class WidgetActionQueue {
  /// Most entries kept; appending beyond it drops the oldest.
  static const maxLength = 200;

  /// Purpose: Read stored queue text with the contract rules.
  /// Inputs: `raw` — the stored string or null.
  /// Returns: The valid actions in stored order; empty for missing, invalid
  /// JSON or a non-array value.
  /// Side effects: None.
  /// Notes: Invalid entries are skipped individually. Mirrors the Kotlin and
  /// Swift `WidgetActionQueue.decode`, checked against `contract/actions/`.
  static List<WidgetAction> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (json is! List) return const [];
    return [for (final entry in json) ?WidgetAction.fromJson(entry)];
  }

  /// Purpose: Serialize a queue for storage.
  /// Inputs: `actions`.
  /// Returns: Compact JSON array text, keeping at most [maxLength] newest.
  /// Side effects: None.
  /// Notes: Used by tests and tools; the native sides write the real queue.
  static String encode(List<WidgetAction> actions) {
    final kept = actions.length > maxLength
        ? actions.sublist(actions.length - maxLength)
        : actions;
    return jsonEncode([for (final a in kept) a.toJson()]);
  }
}
