#include <stdlib.h>
#include <stdio.h>
#include <sqlite3.h>

#define CHAR_TO_INT 48
#define UPPER_TO_LOWER 32
#define LETTER_COORD_INT 96

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

int printBoard(void *v, int n, char **data, char **colName){
  char *p = data[0];
  char *x = data[1];
  char *y = data[2];
  char *s = data[3];
  boardRender[x[0]-CHAR_TO_INT][y[0]-CHAR_TO_INT] = p[0]-((s[0]-CHAR_TO_INT)?UPPER_TO_LOWER:0);
  return 0;
}

int promptTurn(void *v, int n, char **data, char **colName){
  char *c = data[0];
  printf("%s's turn: ",(c[0]-CHAR_TO_INT)?"Uppercase":"Lowercase");
}

int resetBoard(sqlite3 *db, int delete){
  char* SQL_init = filetobuf("sql/init.sql");
  char* SQL_newGame = filetobuf("sql/newGame.sql");

  if(delete){
    sqlite3_close(db);
    printf("\nDeleteing Board..\n");
    remove("game.db");
  }

  int status = 0;
  char *err = 0;

  status = sqlite3_open("game.db",&db);
  if(status != SQLITE_OK){
    fprintf(stderr, "Failed to open database: %s\n", sqlite3_errmsg(db));
    sqlite3_close(db);
    return(1);
  }else{
    printf("Regenerating Board..\n");
  }

  status = sqlite3_exec(db,SQL_init,NULL,(void*)NULL,&err);
  if(status != SQLITE_OK){
    fprintf(stderr, "Error: %s\n", err);
    sqlite3_free(err);
    return(1);
  }else{
    printf("Placing Pieces..\n");
  }

  status = sqlite3_exec(db,SQL_newGame,NULL,(void*)NULL,&err);
  if(status != SQLITE_OK){
    fprintf(stderr, "Error: %s\n", err);
    sqlite3_free(err);
    return(1);
  }else{
    printf("Done!\n");
  }

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

  char lastInput[5];
  while(1) {

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

    status = sqlite3_exec(db,SQL_getTurn,promptTurn,(void*)NULL,&err);

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

    char in[] = "\
    INSERT INTO Move (gameID, type, x, y, tox, toy)\
    VALUES (\"GAME\", \"%c\", %d, %d, %d, %d);\
    ";
    sprintf(in,in,lastInput[0],
      lastInput[1]-LETTER_COORD_INT,
      9-(lastInput[2]-CHAR_TO_INT),
      lastInput[3]-LETTER_COORD_INT,
      9-(lastInput[4]-CHAR_TO_INT)
    );

    //printf(in);

    status = sqlite3_exec(db,in,NULL,(void*)NULL,&err);
    if(status != SQLITE_OK){
      printf("\nInvalid Move! Please try again.\n");
      //fprintf(stderr, "Error: %s\n", err);
      sqlite3_free(err);
    }
    printf("\n");



  }

  sqlite3_close(db);
  return(1);
}
