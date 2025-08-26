import 'dart:async';

/// Minimal in-app safety recorder stub (no audio) with safe-word stop
class SafetyRecorderService {
  SafetyRecorderService._();
  static final SafetyRecorderService instance = SafetyRecorderService._();

  bool _isRecording = false;
  String _safeWord = 'pineapple';
  final _events = <String>[];
  Timer? _timer;

  bool get isRecording => _isRecording;
  List<String> get events => List.unmodifiable(_events);

  void startRecording({String safeWord = 'pineapple'}) {
    if (_isRecording) return;
    _safeWord = safeWord;
    _isRecording = true;
    _events.clear();
    _events.add('Recording started');
    // Simulate periodic event capture
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _events.add('Heartbeat');
    });
  }

  void stopRecording() {
    if (!_isRecording) return;
    _isRecording = false;
    _timer?.cancel();
    _timer = null;
    _events.add('Recording stopped');
  }

  /// Simulate speech input; stops when safe word detected
  void onSpeechInput(String transcript) {
    if (!_isRecording) return;
    _events.add('Speech: $transcript');
    if (transcript.toLowerCase().contains(_safeWord.toLowerCase())) {
      stopRecording();
    }
  }
}


