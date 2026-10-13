import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config.dart';
import '../theme.dart';

/// Tamnoplava pozadina sa blagim prelivom — koristi se na svim glavnim ekranima.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: backgroundGradient),
        child: child,
      );
}

/// Scaffold sa pozadinom igre i providnim gornjim delom.
class GameScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final bool showBack;
  final PreferredSizeWidget? bottom;
  const GameScaffold({super.key, this.title, required this.body, this.actions, this.showBack = true, this.bottom});

  @override
  Widget build(BuildContext context) => AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: title == null && actions == null && !showBack
              ? null
              : AppBar(
                  title: title == null ? null : Text(title!),
                  automaticallyImplyLeading: showBack,
                  actions: actions,
                  bottom: bottom,
                ),
          body: body,
        ),
      );
}

/// Tamni panel sa ivicom (kartica).
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.borderColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? (color ?? panel) : null,
          gradient: gradient,
          borderRadius: radius,
          border: Border.all(color: borderColor ?? panelBorder, width: 1.2),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Veliko zlatno dugme (IGRAJ, POTVRDI…).
class GoldButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  const GoldButton({super.key, required this.label, this.subtitle, this.icon, this.onPressed, this.height = 60});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: goldGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFE9A6), width: 1.5),
          boxShadow: enabled
              ? [BoxShadow(color: goldDeep.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 5))]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, color: goldText, size: height * 0.5), const SizedBox(width: 10)],
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: subtitle == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: goldText, fontSize: height * 0.32, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(color: goldText, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Plavo dugme sa ikonicom i podnaslovom (IGRAJ SA PRIJATELJEM…).
class BlueButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  const BlueButton({super.key, required this.label, this.subtitle, this.icon, this.onPressed, this.height = 56});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          gradient: blueGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF4F80E0), width: 1.2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: subtitle == null ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 28), const SizedBox(width: 14)],
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: subtitle == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                        if (subtitle != null) Text(subtitle!, style: const TextStyle(color: textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Kvadratna pločica menija (Rang-liste, Tokeni…).
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  const MenuTile(this.icon, this.label, this.onTap, {super.key, this.iconColor = gold});

  @override
  Widget build(BuildContext context) => Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: iconColor, size: 34),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
      );
}

class Lives extends StatelessWidget {
  final int lives;
  final double size;
  const Lives(this.lives, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(i < lives ? Icons.favorite : Icons.favorite_border,
                color: i < lives ? danger : textMuted.withOpacity(0.5), size: size),
        ],
      );
}

class UserAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;
  final bool ring;
  const UserAvatar({super.key, required this.url, required this.name, this.radius = 20, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final abs = absoluteUrl(url);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: panelLight,
      backgroundImage: abs != null ? NetworkImage(abs) : null,
      child: abs == null
          ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(fontSize: radius * 0.9, color: Colors.white, fontWeight: FontWeight.bold))
          : null,
    );
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: goldGradient),
      child: avatar,
    );
  }
}

class TokenChip extends StatelessWidget {
  final int tokens;
  final VoidCallback? onTap;
  const TokenChip(this.tokens, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: panelBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const CoinIcon(size: 26),
            const SizedBox(width: 8),
            Text('$tokens', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(width: 8),
            if (onTap != null)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: brandBlue, shape: BoxShape.circle),
                child: const Icon(Icons.add, size: 18, color: Colors.white),
              ),
          ]),
        ),
      );
}

class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: goldGradient,
          border: Border.all(color: const Color(0xFFB87800), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text('S', style: TextStyle(color: goldText, fontWeight: FontWeight.w900, fontSize: size * 0.5)),
      );
}

/// Traka napretka ka sledećem levelu (npr. 295/500).
class LevelBar extends StatelessWidget {
  final Map<String, dynamic>? progress;
  final int totalPoints;
  final double width;
  const LevelBar({super.key, required this.progress, required this.totalPoints, this.width = 120});

  @override
  Widget build(BuildContext context) {
    final min = (progress?['min'] ?? 0) as int;
    final next = progress?['next'] as int?;
    final value = next == null ? 1.0 : ((totalPoints - min) / (next - min)).clamp(0.0, 1.0);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value.toDouble(),
            minHeight: 9,
            backgroundColor: Colors.black.withOpacity(0.35),
            color: gold,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(next == null ? 'MAX' : '$totalPoints/$next',
          style: const TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Logo „25 SLOVA“ od zlatnih pločica.
class SlovaLogo extends StatelessWidget {
  final double size;
  const SlovaLogo({super.key, this.size = 1});

  @override
  Widget build(BuildContext context) {
    Widget tile(String l, double angle) => Transform.rotate(
          angle: angle,
          child: Container(
            width: 46 * size,
            height: 50 * size,
            margin: EdgeInsets.symmetric(horizontal: 2 * size),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF3D1), Color(0xFFF2D8A0)],
              ),
              borderRadius: BorderRadius.circular(8 * size),
              border: Border.all(color: const Color(0xFFC79A4B), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), offset: Offset(0, 4 * size), blurRadius: 6)],
            ),
            child: Text(l, style: TextStyle(fontSize: 30 * size, fontWeight: FontWeight.w900, color: goldText)),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.workspace_premium, color: gold, size: 46 * size),
      ShaderMask(
        shaderCallback: (r) => goldGradient.createShader(r),
        child: Text('25',
            style: TextStyle(
              fontSize: 84 * size,
              height: 0.95,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 8)],
            )),
      ),
      SizedBox(height: 6 * size),
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (i, l) in ['S', 'L', 'O', 'V', 'A'].indexed) tile(l, (i - 2) * 0.06),
      ]),
    ]);
  }
}

/// Kružni tajmer poteza.
class TimerRing extends StatelessWidget {
  final int seconds;
  final double fraction;
  final bool urgent;
  const TimerRing({super.key, required this.seconds, required this.fraction, this.urgent = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 74,
        height: 74,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: bgBottom, border: Border.all(color: panelBorder)),
          ),
          Transform.rotate(
            angle: -math.pi / 2,
            child: SizedBox(
              width: 66,
              height: 66,
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 6,
                backgroundColor: Colors.white12,
                color: urgent ? danger : success,
              ),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$seconds',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: urgent ? danger : Colors.white)),
            const Text('s', style: TextStyle(fontSize: 11, color: textMuted, height: 0.8)),
          ]),
        ]),
      );
}

String medalName(int place) => place == 1
    ? 'Zlatna'
    : place == 2
        ? 'Srebrna'
        : 'Bronzana';
Color medalColor(int place) => place == 1
    ? const Color(0xFFFFC93C)
    : place == 2
        ? const Color(0xFFC9D3E3)
        : const Color(0xFFD08A4E);

String periodName(String period) => switch (period) {
      'WEEK' => 'nedelja',
      'MONTH' => 'mesec',
      _ => 'godina',
    };

/// „1 početno slovo“, „3 početna slova“, „5 početnih slova“.
String initialLettersLabel(int n) => switch (n) {
      1 => '1 početno slovo',
      2 || 3 || 4 => '$n početna slova',
      _ => '$n početnih slova',
    };

Future<void> showError(BuildContext context, Object e) async {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
}
