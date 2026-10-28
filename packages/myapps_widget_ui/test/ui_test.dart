import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapps_widget_ui/myapps_widget_ui.dart';

void main() {
  testWidgets('text scale control shows the clamped percentage', (
    tester,
  ) async {
    double? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: WidgetTextScaleControl(
            value: 1.24,
            title: 'Widget text size',
            subtitle: 'Applies to every widget',
            onChanged: (v) => changed = v,
          ),
        ),
      ),
    );
    expect(find.text('120%'), findsOneWidget);
    expect(find.text('Widget text size'), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    expect(changed, 1.5);
  });

  testWidgets('preview surface has the requested size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: WidgetPreviewSurface(
            width: WidgetPreviewSurface.smallSide,
            height: WidgetPreviewSurface.stripHeight,
            child: Text('x'),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(WidgetPreviewSurface)),
      const Size(172, 76),
    );
  });
}
