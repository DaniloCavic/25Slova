-- Poeni se od sada čuvaju u stotim delovima (dve decimale): 36,11 poena = 3611.
UPDATE "User" SET "totalPoints" = "totalPoints" * 100;
UPDATE "PointsEvent" SET "delta" = "delta" * 100;
UPDATE "MatchPlayer" SET "pointsDelta" = "pointsDelta" * 100;
UPDATE "Medal" SET "points" = "points" * 100;
