import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/avatar.dart';

class InvitesScreen extends StatelessWidget {
  const InvitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final invites = context.watch<AppState>().pendingInvites;

    return Scaffold(
      appBar: AppBar(title: const Text('Pending invitations')),
      body: invites.isEmpty
          ? const Center(child: Text('No pending invitations'))
          : ListView.builder(
              itemCount: invites.length,
              itemBuilder: (context, i) {
                final inv = invites[i];
                return ListTile(
                  leading: AvatarWidget(
                    url: inv.fromUser.avatarUrl,
                    fallbackLetter: inv.fromUser.username,
                  ),
                  title: Text(inv.fromUser.username),
                  subtitle: const Text('Wants to chat with you'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () =>
                            context.read<AppState>().respondInvite(inv.id, true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () =>
                            context.read<AppState>().respondInvite(inv.id, false),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
