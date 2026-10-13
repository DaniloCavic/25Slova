import 'package:flutter/material.dart';
import '../letters.dart';
import '../theme.dart';

/// Izbor slova iz srpske azbuke (30 slova; Lj, Nj, Dž su jedno slovo).
class LetterPicker extends StatelessWidget {
  final Script script;
  final String? selected;
  final ValueChanged<String> onPick;
  final bool enabled;

  const LetterPicker(
      {super.key, required this.script, required this.selected, required this.onPick, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final letters = pickerOrder(script);
    return GridView.count(
      crossAxisCount: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      childAspectRatio: 0.85,
      children: [
        for (final l in letters)
          GestureDetector(
            onTap: enabled ? () => onPick(l) : null,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected == l
                    ? goldGradient
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Color(0xFFDDE3EE)],
                      ),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: selected == l ? const Color(0xFFFFE9A6) : const Color(0xFFB9C3D6), width: 1.2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.35), offset: const Offset(0, 2), blurRadius: 2)
                ],
              ),
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(
                    showLetter(l, script),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: enabled ? const Color(0xFF16233F) : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
