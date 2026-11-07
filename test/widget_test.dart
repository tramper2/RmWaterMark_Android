import 'package:flutter_test/flutter_test.dart';
import 'package:rm_water_mark/main.dart';

void main() {
  testWidgets('CleanMarkApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CleanMarkApp());
    expect(find.text('워터마크 지우개'), findsWidgets);
  });
}
