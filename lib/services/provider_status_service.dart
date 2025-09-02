import 'package:litstop/services/api_service.dart';
import '../providers/provider_status_provider.dart';

abstract class ProviderStatusPort {
  Future<void> setGlobalOnline(bool online);
  Future<void> setProviderOnline(RideProvider provider, bool online);
}

class ProviderStatusService implements ProviderStatusPort {
  final ApiService api;

  ProviderStatusService({required this.api});

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
    await api.post('/provider-status/global', body: {
      'online': online,
    });
  }

  @override
  Future<void> setProviderOnline(RideProvider provider, bool online) async {
    final providerKey = _providerToString(provider);
    await api.post('/provider-status/$providerKey', body: {
      'online': online,
    });
  }
}
