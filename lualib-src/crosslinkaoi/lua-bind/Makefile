OS=$(shell uname -s)
LUAINC?=
SKYNETDIR?=
ifeq ($(OS), Darwin)
SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
endif

ifeq ($(OS), Linux)
SHARED := -fPIC --shared
endif
all : laoi.so

laoi.so: laoi.c ../src/aoi.c
	$(CC)  -Wall -lm -I../src/  -I$(LUAINC) $(SHARED) -o $@ $^ \
		-Wno-int-to-pointer-cast -Wno-pointer-to-int-cast

test:
	lua test.lua

clean:
	rm -f laoi.so

.PHONY: all clean test
