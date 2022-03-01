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
	install $(SKYNETDIR)/3rd/lua/lua  .
go:
	make -C skynetgo LUAINC=`pwd`/$(LUAINC)

LUACLIBS=pb protobuf skiplist lfs
LUACLIB_TARGET=$(patsubst %, $(LUACLIB_DIR)/%.so, $(LUACLIBS))

libs: $(LUACLIB_TARGET)
$(LUACLIB_DIR)/pb.so: 3rd/lua-protobuf/pb.c
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)
	install 3rd/lua-protobuf/protoc.lua public/proto
$(LUACLIB_DIR)/protobuf.so: 3rd/pbc/binding/lua53/pbc-lua53.c
	$(MAKE) -C 3rd/pbc LUA_INCLUDE_DIR=$(LUAINC)
	$(CC) $(CFLAGS) $(SHARED) -o $@ -I3rd/pbc -I$(LUAINC) -L3rd/pbc/build  -lpbc
$(LUACLIB_DIR)/skiplist.so: 3rd/lua-zset/*.c
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^ -I$(LUAINC)
	install 3rd/lua-zset/zset.lua lualib
$(LUACLIB_DIR)/lfs.so: 3rd/luafilesystem/src/lfs.c
	MACOSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)
	export MACOSX_DEPLOYMENT_TARGET
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^ -I$(LUAINC)
$(LUACLIB_DIR)/ecs.so: 3rd/luaecs/luaecs.c
	$(CC) $(CFLAGS) $(SHARED) -o $@ $^ -I$(LUAINC)
	install 3rd/luaecs/ecs.lua lualib
clean:
	make -C 3rd/pbc clean
	make -C $(SKYNETDIR) clean
	rm -f $(LUACLIB_TARGET)
	rm -f lualib/zset.lua
	rm -f lualib/ecs.lua

cleanall: clean
	make -C $(SKYNETDIR) cleanall

testzset:
	lua -l env 3rd/lua-zset/test.lua
	lua -l env 3rd/lua-zset/test_sl.lua
test: testzset
