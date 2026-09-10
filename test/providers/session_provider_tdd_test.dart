import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:litstop/providers/session_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('startSession initializes metrics and toggles active', () async {
    final p = SessionProvider();
    await p.startSession();
    expect(p.isSessionActive, true);
    expect(p.totalEarnings, 0);
    expect(p.totalRides, 0);
  });
}
