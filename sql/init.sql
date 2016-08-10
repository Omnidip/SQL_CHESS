CREATE TABLE Force_Failure(
  key BOOLEAN NOT NULL PRIMARY KEY
);

CREATE TABLE Game(
  gameID CHAR(4),
  turn BOOLEAN DEFAULT 0,
  in_check BOOLEAN DEFAULT NULL,
  PRIMARY KEY(gameID)
);

CREATE TABLE Tile (
  gameID CHAR(4) NOT NULL,
  x SMALLINT CHECK(x <= 8 AND x > 0),
  y SMALLINT CHECK(y <= 8 AND y > 0),
  PRIMARY KEY(x,y),
  FOREIGN KEY(gameID) REFERENCES Game(gameID)
);

CREATE TABLE Piece (
  type CHAR(1) CHECK(
    type LIKE "a" OR /*Pawn*/
    type LIKE "r" OR /*Rook*/
    type LIKE "n" OR /*Knight*/
    type LIKE "b" OR /*Bishop*/
    type LIKE "k" OR /*King*/
    type LIKE "q"    /*Queen*/
  ),
  side BOOLEAN NOT NULL,
  x SMALLINT,
  y SMALLINT,
  recentlyMoved BOOLEAN DEFAULT 0,
  hasMoved BOOLEAN DEFAULT 0,
  PRIMARY KEY(x,y),
  FOREIGN KEY(x,y) REFERENCES Tile(x,y)
);

CREATE TABLE Move (
  moveID INTEGER PRIMARY KEY AUTOINCREMENT,
  /*It costs SIGNIFICANTLY more to delete invalid moves than to just leave them in the table and ignore them*/
  /*techincally this means you can only have 64,000 incorrect moves before a crash*/
  gameID CHAR(4) NOT NULL,
  type CHAR(1) NOT NULL,
  x SMALLINT NOT NULL,
  y SMALLINT NOT NULL,
  tox SMALLINT NOT NULL,
  toy SMALLINT NOT NULL,
  valid BOOLEAN DEFAULT 0,
  FOREIGN KEY(x,y) REFERENCES Tile(x,y),
  FOREIGN KEY(tox,toy) REFERENCES Tile(x,y)
);

/*update recentlyMoved*/
CREATE TRIGGER update_recent AFTER UPDATE ON Piece
  FOR EACH ROW /*This limits users to ONE move at a time, stupid En Passant*/
  BEGIN
    UPDATE Piece
    SET recentlyMoved = 0
    WHERE x != NEW.x AND y != NEW.y;
  END;

/*Captureing*/
CREATE TRIGGER capture BEFORE UPDATE ON Piece
  FOR EACH ROW
  WHEN (NOT NEW.side = (
          SELECT P.side
          FROM Piece P
          WHERE P.x = NEW.x AND P.y = NEW.y
        )
       )
  BEGIN
    DELETE FROM Piece
    WHERE x = NEW.x AND y = NEW.y;
  END;

/*En Passant*/
CREATE TRIGGER en_passant BEFORE UPDATE ON Piece
  FOR EACH ROW
  WHEN (NEW.type LIKE "a" AND NOT NEW.side = (
          SELECT P.side
          FROM Piece P
          WHERE P.type LIKE "a" AND P.recentlyMoved AND P.x = NEW.x AND
            (
              (P.y = NEW.y + 1 AND NEW.side = 0) OR
              (P.y = NEW.y - 1 AND NEW.side = 1)
            )
        )
       )
  BEGIN
    DELETE FROM Piece
    WHERE type LIKE "a" AND recentlyMoved AND x = NEW.x AND
      (
        (y = NEW.y + 1 AND NEW.side = 0) OR
        (y = NEW.y - 1 AND NEW.side = 1)
      );
  END;

/*Promotion*/
CREATE TRIGGER promote AFTER UPDATE ON Piece
  FOR EACH ROW
  WHEN (NEW.type LIKE "a" AND
        (
          NEW.y = 1 OR
          NEW.y = 8
        )
       )
  BEGIN
    UPDATE Piece
    SET type = "q"
    WHERE x = NEW.x AND y = NEW.y;
  END;

