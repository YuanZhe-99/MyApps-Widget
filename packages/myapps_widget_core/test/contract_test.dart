import 'dart:convert';
import 'dart:io';

import 'package:myapps_widget_core/myapps_widget_core.dart';
import 'package:test/test.dart';

/// Reads the repository-level contract fixtures that the Kotlin and Swift
/// readers must interpret identically.
void main() {
  final contract = Directory('../../contract');
  final expectations =
      jsonDecode(File('${contract.path}/expectations.json').readAsStringSync())
          as Map<String, dynamic>;
  final expectedKind = expectations['expectedKind'] as String;
  final cases = expectations['cases'] as Map<String, dynamic>;

  test('every fixture has an expectation', () {
    final files = Directory(
      '${contract.path}/fixtures',
    ).listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(files, cases.keys.toSet());
  });

  for (final entry in cases.entries) {
    test('fixture ${entry.key}', () {
      final raw = File(
        '${contract.path}/fixtures/${entry.key}',
      ).readAsStringSync();
      final want = entry.value as Map<String, dynamic>;
      final read = WidgetEnvelopeRead.decode(raw, expectedKind: expectedKind);
      expect(read.status.name, want['status']);
      if (read.status != WidgetEnvelopeStatus.ok) return;
      final e = read.envelope!;
      expect(e.payloadVersion, want['payloadVersion']);
      expect(e.generatedAt.millisecondsSinceEpoch, want['generatedAt']);
      expect(e.textScale, (want['textScale'] as num).toDouble());
      expect(e.privacy.wire, want['privacy']);
      expect(
        e.refreshAt.map((t) => t.millisecondsSinceEpoch).toList(),
        want['refreshAt'],
      );
      expect(e.instanceId, want['instanceId']);
    });
  }

  test('missing input', () {
    expect(
      WidgetEnvelopeRead.decode(null).status,
      WidgetEnvelopeStatus.missing,
    );
    expect(WidgetEnvelopeRead.decode('').status, WidgetEnvelopeStatus.missing);
  });
}
