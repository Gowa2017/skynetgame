#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include <stdlib.h>
#include <math.h>

#include "gaoi.h"
#include "skynet.h"

#define INVALID_ID        (~0)
#define PRE_DEFAULT_ALLOC 16
#define MAX_RESULT_COUNT  10240
#define MAX_TEAM_COUNT    5

static int8_t GAOI_X_ACTION[25] = {0,  -1, 0, 1, 0, -1, 1,  1,  -1, -2, 0, 2, 0,
                                   -2, -1, 1, 2, 2, 1,  -1, -2, -2, 2,  2, -2};
static int8_t GAOI_Y_ACTION[25] = {0, 0,  -1, 0,  1,  -1, -1, 1,  1,
                                   0, -2, 0,  2,  -1, -2, -2, -1, 1,
                                   2, 2,  1,  -2, -2, 2,  2};

static uint8_t GAOI_PLAYER_TYPE  = 1;
static uint8_t GAOI_NPC_TYPE     = 2;
static uint8_t GAOI_MONSTER_TYPE = 3;

struct map_slot {
    uint32_t id;
    void *   obj;
    int      next;
};

struct map {
    int              size;
    int              lastfree;
    struct map_slot *slot;
};

struct aoi_teaminfo {
    uint32_t m_iEid;
    uint8_t  ml;
    uint8_t  sl;
    uint32_t m_lMem[MAX_TEAM_COUNT]; // member ids, first is the leader id
    uint32_t m_lShort[MAX_TEAM_COUNT];
};

struct aoi_object {
    uint32_t    m_iEid;
    uint8_t     m_iType;
    uint8_t     m_iAcType;
    uint8_t     m_iWeight;
    uint16_t    m_iOtherWeight;
    uint16_t    m_iLimit;
    int16_t     m_iX; // grid's x
    int16_t     m_iY; // grid's y
    struct map *m_mView;

    struct aoi_object *prev;
    struct aoi_object *next;

    uint32_t m_iTeamEid;
};

struct aoi_grid {
    int16_t            m_iX;
    int16_t            m_iY;
    struct aoi_object *m_lPlayerEntity;  // list of aoi_object
    struct aoi_object *m_lNpcEntity;     // list of aoi_object
    struct aoi_object *m_lMonsterEntity; // list of aoi_object

    struct aoi_object *m_Tail;
};

struct aoi_result {
    uint16_t le_n;                 // enter list length
    uint16_t ll_n;                 // leave list length
    uint32_t le[MAX_RESULT_COUNT]; // enter id list
    uint32_t ll[MAX_RESULT_COUNT]; // leave id list
};

struct team_tmp {
    uint8_t  ml;                     // members length
    uint8_t  sl;                     // short leave members length
    uint32_t mmem[MAX_TEAM_COUNT];   // members
    uint32_t mshort[MAX_TEAM_COUNT]; // short leave members
};

struct aoi_space {
    aoi_Alloc alloc;
    void *    alloc_ud;

    uint16_t    m_iMaxX;      // space's x size
    uint16_t    m_iMaxY;      // space's y size
    uint8_t     m_iGridX;     // a grid's x size
    uint8_t     m_iGridY;     // a grid's y size
    uint16_t    m_iXSize;     // number of grids in axis-x
    uint16_t    m_iYSize;     // number of grids in axis-y
    struct map *m_mAllObject; // hashmap objects in space
    struct map *m_mAllGrid;   // grid hashmap
    struct map *m_mAllTeam;   // team hashmap

    struct aoi_result *result;
    struct team_tmp *  ttmp;
};

struct result_action {
    uint8_t           type;
    struct aoi_space *space;
    struct map *      old;
    struct map *new;
};

struct weight_action {
    int32_t           add_weight;
    struct aoi_space *space;
};

struct view_action {
    uint8_t           type;
    uint32_t *        lo;
    uint32_t          lo_size;
    uint32_t          lo_max;
    struct aoi_space *space;
};

static uint32_t                get_eid(struct aoi_object *obj);
static inline struct map_slot *mainposition(struct map *m, uint32_t id);
static void
map_insert(struct aoi_space *space, struct map *m, uint32_t id, void *obj);
static void *map_query(struct aoi_space *space, struct map *m, uint32_t id);
static int   map_foreach_func1(void *ud, uint32_t key, void *obj);
static int   map_foreach_func2(void *ud, uint32_t key, void *obj);
static int   map_foreach_func3(void *ud, uint32_t key, void *obj);
static int   map_foreach_func4(void *ud, uint32_t key, void *obj);
static int   map_foreach_func5(void *ud, uint32_t key, void *obj);
static int   map_foreach_func6(void *ud, uint32_t key, void *obj);
static void  sync_teamleader_view(struct aoi_space *space, uint32_t eid);

// result interface

static void init_result(struct aoi_result *re) {
    re->ll_n = 0;
    re->le_n = 0;
}

/**
 * @brief  init a temp team struct
 *
 * @param ttmp temp_tmp
 */
static void init_team_tmp(struct team_tmp *ttmp) {
    ttmp->ml = 0;
    ttmp->sl = 0;
    memset(ttmp->mmem, 0, sizeof(ttmp->mmem));
    memset(ttmp->mshort, 0, sizeof(ttmp->mshort));
}

/**
 * @brief append a leave id to the resut
 *
 * @param re
 * @param i
 */
static void append_result_leave(struct aoi_result *re, uint32_t i) {
    if (re->ll_n < MAX_RESULT_COUNT) {
        re->ll[re->ll_n] = i;
        re->ll_n++;
    }
}

/**
 * @brief
 *
 * @param re append a leave id to the resut
 * @param i
 */
static void append_result_enter(struct aoi_result *re, uint32_t i) {
    if (re->le_n < MAX_RESULT_COUNT) {
        re->le[re->le_n] = i;
        re->le_n++;
    }
}

// object interface

static void supple_other_weight(struct aoi_object *obj, int16_t i) {
    obj->m_iOtherWeight = obj->m_iOtherWeight + i;
}

static struct map *get_view(struct aoi_object *obj) { return obj->m_mView; }

static uint32_t get_other_weight(struct aoi_object *obj) {
    return obj->m_iOtherWeight;
}

static bool is_player(struct aoi_object *obj) {
    return (obj->m_iType == GAOI_PLAYER_TYPE);
}

static bool is_npc(struct aoi_object *obj) {
    return (obj->m_iType == GAOI_NPC_TYPE);
}

static bool is_monster(struct aoi_object *obj) {
    return (obj->m_iType == GAOI_MONSTER_TYPE);
}

static bool is_in_team(struct aoi_space *space, struct aoi_object *obj) {
    if (obj->m_iTeamEid != 0) {
        struct aoi_teaminfo *team = (struct aoi_teaminfo *)map_query(
            space, space->m_mAllTeam, obj->m_iTeamEid);
        if (team) {
            uint16_t i;
            for (i = 0; i < team->ml; i++) {
                if (team->m_lMem[i] == get_eid(obj)) { return true; }
            }
        }
    }
    return false;
}

/**
 * Team's first member is the leader
 **/
static bool is_team_leader(struct aoi_space *space, struct aoi_object *obj) {
    if (is_in_team(space, obj)) {
        struct aoi_teaminfo *team = (struct aoi_teaminfo *)map_query(
            space, space->m_mAllTeam, obj->m_iTeamEid);
        if (team && team->ml > 0 && team->m_lMem[0] == get_eid(obj)) {
            return true;
        }
    }
    return false;
}

/**
 * @brief Get the weight of a object, NPC is 0, object is weight
 *
 * @param obj aoi_object
 * @return uint8_t
 */
static uint8_t get_weight(struct aoi_object *obj) {
    if (is_npc(obj)) return 0;
    return obj->m_iWeight;
}

/**
 * @brief Get the max other weight of object, NPC is -1，Player is its limit
 * subtraction its weight
 *
 * @param obj aoi_object
 * @return int32_t
 */
static int32_t get_max_other_weight(struct aoi_object *obj) {
    if (is_player(obj)) {
        int32_t r = obj->m_iLimit - obj->m_iWeight;
        if (r < 0) return 0;
        return r;
    }
    return -1;
}

