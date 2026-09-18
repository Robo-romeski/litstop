import 'package:flutter_test/flutter_test.dart';
import 'package:litstop/providers/provider_status_provider.dart';
import 'package:litstop/services/provider_status_service.dart';

void main() {
  test('optimistic global toggle reverts on failure', () async {
    final p = ProviderStatusProvider();
    bool shouldFail = true;

    p.setService(_Service(
      onGlobal: (v) async {
        if (shouldFail) throw Exception('fail');
      },
    ));

    expect(p.globalOnline, false);
    try {
      await p.setGlobalOnline(true);
    } catch (_) {}
    expect(p.globalOnline, false);

    shouldFail = false;
    await p.setGlobalOnline(true);
    expect(p.globalOnline, true);
  });

  test('optimistic provider toggle reverts on failure', () async {
    final p = ProviderStatusProvider();
    bool shouldFail = true;

    p.setService(_Service(
      onProvider: (prov, v) async {
        if (shouldFail) throw Exception('fail');
      },
    ));

    expect(p.isProviderOnline(RideProvider.uber), false);
    try {
      await p.setProviderOnline(RideProvider.uber, true);
    } catch (_) {}
    expect(p.isProviderOnline(RideProvider.uber), false);

    shouldFail = false;
    await p.setProviderOnline(RideProvider.uber, true);
    expect(p.isProviderOnline(RideProvider.uber), true);
  });
}

class _Service implements ProviderStatusPort {
  final Future<void> Function(bool)? onGlobal;
  final Future<void> Function(RideProvider, bool)? onProvider;
  _Service({this.onGlobal, this.onProvider});

  @override
  Future<void> setGlobalOnline(bool online) async {
    if (onGlobal != null) await onGlobal!(online);
  }

  @override
  Future<void> setProviderOnline(RideProvider provider, bool online) async {
    if (onProvider != null) await onProvider!(provider, online);
  }
}
