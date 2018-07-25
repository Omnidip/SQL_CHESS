CC=gcc
CFLAGS= -I. -L. -lsqlite3 -static-libgcc -static-libstdc++ -Wl,-Bstatic -lstdc++ -lpthread

build/%.o: src/%.c
	$(CC) -c -o $@ $< $(CFLAGS)

all: sqlchess 

clean:
	rm -rf build
	mkdir -p build
	make all

sqlchess: build/main.o
	$(CC) -o sqlchess build/main.o $(CFLAGS)