static void set_weight(struct aoi_object *obj, uint8_t weight) {
    obj->m_iWeight = weight;
}

static uint32_t get_eid(struct aoi_object *obj) { return obj->m_iEid; }

static void get_pos(struct aoi_object *obj, int16_t *now_x, int16_t *now_y) {
    *now_x = obj->m_iX;
    *now_y = obj->m_iY;
}

static void set_pos(struct aoi_object *obj, int16_t now_x, int16_t now_y) {
    obj->m_iX = now_x;
    obj->m_iY = now_y;
}

// grid interface

static struct aoi_object *get_npc_map(struct aoi_grid *grid) {
    return grid->m_lNpcEntity;
}

static struct aoi_object *get_player_map(struct aoi_grid *grid) {
    return grid->m_lPlayerEntity;
}

static struct aoi_object *get_monster_map(struct aoi_grid *grid) {
    return grid->m_lMonsterEntity;
}

/**
 * Every grid has three double linke list, player, npc  and monster
 * Depend on the object's type, insert it into correspond link list at the first
 *place.
 **/
static void link_aoi_object(struct aoi_grid *grid, struct aoi_object *obj) {
    struct aoi_object *root;

    if (is_player(obj)) {
        root = grid->m_lPlayerEntity;
    } else if (is_npc(obj)) {
        root = grid->m_lNpcEntity;
    } else if (is_monster(obj)) {
        root = grid->m_lMonsterEntity;
    } else {
        assert(false);
    }

    obj->prev = NULL;
    obj->next = NULL;

    if (root) {
        obj->prev  = NULL;
        obj->next  = root;
        root->prev = obj;
    } else {
        if (is_player(obj)) { grid->m_Tail = obj; }
    }

    if (is_player(obj)) {
        grid->m_lPlayerEntity = obj;
    } else if (is_npc(obj)) {
        grid->m_lNpcEntity = obj;
    } else if (is_monster(obj)) {
        grid->m_lMonsterEntity = obj;
    } else {
        assert(false);
    }
}

/**
 * Every grid has three double linke list, player, npc  and monster
 * Depend on the object's type, remove it from correspond link list.
 **/
static void unlink_aoi_object(struct aoi_grid *grid, struct aoi_object *obj) {
    struct aoi_object *root;

    if (is_player(obj)) {
        root = grid->m_lPlayerEntity;
    } else if (is_npc(obj)) {
        root = grid->m_lNpcEntity;
    } else if (is_monster(obj)) {
        root = grid->m_lMonsterEntity;
    } else {
        assert(false);
    }

    struct aoi_object *pprev = obj->prev;
    struct aoi_object *pnext = obj->next;
    obj->prev                = NULL;
    obj->next                = NULL;

    if (pprev) { pprev->next = pnext; }
    if (pnext) { pnext->prev = pprev; }

    if (is_player(obj) && obj == grid->m_Tail) { grid->m_Tail = pprev; }

    if (root && root == obj) {
        if (is_player(obj)) {
            grid->m_lPlayerEntity = pnext;
        } else if (is_npc(obj)) {
            grid->m_lNpcEntity = pnext;
        } else if (is_monster(obj)) {
            grid->m_lMonsterEntity = pnext;
        } else {
            assert(false);
        }
    }
}

static void loop_change_link_aoi_object(struct aoi_grid *grid) {
    struct aoi_object *obj = grid->m_Tail;
    if (obj) {
        unlink_aoi_object(grid, obj);
        link_aoi_object(grid, obj);
    }
}

// space interface

static void rehash(struct aoi_space *space, struct map *m) {
    struct map_slot *old_slot = m->slot;
    int              old_size = m->size;
    m->size                   = 2 * old_size;
    m->lastfree               = m->size - 1;
    m->slot =
        space->alloc(space->alloc_ud, NULL, m->size * sizeof(struct map_slot));
    int i;
    for (i = 0; i < m->size; i++) {
        struct map_slot *s = &m->slot[i];
        s->id              = INVALID_ID;
        s->obj             = NULL;
        s->next            = -1;
    }
    for (i = 0; i < old_size; i++) {
        struct map_slot *s = &old_slot[i];
        if (s->obj) { map_insert(space, m, s->id, s->obj); }
    }
    space->alloc(space->alloc_ud, old_slot, old_size * sizeof(struct map_slot));
}

static void
map_insert(struct aoi_space *space, struct map *m, uint32_t id, void *obj) {
    struct map_slot *s = mainposition(m, id);
    if (s->id == INVALID_ID || s->obj == NULL) {
        s->id  = id;
        s->obj = obj;
        return;
    }
    if (mainposition(m, s->id) != s) {
        struct map_slot *last = mainposition(m, s->id);
        while (last->next != s - m->slot) {
            assert(last->next >= 0);
            last = &m->slot[last->next];
        }
        uint32_t temp_id  = s->id;
        void *   temp_obj = s->obj;
        last->next        = s->next;
        s->id             = id;
        s->obj            = obj;
        s->next           = -1;
        if (temp_obj) { map_insert(space, m, temp_id, temp_obj); }
        return;
    }
    while (m->lastfree >= 0) {
        struct map_slot *temp = &m->slot[m->lastfree--];
        if (temp->id == INVALID_ID) {
            temp->id   = id;
            temp->obj  = obj;
            temp->next = s->next;
            s->next    = (int)(temp - m->slot);
            return;
        }
    }
    rehash(space, m);
    map_insert(space, m, id, obj);
}

static void *map_query(struct aoi_space *space, struct map *m, uint32_t id) {
    struct map_slot *s = mainposition(m, id);
    for (;;) {
        if (s->id == id) { return s->obj; }
        if (s->next < 0) { break; }
        s = &m->slot[s->next];
    }
    return NULL;
}

static void map_foreach(struct aoi_space *space,
                        struct map *      m,
                        int (*func)(void *ud, uint32_t id, void *obj),
                        void *ud) {
    int i;
    for (i = 0; i < m->size; i++) {
        if (m->slot[i].obj) {
            if (func(ud, m->slot[i].id, m->slot[i].obj)) { break; }
        }
    }
}

static void *map_drop(struct aoi_space *space, struct map *m, uint32_t id) {
    struct map_slot *s = mainposition(m, id);
    for (;;) {
        if (s->id == id) {
            void *obj = s->obj;
            s->obj    = NULL;
            return obj;
        }
        if (s->next < 0) { return NULL; }
        s = &m->slot[s->next];
    }
}

static void map_delete(struct aoi_space *space, struct map *m) {
    space->alloc(space->alloc_ud, m->slot, m->size * sizeof(struct map_slot));
    space->alloc(space->alloc_ud, m, sizeof(*m));
}

static struct map *map_new(struct aoi_space *space, uint32_t mem) {
    int         i;
    struct map *m = space->alloc(space->alloc_ud, NULL, sizeof(*m));

    if (!mem) { mem = PRE_DEFAULT_ALLOC; }

    m->size     = mem;
    m->lastfree = mem - 1;
    m->slot =
        space->alloc(space->alloc_ud, NULL, m->size * sizeof(struct map_slot));
    for (i = 0; i < m->size; i++) {
        struct map_slot *s = &m->slot[i];
        s->id              = INVALID_ID;
        s->obj             = NULL;
        s->next            = -1;
    }
    return m;
}

static void leave_view(struct aoi_space * space,
                       struct aoi_object *o,
                       struct aoi_object *oo) {
    if (map_query(space, o->m_mView, get_eid(oo))) {
        map_drop(space, o->m_mView, get_eid(oo));
        supple_other_weight(o, -get_weight(oo));
    }
}

static void enter_view(struct aoi_space * space,
                       struct aoi_object *o,
                       struct aoi_object *oo) {
    if (!map_query(space, o->m_mView, get_eid(oo))) {
        map_insert(space, o->m_mView, get_eid(oo), (void *)oo);
        supple_other_weight(o, get_weight(oo));
    }
}

/**
 * gen grid key i + j * space->m_iXSize
 **/
static int32_t grid_key(struct aoi_space *space, uint32_t i, uint32_t j) {
    if (i >= 0 && i < space->m_iXSize && j >= 0 && j < space->m_iYSize)
        return i + j * space->m_iXSize;
    return -1;
}

