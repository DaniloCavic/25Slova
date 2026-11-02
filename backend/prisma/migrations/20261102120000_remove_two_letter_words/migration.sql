-- Reči od 2 slova se više ne računaju u igri (najkraća reč je 3 slova).
DELETE FROM "Word" WHERE "length" < 3;
