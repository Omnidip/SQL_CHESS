#include <stdlib.h>
#include <stdio.h>
#include <sqlite3.h>
#include <string.h>

#define CHAR_TO_INT 48
#define UPPER_TO_LOWER 32
#define LETTER_COORD_INT 96

//read a file into a char array, took from the internet somewhere
char* filetobuf(char *file) {
  FILE *fptr;
  long length;
  char *buf;

  fptr = fopen(file, "rb"); /* Open file for reading */
  if (!fptr) /* Return NULL on failure */
      return NULL;
  fseek(fptr, 0, SEEK_END); /* Seek to the end of the file */
  length = ftell(fptr); /* Find out how many bytes into the file we are */
  buf = (char*)malloc(length+1); /* Allocate a buffer for the entire length of the file and a null terminator */
  fseek(fptr, 0, SEEK_SET); /* Go back to the beginning of the file */
  fread(buf, length, 1, fptr); /* Read the contents of the file in to the buffer */
  fclose(fptr); /* Close the file */
  buf[length] = 0; /* Null terminator */

  return buf; /* Return the buffer */
}

//render buffer for the board
char boardRender[9][9] = {
  ' ','8','7','6','5','4','3','2','1',
  'a','-','-','-','-','-','-','-','-',
  'b','-','-','-','-','-','-','-','-',
  'c','-','-','-','-','-','-','-','-',
  'd','-','-','-','-','-','-','-','-',
  'e','-','-','-','-','-','-','-','-',
  'f','-','-','-','-','-','-','-','-',
  'g','-','-','-','-','-','-','-','-',
  'h','-','-','-','-','-','-','-','-'
};

//copies the board into the render buffer
int printBoard(void *v, int n, char **data, char **colName){
  char *p = data[0];
  char *x = data[1];
  char *y = data[2];
  char *s = data[3];
  boardRender[x[0]-CHAR_TO_INT][y[0]-CHAR_TO_INT] = p[0]-((s[0]-CHAR_TO_INT)?UPPER_TO_LOWER:0);
  return 0;
}

//prompt the player for the correct turn
int promptTurn(void *v, int n, char **data, char **colName){
  char *c = data[0];
  printf("%s's turn: ",(c[0]-CHAR_TO_INT)?"Uppercase":"Lowercase");
}

//reset the board back to default
int resetBoard(sqlite3 *db, int delete){
  char* SQL_init = filetobuf("sql/init.sql");
  char* SQL_newGame = filetobuf("sql/newGame.sql");

  sqlite3_close(db);

  //if we are deleting the board, then do it
  if(delete){
    printf("\nDeleteing Board..\n");
    remove("game.db");
  }

  int status = 0;
  char *err = 0;

  //open the board database
  status = sqlite3_open("game.db",&db);
  if(status != SQLITE_OK){
    fprintf(stderr, "Failed to open database: %s\n", sqlite3_errmsg(db));
    sqlite3_close(db);
    return(1);
  }else{
    printf("Regenerating Board..\n");
  }

  //run the initialization script to set up the tables and triggers
  status = sqlite3_exec(db,SQL_init,NULL,(void*)NULL,&err);
  if(status != SQLITE_OK){
    fprintf(stderr, "Error: %s\n", err);
    sqlite3_free(err);
    return(1);
  }else{
    printf("Placing Pieces..\n");
  }

  //place all of the pieces
  status = sqlite3_exec(db,SQL_newGame,NULL,(void*)NULL,&err);
  if(status != SQLITE_OK){
    fprintf(stderr, "Error: %s\n", err);
    sqlite3_free(err);
    return(1);
  }else{
    printf("Done!\n");
  }

  sqlite3_close(db);

  printf("\n");

  free(SQL_init);
  free(SQL_newGame);

  return(0);
}

int main () {
  const char* SQL_getTurn = filetobuf("sql/getTurn.sql");
  const char* SQL_printBoard = filetobuf("sql/printBoard.sql");

  sqlite3 *db;
  int status;
  char *err = 0;

  //open the board database
  //this continues the last game that was played
  status = sqlite3_open("game.db",&db);
  if(status != SQLITE_OK){
    fprintf(stderr, "Failed to open database: %s\n", sqlite3_errmsg(db));
    sqlite3_close(db);
    return(1);
  }else{
    status = sqlite3_exec(db,"SELECT * FROM GAME;",NULL,(void*)NULL,&err);
    if(status != SQLITE_OK){
      if(resetBoard(db,0)){
        return(1);
      };
    }
    printf("Game Start!\n\n");
  }

  //start the main loop
  char lastInput[5];//user input buffer
  while(1) {

    //print the board to the console
    status = sqlite3_exec(db,SQL_printBoard,printBoard,(void*)NULL,&err);
    if(status != SQLITE_OK){
      fprintf(stderr, "Error: %s\n", err);
      sqlite3_free(err);
      return(1);
    }else{
      int x = 0;
      int y = 0;
      for(y=0; y<9; y++){
        for(x=0; x<9; x++){
          printf("%c ",boardRender[x][y]);
        }
        printf("\n");
      }
    }
    printf("\n");

    //get whose turn it is
    status = sqlite3_exec(db,SQL_getTurn,promptTurn,(void*)NULL,&err);

    //get the users input
    int i=0;
    lastInput[0] = 0;
    while(1){
      char next = getchar();
      if(next==EOF || isspace(next)){
        break;
      }else if(i<5){
        lastInput[i] = next;
      }
      i++;
    }

    //if the user typed reset, then reset the database
    if(!strcmp(lastInput,"reset")){

      printf("\nResetting the board...\n");
      resetBoard(db,1);

      status = sqlite3_open("game.db",&db);
      if(status != SQLITE_OK){
        fprintf(stderr, "Failed to open database: %s\n", sqlite3_errmsg(db));
        sqlite3_close(db);
        return(1);
      }else{
        status = sqlite3_exec(db,"SELECT * FROM GAME;",NULL,(void*)NULL,&err);
        if(status != SQLITE_OK){
          if(resetBoard(db,0)){
            return(1);
          };
        }
        printf("Game Start!\n\n");
      }

    //otherwise, translate their input into a move
    }else{
      //initialize a user move sql query
      char in[] = "\
      INSERT INTO Move (gameID, type, x, y, tox, toy)\
      VALUES (\"GAME\", \"%c\", %d, %d, %d, %d);\
      ";

      if( i == 5 && lastInput[1] > LETTER_COORD_INT && lastInput[3] > LETTER_COORD_INT){ //check for errors that would crash
        //translate the user input into a sql query
        sprintf(in,in,lastInput[0],
          lastInput[1]-LETTER_COORD_INT,
          9-(lastInput[2]-CHAR_TO_INT),
          lastInput[3]-LETTER_COORD_INT,
          9-(lastInput[4]-CHAR_TO_INT)
        );

        //attempt the move
        status = sqlite3_exec(db,in,NULL,(void*)NULL,&err);
        if(status != SQLITE_OK){
          printf("\nInvalid Move! Please try again.\n");
          //fprintf(stderr, "Error: %s\n", err);
          sqlite3_free(err);
        }

      }else{
        printf("\nInvalid Move! Please try again.\n");
      }

    }
    printf("\n");

  }

  sqlite3_close(db);
  return(1);
}