static uint32_t get_view_list(struct aoi_space * space,
                              struct aoi_object *obj,
                              uint32_t *         lo,
                              uint32_t           lo_max) {
    struct view_action via;
    via.space   = space;
    via.type    = 0;
    via.lo      = lo;
    via.lo_max  = lo_max;
    via.lo_size = 0;
    map_foreach(space, obj->m_mView, map_foreach_func5, (void *)&via);
    return via.lo_size;
}

static uint32_t get_view_list_by_type(struct aoi_space * space,
                                      struct aoi_object *obj,
                                      uint8_t            type,
                                      uint32_t *         lo,
                                      uint32_t           lo_max) {
    struct view_action via;
    via.space   = space;
    via.type    = type;
    via.lo      = lo;
    via.lo_max  = lo_max;
    via.lo_size = 0;
    map_foreach(space, obj->m_mView, map_foreach_func5, (void *)&via);
    return via.lo_size;
}

/**
 * Gen a grid
 **/
static struct aoi_grid *
new_grid(struct aoi_space *space, uint32_t id, int16_t x, int16_t y) {
    struct aoi_grid *grid  = space->alloc(space->alloc_ud, NULL, sizeof(*grid));
    grid->m_iX             = x;
    grid->m_iY             = y;
    grid->m_lPlayerEntity  = NULL;
    grid->m_lNpcEntity     = NULL;
    grid->m_lMonsterEntity = NULL;
    grid->m_Tail           = NULL;
    return grid;
}

static int free_grid(void *ud, uint32_t key, void *obj) {
    struct aoi_space *space = (struct aoi_space *)ud;
    struct aoi_grid * gobj  = (struct aoi_grid *)obj;
    gobj->m_lPlayerEntity   = NULL;
    gobj->m_lNpcEntity      = NULL;
    gobj->m_lMonsterEntity  = NULL;
    gobj->m_Tail            = NULL;
    space->alloc(space->alloc_ud, gobj, sizeof(*gobj));
    return 0;
}

static struct aoi_object *new_object(struct aoi_space *space,
                                     uint32_t          id,
                                     uint8_t           type,
                                     uint8_t           ac_type,
                                     uint8_t           weight,
                                     uint16_t          limit) {
    struct aoi_object *object =
        space->alloc(space->alloc_ud, NULL, sizeof(*object));
    object->m_iEid         = id;
    object->m_iType        = type;
    object->m_iAcType      = ac_type;
    object->m_iWeight      = weight;
    object->m_iLimit       = limit;
    object->m_iOtherWeight = 0;
    object->m_iX           = -1;
    object->m_iY           = -1;
    object->prev           = NULL;
    object->next           = NULL;
    object->m_mView        = map_new(space, 0);
    object->m_iTeamEid     = 0;
    return object;
}

static int free_object(void *ud, uint32_t key, void *obj) {
    struct aoi_space * space = (struct aoi_space *)ud;
    struct aoi_object *pobj  = (struct aoi_object *)obj;
    pobj->prev               = NULL;
    pobj->next               = NULL;
    map_delete(space, pobj->m_mView);
    space->alloc(space->alloc_ud, pobj, sizeof(*pobj));
    return 0;
}

static int free_team(void *ud, uint32_t key, void *obj) {
    struct aoi_space *   space = (struct aoi_space *)ud;
    struct aoi_teaminfo *team  = (struct aoi_teaminfo *)obj;
    space->alloc(space->alloc_ud, team, sizeof(*team));
    return 0;
}

/**
 * Create a aoi space, it have many grid
 **/
struct aoi_space *aoi_create_space(aoi_Alloc my_alloc,
                                   void *    ud,
                                   uint16_t  max_x,
                                   uint16_t  max_y,
                                   uint8_t   grid_x,
                                   uint8_t   grid_y) {
    struct aoi_space *space = my_alloc(ud, NULL, sizeof(*space));
    space->alloc            = my_alloc;
    space->alloc_ud         = ud;

    space->m_iMaxX  = max_x;
    space->m_iMaxY  = max_y;
    space->m_iGridX = grid_x;
    space->m_iGridY = grid_y;
    space->m_iXSize = floor(max_x / grid_x) + 1;
    space->m_iYSize = floor(max_y / grid_y) + 1;

    space->m_mAllObject = map_new(space, 0);
    space->m_mAllGrid   = map_new(space, 0);
    space->m_mAllTeam   = map_new(space, 0);

    uint32_t i, j;
    for (i = 0; i < space->m_iXSize; i++) {
        for (j = 0; j < space->m_iYSize; j++) {
            int32_t key = grid_key(space, i, j);
            assert(key >= 0);
            struct aoi_grid *grid = new_grid(space, key, i, j);
            map_insert(space, space->m_mAllGrid, key, (void *)grid);
        }
    }

    space->result = my_alloc(ud, NULL, sizeof(struct aoi_result));
    init_result(space->result);

    space->ttmp = my_alloc(ud, NULL, sizeof(struct team_tmp));
    init_team_tmp(space->ttmp);

    return space;
}

void aoi_release(struct aoi_space *space) {
    map_foreach(space, space->m_mAllGrid, free_grid, (void *)space);
    map_delete(space, space->m_mAllGrid);
    space->m_mAllGrid = NULL;

    map_foreach(space, space->m_mAllObject, free_object, (void *)space);
    map_delete(space, space->m_mAllObject);
    space->m_mAllObject = NULL;

    map_foreach(space, space->m_mAllTeam, free_team, (void *)space);
    map_delete(space, space->m_mAllTeam);
    space->m_mAllTeam = NULL;

    space->alloc(space->alloc_ud, space->result, sizeof(struct aoi_result));
    space->result = NULL;

    space->alloc(space->alloc_ud, space->ttmp, sizeof(struct team_tmp));
    space->ttmp = NULL;

    space->alloc(space->alloc_ud, space, sizeof(*space));
}

static struct aoi_teaminfo *new_team(struct aoi_space *space,
                                     uint32_t          id,
                                     uint32_t *        mmem,
                                     uint8_t           ml,
                                     uint32_t *        mshort,
                                     uint8_t           sl) {
    struct aoi_teaminfo *object =
        space->alloc(space->alloc_ud, NULL, sizeof(*object));
    object->m_iEid = id;
    object->ml     = ml;
    object->sl     = sl;
    uint8_t i;
    for (i = 0; i < ml; i++) { object->m_lMem[i] = mmem[i]; }
    for (i = 0; i < sl; i++) { object->m_lShort[i] = mshort[i]; }
    return object;
}

static void set_team_id(struct aoi_object *obj, uint32_t eid) {
    obj->m_iTeamEid = eid;
}

static void set_team_info(struct aoi_teaminfo *obj, struct team_tmp *tmp) {
    obj->ml = tmp->ml;
    obj->sl = tmp->sl;
    uint8_t i;
    for (i = 0; i < tmp->ml; i++) { obj->m_lMem[i] = tmp->mmem[i]; }
    for (i = 0; i < tmp->sl; i++) { obj->m_lShort[i] = tmp->mshort[i]; }
}

/**
 * @brief
 *
 * @param space  aoi_space
 * @param eid  entity id
 */
static void aoi_update_team_member_pos(struct aoi_space *space, uint32_t eid) {
    // use eid as a team id
    struct aoi_teaminfo *team =
        (struct aoi_teaminfo *)map_query(space, space->m_mAllTeam, eid);
    if (!team) { return; }

    // team leader is the first member
    uint32_t           ileader = team->m_lMem[0];
    struct aoi_object *leader =
        (struct aoi_object *)map_query(space, space->m_mAllObject, ileader);
    if (!leader) { return; }

    int16_t grid_x, grid_y, now_x, now_y;
    get_pos(leader, &grid_x, &grid_y);
    int32_t new_key = grid_key(space, grid_x, grid_y);
    assert(new_key >= 0);
    struct aoi_grid *new_grid =
        (struct aoi_grid *)map_query(space, space->m_mAllGrid, new_key);
    assert(new_grid);

    uint16_t i;
    for (i = 1; i < team->ml; i++) {
        uint32_t           id = team->m_lMem[i];
        struct aoi_object *obj =
            (struct aoi_object *)map_query(space, space->m_mAllObject, id);
        if (obj) {
            get_pos(obj, &now_x, &now_y);
            if (grid_x != now_x || grid_y != now_y) {
                if (now_x >= 0 && now_y >= 0) {
                    int32_t old_key = grid_key(space, now_x, now_y);
                    if (old_key >= 0) {
                        struct aoi_grid *old_grid =
                            (struct aoi_grid *)map_query(
                                space, space->m_mAllGrid, old_key);
                        if (old_grid) { unlink_aoi_object(old_grid, obj); }
                    }
                }
                set_pos(obj, grid_x, grid_y);
                link_aoi_object(new_grid, obj);
            }
        }
    }
}

