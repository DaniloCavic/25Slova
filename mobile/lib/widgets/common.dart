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
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: child,
      );
}

/// Ilustrovana pozadina (noć, planine, reka) sa logom — gornji deo početnog ekrana i prijave.
/// Slika zauzima punu širinu (do 700 px), a donji deo se pretapa u tamnoplavu.
class PictureBackground extends StatelessWidget {
  final Widget child;
  const PictureBackground({super.key, required this.child});

  static const _aspect = 1.5; // slika je 1024 × 1536
  static double imageWidth(BuildContext context) => MediaQuery.of(context).size.width.clamp(0.0, 700.0);

  /// Visina do koje se pruža logo na slici (ispod nje počinje sadržaj).
  static double logoBottom(BuildContext context) => imageWidth(context) * _aspect * 0.655;

  /// Boja neba na vrhu slike — vidi se iznad slike kada se ekran povuče na dole.
  static Color get skyColor => isDark ? const Color(0xFF01194F) : const Color(0xFF0B86EE);

  /// Sama slika (pune širine, do 700 px) sa pretapanjem u pozadinu na dnu.
  static Widget image(BuildContext context) {
    final w = imageWidth(context);
    return SizedBox(
      height: w * _aspect,
      child: Center(
        child: SizedBox(
          width: w,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(isDark ? 'assets/images/pozadina.jpg' : 'assets/images/pozadina_svetla.jpg',
                fit: BoxFit.cover, alignment: Alignment.topCenter),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.62, 0.8, 1],
                  colors: [Colors.transparent, Colors.transparent, const Color(0xCC07142E), bgBottom],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Sadržaj koji se pomera zajedno sa slikom (za ekrane sa listom koja se povlači):
  /// slika je deo liste, a iznad nje je nebo u istoj boji, pa se pri povlačenju na dole
  /// sve spušta zajedno.
  static Widget scrolling(BuildContext context, Widget content) => Stack(clipBehavior: Clip.none, children: [
        Positioned(top: -2000, left: 0, right: 0, height: 2001, child: ColoredBox(color: skyColor)),
        Positioned(top: 0, left: 0, right: 0, child: image(context)),
        content,
      ]);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgBottom,
      child: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, child: image(context)),
        child,
      ]),
    );
  }
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
                  title: title == null ? null : ScreenTitle(title!),
                  automaticallyImplyLeading: showBack,
                  actions: actions,
                  bottom: bottom,
                ),
          body: body,
        ),
      );
}

/// Naslov ekrana: velika slova, kontura (outline) — isti stil na svim ekranima.
class ScreenTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  const ScreenTitle(this.text, {super.key, this.fontSize = 21});

  @override
  Widget build(BuildContext context) {
    // Samo kontura slova, unutrašnjost providna (vidi se pozadina).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        style: TextStyle(
          // Naslov ostaje u prethodnom (sistemskom) fontu, ne u Raleway.
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
          height: 1.1,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..strokeJoin = StrokeJoin.round
            ..color = isDark ? Colors.white : const Color(0xFF1E4FA8),
        ),
      ),
    );
  }
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
  final Widget? trailing;
  const GoldButton(
      {super.key, required this.label, this.subtitle, this.icon, this.onPressed, this.height = 60, this.trailing});

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
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: subtitle == null ? 0 : 18),
              child: Row(
                  mainAxisAlignment: subtitle == null ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    if (icon != null) ...[Icon(icon, color: goldText, size: height * 0.5), const SizedBox(width: 12)],
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: subtitle == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                color: goldText,
                                fontSize: height * 0.32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5)),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: const TextStyle(color: goldText, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (trailing != null) ...[const SizedBox(width: 8), const Spacer(), trailing!]
                  ]),
            ),
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
  final Widget? trailing;
  const BlueButton(
      {super.key, required this.label, this.subtitle, this.icon, this.onPressed, this.height = 56, this.trailing});

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
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 28),
                    SizedBox(width: trailing != null ? 10 : 14)
                  ],
                  Flexible(
                    fit: trailing != null ? FlexFit.tight : FlexFit.loose,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: subtitle == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        // Natpis u jednom redu; na uskim ekranima se malo smanji umesto da pređe u novi red.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(label,
                              maxLines: 1,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                        ),
                        if (subtitle != null)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(subtitle!,
                                maxLines: 1, style: const TextStyle(color: Color(0xFFC9D8F5), fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing!]
                ],
              ),
            ),
          ),
        ),
      );
}

