import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapps_widget/myapps_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MyAppsWidgetBridge.channelName);
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  final kind = WidgetKindDescriptor(
    id: 'demo.today',
    androidProviders: const ['com.example.TodayProvider'],
    iosKinds: const ['DemoToday'],
    payloadVersion: 2,
    defaultPrivacy: WidgetPrivacy.sensitive,
  );

  MyAppsWidgetBridge bridge({bool supported = true}) => MyAppsWidgetBridge(
    kinds: [kind],
    appGroupId: 'group.demo',
    supported: supported,
  );

  test('envelope applies the descriptor defaults', () {
    final e = bridge().envelope(
      'demo.today',
      const {'n': 1},
      generatedAt: DateTime.utc(2026, 1, 1),
      textScale: 2,
    );
    expect(e.payloadVersion, 2);
    expect(e.privacy, WidgetPrivacy.sensitive);
    expect(e.textScale, 1.5);
  });

  test('publish sends the target and the encoded envelope', () async {
    final b = bridge();
    await b.publish(b.envelope('demo.today', const {'n': 1}));
    expect(calls.single.method, 'publish');
    final args = calls.single.arguments as Map;
    expect(args['kind'], 'demo.today');
    expect(args['androidProviders'], ['com.example.TodayProvider']);
    expect(args['iosKinds'], ['DemoToday']);
    expect(args['appGroupId'], 'group.demo');
    final read = WidgetEnvelopeRead.decode(
      args['envelope'] as String,
      expectedKind: 'demo.today',
    );
    expect(read.status, WidgetEnvelopeStatus.ok);
    expect(read.envelope!.payload, {'n': 1});
    expect(jsonDecode(args['envelope'] as String)['pv'], 2);
  });

  test('clear sends the target', () async {
    await bridge().clear('demo.today');
    expect(calls.single.method, 'clear');
    expect((calls.single.arguments as Map)['kind'], 'demo.today');
  });

  test('unsupported platforms send nothing', () async {
    final b = bridge(supported: false);
    await b.publish(b.envelope('demo.today', const {}));
    await b.clear('demo.today');
    expect(calls, isEmpty);
  });

  test('placedSizes reads instances and skips malformed ones', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return [
            {
              'provider': 'com.example.TodayProvider',
              'widgetId': 7,
              'minWidth': 231,
              'minHeight': 140,
              'maxWidth': 320,
              'maxHeight': 156,
            },
            {'provider': 'com.example.TodayProvider', 'widgetId': 8},
            {
              'provider': 'com.example.TodayProvider',
              'widgetId': 9,
              'minWidth': 0,
              'minHeight': 0,
              'maxWidth': 0,
              'maxHeight': 0,
            },
          ];
        });
    final sizes = await bridge().placedSizes('demo.today');
    expect(calls.single.method, 'placedSizes');
    expect((calls.single.arguments as Map)['androidProviders'], [
      'com.example.TodayProvider',
    ]);
    expect(sizes.single.widgetId, 7);
    expect(sizes.single.portrait, const Size(231, 156));
    expect(sizes.single.landscape, const Size(320, 140));
  });

  test('placedSizes reads channel errors as empty', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'boom'),
        );
    expect(await bridge().placedSizes('demo.today'), isEmpty);
    expect(await bridge(supported: false).placedSizes('demo.today'), isEmpty);
  });

  test('unregistered and duplicate kinds are rejected', () {
    expect(
      () => bridge().envelope('demo.other', const {}),
      throwsArgumentError,
    );
    expect(
      () => MyAppsWidgetBridge(kinds: [kind, kind], supported: true),
      throwsArgumentError,
    );
  });

  group('WidgetRefreshScheduler', () {
    test('debounces a burst into one refresh', () async {
      var runs = 0;
      final s = WidgetRefreshScheduler(
        delay: const Duration(milliseconds: 20),
        onRefresh: () async => runs++,
      );
      s.schedule();
      s.schedule();
      s.schedule();
      expect(s.isPending, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(runs, 1);
      expect(s.isPending, isFalse);
    });

    test('flush runs now and cancel drops', () async {
      var runs = 0;
      final s = WidgetRefreshScheduler(
        delay: const Duration(milliseconds: 20),
        onRefresh: () async => runs++,
      );
      s.schedule();
      await s.flush();
      expect(runs, 1);
      s.schedule();
      s.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(runs, 1);
    });

    test('routes failures to onError', () async {
      final errors = <Object>[];
      final s = WidgetRefreshScheduler(
        onRefresh: () async => throw StateError('boom'),
        onError: (e, _) => errors.add(e),
      );
      await s.flush();
      expect(errors.single, isA<StateError>());
    });
  });
}
