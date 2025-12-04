import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder widget test', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('test placeholder')),
    ));

    expect(find.text('test placeholder'), findsOneWidget);
  });
}
