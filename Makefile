OS=$(shell uname -s)
PLAT ?= none
LIBS := -lpthread -lm -dl
SHARED := -fPIC --shared
EXPORT := -Wl,-E

ifeq ($(OS), Darwin)
PLAT = macosx
SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
EXPORT :=
endif

ifeq ($(OS), Linux)
PLAT=linux
LIBS += -lrt
endif

SKYNETDIR:=skynet
LUACLIB_DIR:=luaclib
LUAINC:=$(SKYNETDIR)/3rd/lua

CFLAGS = -g -O2 -Wall -I$(LUAINC)
LDFLAGS = $(LIBS)
all: engine go libs

engine:
	make -C $(SKYNETDIR) $(PLAT)
go:
	make -C skynetgo LUAINC=`pwd`/$(LUAINC)

LUACLIBS=pb protobuf
LUACLIB_TARGET=$(patsubst %, $(LUACLIB_DIR)/%.so, $(LUACLIBS))
libs: $(LUACLIB_TARGET)

$(LUACLIB_DIR)/pb.so: 3rd/lua-protobuf/pb.c
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)
$(LUACLIB_DIR)/protobuf.so: 3rd/pbc/binding/lua53/pbc-lua53.c
	$(MAKE) -C 3rd/pbc
	$(CC) $(CFLAGS) $(SHARED) -o $@ -I3rd/pbc -I$(LUAINC) -L3rd/pbc/build  -lpbc

clean:
	make -C 3rd/pbc clean
	make -C $(SKYNETDIR) clean
	rm -f $(LUACLIB_TARGET)