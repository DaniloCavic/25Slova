/// Srpska azbuka. Interno (i na serveru) sva slova su ćirilica;
/// latinica je samo način prikaza koji igrač bira u podešavanjima.
const cyrillicAlphabet = [
  'А',
  'Б',
  'В',
  'Г',
  'Д',
  'Ђ',
  'Е',
  'Ж',
  'З',
  'И',
  'Ј',
  'К',
  'Л',
  'Љ',
  'М',
  'Н',
  'Њ',
  'О',
  'П',
  'Р',
  'С',
  'Т',
  'Ћ',
  'У',
  'Ф',
  'Х',
  'Ц',
  'Ч',
  'Џ',
  'Ш',
];

const latinByCyrillic = {
  'А': 'A',
  'Б': 'B',
  'В': 'V',
  'Г': 'G',
  'Д': 'D',
  'Ђ': 'Đ',
  'Е': 'E',
  'Ж': 'Ž',
  'З': 'Z',
  'И': 'I',
  'Ј': 'J',
  'К': 'K',
  'Л': 'L',
  'Љ': 'Lj',
  'М': 'M',
  'Н': 'N',
  'Њ': 'Nj',
  'О': 'O',
  'П': 'P',
  'Р': 'R',
  'С': 'S',
  'Т': 'T',
  'Ћ': 'Ć',
  'У': 'U',
  'Ф': 'F',
  'Х': 'H',
  'Ц': 'C',
  'Ч': 'Č',
  'Џ': 'Dž',
  'Ш': 'Š',
};

/// Redosled latinične abecede (A B C Č Ć D Dž Đ ...).
const latinOrder = [
  'А',
  'Б',
  'Ц',
  'Ч',
  'Ћ',
  'Д',
  'Џ',
  'Ђ',
  'Е',
  'Ф',
  'Г',
  'Х',
  'И',
  'Ј',
  'К',
  'Л',
  'Љ',
  'М',
  'Н',
  'Њ',
  'О',
  'П',
  'Р',
  'С',
  'Ш',
  'Т',
  'У',
  'В',
  'З',
  'Ж',
];

enum Script { latin, cyrillic }

String showLetter(String? cyr, Script script) {
  if (cyr == null) return '';
  return script == Script.latin ? (latinByCyrillic[cyr] ?? cyr) : cyr;
}

String showWord(String? cyr, Script script) {
  if (cyr == null) return '';
  if (script == Script.cyrillic) return cyr;
  return cyr.split('').map((c) => latinByCyrillic[c] ?? c).join().toUpperCase();
}

List<String> pickerOrder(Script script) => script == Script.latin ? latinOrder : cyrillicAlphabet;
