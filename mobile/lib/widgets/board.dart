import 'package:flutter/material.dart';
import '../letters.dart';
import '../theme.dart';

/// Tabla 5 × 5. Početna nasumična slova su obeležena, a u rezultatu i polja reči.
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
            Color bg = letter == null ? cellEmpty : cellFilled;
            if (initialCells.contains(i)) bg = cellInitial;
            if (highlighted.contains(i)) bg = cellWord;
            if (isSel) bg = cellSelected;
            return Semantics(
              button: onTap != null && letter == null,
              label: 'Polje ${i + 1}${shown == null ? '' : ': ${showLetter(shown, script)}'}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onTap == null || letter != null ? null : () => onTap!(i),
                child: Container(
                  margin: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel
                          ? brandBlue
                          : (initialCells.contains(i) ? const Color(0xFFE0A800) : const Color(0xFFD5DAE3)),
                      width: isSel ? 2.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    showLetter(shown, script),
                    style: TextStyle(
                      fontSize: cell * 0.42,
                      fontWeight: FontWeight.w700,
                      color: letter == null ? brandBlue.withOpacity(0.5) : const Color(0xFF1C2230),
                    ),
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
