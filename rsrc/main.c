#include <stdlib.h>
#include <stdio.h>
#include <sqlite3.h>

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

int main(){
  const char* SQL_init = filetobuf("sql/init.sql");
  const char* SQL_newGame = filetobuf("sql/newGame.sql");

  sqlite3 *db;
  int status;
  char *err = 0;

  printf("\nDeleteing Board..\n");
  remove("game.db");

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

  return(0);
}
