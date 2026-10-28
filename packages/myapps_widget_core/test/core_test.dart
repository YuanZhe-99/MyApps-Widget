import 'package:myapps_widget_core/myapps_widget_core.dart';
import 'package:test/test.dart';

void main() {
  group('WidgetTextScale.clamp', () {
    test('clamps, rounds and rejects non-finite values', () {
      expect(WidgetTextScale.clamp(0.5), 0.9);
      expect(WidgetTextScale.clamp(3), 1.5);
      expect(WidgetTextScale.clamp(1.24), 1.2);
      expect(WidgetTextScale.clamp(double.nan), 1.0);
      expect(WidgetTextScale.clamp(double.infinity), 1.0);
    });
  });

  group('WidgetEnvelope', () {
    test('round-trips and preserves unknown fields', () {
      final raw =
          '{"v":1,"kind":"a.b","generatedAt":5,"payload":{"x":1},"later":[1]}';
      final read = WidgetEnvelopeRead.decode(raw);
      final again = read.envelope!.toJson();
      expect(again['later'], [1]);
      expect(again['payload'], {'x': 1});
      expect(again['generatedAt'], 5);
    });

    test('known fields win over extraJson', () {
      final e = WidgetEnvelope(
        kind: 'a.b',
        generatedAt: DateTime.utc(2026),
        payload: const {},
        extraJson: const {'kind': 'evil', 'x': 1},
      );
      expect(e.toJson()['kind'], 'a.b');
      expect(e.toJson()['x'], 1);
    });

    test('encodes UTC milliseconds, sorted refreshAt, clamped scale', () {
      final e = WidgetEnvelope(
        kind: 'a.b',
        generatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        payload: const {},
        textScale: 7,
        refreshAt: [
          DateTime.fromMillisecondsSinceEpoch(30, isUtc: true),
          DateTime.fromMillisecondsSinceEpoch(20, isUtc: true),
        ],
      );
      final json = e.toJson();
      expect(json['generatedAt'], 1000);
      expect(json['refreshAt'], [20, 30]);
      expect(json['textScale'], 1.5);
      expect(json.containsKey('instanceId'), isFalse);
    });
  });

  group('WidgetKindDescriptor', () {
    test('validates ids', () {
      expect(WidgetKindDescriptor.isValidId('myday.todoToday'), isTrue);
      expect(WidgetKindDescriptor.isValidId('myday'), isFalse);
      expect(WidgetKindDescriptor.isValidId('MyDay.todo'), isFalse);
      expect(WidgetKindDescriptor.isValidId('myday.todo-today'), isFalse);
      expect(() => WidgetKindDescriptor(id: 'bad'), throwsArgumentError);
      expect(
        () => WidgetKindDescriptor(id: 'a.b', payloadVersion: 0),
        throwsArgumentError,
      );
    });
  });

  group('WidgetPrivacy', () {
    test('unknown wire values read as normal', () {
      expect(WidgetPrivacy.fromWire('hidden'), WidgetPrivacy.hidden);
      expect(WidgetPrivacy.fromWire('nope'), WidgetPrivacy.normal);
      expect(WidgetPrivacy.fromWire(null), WidgetPrivacy.normal);
    });
  });

  group('WidgetDeepLink', () {
    test('round-trips', () {
      const link = WidgetDeepLink(kind: 'myday.todoToday', instanceId: 'l1');
      final uri = link.toUri('myday');
      expect(uri.toString(), 'myday://widget/myday.todoToday?instance=l1');
      final back = WidgetDeepLink.tryParse(uri, scheme: 'myday')!;
      expect(back.kind, 'myday.todoToday');
      expect(back.instanceId, 'l1');
    });

    test('rejects other links', () {
      expect(WidgetDeepLink.tryParse(Uri.parse('myday://todo/1')), isNull);
      expect(
        WidgetDeepLink.tryParse(Uri.parse('x://widget/a.b'), scheme: 'myday'),
        isNull,
      );
    });
  });
}
