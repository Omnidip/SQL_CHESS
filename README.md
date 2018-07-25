# SQL_CHESS
Chess implemented is SQLite

# How to build
The current makefile only supports make + gcc with Msys2. If you are using Msys, simply run "make all". but if you want to use a different compiler the only GCC 
flags you need are "I." "L." and "lsqlite3". You will need to build main in src (the main sql_chess program). 

# How to use
To reset the board type "reset" at any turn.
To make a move you type the letter of the piece you want, followed by its current position then the position you want it to go (all lowercase). 
Eg: aa7a5 will move a pawn at a7 to a5.
