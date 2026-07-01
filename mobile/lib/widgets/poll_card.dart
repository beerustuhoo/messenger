import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';

class PollCard extends StatelessWidget {
  const PollCard({super.key, required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final poll = message.poll;
    if (poll == null) return Text(message.content ?? 'Poll');

    final state = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(poll.question, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (poll.anonymous)
          Text('Anonymous poll', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        ...poll.options.map((opt) {
          final selected = poll.myVotes.contains(opt.id);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(opt.text),
            subtitle: Text('${opt.votes} vote(s)'),
            trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
            onTap: () async {
              try {
                if (selected) {
                  await state.retractPollVote(poll.id, optionId: opt.id);
                } else {
                  await state.votePoll(poll.id, opt.id);
                }
              } catch (e) {
                state.showBannerError(e.toString());
              }
            },
          );
        }),
        if (poll.myVotes.isNotEmpty)
          TextButton(
            onPressed: () => state.retractPollVote(poll.id),
            child: const Text('Retract vote'),
          ),
      ],
    );
  }
}
