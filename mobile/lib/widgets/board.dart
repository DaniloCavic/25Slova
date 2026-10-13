import 'package:flutter/material.dart';
import '../letters.dart';
import '../theme.dart';

/// Tabla 5 × 5. Postavljena slova su zlatne pločice, početna nasumična slova su svetle,
/// a u rezultatu su polja pronađenih reči uokvirena zeleno.
class BoardGrid extends StatelessWidget {
  final List<dynamic> board;
  final Script script;
  final Set<int> initialCells;
  final Set<int> highlighted;
  final int? selected;
  final String? previewLetter;
  final void Function(int cell)? onTap;
  final double maxSize;

  const BoardGrid({
    super.key,
    required this.board,
    required this.script,
    this.initialCells = const {},
    this.highlighted = const {},
    this.selected,
    this.previewLetter,
    this.onTap,
    this.maxSize = 420,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = [c.maxWidth, maxSize].reduce((a, b) => a < b ? a : b);
      final cell = size / 5;
      return SizedBox(
        width: size,
        height: size,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
          itemCount: 25,
          itemBuilder: (_, i) {
            final letter = board[i] as String?;
            final isSel = selected == i;
            final shown = letter ?? (isSel ? previewLetter : null);
            final isInitial = initialCells.contains(i);
            final isWord = highlighted.contains(i);

            BoxDecoration deco;
            Color textColor = goldText;
            if (letter == null && !isSel) {
              deco = BoxDecoration(
                color: cellEmpty,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: panelBorder, width: 1.2),
              );
            } else if (isSel) {
              deco = BoxDecoration(
                color: cellSelected.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cellSelected, width: 2.5),
                boxShadow: [BoxShadow(color: cellSelected.withOpacity(0.5), blurRadius: 10)],
              );
              textColor = Colors.white;
            } else {
              deco = BoxDecoration(
                gradient: isInitial
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, cellInitial],
                      )
                    : goldGradient,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isWord ? success : (isInitial ? const Color(0xFFE6C98A) : const Color(0xFFFFE9A6)),
                  width: isWord ? 3 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.35), offset: const Offset(0, 3), blurRadius: 4),
                  if (isWord) BoxShadow(color: success.withOpacity(0.45), blurRadius: 8),
                ],
              );
            }

            return Semantics(
              button: onTap != null && letter == null,
              label: 'Polje ${i + 1}${shown == null ? '' : ': ${showLetter(shown, script)}'}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onTap == null || letter != null ? null : () => onTap!(i),
                child: Container(
                  margin: EdgeInsets.all(cell * 0.045),
                  decoration: deco,
                  alignment: Alignment.center,
                  child: Text(
                    showLetter(shown, script),
                    style: TextStyle(fontSize: cell * 0.42, fontWeight: FontWeight.w900, color: textColor),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
