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
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 0.9,
      children: [
        for (final l in letters)
          Material(
            color: selected == l ? brandBlue : Colors.white,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: enabled ? () => onPick(l) : null,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD5DAE3)),
                ),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Text(
                      showLetter(l, script),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: selected == l ? Colors.white : (enabled ? const Color(0xFF1C2230) : Colors.grey),
                      ),
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