/**
 * @brief create a team
 *
 * @param space aoi_space
 * @param ud now is NULL
 * @param callback
 * @param receive
 * @param eid entityid
 */
void aoi_create_team(struct aoi_space * space,
                     void *             ud,
                     aoi_Callback       callback,
                     aoi_ReviceTeamInfo receive,
                     uint32_t           eid) {
    struct team_tmp *tmp = space->ttmp;
    init_team_tmp(tmp);

    receive(
        ud, tmp->mshort,
        &tmp->sl); // will get the short leave members's id
                   // from the lua state stack, it passed after the members list
    receive(ud, tmp->mmem, &tmp->ml); // will get the short leave members's id
                                      // from the lua state stack

    struct aoi_teaminfo *team =
        (struct aoi_teaminfo *)map_query(space, space->m_mAllTeam, eid);
    assert(!team);

    team = new_team(space, eid, tmp->mmem, tmp->ml, tmp->mshort, tmp->sl);
    map_insert(space, space->m_mAllTeam, eid, (void *)team);

    uint16_t           i;
    struct aoi_object *leader = NULL;

    for (i = 0; i < team->sl; i++) {
        struct aoi_object *obj = (struct aoi_object *)map_query(
            space, space->m_mAllObject, team->m_lShort[i]);
        if (obj) { set_team_id(obj, eid); }
    }
    for (i = 0; i < team->ml; i++) {
        struct aoi_object *obj = (struct aoi_object *)map_query(
            space, space->m_mAllObject, team->m_lMem[i]);
        if (obj) {
            if (i == 0) { leader = obj; }
            set_team_id(obj, eid);
        }
    }

    struct aoi_result *result = space->result;
    init_result(result);

    int16_t now_x, now_y;

    if (leader) {
        get_pos(leader, &now_x, &now_y);
        float x = now_x * space->m_iGridX;
        float y = now_y * space->m_iGridY;
        aoi_update_object_position(space, ud, callback, get_eid(leader), x, y,
                                   true, false);
    }

    for (i = 0; i < team->sl; i++) {
        struct aoi_object *obj = (struct aoi_object *)map_query(
            space, space->m_mAllObject, team->m_lShort[i]);
        if (obj) {
            get_pos(obj, &now_x, &now_y);
            float x = now_x * space->m_iGridX;
            float y = now_y * space->m_iGridY;
            aoi_update_object_position(space, ud, callback, get_eid(obj), x, y,
                                       true, false);
        }
    }

    callback(ud, result->le, result->le_n, result->ll, result->ll_n);
}

void aoi_remove_team(struct aoi_space *space, uint32_t eid) {
    struct aoi_teaminfo *team =
        (struct aoi_teaminfo *)map_query(space, space->m_mAllTeam, eid);
    if (team) {
        uint16_t i;
        for (i = 0; i < team->sl; i++) {
            struct aoi_object *obj = (struct aoi_object *)map_query(
                space, space->m_mAllObject, team->m_lShort[i]);
            if (obj) { set_team_id(obj, 0); }
        }
        for (i = 0; i < team->ml; i++) {
            struct aoi_object *obj = (struct aoi_object *)map_query(
                space, space->m_mAllObject, team->m_lMem[i]);
            if (obj) { set_team_id(obj, 0); }
        }
        map_drop(space, space->m_mAllTeam, eid);
        free_team((void *)space, eid, (void *)team);
    }
}

void aoi_update_team(struct aoi_space * space,
                     void *             ud,
                     aoi_Callback       my_callback,
                     aoi_ReviceTeamInfo my_recive,
                     uint32_t           eid) {
    struct team_tmp *tmp = space->ttmp;
    init_team_tmp(tmp);

    my_recive(ud, tmp->mshort, &tmp->sl);
    my_recive(ud, tmp->mmem, &tmp->ml);

    struct aoi_teaminfo *team =
        (struct aoi_teaminfo *)map_query(space, space->m_mAllTeam, eid);
    if (!team) { return; }
    uint16_t    i;
    struct map *old_short = map_new(space, 16);
    for (i = 0; i < team->sl; i++) {
        struct aoi_object *obj = (struct aoi_object *)map_query(
            space, space->m_mAllObject, team->m_lShort[i]);
        if (obj) {
            set_team_id(obj, 0);
            map_insert(space, old_short, get_eid(obj), (void *)obj);
        }
    }
    for (i = 0; i < team->ml; i++) {
        struct aoi_object *obj = (struct aoi_object *)map_query(
            space, space->m_mAllObject, team->m_lMem[i]);
        if (obj) { set_team_id(obj, 0); }
    }

    set_team_info(team, tmp);

    struct aoi_object *leader = NULL;
    for (i = 0; i < team->sl; i++) {
        struct aoi_object *obj = (struct aoi_object *)map_query(
            space, space->m_mAllObject, team->m_lShort[i]);
        if (obj) { set_team_id(obj, eid); }
    }
    for (i = 0; i < team->ml; i++) {
        struct aoi_object *obj = (struct aoi_object *)map_query(
            space, space->m_mAllObject, team->m_lMem[i]);
        if (obj) {
            if (i == 0) { leader = obj; }
            set_team_id(obj, eid);
        }
    }

    struct aoi_result *result = space->result;
    init_result(result);

    int16_t now_x, now_y;
    if (leader) {
        get_pos(leader, &now_x, &now_y);
        float x = now_x * space->m_iGridX;
        float y = now_y * space->m_iGridY;
        aoi_update_object_position(space, ud, my_callback, get_eid(leader), x,
                                   y, true, false);
    }
    for (i = 0; i < team->sl; i++) {
        struct aoi_object *obj = (struct aoi_object *)map_query(
            space, space->m_mAllObject, team->m_lShort[i]);
        if (obj && !map_query(space, old_short, team->m_lShort[i])) {
            get_pos(obj, &now_x, &now_y);
            float x = now_x * space->m_iGridX;
            float y = now_y * space->m_iGridY;
            aoi_update_object_position(space, ud, my_callback, get_eid(obj), x,
                                       y, true, false);
        }
    }

    my_callback(ud, result->le, result->le_n, result->ll, result->ll_n);
}

void aoi_create_object(struct aoi_space *space,
                       void *            ud,
                       aoi_Callback      my_callback,
                       uint32_t          eid,
                       uint8_t           type,
                       uint8_t           ac_type,
                       uint8_t           weight,
                       uint16_t          limit,
                       float             x,
                       float             y) {
    assert(weight >= 0 && limit >= 0 && x >= 0 && x <= space->m_iMaxX &&
           y >= 0 && y <= space->m_iMaxY);

    struct aoi_object *obj =
        (struct aoi_object *)map_query(space, space->m_mAllObject, eid);
    assert(!obj);

    obj = new_object(space, eid, type, ac_type, weight, limit);
    map_insert(space, space->m_mAllObject, eid, (void *)obj);

    aoi_update_object_position(space, ud, my_callback, eid, x, y, true, true);
}

static bool is_near(struct aoi_object *obj, struct aoi_object *target) {
    int16_t now_x, now_y, t_x, t_y;
    get_pos(obj, &now_x, &now_y);
    get_pos(target, &t_x, &t_y);
    int16_t dis = 0;
    if (abs(now_y - t_y) > dis) { return false; }
    if (abs(now_x - t_x) > dis) { return false; }
    return true;
}

