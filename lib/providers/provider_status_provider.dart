import 'package:flutter/foundation.dart';
import '../services/provider_status_service.dart';

enum RideProvider { uber, lyft }

class ProviderStatusProvider with ChangeNotifier {
  ProviderStatusPort? _service;
  bool _globalOnline = false;
  final Map<RideProvider, bool> _providerOnline = {
    RideProvider.uber: false,
    RideProvider.lyft: false,
  };

  bool get globalOnline => _globalOnline;
  bool isProviderOnline(RideProvider p) => _providerOnline[p] ?? false;

  void setService(ProviderStatusPort service) {
    _service = service;
  }

  Future<void> setGlobalOnline(bool online) async {
    if (_globalOnline == online) return;
    final prev = _globalOnline;
    _globalOnline = online;
    notifyListeners();
    try {
      await _service?.setGlobalOnline(online);
    } catch (_) {
      _globalOnline = prev;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setProviderOnline(RideProvider p, bool online) async {
    if (_providerOnline[p] == online) return;
    final prev = _providerOnline[p] ?? false;
    _providerOnline[p] = online;
    notifyListeners();
    try {
      await _service?.setProviderOnline(p, online);
    } catch (_) {
      _providerOnline[p] = prev;
      notifyListeners();
      rethrow;
    }
  }
}
