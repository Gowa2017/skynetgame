#ifndef _GAOI_H
#define _GAOI_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef void *(*aoi_Alloc)(void *ud, void *ptr, size_t sz);
typedef void (*aoi_Callback)(
    void *ud, uint32_t *le, uint32_t le_n, uint32_t *ll, uint32_t ll_n);
typedef void (*aoi_ReviceTeamInfo)(void *ud, uint32_t *m, uint8_t *l);

struct aoi_space;

struct aoi_space *aoi_create_space(aoi_Alloc my_alloc,
                                   void *    ud,
                                   uint16_t  iMaxX,
                                   uint16_t  iMaxY,
                                   uint8_t   iGridX,
                                   uint8_t   iGridY);
void              aoi_release(struct aoi_space *oAoi);

void aoi_create_object(struct aoi_space *oAoi,
                       void *            ud,
                       aoi_Callback      my_callback,
                       uint32_t          iEid,
                       uint8_t           iType,
                       uint8_t           iAcType,
                       uint8_t           iWeight,
                       uint16_t          iLimit,
                       float             fX,
                       float             fY);
void aoi_remove_object(struct aoi_space *oAoi,
                       void *            ud,
                       aoi_Callback      my_callback,
                       uint32_t          iEid);
void aoi_update_object_position(struct aoi_space *oAoi,
                                void *            ud,
                                aoi_Callback      my_callback,
                                uint32_t          iEid,
                                float             fX,
                                float             fY,
                                bool              bForce,
                                bool              bBack);
void aoi_update_object_weight(struct aoi_space *oAoi,
                              void *            ud,
                              aoi_Callback      my_callback,
                              uint32_t          iEid,
                              uint8_t           iWeight);

void aoi_get_view(struct aoi_space *oAoi,
                  uint32_t          iEid,
                  uint8_t           iType,
                  uint32_t *        lo,
                  uint32_t          lo_max,
                  uint32_t *        lo_size);

void aoi_create_team(struct aoi_space * oAoi,
                     void *             ud,
                     aoi_Callback       my_callback,
                     aoi_ReviceTeamInfo my_recive,
                     uint32_t           iEid);

void aoi_remove_team(struct aoi_space *oAoi, uint32_t iEid);

void aoi_update_team(struct aoi_space * oAoi,
                     void *             ud,
                     aoi_Callback       my_callback,
                     aoi_ReviceTeamInfo my_recive,
                     uint32_t           iEid);

#endif
