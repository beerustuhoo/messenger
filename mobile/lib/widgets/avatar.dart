import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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

  Widget _fallback(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : '?',
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _fallback(context);
    }

    final src = AppConfig.mediaUrl(url!);
    final size = radius * 2;

    if (kIsWeb) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: ClipOval(
          child: Image.network(
            src,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => SizedBox(
              width: size,
              height: size,
              child: Center(
                child: Text(
                  fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: CachedNetworkImageProvider(src),
    );
  }
}
