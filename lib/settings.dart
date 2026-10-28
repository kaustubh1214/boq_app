import 'package:flutter/material.dart';

import 'config.dart';

/// Change the server address without rebuilding the app (e.g. a new ngrok domain or the office Wi-Fi address).
/// Pops with true when a new address was saved.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.current});

  final String current;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _field = TextEditingController(text: widget.current);
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save({bool reset = false}) async {
    final url = reset ? defaultServer : ServerConfig.normalise(_field.text);
    if (url == null) {
      setState(() {
        _message = 'Enter an address like https://name.ngrok-free.dev';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final problem = await ServerConfig.check(url);
    if (!mounted) return;
    if (problem != null && !reset) {
      setState(() {
        _busy = false;
        _message = '$problem\nNot saved.';
      });
      return;
    }
    await ServerConfig.save(url);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Server settings')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Server address', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
          const SizedBox(height: 8),
          TextField(
            controller: _field,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(hintText: 'https://name.ngrok-free.dev'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          const Text(
            'Only change this if the office gives you a new address.',
            style: TextStyle(color: mutedText),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: const TextStyle(color: danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: paper))
                : const Text('Check and save'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _busy ? null : () => _save(reset: true), child: const Text('Use the default address')),
          const SizedBox(height: 24),
          const Text('Default: $defaultServer', style: TextStyle(color: mutedText, fontSize: 12)),
        ]),
      );
}
