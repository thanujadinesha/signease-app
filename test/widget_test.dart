import 'package:flutter_test/flutter_test.dart';
import 'package:signease_app/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SignEaseApp());
    expect(find.text('SignEase'), findsWidgets);
  });
}
