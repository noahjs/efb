import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const EfbApp());
    expect(find.text('Maps'), findsWidgets);
  });
}
