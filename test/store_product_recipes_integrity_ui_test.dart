import 'package:bigger_brew_store_management/features/recipes/product_recipes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('product recipes page exposes recipe integrity check', (tester) async {
    // The production AppBar contains multiple action buttons. Give the test
    // enough horizontal space so the widget tree is built without an
    // overflow exception on Flutter's default test viewport.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ProductRecipesPage(loadOnInit: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
    expect(find.text('CHECK INTEGRITY'), findsOneWidget);
  });
}