/*check*/
CREATE TRIGGER check_condition BEFORE UPDATE ON Piece
  FOR EACH ROW
  WHEN(
    NEW.type LIKE "k" AND
    NEW.side = (
        SELECT G.turn
        FROM Game G
        WHERE G.gameID LIKE "GAME"
    ) AND
    EXISTS(
      SELECT P.x,P.y
      FROM Piece P
      WHERE P.side != NEW.side AND (
        (
          /*PAWN*/
          P.type LIKE "a" AND
          (
            (
              P.side = 1 AND
              P.y = NEW.y - 1 AND
              (P.x = NEW.x + 1 OR P.x = NEW.x - 1)
            ) OR (
              P.side = 0 AND
              P.y = NEW.y + 1 AND
              (P.x = NEW.x + 1 OR P.x = NEW.x - 1)
            )
          )
        ) OR (
          /*ROOK*/
          (P.type LIKE "r" OR P.type LIKE "q") AND
          (
            (
              P.x != NEW.x AND P.y = NEW.y AND (
                (
                  P.x > NEW.x AND NOT EXISTS(
                    SELECT PI.x,PI.y
                    FROM Piece PI
                    WHERE PI.y = NEW.y AND PI.x < P.x AND PI.x > NEW.x
                  )
                ) OR (
                  P.x < x AND NOT EXISTS(
                    SELECT PI.x,PI.y
                    FROM Piece PI
                    WHERE PI.y = NEW.y AND PI.x > P.x AND PI.x < NEW.x
                  )
                )
              )
            ) OR (
              P.x = x AND P.y != NEW.y AND (
                (
                  P.y > y AND NOT EXISTS(
                    SELECT PI.x,PI.y
                    FROM Piece PI
                    WHERE PI.x = NEW.x AND PI.y < P.y AND PI.y > NEW.y
                  )
                ) OR (
                  P.y < NEW.y AND NOT EXISTS(
                    SELECT PI.x,PI.y
                    FROM Piece PI
                    WHERE PI.x = NEW.x AND PI.y > P.y AND PI.y < NEW.y
                  )
                )
              )
            )
          )
        ) OR (
          /*BISHOP*/
          (P.type LIKE "b" OR P.type LIKE "q") AND
          (
            (
              P.x - NEW.x = P.y - NEW.y AND (
                (
                  P.x < NEW.x AND P.y < NEW.y AND NOT EXISTS(
                    SELECT PI.x,PI.y
                    FROM Piece PI
                    WHERE PI.x - NEW.x = PI.y - NEW.y AND
                      PI.x < NEW.x AND PI.y < NEW.y AND
                      PI.x > P.x AND PI.y > P.y
                  )
                ) OR (
                  P.x > NEW.x AND P.y > NEW.y AND NOT EXISTS(
                    SELECT PI.x,PI.y
                    FROM Piece PI
                    WHERE PI.x - NEW.x = PI.y - NEW.y AND
                      PI.x > NEW.x AND PI.y > NEW.y AND
                      PI.x < P.x AND PI.y < P.y
                  )
                )
              )
            ) OR (
              P.x - NEW.x = -(P.y - NEW.y) AND (
                (
                  P.x < NEW.x AND P.y > NEW.y AND NOT EXISTS(
                    SELECT PI.x,PI.y
                    FROM Piece PI
                    WHERE PI.x - NEW.x = -(PI.y - NEW.y) AND
                      PI.x < NEW.x AND PI.y > NEW.y AND
                      PI.x > P.x AND PI.y < P.y
                  )
                ) OR (
                  P.x > NEW.x AND P.y < NEW.y AND NOT EXISTS(
                    SELECT PI.x,PI.y
                    FROM Piece PI
                    WHERE PI.x - NEW.x = -(PI.y - NEW.y) AND
                      PI.x > NEW.x AND PI.y < NEW.y AND
                      PI.x < P.x AND PI.y > P.y
                  )
                )
              )
            )
          )
        ) OR (
          /*KNIGHT*/
          P.type LIKE "n" AND (
            (P.x = NEW.x + 1 AND P.y = NEW.y + 2) OR
            (P.x = NEW.x + 2 AND P.y = NEW.y + 1) OR
            (P.x = NEW.x - 1 AND P.y = NEW.y + 2) OR
            (P.x = NEW.x - 2 AND P.y = NEW.y + 1) OR
            (P.x = NEW.x + 1 AND P.y = NEW.y - 2) OR
            (P.x = NEW.x + 2 AND P.y = NEW.y - 1) OR
            (P.x = NEW.x - 1 AND P.y = NEW.y - 2) OR
            (P.x = NEW.x - 2 AND P.y = NEW.y - 1)
          )
        ) OR (
          /*KING*/
          P.type LIKE "k" AND (
            (P.x = NEW.x + 1 AND P.y = NEW.y + 1) OR
            (P.x = NEW.x + 1 AND P.y = NEW.y - 1) OR
            (P.x = NEW.x - 1 AND P.y = NEW.y + 1) OR
            (P.x = NEW.x - 1 AND P.y = NEW.y - 1) OR
            (P.x = NEW.x + 1 AND P.y = NEW.y    ) OR
            (P.x = NEW.x - 1 AND P.y = NEW.y    ) OR
            (P.x = NEW.x     AND P.y = NEW.y + 1) OR
            (P.x = NEW.x     AND P.y = NEW.y - 1)
          )
        )
      )
    )
  )
  BEGIN
    INSERT INTO Force_Failure(key)
    VALUES (NULL);
  END;

