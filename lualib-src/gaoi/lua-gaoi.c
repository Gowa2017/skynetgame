#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <lua.h>
#include <lauxlib.h>

#include "skynet_malloc.h"
#include "gaoi.h"

#define check_aoi(L, idx)                                                      \
    *(struct aoi_space **)luaL_checkudata(L, idx, "gaoi_meta")

static void
lcallback(void *ud, uint32_t *le, uint32_t le_n, uint32_t *ll, uint32_t ll_n) {
    lua_State *L = (lua_State *)ud;
    uint32_t   i;

    i = 0;
    lua_createtable(L, le_n, 0);
    while (i < le_n) {
        lua_pushinteger(L, le[i]);
        i++;
        lua_rawseti(L, -2, i);
    }

    i = 0;
    lua_createtable(L, ll_n, 0);
    while (i < ll_n) {
        lua_pushinteger(L, ll[i]);
        i++;
        lua_rawseti(L, -2, i);
    }
}

static void *my_alloc(void *ud, void *ptr, size_t sz) {
    if (ptr == NULL) {
        void *p = skynet_malloc(sz);
        return p;
    }
    skynet_free(ptr);
    return NULL;
}

static int gaoi_gc(lua_State *L) {
    struct aoi_space *oAoi = check_aoi(L, 1);
    if (oAoi == NULL) { return 0; }
    aoi_release(oAoi);
    oAoi = NULL;
    return 0;
}

static int lcreate_space(lua_State *L) {
    uint16_t iMaxX  = luaL_checkinteger(L, 1);
    uint16_t iMaxY  = luaL_checkinteger(L, 2);
    uint8_t  iGridX = luaL_checkinteger(L, 3);
    uint8_t  iGridY = luaL_checkinteger(L, 4);

    struct aoi_space *oAoi =
        aoi_create_space(my_alloc, NULL, iMaxX, iMaxY, iGridX, iGridY);
    if (oAoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "lcreate_space error: fail to create aoi");
        return 2;
    }

    *(struct aoi_space **)lua_newuserdatauv(L, sizeof(void *), 0) = oAoi;
    luaL_getmetatable(L, "gaoi_meta");
    lua_setmetatable(L, -2);
    return 1;
}

static int lcreate_object(lua_State *L) {
    struct aoi_space *oAoi = check_aoi(L, 1);
    if (oAoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "lcreate_object error: aoi not args");
        return 2;
    }

    uint32_t iEid    = luaL_checkinteger(L, 2);
    uint8_t  iType   = luaL_checkinteger(L, 3);
    uint8_t  iAcType = luaL_checkinteger(L, 4);
    uint8_t  iWeight = luaL_checkinteger(L, 5);
    uint16_t iLimit  = luaL_checkinteger(L, 6);
    float    fX      = luaL_checknumber(L, 7);
    float    fY      = luaL_checknumber(L, 8);
    // now only three entity type 1 player ,2 npc, 3 monster.
    if (iType > 3) return 0;

    aoi_create_object(oAoi, (void *)L, lcallback, iEid, iType, iAcType, iWeight,
                      iLimit, fX, fY);

    return 2;
}

static int lremove_object(lua_State *L) {
    struct aoi_space *oAoi = check_aoi(L, 1);
    if (oAoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "lremove_object error: aoi not args");
        return 2;
    }

    uint32_t iEid = luaL_checkinteger(L, 2);

    aoi_remove_object(oAoi, (void *)L, lcallback, iEid);

    return 2;
}

static int lupdate_object_position(lua_State *L) {
    struct aoi_space *oAoi = check_aoi(L, 1);
    if (oAoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "lupdate_object_position error: aoi not args");
        return 2;
    }

    uint32_t iEid   = luaL_checkinteger(L, 2);
    float    fX     = luaL_checknumber(L, 3);
    float    fY     = luaL_checknumber(L, 4);
    bool     bForce = lua_toboolean(L, 5);

    aoi_update_object_position(oAoi, (void *)L, lcallback, iEid, fX, fY, bForce,
                               true);

    return 2;
}