/// Kvadratna pločica menija (RANG LISTE, TOKENI…) — natpis velikim slovima.
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Widget? iconWidget;
  const MenuTile(this.icon, this.label, this.onTap, {super.key, this.iconColor = gold, this.iconWidget});

  @override
  Widget build(BuildContext context) => Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          iconWidget ?? Icon(icon, color: iconColor, size: 34),
          const SizedBox(height: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label.toUpperCase(),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
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
              style: TextStyle(fontSize: radius * 0.9, color: textMain, fontWeight: FontWeight.bold))
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

  /// Svetla varijanta (svetlo plava pozadina, tamni tekst) — za svetle ekrane u svetlom režimu.
  final bool light;
  const TokenChip(this.tokens, {super.key, this.onTap, this.light = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          decoration: BoxDecoration(
            color: light ? const Color(0xFFDDEBFF) : headerChipColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: light ? const Color(0xFF9DBFF2) : panelBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const CoinIcon(size: 26),
            const SizedBox(width: 8),
            Text('$tokens',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, color: light ? const Color(0xFF1E4FA8) : null)),
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
        child: Text('T', style: TextStyle(color: goldText, fontWeight: FontWeight.w900, fontSize: size * 0.5)),
      );
}

/// Traka napretka ka sledećem levelu (npr. 295/500).
class LevelBar extends StatelessWidget {
  final Map<String, dynamic>? progress;
  final num totalPoints;
  final double width;
  final Color? textColor;

  /// Kratak zapis (bez decimala, hiljade kao „15,3K“) — za usku traku na početnom ekranu.
  final bool compact;
  const LevelBar(
      {super.key,
      required this.progress,
      required this.totalPoints,
      this.width = 120,
      this.textColor,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final min = (progress?['min'] ?? 0) as num;
    final max = progress?['max'] as num?;
    final value = max == null ? 1.0 : ((totalPoints - min) / (max + 1 - min)).clamp(0.0, 1.0);
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
      // Tekst se smanji ako ne staje, da ne pređe preko susednih elemenata.
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
              max == null
                  ? 'MAX'
                  : compact
                      ? '${fmtCompact(totalPoints)}/${fmtCompact(max)}'
                      : '${fmtPointsShort(totalPoints)}/$max',
              maxLines: 1,
              style: TextStyle(fontSize: 12, color: textColor ?? textMuted, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }
}

/// Cena partije na dugmetu: „10“ i znak tokena u elipsi.
class CostTag extends StatelessWidget {
  final int amount;
  final Color color;
  const CostTag(this.amount, {super.key, this.color = goldText});

  @override
  Widget build(BuildContext context) {
    // Cena u „elipsi“: tamna providna podloga sa svetlom ivicom i sjajem.
    final onGold = color == goldText;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 3, 4, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: onGold
              ? [const Color(0x40FFFFFF), const Color(0x1A8A5A00)]
              : [const Color(0x33FFFFFF), const Color(0x330A1530)],
        ),
        border: Border.all(color: onGold ? const Color(0xCC8A5A00) : Colors.white.withOpacity(0.55), width: 1.6),
        boxShadow: [
          BoxShadow(
              color: (onGold ? const Color(0xFF8A5A00) : Colors.black).withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$amount', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(width: 6),
        const CoinIcon(size: 24),
      ]),
    );
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
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: urgent ? danger : textMain)),
            Text('s', style: TextStyle(fontSize: 11, color: textMuted, height: 0.8)),
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

