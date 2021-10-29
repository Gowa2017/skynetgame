OS=$(shell uname -s)
LUAINC?=
SKYNETDIR?=
ifeq ($(OS), Darwin)
SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
endif

ifeq ($(OS), Linux)
SHARED := -fPIC --shared
endif

lib:
	$(CC) -o gaoi.so -g -Wall gaoi.c lua-gaoi.c $(SHARED) -I$(LUAINC) -I$(SKYNETDIR)/skynet-src

clean:
	rm -rf gaoi.so*