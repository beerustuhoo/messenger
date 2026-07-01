import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_client.dart';
import '../widgets/avatar.dart';

/// Search users by username/email and pick one or many (for group create / invite).
class UserPickerDialog extends StatefulWidget {
  const UserPickerDialog({
    super.key,
    this.title = 'Select users',
    this.allowMultiple = false,
    this.confirmLabel = 'Add',
  });

  final String title;
  final bool allowMultiple;
  final String confirmLabel;

  static Future<List<UserSummary>?> pickMany(BuildContext context, {String? title}) {
    return showDialog<List<UserSummary>>(
      context: context,
      builder: (_) => UserPickerDialog(
        title: title ?? 'Add group members',
        allowMultiple: true,
        confirmLabel: 'Done',
      ),
    );
  }

  static Future<UserSummary?> pickOne(BuildContext context, {String? title}) async {
    final list = await showDialog<List<UserSummary>>(
      context: context,
      builder: (_) => UserPickerDialog(
        title: title ?? 'Invite user',
        allowMultiple: false,
        confirmLabel: 'Invite',
      ),
    );
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  @override
  State<UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<UserPickerDialog> {
  final _query = TextEditingController();
  final _selected = <String, UserSummary>{};
  List<UserSummary> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() => _error = 'Enter at least 2 characters');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context.read<AppState>().searchUsers(q);
      if (mounted) setState(() => _results = results);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(UserSummary user) {
    setState(() {
      if (_selected.containsKey(user.id)) {
        _selected.remove(user.id);
      } else if (widget.allowMultiple) {
        _selected[user.id] = user;
      } else {
        _selected
          ..clear()
          ..[user.id] = user;
      }
    });
  }

  void _confirm() {
    if (_selected.isEmpty && !widget.allowMultiple) {
      setState(() => _error = 'Select a user');
      return;
    }
    Navigator.pop(context, _selected.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    decoration: const InputDecoration(
                      hintText: 'Username or email',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.search), onPressed: _search),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selected.values
                      .map(
                        (u) => Chip(
                          label: Text(u.username),
                          onDeleted: () => setState(() => _selected.remove(u.id)),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('Search for users to add'))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final u = _results[i];
                        final picked = _selected.containsKey(u.id);
                        return ListTile(
                          leading: AvatarWidget(url: u.avatarUrl, fallbackLetter: u.username),
                          title: Text(u.username),
                          trailing: picked
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.add_circle_outline),
                          onTap: () => _toggle(u),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (widget.allowMultiple)
          TextButton(onPressed: () => Navigator.pop(context, <UserSummary>[]), child: const Text('Skip')),
        FilledButton(onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
