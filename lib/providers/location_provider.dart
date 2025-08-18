import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  bool _isTracking = false;
  List<Position> _trackingHistory = [];

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  List<Position> get trackingHistory => _trackingHistory;

  Future<void> initializeLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    _currentPosition = await Geolocator.getCurrentPosition();
    notifyListeners();
  }

  void startTracking() {
    _isTracking = true;
    _trackingHistory = [];
    notifyListeners();
  }

  void stopTracking() {
    _isTracking = false;
    notifyListeners();
  }

  void updatePosition(Position position) {
    _currentPosition = position;
    if (_isTracking) {
      _trackingHistory.add(position);
    }
    notifyListeners();
  }
}
