local gaoi       = {}
---@class GAOI_SPACE
local GAOI_SPACE = {}
---Create a AOI_SPACE which size is (x,y), and divide it into grids of size (gridx, gridy)
---@param x number xsize
---@param y number xsize
---@param gridx number grid xsize
---@param gridy number grid ysize
---@return GAOI_SPACE
function gaoi.create(x, y, gridx, gridy)
end
---add a object into space
---@param eid integer
---@param etype integer # must 1 player 2 npc 3 monster
---@param actype integer
---@param weight integer # every object has a weight, NPC is always 0
---@param limit integer # limit - self weight is the weight a object can view, and team member will need weight
---@param x number
---@param y number
---@return table[], table[] #enter id list, leave id list
function GAOI_SPACE:addObject(eid, etype, actype, weight, limit, x, y)
end
---remove a entity
---@param eid integer
---@return table[], table[] #enter id list, leave id list
function GAOI_SPACE:removeObject(eid)
end
---update a object's position
---@param eid integer
---@param x number
---@param y number
---@param force boolean
---@return table[], table[] #enter id list, leave id list
function GAOI_SPACE:updatePosition(eid, x, y, force)
end
---update a objects' weight
---@param eid integer
---@param weight integer
---@return table[], table[] #enter id list, leave id list
function GAOI_SPACE:updateWeight(eid, weight)
end
---@param eid integer
---@param actype integer
---@return integer[] # id list
function GAOI_SPACE:getview(eid, actype)
end
---remove a team
---@param eid integer
function GAOI_SPACE:removeTeam(eid)
end
---add a team to space
---@param eid integer
---@param members integer[] #members list
---@param short integer[] #short leaver member list
---@return table[], table[] #enter id list, leave id list
function GAOI_SPACE:addTeam(eid, members, short)
end
---update a team
---@param eid integer
---@param members integer[] #members list
---@param short integer[] #short leaver member list
---@return table[], table[] #enter id list, leave id list
function GAOI_SPACE:updateTeam(eid, members, short)
end
return gaoi
