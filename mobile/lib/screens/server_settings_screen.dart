import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/app_state.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _url;
  bool _testing = false;
  bool _saving = false;
  String? _status;
  bool? _statusOk;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: AppConfig.apiBaseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _status = null;
      _statusOk = null;
    });
    final result = await AppConfig.testConnection(_url.text);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _status = result.message;
      _statusOk = result.ok;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await AppConfig.testConnection(_url.text);
    if (!result.ok) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = result.message;
        _statusOk = false;
      });
      return;
    }

    await AppConfig.setBaseUrl(_url.text);
    if (mounted) {
      await context.read<AppState>().onServerUrlChanged();
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = result.message;
      _statusOk = true;
      _url.text = AppConfig.apiBaseUrl;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server URL saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Point the app at the machine running Docker.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'Backend URL',
              hintText: 'http://10.0.2.2:3000',
              prefixIcon: Icon(Icons.dns),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            enabled: !_saving,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _hintRow(Icons.computer, 'Android emulator (default)',
                    'http://10.0.2.2:3000'),
                const Divider(height: 24),
                _hintRow(Icons.phone_android, 'Physical phone on same Wi‑Fi',
                    'http://YOUR_PC_IP:3000'),
                const Divider(height: 24),
                _hintRow(Icons.cloud, 'Render (cloud server)',
                    'https://YOUR-SERVICE.onrender.com'),
                const SizedBox(height: 8),
                Text(
                  'Render must use https:// — http:// breaks register and login.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'After .\\start-backend.ps1, your PC IP is printed in the terminal.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                ],
              ),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(
              _status!,
              style: TextStyle(
                color: _statusOk == true
                    ? Colors.green.shade700
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
            label: const Text('Test connection'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    await AppConfig.resetToDefault();
                    if (!mounted) return;
                    setState(() {
                      _url.text = AppConfig.apiBaseUrl;
                      _status = null;
                      _statusOk = null;
                    });
                    if (!mounted) return;
                    await context.read<AppState>().onServerUrlChanged();
                  },
            child: const Text('Reset to emulator default'),
          ),
        ],
      ),
    );
  }

  Widget _hintRow(IconData icon, String title, String example) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SelectableText(example),
            ],
          ),
        ),
      ],
    );
  }
}
