OS=$(shell uname -s)
LUAINC?=
SKYNETDIR?=
ifeq ($(OS), Darwin)
SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
endif

ifeq ($(OS), Linux)
SHARED := -fPIC --shared
endif
all: lib test
	$(CC) -o test -g -Wall aoi.c test.c
lib:
	$(CC) -o laoi.so -g -Wall aoi.c lua-aoi.c $(SHARED) -I$(LUAINC) -I$(SKYNETDIR)/skynet-src
test:
	$(CC) -o testmap -g -Wall testmap.c

clean:
	rm -f test testmap laoi.so