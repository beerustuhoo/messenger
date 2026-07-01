import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_client.dart';
import '../widgets/avatar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  List<UserSummary> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() {
        _error = 'Enter at least 2 characters';
        _searched = false;
        _results = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context.read<AppState>().searchUsers(q);
      if (mounted) {
        setState(() {
          _results = results;
          _searched = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _searched = true;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _searched = true;
          _error = 'Search failed. Check your connection.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    decoration: const InputDecoration(
                      hintText: 'Username or email',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.search), onPressed: _search),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: _results.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 48),
                      Icon(Icons.search_off,
                          size: 48, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        _searched
                            ? 'No users found'
                            : 'Search by username (partial) or full email',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (_searched)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'You cannot find your own account. Email search needs the exact address.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  )
                : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final u = _results[i];
                return ListTile(
                  leading: AvatarWidget(url: u.avatarUrl, fallbackLetter: u.username),
                  title: Text(u.username),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      try {
                        await context.read<AppState>().sendInvite(u.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invitation sent')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
                    child: const Text('Invite'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
