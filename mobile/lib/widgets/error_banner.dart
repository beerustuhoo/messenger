import 'package:flutter/material.dart';

class ErrorBanner extends StatelessWidget {
  final String? message;
  final VoidCallback? onDismiss;

  const ErrorBanner({super.key, this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      content: Text(message!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
      actions: [
        TextButton(onPressed: onDismiss ?? () {}, child: const Text('Dismiss')),
      ],
    );
  }
}
