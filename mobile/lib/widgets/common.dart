import 'package:flutter/material.dart';
import '../config.dart';
import '../theme.dart';

class Lives extends StatelessWidget {
  final int lives;
  final double size;
  const Lives(this.lives, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(i < lives ? Icons.favorite : Icons.favorite_border, color: brandRed, size: size),
        ],
      );
}

class UserAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;
  const UserAvatar({super.key, required this.url, required this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final abs = absoluteUrl(url);
    return CircleAvatar(
      radius: radius,
      backgroundColor: brandBlue.withOpacity(0.15),
      backgroundImage: abs != null ? NetworkImage(abs) : null,
      child: abs == null
          ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(fontSize: radius * 0.9, color: brandBlue, fontWeight: FontWeight.bold))
          : null,
    );
  }
}

class TokenChip extends StatelessWidget {
  final int tokens;
  const TokenChip(this.tokens, {super.key});

  @override
  Widget build(BuildContext context) => Chip(
        avatar: const Icon(Icons.toll, color: Color(0xFFE0A800)),
        label: Text('$tokens', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
      );
}

String medalName(int place) => place == 1
    ? 'Zlatna'
    : place == 2
        ? 'Srebrna'
        : 'Bronzana';
Color medalColor(int place) => place == 1
    ? const Color(0xFFE0A800)
    : place == 2
        ? const Color(0xFF9EA7B3)
        : const Color(0xFFB0703A);

Future<void> showError(BuildContext context, Object e) async {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
}