static bool aoi_kick_object_view(struct aoi_space * space,
                                 struct aoi_object *obj,
                                 int32_t            kick_weight) {
    if (!obj) { return false; }
    struct map *       now_view   = get_view(obj);
    uint32_t           weight_cnt = 0;
    uint32_t           i;
    struct aoi_result *result = space->result;
    append_result_leave(result, 0);
    append_result_leave(result, get_eid(obj));
    uint32_t ll = result->ll_n;

    for (i = 0; i < now_view->size; i++) {
        if (weight_cnt >= kick_weight) { break; }
        struct aoi_object *target = (struct aoi_object *)now_view->slot[i].obj;
        if (!target) { continue; }
        if (!is_player(target)) { continue; }
        if (target->m_iTeamEid != 0 && target->m_iTeamEid == obj->m_iTeamEid) {
            continue;
        }

        if (!is_in_team(space, target)) {
            weight_cnt = weight_cnt + get_weight(target);
            append_result_leave(result, get_eid(target));
        } else if (is_team_leader(space, target)) {
            struct aoi_teaminfo *team = (struct aoi_teaminfo *)map_query(
                space, space->m_mAllTeam, target->m_iTeamEid);
            if (team) {
                weight_cnt = weight_cnt + team->ml;
                uint16_t j = 0;
                for (j = 0; j < team->ml; j++) {
                    append_result_leave(result, team->m_lMem[j]);
                }
            }
        }
    }
    if (weight_cnt >= kick_weight) {
        uint32_t i = ll;
        while (i < result->ll_n) {
            struct aoi_object *oo = (struct aoi_object *)map_query(
                space, space->m_mAllObject, result->ll[i]);
            if (oo) {
                leave_view(space, oo, obj);
                leave_view(space, obj, oo);
            }
            i++;
        }
        if (is_team_leader(space, obj)) {
            sync_teamleader_view(space, get_eid(obj));
        }
        i = ll;
        while (i < result->ll_n) {
            struct aoi_object *oo = (struct aoi_object *)map_query(
                space, space->m_mAllObject, result->ll[i]);
            if (oo && is_team_leader(space, oo)) {
                sync_teamleader_view(space, get_eid(oo));
            }
            i++;
        }
        return true;
    }
    return false;
}

/**
 * @brief  update a object's position
 *
 * @param space aoi_space
 * @param ud memory data, or NULL if does not use a memory allocator
 * @param my_callback  callback, aoi_Callback
 * @param eid entity id
 * @param x  x pos
 * @param y  y pos
 * @param force boolean
 * @param back what?
 */
