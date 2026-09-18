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
  String? _globalError;
  final Map<RideProvider, String?> _providerError = {
    RideProvider.uber: null,
    RideProvider.lyft: null,
  };

  bool get globalOnline => _globalOnline;
  bool isProviderOnline(RideProvider p) => _providerOnline[p] ?? false;
  String? get globalError => _globalError;
  String? providerError(RideProvider p) => _providerError[p];

  void setService(ProviderStatusPort service) {
    _service = service;
  }

  Future<void> setGlobalOnline(bool online) async {
    if (_globalOnline == online) return;
    final prev = _globalOnline;
    _globalOnline = online;
    _globalError = null;
    notifyListeners();
    try {
      await _service?.setGlobalOnline(online);
    } catch (_) {
      _globalOnline = prev;
      _globalError = 'sync_failed';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setProviderOnline(RideProvider p, bool online) async {
    if (_providerOnline[p] == online) return;
    final prev = _providerOnline[p] ?? false;
    _providerOnline[p] = online;
    _providerError[p] = null;
    notifyListeners();
    try {
      await _service?.setProviderOnline(p, online);
    } catch (_) {
      _providerOnline[p] = prev;
      _providerError[p] = 'sync_failed';
      notifyListeners();
      rethrow;
    }
  }
}
