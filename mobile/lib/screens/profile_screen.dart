import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/app_state.dart';
import '../providers/theme_provider.dart';
import '../utils/image_upload.dart';
import '../widgets/avatar.dart';
import 'server_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _username;
  late TextEditingController _about;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().user!;
    _username = TextEditingController(text: u.username);
    _about = TextEditingController(text: u.about);
  }

  @override
  void dispose() {
    _username.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final prepared = preparePickedImage(file, bytes);
    if (prepared.bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be under 5MB')),
        );
      }
      return;
    }
    if (!isAllowedImageMime(prepared.mimeType)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only JPEG and PNG are supported')),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().uploadAvatar(
            prepared.bytes,
            prepared.filename,
            mimeType: prepared.mimeType,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await context.read<AppState>().updateProfile(
                            username: _username.text.trim(),
                            about: _about.text,
                          );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile saved')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                    if (mounted) setState(() => _saving = false);
                  },
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  AvatarWidget(
                    url: user.avatarUrl,
                    radius: 50,
                    fallbackLetter: user.username,
                  ),
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.camera_alt, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Tap to change (JPEG/PNG, max 5MB)',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _about,
            decoration: const InputDecoration(
              labelText: 'About me',
              hintText: 'Tell others about yourself',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          if (user.email != null)
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(user.email!),
              trailing: user.emailVerified
                  ? const Icon(Icons.verified, color: Colors.green)
                  : const Icon(Icons.warning_amber, color: Colors.orange),
            ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Server'),
            subtitle: Text(AppConfig.apiBaseUrl),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(_themeLabel(context.watch<ThemeProvider>().mode)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('System'),
                ),
              ],
              selected: {context.watch<ThemeProvider>().mode},
              onSelectionChanged: (selection) {
                context.read<ThemeProvider>().setMode(selection.first);
              },
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out', style: TextStyle(color: Colors.red)),
            onTap: () => context.read<AppState>().logout(),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System default',
      };
}
