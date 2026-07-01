import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config.dart';

class AvatarWidget extends StatelessWidget {
  final String? url;
  final double radius;
  final String fallbackLetter;

  const AvatarWidget({
    super.key,
    this.url,
    this.radius = 24,
    required this.fallbackLetter,
  });

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(AppConfig.mediaUrl(url!)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : '?',
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.bold),
      ),
    );
  }
}
