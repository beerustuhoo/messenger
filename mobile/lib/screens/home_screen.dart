import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/avatar.dart';
import '../widgets/verification_banner.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'invites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = _showArchived ? state.archivedChats : state.chats;
    final inviteCount = state.pendingInvites.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? 'Archived' : 'Chats'),
        actions: [
          IconButton(
            icon: Badge(
              label: inviteCount > 0 ? Text('$inviteCount') : null,
              child: const Icon(Icons.mail_outline),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvitesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!state.user!.emailVerified) const VerificationBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.loadChats,
              child: list.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Text(_showArchived
                                ? 'No archived chats'
                                : 'No chats yet.\nSearch users to send invites.'),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final chat = list[i];
                        return Dismissible(
                          key: Key(chat.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.orange,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: Icon(
                              _showArchived ? Icons.unarchive : Icons.archive,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            await state.archiveChat(chat.id, !_showArchived);
                            return false;
                          },
                          child: ListTile(
                            leading: AvatarWidget(
                              url: chat.otherUser.avatarUrl,
                              fallbackLetter: chat.displayTitle,
                            ),
                            title: Row(
                              children: [
                                if (chat.isGroup)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.groups, size: 16),
                                  ),
                                Expanded(child: Text(chat.displayTitle)),
                                if (chat.muted) const Icon(Icons.notifications_off, size: 16),
                              ],
                            ),
                            subtitle: Text(
                              chat.lastMessage?.preview ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: chat.lastMessage != null
                                ? Text(
                                    _formatTime(chat.lastMessage!.createdAt),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  )
                                : null,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(chat: chat),
                              ),
                            ).then((_) => state.loadChats()),
                            onLongPress: () => _chatOptions(context, chat.id, chat.muted),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _showArchived = !_showArchived),
        icon: Icon(_showArchived ? Icons.chat : Icons.archive),
        label: Text(_showArchived ? 'Active chats' : 'Archived'),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }

  void _showVerifyDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste the long token from Mailhog (plain text, not the URL).'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '64-character token',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await context.read<AppState>().verifyEmail(controller.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email verified!')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _chatOptions(BuildContext context, String chatId, bool muted) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(muted ? Icons.notifications : Icons.notifications_off),
              title: Text(muted ? 'Unmute notifications' : 'Mute notifications'),
              onTap: () {
                context.read<AppState>().muteChat(chatId, !muted);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
