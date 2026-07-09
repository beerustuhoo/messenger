import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class VerificationBanner extends StatelessWidget {
  const VerificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.user == null || state.user!.emailVerified) {
      return const SizedBox.shrink();
    }

    final usesFirebase = state.usesFirebaseAuth;

    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Verify your email', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              usesFirebase
                  ? 'We sent a verification email to ${state.user!.email ?? 'your address'} via Firebase. Open the link in that message, then tap "I verified".'
                  : state.lastVerificationEmailSent
                      ? 'We sent a verification email to ${state.user!.email ?? 'your address'}. Open the link or use Verify now below.'
                      : 'No verification email was sent (SMTP not configured). Use Verify now below, or configure SMTP on the server.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton(
                  onPressed: () async {
                    try {
                      await state.verifyEmailNow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email verified!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  child: Text(usesFirebase ? 'I verified' : 'Verify now'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await state.resendVerification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Verification email sent — check inbox and spam'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  child: const Text('Resend email'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
