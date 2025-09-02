import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/ai_controller_service.dart';

class AIControllerButton extends StatelessWidget {
  const AIControllerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'aiController',
      icon: const Icon(Icons.smart_toy),
      label: const Text('AI'),
      onPressed: () async {
        final service = AIControllerService(context: context);
        final choice = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => _PromptSheet(service: service),
        );
        if (choice != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(choice)),
          );
        }
      },
    );
  }
}

class _PromptSheet extends StatefulWidget {
  final AIControllerService service;
  const _PromptSheet({required this.service});

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  String _mode = 'ASK';
  final _controller = TextEditingController();
  bool _busy = false;
  String? _response;
  bool _listening = false;
  stt.SpeechToText? _speech;
  final _tts = FlutterTts();
  final List<String> _history = [];

  @override
  void dispose() {
    _controller.dispose();
    _speech?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('ASK'),
                  selected: _mode == 'ASK',
                  onSelected: (v) => setState(() => _mode = 'ASK'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('DO'),
                  selected: _mode == 'DO',
                  onSelected: (v) => setState(() => _mode = 'DO'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Type a prompt',
                hintText: 'e.g., Where is my route? or Make a route to ...',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: _listening ? 'Listening…' : 'Speak',
                  onPressed: _busy
                      ? null
                      : () async {
                          _speech ??= stt.SpeechToText();
                          final available = await _speech!.initialize(
                            onStatus: (s) {},
                            onError: (e) {},
                          );
                          if (!available) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Speech not available')),
                            );
                            return;
                          }
                          setState(() => _listening = true);
                          await _speech!.listen(
                            onResult: (r) {
                              final text = r.recognizedWords.trim();
                              if (text.isNotEmpty) {
                                _controller.text =
                                    (_controller.text.trim().isEmpty)
                                        ? text
                                        : '${_controller.text} $text';
                                _controller.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(offset: _controller.text.length),
                                );
                              }
                              if (r.finalResult) {
                                setState(() => _listening = false);
                              }
                            },
                          );
                        },
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _listening
                        ? 'Listening… say your prompt, then tap Submit.'
                        : 'Tip: tap the mic to speak your prompt.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_response != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_response!),
              ),
            if (_history.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _history
                      .take(6)
                      .map((h) => ActionChip(
                            label: Text(h, overflow: TextOverflow.ellipsis),
                            onPressed: () =>
                                setState(() => _controller.text = h),
                          ))
                      .toList(),
                ),
              ),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final text = _controller.text.trim();
                      String result;
                      if (_mode == 'ASK') {
                        result = await widget.service.handleAsk(text);
                      } else {
                        result = await widget.service.handleDo(text);
                      }
                      if (!mounted) return;
                      setState(() {
                        _busy = false;
                        _response = result;
                        if (text.isNotEmpty) {
                          _history.insert(0, text);
                          if (_history.length > 10) _history.removeLast();
                        }
                      });
                      // Speak confirmation for DO mode or short ASK responses
                      try {
                        if (_mode == 'DO' || result.length <= 120) {
                          await _tts.setLanguage('en-US');
                          await _tts.speak(result);
                        }
                      } catch (_) {}
                    },
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_busy ? 'Working...' : 'Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