/*-------------------------*/
/*-----UPPERCASE PAWNS-----*/
/*-------------------------*/

/*Uppercase pawn single space movement*/
CREATE TRIGGER pawn_basic_upper AFTER INSERT ON Move
  FOR EACH ROW
  WHEN (NEW.type LIKE "a" AND 1 = (
          SELECT P.side
          FROM Piece P
          WHERE P.type LIKE NEW.type AND P.x = NEW.x AND P.y = NEW.y
        ) AND
        NEW.toy = NEW.y + 1 AND
        NEW.tox = NEW.x AND
        NEW.toy <= 8 AND
        NOT EXISTS (
          SELECT P.x,P.y
          FROM Piece P
          WHERE P.x = NEW.tox AND P.y = NEW.toy
        )
       )
  BEGIN
    UPDATE Move
    SET valid = 1
    WHERE moveID = NEW.moveID;
  END;

/*Uppercase pawn double space movement*/
CREATE TRIGGER pawn_adv_upper AFTER INSERT ON Move
  FOR EACH ROW
  WHEN (NEW.type LIKE "a" AND 1 = (
          SELECT P.side
          FROM Piece P
          WHERE P.type LIKE NEW.type AND P.x = NEW.x AND P.y = NEW.y
        ) AND
        NEW.y = 2 AND
        NEW.toy = NEW.y + 2 AND
        NEW.tox = NEW.x AND
        NOT EXISTS (
          SELECT P.x,P.y
          FROM Piece P
          WHERE P.x = NEW.tox AND (P.y = NEW.toy OR P.y = NEW.toy - 1)
        )
       )
  BEGIN
    UPDATE Move
    SET valid = 1
    WHERE moveID = NEW.moveID;
  END;

/*Uppercase pawn cross capture movement*/
CREATE TRIGGER pawn_capture_upper AFTER INSERT ON Move
  FOR EACH ROW
  WHEN (NEW.type LIKE "a" AND 1 = (
          SELECT P.side
          FROM Piece P
          WHERE P.type LIKE NEW.type AND P.x = NEW.x AND P.y = NEW.y
        ) AND (
          (
            NEW.toy = NEW.y + 1 AND
            NEW.tox = NEW.x + 1
          ) OR (
            NEW.toy = NEW.y + 1 AND
            NEW.tox = NEW.x - 1
          )
        ) AND
        NEW.tox > 0 AND
        NEW.tox <=8 AND
        NEW.toy <=8 AND (
          EXISTS(/*Regular capture*/
            SELECT P.x,P.y
            FROM Piece P
            WHERE P.x = NEW.tox AND P.y = NEW.toy
          ) OR
          EXISTS(/*En Passant*/
            SELECT P.x,P.y
            FROM Piece P
            WHERE P.type LIKE "a" AND P.recentlyMoved AND P.x = NEW.tox AND
              P.y = NEW.toy-1 AND P.y = 5 AND P.side != (
                SELECT PI.side
                FROM Piece PI
                WHERE PI.x = NEW.x AND PI.y = NEW.y
              )
          )
        )
      )
  BEGIN
    UPDATE Move
    SET valid = 1
    WHERE moveID = NEW.moveID;
  END;

/*-------------------------*/
/*-----LOWERCASE PAWNS-----*/
/*-------------------------*/