const monthNames = [
  'Januar',
  'Februar',
  'Mart',
  'April',
  'Maj',
  'Jun',
  'Jul',
  'Avgust',
  'Septembar',
  'Oktobar',
  'Novembar',
  'Decembar',
];

/// "2026-10" → "Oktobar 2026."
String monthLabel(String key) {
  final parts = key.split('-');
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
  return '${monthNames[(m - 1).clamp(0, 11)]} ${parts[0]}.';
}

/// Opis perioda medalje: "Oktobar 2026.", "Godina 2026.", "Nedelja 2026-W42".
String medalPeriodLabel(String period, String key) => switch (period) {
      'MONTH' => monthLabel(key),
      'YEAR' => 'Godina $key.',
      _ => 'Nedelja $key',
    };

/// Poeni sa dve decimale i zarezom: 36.1 → "36,10".
String fmtPoints(num? v) => (v ?? 0).toStringAsFixed(2).replaceAll('.', ',');

/// Kao fmtPoints, ali bez ",00" kad je ceo broj (za uske prikaze).
String fmtPointsShort(num? v) {
  final x = v ?? 0;
  return x == x.roundToDouble() ? x.round().toString() : fmtPoints(x);
}

/// Kratko, za uske prikaze: 579,68 → "579", 15300 → "15,3K", 200000 → "200K".
String fmtCompact(num? v) {
  final x = (v ?? 0).toDouble();
  if (x.abs() < 10000) return x.truncate().toString();
  final k = x / 1000;
  final s = k.abs() >= 100 ? k.truncate().toString() : ((k * 10).truncate() / 10).toString();
  return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s.replaceAll('.', ',')}K';
}

/// "+36,11" / "-10,00" / "0,00"
String fmtSignedPoints(num? v) => '${(v ?? 0) > 0 ? '+' : ''}${fmtPoints(v)}';

/// Leveli prema ukupnom saldu (isto kao na serveru): svaki se završava na …00, sledeći počinje od …01.
const levelRanges = <(int, int, int?)>[
  (1, 0, 100),
  (2, 101, 500),
  (3, 501, 2000),
  (4, 2001, 5000),
  (5, 5001, 15000),
  (6, 15001, 50000),
  (7, 50001, 100000),
  (8, 100001, 200000),
  (9, 200001, 500000),
  (10, 500001, null),
];

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

/// Tabela levela (od–do poena), sa istaknutim trenutnim levelom.
class LevelTable extends StatelessWidget {
  final int? current;
  const LevelTable({super.key, this.current});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (level, from, to) in levelRanges)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: level == current ? gold.withOpacity(0.18) : panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: level == current ? gold : panelBorder),
            ),
            child: Row(children: [
              Text('Level $level',
                  style: TextStyle(fontWeight: FontWeight.w800, color: level == current ? goldAccent : textMain)),
              const Spacer(),
              Text(to == null ? 'više od ${_thousands(from - 1)}' : '${_thousands(from)} – ${_thousands(to)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('  poena', style: TextStyle(color: textMuted, fontSize: 12)),
            ]),
          ),
      ]);
}

void showLevelsSheet(BuildContext context, {int? current}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Leveli', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Level zavisi od ukupnog broja poena.', style: TextStyle(color: textMuted)),
          const SizedBox(height: 12),
          LevelTable(current: current),
        ]),
      ),
    ),
  );
}

/// „1 početno slovo“, „3 početna slova“, „5 početnih slova“.
String initialLettersLabel(int n) => switch (n) {
      1 => '1 početno slovo',
      2 || 3 || 4 => '$n početna slova',
      _ => '$n početnih slova',
    };

Future<void> showError(BuildContext context, Object e) async {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
}

/// Izbor kao kartice na rang listama: izabrana opcija je plava, ostale prigušene.
class PillTabs extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const PillTabs({super.key, required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: panelBorder),
        ),
        child: Row(children: [
          for (final e in options.entries)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: e.key == selected ? blueGradient : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(e.value,
                          maxLines: 1,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: e.key == selected ? Colors.white : textMuted)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}
