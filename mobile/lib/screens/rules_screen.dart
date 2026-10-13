import 'package:flutter/material.dart';
import '../widgets/common.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sections = <(String, String)>[
      (
        'Cilj',
        'Svaki igrač ima svoju tablu 5 × 5. Igrači naizmenično biraju slovo i postavljaju ga na svoju tablu, a protivnik isto slovo postavlja na svoju. Kada se table popune, broje se reči.'
      ),
      (
        'Početak',
        'Partija počinje sa 1, 3 ili 5 nasumičnih slova na nasumičnim poljima (ista za oba igrača). Tip partije je nasumičan: 1 slovo — 30 s po potezu, 3 slova — 45 s, 5 slova — 60 s.'
      ),
      (
        'Potez',
        'Igrač na potezu bira bilo koje slovo srpske azbuke i slobodno polje. Protivnik zatim isto slovo postavlja na svoju tablu i bira sledeće slovo. Postavljeno slovo se ne može menjati. Lj, Nj i Dž su jedno slovo i zauzimaju jedno polje.'
      ),
      (
        'Vreme i životi',
        'Svaki igrač ima 3 života. Ako ne odigraš na vreme, gubiš život i odbrojavanje kreće ponovo. Gubitak sva 3 života znači poraz. Vreme teče i kad nemaš internet.'
      ),
      (
        'Bodovanje',
        'Proverava se 5 redova, 5 kolona i 2 dijagonale, u oba smera. Svaki niz donosi onoliko poena koliko slova ima najduža reč u njemu (2–5). Kraće reči unutar duže se ne sabiraju. Najviše 60 poena po tabli.'
      ),
      (
        'Reči',
        'Važe reči iz rečnika igre: imenice i pridevi u nominativu jednine ili množine, kao i geografski nazivi. Ne važe lična imena, skraćenice, brendovi i strane reči.'
      ),
      ('Pobednik', 'Pobeđuje igrač sa više poena; ako su poeni isti — onaj sa više reči; ako je i to isto — nerešeno.'),
      (
        'Saldo',
        'Pobednik dobija (poeni × broj reči) ÷ 7,2 poena na ukupni, nedeljni, mesečni i godišnji saldo, na dve decimale (npr. 36,11). Poraz oduzima 10 poena. Nerešeno ne menja saldo.'
      ),
      (
        'Tokeni',
        'Partija košta 10 tokena (naplaćuje se kad protivnik bude pronađen). Svakog dana dobijaš 30 tokena pri prvoj prijavi.'
      ),
      (
        'Medalje',
        'Prva tri mesta na nedeljnoj, mesečnoj i godišnjoj rang-listi dobijaju zlatnu, srebrnu i bronzanu medalju koja ostaje na profilu. Pri istom broju poena ispred je igrač koji je do njih stigao ranije.'
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Pravila igre')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (t, body) in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(height: 1.4)),
              ]),
            ),
          const Text('Primer: OROGT donosi 3 poena (ROG), a GORTS 5 poena jer se unazad čita STROG.',
              style: TextStyle(fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          const Text('Leveli', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Level zavisi od ukupnog broja poena:', style: TextStyle(height: 1.4)),
          const SizedBox(height: 8),
          const LevelTable(),
        ],
      ),
    );
  }
}
