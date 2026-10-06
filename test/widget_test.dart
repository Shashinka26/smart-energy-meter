import 'package:flutter_test/flutter_test.dart';
import 'package:smart_energy_app/main.dart';

void main() {
  testWidgets('Smart Energy app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartEnergyApp());

    expect(find.text('Smart Energy Meter'), findsOneWidget);
  });
}
