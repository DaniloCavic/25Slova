import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slova25/letters.dart';
import 'package:slova25/widgets/board.dart';
import 'package:slova25/widgets/letter_picker.dart';

void main() {
  test('azbuka ima 30 slova, Lj/Nj/Dž su jedno slovo', () {
    expect(cyrillicAlphabet.length, 30);
    expect(latinOrder.toSet(), cyrillicAlphabet.toSet());
    expect(showLetter('Љ', Script.latin), 'Lj');
    expect(showLetter('Џ', Script.latin), 'Dž');
    expect(showLetter('Џ', Script.cyrillic), 'Џ');
    expect(showWord('ЊИВА', Script.latin), 'NJIVA');
  });

  testWidgets('tabla prikazuje slova i prijavljuje dodir na prazno polje', (tester) async {
    int? tapped;
    final board = List<String?>.filled(25, null)..[0] = 'Љ';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BoardGrid(board: board, script: Script.latin, initialCells: const {0}, onTap: (i) => tapped = i),
      ),
    ));
    expect(find.text('Lj'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Polje 1: Lj'));
    expect(tapped, isNull, reason: 'zauzeto polje se ne može izabrati');
    await tester.tap(find.bySemanticsLabel('Polje 7'));
    expect(tapped, 6);
  });

  testWidgets('izbor slova nudi svih 30 slova', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LetterPicker(script: Script.latin, selected: null, onPick: (l) => picked = l)),
    ));
    expect(find.byType(InkWell), findsNWidgets(30));
    await tester.tap(find.text('Dž'));
    expect(picked, 'Џ');
  });
}
