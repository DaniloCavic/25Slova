-- Reči se sortiraju po srpskoj azbuci (А Б В Г Д Ђ ...), a ne po kodu znaka.
ALTER TABLE "Word" ALTER COLUMN "word" TYPE TEXT COLLATE "sr-Cyrl-x-icu";