static int lupdate_object_weight(lua_State *L) {
    struct aoi_space *oAoi = check_aoi(L, 1);
    if (oAoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "lupdate_object_weight error: aoi not args");
        return 2;
    }

    uint32_t iEid    = luaL_checkinteger(L, 2);
    uint8_t  iWeight = luaL_checkinteger(L, 3);

    aoi_update_object_weight(oAoi, (void *)L, lcallback, iEid, iWeight);

    return 2;
}

static int lget_view(lua_State *L) {
    struct aoi_space *oAoi = check_aoi(L, 1);
    if (oAoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "lget_view error: aoi not args");
        return 2;
    }

    uint32_t iEid  = luaL_checkinteger(L, 2);
    uint8_t  iType = luaL_checkinteger(L, 3);

    uint32_t lOut[2048];
    uint32_t iOut = 0;
    aoi_get_view(oAoi, iEid, iType, lOut, 2048, &iOut);

    uint32_t i = 0;
    lua_createtable(L, iOut, 0);
    while (i < iOut) {
        lua_pushinteger(L, lOut[i]);
        i++;
        lua_rawseti(L, -2, i);
    }
    return 1;
}

static void lreceive(void *ud, uint32_t *m, uint8_t *l) {
    lua_State *L = (lua_State *)ud;
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
        uint32_t type2 = lua_type(L, -2);
        uint32_t type1 = lua_type(L, -1);
        if (type2 == LUA_TNUMBER && type1 == LUA_TNUMBER) {
            uint32_t eid = (uint32_t)lua_tonumber(L, -2);
            uint8_t  pos = (uint8_t)lua_tonumber(L, -1);
            if (pos >= 1 && pos <= 5) {
                m[pos - 1] = eid;
                if (pos > *l) { *l = pos; }
            }
        }
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
}

/**
 * @brief  create a team object,
 *
 * @param  members members id
 * @param  shortleave short leave members id
 * @return int
 */
static int lcreate_scene_team(lua_State *L) {
    struct aoi_space *oAoi = check_aoi(L, 1);
    if (oAoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "lcreate_scene_team error: aoi not args");
        return 2;
    }
    uint32_t iEid = luaL_checkinteger(L, 2);
    aoi_create_team(oAoi, (void *)L, lcallback, lreceive, iEid);

    return 2;
}

static int lremove_scene_team(lua_State *L) {
    struct aoi_space *oAoi = check_aoi(L, 1);
    if (oAoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "lremove_scene_team error: aoi not args");
        return 2;
    }
    uint32_t iEid = luaL_checkinteger(L, 2);
    aoi_remove_team(oAoi, iEid);

    return 0;
}

static int lupdate_scene_team(lua_State *L) {
    struct aoi_space *oAoi = check_aoi(L, 1);
    if (oAoi == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "lupdate_scene_team error: aoi not args");
        return 2;
    }
    uint32_t iEid = luaL_checkinteger(L, 2);
    aoi_update_team(oAoi, (void *)L, lcallback, lreceive, iEid);

    return 2;
}

static const struct luaL_Reg gaoi_methods[] = {
    {"addObject", lcreate_object},
    {"removeObject", lremove_object},
    {"updatePosition", lupdate_object_position},
    {"updateWeight", lupdate_object_weight},
    {"getview", lget_view},
    {"addTeam", lcreate_scene_team},
    {"removeTeam", lremove_scene_team},
    {"updateTeam", lupdate_scene_team},
    {NULL, NULL},
};

static const struct luaL_Reg l_methods[] = {
    {"create", lcreate_space},
    {NULL, NULL},
};

int luaopen_gaoi(lua_State *L) {
    luaL_checkversion(L);

    luaL_newmetatable(L, "gaoi_meta");

    lua_newtable(L);
    luaL_setfuncs(L, gaoi_methods, 0);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, gaoi_gc);
    lua_setfield(L, -2, "__gc");

    luaL_newlib(L, l_methods);

    return 1;
}
