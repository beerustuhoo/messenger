import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    final token = state.pendingVerificationToken;
    final emailSent = state.lastVerificationEmailSent;

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
              emailSent
                  ? 'We sent a verification email to ${state.user!.email ?? 'your address'}. Open the link in that message, or use Verify now below.'
                  : 'No verification email was sent (SMTP is not configured on the server). Use Verify now below, or ask the admin to set SMTP on Render.',
            ),
            if (!emailSent) ...[
              const SizedBox(height: 8),
              Text(
                'Render needs real SMTP (e.g. Resend). See RENDER.md in the repo.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            if (token != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                token,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ],
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
                  child: const Text('Verify now'),
                ),
                if (token != null)
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')),
                      );
                    },
                    child: const Text('Copy code'),
                  ),
                TextButton(
                  onPressed: () async {
                    try {
                      final sent = await state.resendVerification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              sent
                                  ? 'Verification email sent — check your inbox and spam folder.'
                                  : 'Could not send email. SMTP is not set up on the server.',
                            ),
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