void aoi_update_object_position(struct aoi_space *space,
                                void *            ud,
                                aoi_Callback      my_callback,
                                uint32_t          eid,
                                float             x,
                                float             y,
                                bool              force,
                                bool              back) {
    assert(x >= 0 && x <= space->m_iMaxX && y >= 0 && y <= space->m_iMaxY);
    // get the grid which the object now in
    uint16_t grid_x  = floor(x / space->m_iGridX);
    uint16_t grid_y  = floor(y / space->m_iGridY);
    int32_t  new_key = grid_key(space, grid_x, grid_y);
    assert(new_key >= 0);

    struct aoi_object *obj =
        (struct aoi_object *)map_query(space, space->m_mAllObject, eid);
    struct aoi_grid *new_grid =
        (struct aoi_grid *)map_query(space, space->m_mAllGrid, new_key);
    assert(obj && new_grid);

    int16_t now_x, now_y;
    get_pos(obj, &now_x, &now_y);

    // not move out a grid
    if (grid_x == now_x && grid_y == now_y) {
        // not force
        if (!force) {
            struct aoi_result *result = space->result;
            init_result(result);
            my_callback(ud, result->le, result->le_n, result->ll, result->ll_n);
            return;
        }
        // in a new grid
    } else {
        if (now_x >= 0 && now_y >= 0) {
            int32_t old_key = grid_key(space, now_x, now_y);
            if (old_key >= 0) {
                struct aoi_grid *old_grid = (struct aoi_grid *)map_query(
                    space, space->m_mAllGrid, old_key);
                // move out from old grid
                if (old_grid) { unlink_aoi_object(old_grid, obj); }
            }
        }
        // set pos and link in new grid
        set_pos(obj, grid_x, grid_y);
        link_aoi_object(new_grid, obj);
    }

    // update the team member 's view
    if (is_team_leader(space, obj)) {
        aoi_update_team_member_pos(space, obj->m_iTeamEid);
    }

    struct map *new_view  = map_new(space, 256);
    struct map *new_view2 = map_new(space, 256);
    struct map *old_view  = get_view(obj);
    int32_t     my_weight, my_left_weight;
    int32_t     need_weight;
    uint32_t    my_eid = 0;

    struct aoi_result *result = space->result;
    if (back) { init_result(result); }

    uint32_t i;
    // object is a player
    if (is_player(obj)) {
        my_weight      = get_weight(obj);
        my_left_weight = get_max_other_weight(obj);
        need_weight    = my_left_weight * 2 / 3;
        my_eid         = get_eid(obj);
        // has team
        if (obj->m_iTeamEid != 0) {
            struct aoi_teaminfo *team = (struct aoi_teaminfo *)map_query(
                space, space->m_mAllTeam, obj->m_iTeamEid);
            // team exists
            if (team) {
                if (is_in_team(space, obj)) { my_weight = team->ml; }
                for (i = 0; i < team->ml; i++) {
                    if (my_left_weight <= 0) { break; }
                    struct aoi_object *mem = (struct aoi_object *)map_query(
                        space, space->m_mAllObject, team->m_lMem[i]);
                    if (mem && get_eid(mem) != my_eid) {
                        my_left_weight = my_left_weight - get_weight(mem);
                        map_insert(space, new_view, get_eid(mem), (void *)mem);
                    }
                }
                for (i = 0; i < team->sl; i++) {
                    if (my_left_weight <= 0) { break; }
                    struct aoi_object *mem = (struct aoi_object *)map_query(
                        space, space->m_mAllObject, team->m_lShort[i]);
                    if (mem && get_eid(mem) != my_eid) {
                        my_left_weight = my_left_weight - get_weight(mem);
                        map_insert(space, new_view, get_eid(mem), (void *)mem);
                    }
                }
            }
        }
        // update old view
        for (i = 0; i < old_view->size; i++) {
            if (my_left_weight <= 0) { break; }
            if (old_view->slot[i].obj == NULL) { continue; }
            struct aoi_object *oldobj =
                (struct aoi_object *)old_view->slot[i].obj;
            // we look it
            if (is_near(obj, oldobj) &&
                !map_query(space, new_view, get_eid(oldobj))) {
                if (is_npc(oldobj)) {
                    // npc does not need weight, always 0
                    map_insert(space, new_view, get_eid(oldobj),
                               (void *)oldobj);
                } else if (is_monster(oldobj)) {
                    // monster has weight
                    int32_t p_weight = get_weight(oldobj);
                    if (my_left_weight >= p_weight) {
                        my_left_weight = my_left_weight - p_weight;
                        map_insert(space, new_view, get_eid(oldobj),
                                   (void *)oldobj);
                    }
                } else if (is_player(oldobj)) {
                    if (my_eid != get_eid(oldobj)) {
                        // team member has added
                        if (oldobj->m_iTeamEid != 0 &&
                            oldobj->m_iTeamEid == obj->m_iTeamEid) {
                            continue;
                        }
                        int32_t p_weight = get_weight(oldobj);
                        // target is in a team , we handle it next
                        if (is_in_team(space, oldobj) &&
                            !is_team_leader(space, oldobj)) {
                            continue;
                        }
                        // handle team
                        if (is_team_leader(space, oldobj)) {
                            struct aoi_teaminfo *team =
                                (struct aoi_teaminfo *)map_query(
                                    space, space->m_mAllTeam,
                                    oldobj->m_iTeamEid);
                            if (team) {
                                uint16_t j;
                                p_weight = 0;
                                for (j = 0; j < team->ml; j++) {
                                    if (!map_query(space, new_view,
                                                   team->m_lMem[j])) {
                                        p_weight = p_weight + 1;
                                    }
                                }
                            }
                        }
                        int32_t p_left_weight = get_max_other_weight(oldobj) -
                                                get_other_weight(oldobj);
                        if (!is_in_team(space, obj)) {
                            if (map_query(space, get_view(oldobj),
                                          get_eid(obj))) {
                                p_left_weight = p_left_weight + my_weight;
                            }
                        } else if (is_team_leader(space, obj)) {
                            struct aoi_teaminfo *team =
                                (struct aoi_teaminfo *)map_query(
                                    space, space->m_mAllTeam, obj->m_iTeamEid);
                            if (team) {
                                uint16_t j;
                                for (j = 0; j < team->ml; j++) {
                                    if (map_query(space, get_view(oldobj),
                                                  team->m_lMem[j])) {
                                        p_left_weight = p_left_weight + 1;
                                    }
                                }
                            }
                        }

                        if (p_weight > 0 && my_left_weight >= p_weight) {
                            if (p_left_weight >= my_weight) {
                                if (!is_in_team(space, oldobj)) {
                                    my_left_weight = my_left_weight - p_weight;
                                    if (oldobj && !map_query(space, new_view,
                                                             get_eid(oldobj))) {
                                        map_insert(space, new_view,
                                                   get_eid(oldobj),
                                                   (void *)oldobj);
                                    }
                                } else if (is_team_leader(space, oldobj)) {
                                    my_left_weight = my_left_weight - p_weight;
                                    struct aoi_teaminfo *team =
                                        (struct aoi_teaminfo *)map_query(
                                            space, space->m_mAllTeam,
                                            oldobj->m_iTeamEid);
                                    if (team) {
                                        uint16_t j;
                                        for (j = 0; j < team->ml; j++) {
                                            struct aoi_object *mem =
                                                (struct aoi_object *)map_query(
                                                    space, space->m_mAllObject,
                                                    team->m_lMem[j]);
                                            if (mem &&
                                                !map_query(space, new_view,
                                                           get_eid(mem))) {
                                                map_insert(space, new_view,
                                                           get_eid(mem),
                                                           (void *)mem);
                                            }
                                        }
                                    }
                                }
                            } else {
                                if (!is_in_team(space, oldobj) ||
                                    is_team_leader(space, oldobj)) {
                                    if (!map_query(space, new_view2,
                                                   get_eid(oldobj))) {
                                        map_insert(space, new_view2,
                                                   get_eid(oldobj),
                                                   (void *)oldobj);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // object will view the grids which distance is litt than 25
        for (i = 0; i < 25; i++) {
            int8_t dx = GAOI_X_ACTION[i];
            int8_t dy = GAOI_Y_ACTION[i];

            int32_t key = grid_key(space, grid_x + dx, grid_y + dy);
            if (key >= 0) {
                struct aoi_grid *o =
                    (struct aoi_grid *)map_query(space, space->m_mAllGrid, key);
                if (o) {
                    struct aoi_object *npc = get_npc_map(o);
                    while (npc) {
                        if (!map_query(space, new_view, get_eid(npc))) {
                            map_insert(space, new_view, get_eid(npc),
                                       (void *)npc);
                        }
                        npc = npc->next;
                    }
                }
            }
        }
        // object will view the grids's monster which distance is little than 9,
        // if weight enough
        for (i = 0; i < 9; i++) {
            if (my_left_weight <= 0) { break; }

            int8_t dx = GAOI_X_ACTION[i];
            int8_t dy = GAOI_Y_ACTION[i];

            int32_t key = grid_key(space, grid_x + dx, grid_y + dy);
            if (key >= 0) {
                struct aoi_grid *o =
                    (struct aoi_grid *)map_query(space, space->m_mAllGrid, key);
                if (o) {
                    struct aoi_object *pl = get_monster_map(o);
                    while (pl) {
                        if (my_left_weight <= 0) { break; }

                        if (my_eid != get_eid(pl) &&
                            !map_query(space, new_view, get_eid(pl))) {
                            int32_t p_weight = get_weight(pl);
                            if (my_left_weight >= p_weight) {
                                my_left_weight = my_left_weight - p_weight;
                                map_insert(space, new_view, get_eid(pl),
                                           (void *)pl);
                            }
                        }

                        pl = pl->next;
                    }
                }
            }
        }
        // object will view the grids's player which distance is little than 9,
        // if weight enough
        for (i = 0; i < 9; i++) {
            if (my_left_weight <= 0) { break; }

            int8_t dx = GAOI_X_ACTION[i];
            int8_t dy = GAOI_Y_ACTION[i];

            int32_t key = grid_key(space, grid_x + dx, grid_y + dy);
            if (key >= 0) {
                struct aoi_grid *o =
                    (struct aoi_grid *)map_query(space, space->m_mAllGrid, key);
                if (o) {
                    loop_change_link_aoi_object(o);
                    struct aoi_object *pl = get_player_map(o);
                    while (pl) {
                        if (my_left_weight <= 0) { break; }
                        if (pl->m_iTeamEid != 0 &&
                            pl->m_iTeamEid == obj->m_iTeamEid) {
                            pl = pl->next;
                            continue;
                        }
                        if (is_in_team(space, pl) &&
                            !is_team_leader(space, pl)) {
                            pl = pl->next;
                            continue;
                        }
                        if (my_eid != get_eid(pl) &&
                            !map_query(space, new_view, get_eid(pl))) {
                            int32_t p_weight = get_weight(pl);
                            if (is_team_leader(space, pl)) {
                                struct aoi_teaminfo *team =
                                    (struct aoi_teaminfo *)map_query(
                                        space, space->m_mAllTeam,
                                        pl->m_iTeamEid);
                                if (team) {
                                    p_weight = 0;
                                    uint16_t j;
                                    for (j = 0; j < team->ml; j++) {
                                        if (!map_query(space, new_view,
                                                       team->m_lMem[j])) {
                                            p_weight = p_weight + 1;
                                        }
                                    }
                                }
                            }
                            int32_t p_left_weight =
                                get_max_other_weight(pl) - get_other_weight(pl);
                            if (!is_in_team(space, obj)) {
                                if (map_query(space, get_view(pl),
                                              get_eid(obj))) {
                                    p_left_weight = p_left_weight + my_weight;
                                }
                            } else if (is_team_leader(space, obj)) {
                                struct aoi_teaminfo *team =
                                    (struct aoi_teaminfo *)map_query(
                                        space, space->m_mAllTeam,
                                        obj->m_iTeamEid);
                                if (team) {
                                    uint16_t j;
                                    for (j = 0; j < team->ml; j++) {
                                        if (map_query(space, get_view(pl),
                                                      team->m_lMem[j])) {
                                            p_left_weight = p_left_weight + 1;
                                        }
                                    }
                                }
                            }

                            if (p_weight > 0 && my_left_weight >= p_weight) {
                                if (p_left_weight >= my_weight) {
                                    if (!is_in_team(space, pl)) {
                                        my_left_weight =
                                            my_left_weight - p_weight;
                                        if (pl && !map_query(space, new_view,
                                                             get_eid(pl))) {
                                            map_insert(space, new_view,
                                                       get_eid(pl), (void *)pl);
                                        }
                                    } else if (is_team_leader(space, pl)) {
                                        my_left_weight =
                                            my_left_weight - p_weight;
                                        struct aoi_teaminfo *team =
                                            (struct aoi_teaminfo *)map_query(
                                                space, space->m_mAllTeam,
                                                pl->m_iTeamEid);
                                        if (team) {
                                            uint16_t j;
                                            for (j = 0; j < team->ml; j++) {
                                                struct aoi_object *mem =
                                                    (struct aoi_object *)
                                                        map_query(
                                                            space,
                                                            space->m_mAllObject,
                                                            team->m_lMem[j]);
                                                if (mem &&
                                                    !map_query(space, new_view,
                                                               get_eid(mem))) {
                                                    map_insert(space, new_view,
                                                               get_eid(mem),
                                                               (void *)mem);
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    if (!is_in_team(space, pl) ||
                                        is_team_leader(space, pl)) {
                                        if (!map_query(space, new_view2,
                                                       get_eid(pl))) {
                                            map_insert(space, new_view2,
                                                       get_eid(pl), (void *)pl);
                                        }
                                    }
                                }
                            }
                        }
                        pl = pl->next;
                    }
                }
            }
        }
        for (i = 0; i < new_view2->size; i++) {
            if (my_left_weight <= need_weight) { break; }
            if (new_view2->slot[i].obj == NULL) { continue; }
            struct aoi_object *pl = (struct aoi_object *)new_view2->slot[i].obj;
            if (!pl) { continue; }
            if (is_in_team(space, pl) && !is_team_leader(space, pl)) {
                continue;
            }
            if (aoi_kick_object_view(space, pl, my_weight)) {
                int32_t p_weight = get_weight(pl);
                if (is_team_leader(space, pl)) {
                    struct aoi_teaminfo *team =
                        (struct aoi_teaminfo *)map_query(
                            space, space->m_mAllTeam, pl->m_iTeamEid);
                    if (team) { p_weight = team->ml; }
                }
                if (!is_in_team(space, pl)) {
                    my_left_weight = my_left_weight - p_weight;
                    if (pl && !map_query(space, new_view, get_eid(pl))) {
                        map_insert(space, new_view, get_eid(pl), (void *)pl);
                    }
                } else if (is_team_leader(space, pl)) {
                    my_left_weight = my_left_weight - p_weight;
                    struct aoi_teaminfo *team =
                        (struct aoi_teaminfo *)map_query(
                            space, space->m_mAllTeam, pl->m_iTeamEid);
                    if (team) {
                        uint16_t j;
                        for (j = 0; j < team->ml; j++) {
                            struct aoi_object *mem =
                                (struct aoi_object *)map_query(
                                    space, space->m_mAllObject,
                                    team->m_lMem[j]);
                            if (mem &&
                                !map_query(space, new_view, get_eid(mem))) {
                                map_insert(space, new_view, get_eid(mem),
                                           (void *)mem);
                            }
                        }
                    }
                }
            }
        }
    } else if (is_npc(obj)) {
        my_eid = get_eid(obj);
        for (i = 0; i < 25; i++) {
            int8_t dx = GAOI_X_ACTION[i];
            int8_t dy = GAOI_Y_ACTION[i];

            int32_t key = grid_key(space, grid_x + dx, grid_y + dy);
            if (key >= 0) {
                struct aoi_grid *o =
                    (struct aoi_grid *)map_query(space, space->m_mAllGrid, key);
                if (o) {
                    struct aoi_object *pl = get_player_map(o);
                    while (pl) {
                        map_insert(space, new_view, get_eid(pl), (void *)pl);
                        pl = pl->next;
                    }
                }
            }
        }
    } else if (is_monster(obj)) {
        my_weight = get_weight(obj);
        my_eid    = get_eid(obj);

        for (i = 0; i < 9; i++) {
            int8_t dx = GAOI_X_ACTION[i];
            int8_t dy = GAOI_Y_ACTION[i];

            int32_t key = grid_key(space, grid_x + dx, grid_y + dy);
            if (key >= 0) {
                struct aoi_grid *o =
                    (struct aoi_grid *)map_query(space, space->m_mAllGrid, key);
                if (o) {
                    struct aoi_object *pl = get_player_map(o);
                    while (pl) {
                        if (my_eid != get_eid(pl)) {
                            int32_t p_left_weight =
                                get_max_other_weight(pl) - get_other_weight(pl);
                            if (map_query(space, pl->m_mView, get_eid(obj))) {
                                p_left_weight = p_left_weight + my_weight;
                            }

                            if (p_left_weight >= my_weight) {
                                map_insert(space, new_view, get_eid(pl),
                                           (void *)pl);
                            }
                        }

                        pl = pl->next;
                    }
                }
            }
        }

    } else {
        assert(false);
    }

    append_result_leave(result, 0);
    append_result_leave(result, my_eid);
    uint32_t             ll = result->ll_n;
    struct result_action rea1;
    rea1.type  = 1;
    rea1.space = space;
    rea1.old   = old_view;
    rea1.new   = new_view;
    map_foreach(space, old_view, map_foreach_func1, (void *)&rea1);

    append_result_enter(result, 0);
    append_result_enter(result, my_eid);
    uint32_t             le = result->le_n;
    struct result_action rea2;
    rea2.type  = 0;
    rea2.space = space;
    rea2.old   = old_view;
    rea2.new   = new_view;
    map_foreach(space, new_view, map_foreach_func1, (void *)&rea2);

    while (ll < result->ll_n) {
        struct aoi_object *oo = (struct aoi_object *)map_query(
            space, space->m_mAllObject, result->ll[ll]);
        if (oo) {
            leave_view(space, oo, obj);
            leave_view(space, obj, oo);
        }
        ll++;
    }

    while (le < result->le_n) {
        struct aoi_object *oo = (struct aoi_object *)map_query(
            space, space->m_mAllObject, result->le[le]);
        if (oo) {
            enter_view(space, oo, obj);
            enter_view(space, obj, oo);
        }
        le++;
    }

    if (my_eid != 0) { sync_teamleader_view(space, my_eid); }

    map_delete(space, new_view);
    map_delete(space, new_view2);

    new_view  = NULL;
    new_view2 = NULL;

    if (back) {
        my_callback(ud, result->le, result->le_n, result->ll, result->ll_n);
    }
}

static void sync_teamleader_view(struct aoi_space *space, uint32_t eid) {
    struct aoi_object *obj =
        (struct aoi_object *)map_query(space, space->m_mAllObject, eid);
    if (obj && is_player(obj) && is_team_leader(space, obj)) {
        struct map *       new_view    = map_new(space, 256);
        struct map *       leader_view = get_view(obj);
        struct aoi_object *oo          = NULL;
        uint32_t           i           = 0;
        for (i = 0; i < leader_view->size; i++) {
            oo = leader_view->slot[i].obj;
            if (oo) { map_insert(space, new_view, get_eid(oo), (void *)oo); }
        }
        map_insert(space, new_view, get_eid(obj), (void *)obj);
        struct aoi_result *  result = space->result;
        struct aoi_teaminfo *team   = (struct aoi_teaminfo *)map_query(
            space, space->m_mAllTeam, obj->m_iTeamEid);
        if (team) {
            uint32_t j, ll, el;
            for (j = 1; j < team->ml; j++) {
                uint32_t           mem_eid = team->m_lMem[j];
                struct aoi_object *mem     = (struct aoi_object *)map_query(
                    space, space->m_mAllObject, mem_eid);
                if (mem) {
                    map_drop(space, new_view, get_eid(mem));
                    struct map *         old_view = get_view(mem);
                    struct result_action rea1;
                    rea1.type  = 1;
                    rea1.space = space;
                    rea1.old   = old_view;
                    rea1.new   = new_view;
                    append_result_leave(result, 0);
                    append_result_leave(result, mem_eid);
                    ll = result->ll_n;
                    map_foreach(space, old_view, map_foreach_func1,
                                (void *)&rea1);

                    struct result_action rea2;
                    rea2.type  = 0;
                    rea2.space = space;
                    rea2.old   = old_view;
                    rea2.new   = new_view;
                    append_result_enter(result, 0);
                    append_result_enter(result, mem_eid);
                    el = result->le_n;
                    map_foreach(space, new_view, map_foreach_func1,
                                (void *)&rea2);
                    map_insert(space, new_view, get_eid(mem), (void *)mem);

                    while (ll < result->ll_n) {
                        struct aoi_object *oo = (struct aoi_object *)map_query(
                            space, space->m_mAllObject, result->ll[ll]);
                        if (oo) {
                            leave_view(space, oo, mem);
                            leave_view(space, mem, oo);
                        }
                        ll++;
                    }

                    while (el < result->le_n) {
                        struct aoi_object *oo = (struct aoi_object *)map_query(
                            space, space->m_mAllObject, result->le[el]);
                        if (oo) {
                            enter_view(space, oo, mem);
                            enter_view(space, mem, oo);
                        }
                        el++;
                    }
                }
            }
        }
        map_delete(space, new_view);
        new_view = NULL;
    }
}

void aoi_update_object_weight(struct aoi_space *space,
                              void *            ud,
                              aoi_Callback      my_callback,
                              uint32_t          eid,
                              uint8_t           weight) {
    struct aoi_object *obj =
        (struct aoi_object *)map_query(space, space->m_mAllObject, eid);
    assert(obj && is_player(obj) && weight >= 0);

    uint8_t my_weight = get_weight(obj);
    set_weight(obj, weight);

    int8_t add_weight = weight - my_weight;

    struct aoi_result *result = space->result;
    if (add_weight == 0) {
        init_result(result);
        my_callback(ud, result->le, result->le_n, result->ll, result->ll_n);
        return;
    } else {
        struct map *old_view = get_view(obj);

        if (add_weight > 0) {
            init_result(result);

            struct weight_action wea;
            wea.space      = space;
            wea.add_weight = add_weight;
            map_foreach(space, old_view, map_foreach_func2, (void *)&wea);

            uint32_t i = 0;
            while (i < result->ll_n) {
                struct aoi_object *oo = (struct aoi_object *)map_query(
                    space, space->m_mAllObject, result->ll[i]);
                if (oo) {
                    leave_view(space, oo, obj);
                    leave_view(space, obj, oo);
                }
                i++;
            }

            int8_t over_num = get_other_weight(obj) - get_max_other_weight(obj);
            if (over_num > 0) {
                struct map *old_view2 = get_view(obj);

                struct weight_action wea2;
                wea2.space      = space;
                wea2.add_weight = over_num;
                map_foreach(space, old_view2, map_foreach_func6, (void *)&wea2);

                uint32_t j = i;
                while (j < result->ll_n) {
                    struct aoi_object *oo = (struct aoi_object *)map_query(
                        space, space->m_mAllObject, result->ll[j]);
                    if (oo) {
                        leave_view(space, oo, obj);
                        leave_view(space, obj, oo);
                    }
                    j++;
                }
            }

            my_callback(ud, result->le, result->le_n, result->ll, result->ll_n);
        } else {
            init_result(result);

            struct weight_action wea;
            wea.space      = space;
            wea.add_weight = add_weight;
            map_foreach(space, old_view, map_foreach_func3, (void *)&wea);

            my_callback(ud, result->le, result->le_n, result->ll, result->ll_n);
        }
    }
}

void aoi_remove_object(struct aoi_space *space,
                       void *            ud,
                       aoi_Callback      my_callback,
                       uint32_t          eid) {
    struct aoi_object *obj =
        (struct aoi_object *)map_query(space, space->m_mAllObject, eid);
    assert(obj);

    struct aoi_result *result = space->result;

    init_result(result);

    struct map *old_view = get_view(obj);
    map_foreach(space, old_view, map_foreach_func4, (void *)space);

    uint32_t i = 0;
    while (i < result->ll_n) {
        struct aoi_object *oo = (struct aoi_object *)map_query(
            space, space->m_mAllObject, result->ll[i]);
        if (oo) {
            leave_view(space, oo, obj);
            leave_view(space, obj, oo);
        }
        i++;
    }

    int16_t now_x, now_y;
    get_pos(obj, &now_x, &now_y);
    if (now_x >= 0 && now_y >= 0) {
        int32_t old_key = grid_key(space, now_x, now_y);
        if (old_key >= 0) {
            struct aoi_grid *old_grid =
                (struct aoi_grid *)map_query(space, space->m_mAllGrid, old_key);
            if (old_grid) { unlink_aoi_object(old_grid, obj); }
        }
    }
    map_drop(space, space->m_mAllObject, eid);
    free_object((void *)space, eid, (void *)obj);

    my_callback(ud, result->le, result->le_n, result->ll, result->ll_n);
}

/**
 * @brief get a object's view
 *
 * @param space aoi_space
 * @param eid entity id
 * @param type entity type
 * @param lo pointer of int list to save the return ids
 * @param lo_max result list size
 * @param lo_size use to save the return size
 */
void aoi_get_view(struct aoi_space *space,
                  uint32_t          eid,
                  uint8_t           type,
                  uint32_t *        lo,
                  uint32_t          lo_max,
                  uint32_t *        lo_size) {
    struct aoi_object *obj =
        (struct aoi_object *)map_query(space, space->m_mAllObject, eid);
    assert(obj);

    if (!type) {
        *lo_size = get_view_list(space, obj, lo, lo_max);
    } else {
        *lo_size = get_view_list_by_type(space, obj, type, lo, lo_max);
    }
}

static inline struct map_slot *mainposition(struct map *m, uint32_t id) {
    uint32_t hash = id & (m->size - 1);
    return &m->slot[hash];
}

static int map_foreach_func1(void *ud, uint32_t key, void *obj) {
    struct result_action *ac     = (struct result_action *)ud;
    uint8_t               type   = ac->type;
    struct aoi_space *    space  = ac->space;
    struct aoi_result *   result = space->result;
    struct map *          old    = ac->old;
    struct map *new              = ac->new;

    if (type) {
        if (!map_query(space, new, key)) { append_result_leave(result, key); }
    } else {
        if (!map_query(space, old, key)) { append_result_enter(result, key); }
    }

    return 0;
}

static int map_foreach_func2(void *ud, uint32_t key, void *obj) {
    struct weight_action *ac         = (struct weight_action *)ud;
    struct aoi_space *    space      = ac->space;
    struct aoi_result *   result     = space->result;
    int8_t                add_weight = ac->add_weight;

    struct aoi_object *oo =
        (struct aoi_object *)map_query(space, space->m_mAllObject, key);
    if (oo) {
        int32_t max_other_weight = get_max_other_weight(oo);
        if (max_other_weight < 0) {
            supple_other_weight(oo, add_weight);
        } else {
            int32_t left_weight = max_other_weight - get_other_weight(oo);
            if (add_weight > left_weight) {
                append_result_leave(result, key);
            } else {
                supple_other_weight(oo, add_weight);
            }
        }
    }

    return 0;
}

static int map_foreach_func3(void *ud, uint32_t key, void *obj) {
    struct weight_action *ac         = (struct weight_action *)ud;
    struct aoi_space *    space      = ac->space;
    int8_t                add_weight = ac->add_weight;

    struct aoi_object *oo =
        (struct aoi_object *)map_query(space, space->m_mAllObject, key);
    if (oo) { supple_other_weight(oo, add_weight); }

    return 0;
}

static int map_foreach_func4(void *ud, uint32_t key, void *obj) {
    struct aoi_space * space  = (struct aoi_space *)ud;
    struct aoi_result *result = space->result;

    struct aoi_object *oo =
        (struct aoi_object *)map_query(space, space->m_mAllObject, key);
    if (oo) { append_result_leave(result, key); }

    return 0;
}

static int map_foreach_func5(void *ud, uint32_t key, void *obj) {
    struct view_action *ac      = (struct view_action *)ud;
    struct aoi_space *  space   = ac->space;
    uint8_t             type    = ac->type;
    uint32_t *          lo      = ac->lo;
    uint32_t            lo_max  = ac->lo_max;
    uint32_t            lo_size = ac->lo_size;

    if (lo_size >= lo_max) { return 1; }

    struct aoi_object *oo =
        (struct aoi_object *)map_query(space, space->m_mAllObject, key);
    if (oo) {
        if (!type) {
            lo[lo_size] = key;
            ac->lo_size++;
        } else {
            if (oo->m_iAcType == type) {
                lo[lo_size] = key;
                ac->lo_size++;
            }
        }
    }

    return 0;
}

static int map_foreach_func6(void *ud, uint32_t key, void *obj) {
    struct weight_action *ac         = (struct weight_action *)ud;
    struct aoi_space *    space      = ac->space;
    struct aoi_result *   result     = space->result;
    int8_t                add_weight = ac->add_weight;

    if (add_weight <= 0) { return 1; }

    struct aoi_object *oo =
        (struct aoi_object *)map_query(space, space->m_mAllObject, key);
    if (oo) {
        uint8_t other_weight = get_weight(oo);
        if (other_weight > 0) {
            append_result_leave(result, key);
            ac->add_weight = ac->add_weight - other_weight;
        }
    }

    return 0;
}