/*Lowercase pawn single space movement*/
CREATE TRIGGER pawn_basic_lower AFTER INSERT ON Move
  FOR EACH ROW
  WHEN (NEW.type LIKE "a" AND 0 = (
          SELECT P.side
          FROM Piece P
          WHERE P.type LIKE NEW.type AND P.x = NEW.x AND P.y = NEW.y
        ) AND
        NEW.toy = NEW.y - 1 AND
        NEW.tox = NEW.x AND
        NEW.toy > 0 AND
        NOT EXISTS (
          SELECT P.x,P.y
          FROM Piece P
          WHERE P.x = NEW.tox AND P.y = NEW.toy
        )
       )
  BEGIN
    UPDATE Move
    SET valid = 1
    WHERE moveID = NEW.moveID;
  END;

/*Lowercase pawn double space movement*/
CREATE TRIGGER pawn_adv_lower AFTER INSERT ON Move
  FOR EACH ROW
  WHEN (NEW.type LIKE "a" AND 0 = (
          SELECT P.side
          FROM Piece P
          WHERE P.type LIKE NEW.type AND P.x = NEW.x AND P.y = NEW.y
        ) AND
        NEW.y = 7 AND
        NEW.toy = NEW.y - 2 AND
        NEW.tox = NEW.x AND
        NOT EXISTS (
          SELECT P.x,P.y
          FROM Piece P
          WHERE P.x = NEW.tox AND (P.y = NEW.toy OR P.y = NEW.toy + 1)
        )
       )
  BEGIN
    UPDATE Move
    SET valid = 1
    WHERE moveID = NEW.moveID;
  END;

/*Lowercase pawn cross capture movement*/
CREATE TRIGGER pawn_capture_lower AFTER INSERT ON Move
  FOR EACH ROW
  WHEN (NEW.type LIKE "a" AND 0 = (
          SELECT P.side
          FROM Piece P
          WHERE P.type LIKE NEW.type AND P.x = NEW.x AND P.y = NEW.y
        ) AND (
          (
            NEW.toy = NEW.y - 1 AND
            NEW.tox = NEW.x + 1
          ) OR (
            NEW.toy = NEW.y - 1 AND
            NEW.tox = NEW.x - 1
          )
        ) AND
        NEW.tox > 0 AND
        NEW.tox <=8 AND
        NEW.toy > 0 AND (
          EXISTS(/*Regular capture*/
            SELECT P.x,P.y
            FROM Piece P
            WHERE P.x = NEW.tox AND P.y = NEW.toy
          ) OR
          EXISTS(/*En Passant*/
            SELECT P.x,P.y
            FROM Piece P
            WHERE P.type LIKE "a" AND P.recentlyMoved AND P.x = NEW.tox AND
              P.y = NEW.toy+1 AND P.y = 4 AND P.side != (
                SELECT PI.side
                FROM Piece PI
                WHERE PI.x = NEW.x AND PI.y = NEW.y
              )
          )
        )
      )
  BEGIN
    UPDATE Move
    SET valid = 1
    WHERE moveID = NEW.moveID;
  END;

/*-------------------------*/
/*------ROOKS + QUEEN------*/
/*-------------------------*/

CREATE TRIGGER rook AFTER INSERT ON Move
  FOR EACH ROW
  WHEN ((NEW.type LIKE "r" OR NEW.type LIKE "q") AND
        NEW.tox > 0 AND
        NEW.tox <= 8 AND
        NEW.toy > 0 AND
        NEW.toy <= 8 AND (
          (
            NEW.tox != NEW.x AND NEW.toy = NEW.y AND (
              (
                NEW.tox > NEW.x AND NOT EXISTS(
                  SELECT P.x,P.y
                  FROM Piece P
                  WHERE P.y = NEW.y AND P.x > NEW.x AND P.x < NEW.tox
                )
              ) OR (
                NEW.tox < NEW.x AND NOT EXISTS(
                  SELECT P.x,P.y
                  FROM Piece P
                  WHERE P.y = NEW.y AND P.x < NEW.x AND P.x > NEW.tox
                )
              )
            )
          ) OR (
            NEW.tox = NEW.x AND NEW.toy != NEW.y AND (
              (
                NEW.toy > NEW.y AND NOT EXISTS(
                  SELECT P.x,P.y
                  FROM Piece P
                  WHERE P.x = NEW.x AND P.y > NEW.y AND P.y < NEW.toy
                )
              ) OR (
                NEW.toy < NEW.y AND NOT EXISTS(
                  SELECT P.x,P.y
                  FROM Piece P
                  WHERE P.x = NEW.x AND P.y < NEW.y AND P.y > NEW.toy
                )
              )
            )
          )
        )
       )
  BEGIN
    UPDATE Move
    SET valid = 1
    WHERE moveID = NEW.moveID;
  END;

