
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_qr_generator/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WifiQrGeneratorApp());

    // Verify that our app builds
    expect(find.text('Wi-Fi QR Generator'), findsOneWidget);
  });
}
