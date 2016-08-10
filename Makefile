CC=gcc
CFLAGS= -I. -L. -lsqlite3

build/%.o: src/%.c
	$(CC) -c -o $@ $< $(CFLAGS)

rbuild/%.o: rsrc/%.c
	$(CC) -c -o $@ $< $(CFLAGS)

all: sqlchess reset

sqlchess: build/main.o
	$(CC) -o sqlchess build/main.o $(CFLAGS)

reset: rbuild/main.o
	$(CC) -o reset rbuild/main.o $(CFLAGS)