/*-------------------------*/
/*-----BISHOP + QUEEN------*/
/*-------------------------*/

CREATE TRIGGER bishop AFTER INSERT ON Move
  FOR EACH ROW
  WHEN ((NEW.type LIKE "b" OR NEW.type LIKE "q") AND
        NEW.tox > 0 AND
        NEW.tox <= 8 AND
        NEW.toy > 0 AND
        NEW.toy <= 8 AND (
          (
            NEW.tox - NEW.x = NEW.toy - NEW.y AND (
              (
                NEW.tox < NEW.x AND NEW.toy < NEW.y AND NOT EXISTS(
                  SELECT P.x,P.y
                  FROM Piece P
                  WHERE P.x - NEW.x = P.y - NEW.y AND
                    P.x < NEW.x AND P.y < NEW.y AND
                    P.x > NEW.tox AND P.y > NEW.toy
                )
              ) OR (
                NEW.tox > NEW.x AND NEW.toy > NEW.y AND NOT EXISTS(
                  SELECT P.x,P.y
                  FROM Piece P
                  WHERE P.x - NEW.x = P.y - NEW.y AND
                    P.x > NEW.x AND P.y > NEW.y AND
                    P.x < NEW.tox AND P.y < NEW.toy
                )
              )
            )
          ) OR (
            NEW.tox - NEW.x = -(NEW.toy - NEW.y) AND (
              (
                NEW.tox < NEW.x AND NEW.toy > NEW.y AND NOT EXISTS(
                  SELECT P.x,P.y
                  FROM Piece P
                  WHERE P.x - NEW.x = -(P.y - NEW.y) AND
                    P.x < NEW.x AND P.y > NEW.y AND
                    P.x > NEW.tox AND P.y < NEW.toy
                )
              ) OR (
                NEW.tox > NEW.x AND NEW.toy < NEW.y AND NOT EXISTS(
                  SELECT P.x,P.y
                  FROM Piece P
                  WHERE P.x - NEW.x = -(P.y - NEW.y) AND
                    P.x > NEW.x AND P.y < NEW.y AND
                    P.x < NEW.tox AND P.y > NEW.toy
                )
              )
            )
          )
        )
       )
  BEGIN
    UPDATE Move
    SET valid = 1
    WHERE moveID = NEW.moveID;
  END;


/*-------------------------*/
/*---------KNIGHT----------*/
/*-------------------------*/

CREATE TRIGGER knight AFTER INSERT ON Move
  FOR EACH ROW
  WHEN (NEW.type LIKE "n" AND
        NEW.tox > 0 AND
        NEW.tox <= 8 AND
        NEW.toy > 0 AND
        NEW.toy <= 8 AND (
          (NEW.tox = NEW.x + 1 AND NEW.toy = NEW.y + 2) OR
          (NEW.tox = NEW.x + 2 AND NEW.toy = NEW.y + 1) OR
          (NEW.tox = NEW.x - 1 AND NEW.toy = NEW.y + 2) OR
          (NEW.tox = NEW.x - 2 AND NEW.toy = NEW.y + 1) OR
          (NEW.tox = NEW.x + 1 AND NEW.toy = NEW.y - 2) OR
          (NEW.tox = NEW.x + 2 AND NEW.toy = NEW.y - 1) OR
          (NEW.tox = NEW.x - 1 AND NEW.toy = NEW.y - 2) OR
          (NEW.tox = NEW.x - 2 AND NEW.toy = NEW.y - 1)
        )
       )
  BEGIN
    UPDATE Move
    SET valid = 1
    WHERE moveID = NEW.moveID;
  END;


/*-------------------------*/
/*----------KING-----------*/
/*-------------------------*/

