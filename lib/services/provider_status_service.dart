import 'package:litstop/services/api_service.dart';
import '../providers/provider_status_provider.dart';

typedef TokenSupplier = Future<String?> Function();

abstract class ProviderStatusPort {
  Future<void> setGlobalOnline(bool online);
  Future<void> setProviderOnline(RideProvider provider, bool online);
}

class ProviderStatusService implements ProviderStatusPort {
  final ApiService api;
  final TokenSupplier? tokenSupplier;

  ProviderStatusService({required this.api, this.tokenSupplier});

  Future<Map<String, String>?> _authHeaders() async {
    if (tokenSupplier == null) return null;
    final token = await tokenSupplier!();
    if (token == null) return null;
    return {'Authorization': 'Bearer $token'};
  }

  String _providerToString(RideProvider p) {
    switch (p) {
      case RideProvider.uber:
        return 'uber';
      case RideProvider.lyft:
        return 'lyft';
    }
  }

  @override
  Future<void> setGlobalOnline(bool online) async {
    await api
        .post('/provider-status/global', headers: await _authHeaders(), body: {
      'online': online,
    });
  }

  @override
  Future<void> setProviderOnline(RideProvider provider, bool online) async {
    final providerKey = _providerToString(provider);
    await api.post('/provider-status/$providerKey',
        headers: await _authHeaders(),
        body: {
          'online': online,
        });
  }
}
