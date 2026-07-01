import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/avatar.dart';
import '../widgets/error_banner.dart';
import '../widgets/verification_banner.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  final _messageSearch = TextEditingController();
  String? _searchScopeChatId;
  int _searchResultIndex = 0;

  @override
  void dispose() {
    _messageSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Messenger'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: state.pendingInvites.isNotEmpty || state.pendingGroupInvites.isNotEmpty,
              label: Text('${state.pendingInvites.length + state.pendingGroupInvites.length}'),
              child: const Icon(Icons.mail_outline),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _WebInvitesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showCreateGroup(context),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          const VerificationBanner(),
          ErrorBanner(message: state.bannerError, onDismiss: () => state.clearBannerError()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageSearch,
                    decoration: const InputDecoration(
                      labelText: 'Search messages',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (q) => _runSearch(state, q),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => _runSearch(state, _messageSearch.text), child: const Text('Search')),
                if (state.searchResults.isNotEmpty) ...[
                  IconButton(
                    tooltip: 'Previous match',
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: _searchResultIndex > 0 ? () => _jumpToSearchResult(state, _searchResultIndex - 1) : null,
                  ),
                  Text('${_searchResultIndex + 1}/${state.searchResults.length}'),
                  IconButton(
                    tooltip: 'Next match',
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: _searchResultIndex < state.searchResults.length - 1
                        ? () => _jumpToSearchResult(state, _searchResultIndex + 1)
                        : null,
                  ),
                  TextButton(onPressed: () {
                    setState(() {
                      _searchScopeChatId = null;
                      _searchResultIndex = 0;
                    });
                    state.clearSearch();
                  }, child: const Text('Clear')),
                ],
              ],
            ),
          ),
          if (state.searchResults.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: state.searchResults.length,
                itemBuilder: (context, i) {
                  final m = state.searchResults[i];
                  final chat = state.chatById(m.chatId);
                  return Card(
                    child: InkWell(
                      onTap: () => _jumpToSearchResult(state, i),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 220,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(chat?.displayTitle ?? 'Chat', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(m.content ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 300,
                  child: _ChatSidebar(
                    onOpen: (id) => context.read<AppState>().openChat(id),
                    selectedIds: state.openChatIds,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: state.openChatIds.isEmpty
                      ? const Center(child: Text('Select a chat or open up to 2 side by side'))
                      : Row(
                          children: [
                            for (final id in state.openChatIds) ...[
                              Expanded(
                                child: _OpenChatPane(
                                  chatId: id,
                                  highlightQuery: _activeHighlightQuery(state, id),
                                  highlightMessageId: _activeHighlightMessageId(state, id),
                                  onClose: () => context.read<AppState>().closeChat(id),
                                  onInvite: () => _showInviteToGroup(context, id),
                                ),
                              ),
                              if (id != state.openChatIds.last) const VerticalDivider(width: 1),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runSearch(AppState state, String q) async {
    try {
      await state.searchMessages(q, chatId: _searchScopeChatId);
      if (state.searchResults.isNotEmpty) {
        _jumpToSearchResult(state, 0);
      } else {
        setState(() => _searchResultIndex = 0);
      }
    } catch (e) {
      state.showBannerError(e.toString());
    }
  }

  void _jumpToSearchResult(AppState state, int index) {
    if (index < 0 || index >= state.searchResults.length) return;
    final m = state.searchResults[index];
    state.openChat(m.chatId);
    setState(() {
      _searchResultIndex = index;
      _searchScopeChatId = m.chatId;
    });
  }

  String? _activeHighlightQuery(AppState state, String chatId) {
    if (state.searchResults.isEmpty || _searchScopeChatId != chatId) return null;
    return state.searchQuery;
  }

  String? _activeHighlightMessageId(AppState state, String chatId) {
    if (state.searchResults.isEmpty || _searchScopeChatId != chatId) return null;
    return state.searchResults[_searchResultIndex].id;
  }

  Future<void> _showInviteToGroup(BuildContext context, String chatId) async {
    final userIdCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite to group'),
        content: TextField(
          controller: userIdCtrl,
          decoration: const InputDecoration(
            labelText: 'User ID',
            helperText: 'Find users via Search (person icon)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send invite')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<AppState>().sendGroupInvite(chatId, userIdCtrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group invite sent')));
      }
    } catch (e) {
      context.read<AppState>().showBannerError(e.toString());
    }
  }

  Future<void> _showCreateGroup(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final membersCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create group chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group name')),
            TextField(
              controller: membersCtrl,
              decoration: const InputDecoration(
                labelText: 'Member user IDs (comma-separated)',
                helperText: 'Find users via Search first',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final ids = membersCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      await context.read<AppState>().createGroup(nameCtrl.text.trim(), ids);
    } catch (e) {
      context.read<AppState>().showBannerError(e.toString());
    }
  }
}

class _ChatSidebar extends StatelessWidget {
  const _ChatSidebar({required this.onOpen, required this.selectedIds});

  final void Function(String chatId) onOpen;
  final List<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Chats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => state.loadChats(),
            child: ListView.builder(
              itemCount: state.chats.length,
              itemBuilder: (context, i) {
                final chat = state.chats[i];
                final selected = selectedIds.contains(chat.id);
                return ListTile(
                  selected: selected,
                  leading: AvatarWidget(
                    url: chat.isGroup ? null : chat.otherUser.avatarUrl,
                    fallbackLetter: chat.displayTitle,
                  ),
                  title: Text(chat.displayTitle),
                  subtitle: Text(chat.lastMessage?.preview ?? 'No messages yet'),
                  onTap: () => onOpen(chat.id),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _OpenChatPane extends StatelessWidget {
  const _OpenChatPane({
    required this.chatId,
    required this.onClose,
    this.highlightQuery,
    this.highlightMessageId,
    this.onInvite,
  });

  final String chatId;
  final VoidCallback onClose;
  final String? highlightQuery;
  final String? highlightMessageId;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<AppState>().chatById(chatId);
    if (chat == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(chat.displayTitle, style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
              if (chat.isGroup && onInvite != null)
                IconButton(icon: const Icon(Icons.person_add), tooltip: 'Invite member', onPressed: onInvite),
            ],
          ),
        ),
        Expanded(
          child: ChatScreen(
            chat: chat,
            embedded: true,
            highlightQuery: highlightQuery,
            highlightMessageId: highlightMessageId,
          ),
        ),
      ],
    );
  }
}

class _WebInvitesScreen extends StatelessWidget {
  const _WebInvitesScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Invitations')),
      body: ListView(
        children: [
          if (state.pendingInvites.isNotEmpty)
            const ListTile(title: Text('Direct invites', style: TextStyle(fontWeight: FontWeight.bold))),
          ...state.pendingInvites.map(
            (inv) => ListTile(
              leading: AvatarWidget(url: inv.fromUser.avatarUrl, fallbackLetter: inv.fromUser.username),
              title: Text(inv.fromUser.username),
              subtitle: const Text('Direct chat invitation'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => state.respondInvite(inv.id, true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => state.respondInvite(inv.id, false),
                  ),
                ],
              ),
            ),
          ),
          if (state.pendingGroupInvites.isNotEmpty)
            const ListTile(title: Text('Group invites', style: TextStyle(fontWeight: FontWeight.bold))),
          ...state.pendingGroupInvites.map(
            (inv) => ListTile(
              leading: const Icon(Icons.groups),
              title: Text(inv.chatName),
              subtitle: Text('From ${inv.fromUser.username}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => state.respondGroupInvite(inv.id, true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => state.respondGroupInvite(inv.id, false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