CREATE TRIGGER king AFTER INSERT ON Move
  FOR EACH ROW
  WHEN (NEW.type LIKE "k" AND
        NEW.tox > 0 AND
        NEW.tox <= 8 AND
        NEW.toy > 0 AND
        NEW.toy <= 8 AND (
          (NEW.tox = NEW.x + 1 AND NEW.toy = NEW.y + 1) OR
          (NEW.tox = NEW.x + 1 AND NEW.toy = NEW.y - 1) OR
          (NEW.tox = NEW.x - 1 AND NEW.toy = NEW.y + 1) OR
          (NEW.tox = NEW.x - 1 AND NEW.toy = NEW.y - 1) OR
          (NEW.tox = NEW.x + 1 AND NEW.toy = NEW.y    ) OR
          (NEW.tox = NEW.x - 1 AND NEW.toy = NEW.y    ) OR
          (NEW.tox = NEW.x     AND NEW.toy = NEW.y + 1) OR
          (NEW.tox = NEW.x     AND NEW.toy = NEW.y - 1) OR
          (
            EXISTS (
              SELECT P.side
              FROM Piece P
              WHERE P.x = NEW.x AND P.y = NEW.y AND NOT P.hasMoved
            ) AND
            NEW.toy = NEW.y AND
            NEW.tox = NEW.x + 2 AND
            EXISTS (
              SELECT P.side
              FROM Piece P
              WHERE P.type LIKE "r" AND P.x = NEW.x + 3 AND P.y = NEW.y AND NOT P.hasMoved
            ) AND
            NOT EXISTS (
              SELECT P.x,P.y
              FROM Piece P
              WHERE P.side != (
                  SELECT PI.side
                  FROM Piece PI
                  WHERE PI.x = NEW.x AND PI.y = NEW.y
                ) AND (
                  (
                    P.y = NEW.y AND
                    (P.x = NEW.x + 1 OR P.x = NEW.x + 2)
                  ) OR (
                    /*PAWN*/
                    P.type LIKE "a" AND
                    (
                      (
                        P.side = 1 AND
                        P.y = NEW.y - 1 AND
                        (P.x = NEW.x + 1 + 1 OR P.x = NEW.x + 1 - 1)
                      ) OR (
                        P.side = 0 AND
                        P.y = NEW.y + 1 AND
                        (P.x = NEW.x + 1 + 1 OR P.x = NEW.x + 1 - 1)
                      )
                    )
                  ) OR (
                    /*ROOK*/
                    (P.type LIKE "r" OR P.type LIKE "q") AND
                    (
                      (
                        P.x != NEW.x + 1 AND P.y = NEW.y AND (
                          (
                            P.x > NEW.x + 1 AND NOT EXISTS (
                              SELECT PI.x,PI.y
                              FROM Piece PI
                              WHERE PI.y = NEW.y AND PI.x < P.x AND PI.x > NEW.x + 1
                            )
                          ) OR (
                            P.x < x AND NOT EXISTS(
                              SELECT PI.x,PI.y
                              FROM Piece PI
                              WHERE PI.y = NEW.y AND PI.x > P.x AND PI.x < NEW.x + 1
                            )
                          )
                        )
                      ) OR (
                        P.x = x AND P.y != NEW.y AND (
                          (
                            P.y > y AND NOT EXISTS (
                              SELECT PI.x,PI.y
                              FROM Piece PI
                              WHERE PI.x = NEW.x + 1 AND PI.y < P.y AND PI.y > NEW.y
                            )
                          ) OR (
                            P.y < NEW.y AND NOT EXISTS (
                              SELECT PI.x,PI.y
                              FROM Piece PI
                              WHERE PI.x = NEW.x + 1 AND PI.y > P.y AND PI.y < NEW.y
                            )
                          )
                        )
                      )
                    )
                  ) OR (
                    /*BISHOP*/
                    (P.type LIKE "b" OR P.type LIKE "q") AND
                    (
                      (
                        P.x - NEW.x + 1 = P.y - NEW.y AND (
                          (
                            P.x < NEW.x + 1 AND P.y < NEW.y AND NOT EXISTS(
                              SELECT PI.x,PI.y
                              FROM Piece PI
                              WHERE PI.x - NEW.x + 1 = PI.y - NEW.y AND
                                PI.x < NEW.x + 1 AND PI.y < NEW.y AND
                                PI.x > P.x AND PI.y > P.y
                            )
                          ) OR (
                            P.x > NEW.x + 1 AND P.y > NEW.y AND NOT EXISTS(
                              SELECT PI.x,PI.y
                              FROM Piece PI
                              WHERE PI.x - NEW.x + 1 = PI.y - NEW.y AND
                                PI.x > NEW.x + 1 AND PI.y > NEW.y AND
                                PI.x < P.x AND PI.y < P.y
                            )
                          )
                        )
                      ) OR (
                        P.x - NEW.x + 1 = -(P.y - NEW.y) AND (
                          (
                            P.x < NEW.x + 1 AND P.y > NEW.y AND NOT EXISTS(
                              SELECT PI.x,PI.y
                              FROM Piece PI
                              WHERE PI.x - NEW.x + 1 = -(PI.y - NEW.y) AND
                                PI.x < NEW.x + 1 AND PI.y > NEW.y AND
                                PI.x > P.x AND PI.y < P.y
                            )
                          ) OR (
                            P.x > NEW.x + 1 AND P.y < NEW.y AND NOT EXISTS(
                              SELECT PI.x,PI.y
                              FROM Piece PI
                              WHERE PI.x - NEW.x + 1 = -(PI.y - NEW.y) AND
                                PI.x > NEW.x + 1 AND PI.y < NEW.y AND
                                PI.x < P.x AND PI.y > P.y
                            )
                          )
                        )
                      )
                    )
                  ) OR (
                    /*KNIGHT*/
                    P.type LIKE "n" AND (
                      (P.x = NEW.x + 1 + 1 AND P.y = NEW.y + 2) OR
                      (P.x = NEW.x + 1 + 2 AND P.y = NEW.y + 1) OR
                      (P.x = NEW.x + 1 - 1 AND P.y = NEW.y + 2) OR
                      (P.x = NEW.x + 1 - 2 AND P.y = NEW.y + 1) OR
                      (P.x = NEW.x + 1 + 1 AND P.y = NEW.y - 2) OR
                      (P.x = NEW.x + 1 + 2 AND P.y = NEW.y - 1) OR
                      (P.x = NEW.x + 1 - 1 AND P.y = NEW.y - 2) OR
                      (P.x = NEW.x + 1 - 2 AND P.y = NEW.y - 1)
                    )
                  ) OR (
                    /*KING*/
                    P.type LIKE "k" AND (
                      (P.x = NEW.x + 1 + 1 AND P.y = NEW.y + 1) OR
                      (P.x = NEW.x + 1 + 1 AND P.y = NEW.y - 1) OR
                      (P.x = NEW.x + 1 - 1 AND P.y = NEW.y + 1) OR
                      (P.x = NEW.x + 1 - 1 AND P.y = NEW.y - 1) OR
                      (P.x = NEW.x + 1 + 1 AND P.y = NEW.y    ) OR
                      (P.x = NEW.x + 1 - 1 AND P.y = NEW.y    ) OR
                      (P.x = NEW.x + 1     AND P.y = NEW.y + 1) OR
                      (P.x = NEW.x + 1     AND P.y = NEW.y - 1)
                    )
                  )
                )
            )
          )
        )
       )
  BEGIN
    UPDATE Move
    SET valid = 1
    WHERE moveID = NEW.moveID;
  END;

