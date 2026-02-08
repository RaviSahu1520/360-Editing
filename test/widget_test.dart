import 'package:flutter_test/flutter_test.dart';

import 'package:photo_editor_auto_improve/main.dart';

import 'test_bootstrap.dart';

void main() {
  testWidgets('home renders upload CTA', (WidgetTester tester) async {
    await setupTestDependencies();
    await tester.pumpWidget(const PhotoEditorMvpApp());
    await tester.pumpAndSettle();

    expect(find.text('Upload Photo'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });
}
