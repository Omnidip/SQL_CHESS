SELECT IFNULL(p.type,"-"), t.x, t.y, IFNULL(p.side,0)
FROM Tile t NATURAL LEFT OUTER JOIN Piece p;