/*-------------------------*/
/*-----POST VALIDATION-----*/
/*-------------------------*/

CREATE TRIGGER do_move AFTER UPDATE ON Move
  FOR EACH ROW
  WHEN (NEW.valid = 1)
  BEGIN
    UPDATE Piece
    SET x = NEW.tox , y = NEW.toy, recentlyMoved = 1, hasMoved = 1
    WHERE x = NEW.x AND y = NEW.y AND side = (
        SELECT G.turn
        FROM Game G
        WHERE G.gameID LIKE "GAME"
      );

    UPDATE Game
    SET turn = NOT turn
    WHERE gameID LIKE "GAME" AND turn = (
        SELECT P.side
        FROM Piece P
        WHERE x = NEW.tox AND y = NEW.toy
      );

    DELETE FROM Move
    WHERE moveID = NEW.moveID;
  END;

CREATE TRIGGER trigger_castle BEFORE DELETE ON Move
  FOR EACH ROW
  WHEN (OLD.valid = 1 AND OLD.type = "k" AND OLD.tox = OLD.x + 2)
  BEGIN
    UPDATE Piece
    SET x = OLD.x + 1, hasMoved = 1
    WHERE type LIKE "r" AND y = OLD.y AND x = OLD.x + 3 AND NOT hasMoved;
  END;
