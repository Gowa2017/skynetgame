#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <lua.h>
#include <lauxlib.h>

#include "skynet_malloc.h"
#include "aoi.h"

#define check_aoi(L, idx)                                                      \
    *(struct aoi_space **)luaL_checkudata(L, idx, "aoi_meta")

static void *my_alloc(void *ud, void *ptr, size_t sz) {
    if (ptr == NULL) {
        void *p = skynet_malloc(sz);
        return p;
    }
    skynet_free(ptr);
    return NULL;
}

static void lcallback(void *ud, uint32_t watcher, uint32_t marker) {
    lua_State *L = (lua_State *)ud;
    lua_newtable(L);
    lua_pushinteger(L, watcher);
    lua_rawseti(L, -2, 1);
    lua_pushinteger(L, marker);
    lua_rawseti(L, -2, 2);
    uint32_t iLen = lua_rawlen(L, -2);
    lua_rawseti(L, -2, iLen + 1);
}

static int aoi_gc(lua_State *L) {
    struct aoi_space *aoi = check_aoi(L, 1);
    if (aoi == NULL) { return 0; }
    aoi_release(aoi);
    aoi = NULL;
    return 0;
}

static int laoi_create(lua_State *L) {
    float             radius = luaL_checknumber(L, 1);
    struct aoi_space *aoi    = aoi_create(my_alloc, radius, NULL);
    if (aoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: fail to create aoi");
        return 2;
    }

    *(struct aoi_space **)lua_newuserdatauv(L, sizeof(void *), 0) = aoi;
    luaL_getmetatable(L, "aoi_meta");
    lua_setmetatable(L, -2);
    return 1;
}

static int laoi_update(lua_State *L) {
    struct aoi_space *aoi = check_aoi(L, 1);
    if (aoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: aoi not args");
        return 2;
    }
    uint32_t    id   = luaL_checkinteger(L, 2);
    const char *mode = luaL_checkstring(L, 3);

    float pos[3];
    pos[0] = luaL_checknumber(L, 4);
    pos[1] = luaL_checknumber(L, 5);
    pos[2] = luaL_checknumber(L, 6);

    aoi_update(aoi, id, mode, pos);
    return 0;
}

/**
 * params table, return paris will insert it
 * Return table will like { { watcherid, markerid, len}, ...}
 **/
static int laoi_message(lua_State *L) {
    struct aoi_space *aoi = check_aoi(L, 1);
    if (aoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: aoi not args");
        return 2;
    }

    // lua_newtable(L);
    aoi_message(aoi, lcallback, (void *)L);
    return 1;
}

static const struct luaL_Reg laoi_methods[] = {
    {"update", laoi_update},
    {"message", laoi_message},
    {NULL, NULL},
};

static const struct luaL_Reg l_methods[] = {
    {"create", laoi_create},
    {NULL, NULL},
};

int luaopen_aoi(lua_State *L) {
    luaL_checkversion(L);

    luaL_newmetatable(L, "aoi_meta");

    lua_newtable(L);
    luaL_setfuncs(L, laoi_methods, 0);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, aoi_gc);
    lua_setfield(L, -2, "__gc");

    luaL_newlib(L, l_methods);

    return 1;
}
