import 'dart:convert';
import 'dart:io';

import 'package:myapps_widget_core/myapps_widget_core.dart';
import 'package:test/test.dart';

/// Reads the pending-action fixtures that the Kotlin and Swift queue readers
/// must interpret identically.
void main() {
  final contract = Directory('../../contract');
  final expectations =
      jsonDecode(
            File(
              '${contract.path}/action_expectations.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = expectations['cases'] as Map<String, dynamic>;

  test('every action fixture has an expectation', () {
    final files = Directory(
      '${contract.path}/actions',
    ).listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(files, cases.keys.toSet());
  });

  for (final entry in cases.entries) {
    test('action fixture ${entry.key}', () {
      final raw = File(
        '${contract.path}/actions/${entry.key}',
      ).readAsStringSync();
      final read = WidgetActionQueue.decode(raw);
      final want = entry.value as List<dynamic>;
      expect(read.length, want.length);
      for (var i = 0; i < want.length; i++) {
        final w = want[i] as Map<String, dynamic>;
        final a = read[i];
        expect(a.id, w['id']);
        expect(a.kind, w['kind']);
        expect(a.action, w['action']);
        expect(a.at.millisecondsSinceEpoch, w['at']);
        expect(a.args, w['args']);
        expect(a.instanceId, w['instanceId']);
      }
    });
  }

  test('missing queue reads empty', () {
    expect(WidgetActionQueue.decode(null), isEmpty);
    expect(WidgetActionQueue.decode(''), isEmpty);
  });

  test('encode round-trips and keeps the newest entries', () {
    final actions = [
      for (var i = 0; i < WidgetActionQueue.maxLength + 5; i++)
        WidgetAction(
          id: 'a$i',
          kind: 'demo.today',
          action: 'setDone',
          at: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
          args: {'n': i},
          instanceId: i.isEven ? 'x' : null,
        ),
    ];
    final read = WidgetActionQueue.decode(WidgetActionQueue.encode(actions));
    expect(read.length, WidgetActionQueue.maxLength);
    expect(read.first.id, 'a5');
    expect(read.last.args, {'n': WidgetActionQueue.maxLength + 4});
    expect(read.first.at.isUtc, isTrue);
  });
}
