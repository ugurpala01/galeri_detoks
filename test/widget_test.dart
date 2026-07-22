import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:galeri_detoks/main.dart';

void main() {
  testWidgets('App smoke test - renders without crash',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: GaleriDetoksApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
