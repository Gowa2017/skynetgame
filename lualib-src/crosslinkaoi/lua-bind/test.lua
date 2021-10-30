local laoi = require "laoi"

local OBJ = {}
local check_leave_aoi = true
local map_size = {100,100,100}
local view_size = {4.5,4.5,4.5}
-- 2d
--local map_size = {100,100,0}
--local view_size = {4.5,4.5,0}

function init_obj(id,pos,v,mode)
	OBJ[id] = {
		pos = pos,
		v = v,
		mode = mode,
	}
end

function update_obj(aoi,id)
	for i=1,3 do
		OBJ[id].pos[i] = OBJ[id].pos[i] + OBJ[id].v[i]
		if OBJ[id].pos[i] > map_size[i] then
			OBJ[id].pos[i] = OBJ[id].pos[i] - map_size[i]
		elseif OBJ[id].pos[i] < 0.0 then
			OBJ[id].pos[i] = OBJ[id].pos[i] + map_size[i]
		end
	end
	--laoi.move(aoi,id,OBJ[id].pos[1],OBJ[id].pos[2],OBJ[id].pos[3])
	aoi:move(id,OBJ[id].pos[1],OBJ[id].pos[2],OBJ[id].pos[3])
end

function in_view(pos1,pos2)
	for i=1,3 do
		if math.abs(pos1[i]-pos2[i]) > view_size[i] then
			return false
		end
	end
	return true
end

function enterAOI(aoi,watcher,marker)
	print(string.format("op=enterAOI,watcher=[id=%d,pos=(%.1f,%.1f,%.1f)],marker=[id=%d,pos=(%.1f,%.1f,%.1f)]",
			watcher,OBJ[watcher].pos[1],OBJ[watcher].pos[2],OBJ[watcher].pos[3],
			marker,OBJ[marker].pos[1],OBJ[marker].pos[2],OBJ[marker].pos[3]))
	assert(in_view(OBJ[watcher].pos,OBJ[marker].pos))
end

function leaveAOI(aoi,watcher,marker)
	print(string.format("op=leaveAOI,watcher=[id=%d,pos=(%.1f,%.1f,%.1f)],marker=[id=%d,pos=(%.1f,%.1f,%.1f)]",
			watcher,OBJ[watcher].pos[1],OBJ[watcher].pos[2],OBJ[watcher].pos[3],
			marker,OBJ[marker].pos[1],OBJ[marker].pos[2],OBJ[marker].pos[3]))
	if (check_leave_aoi) then
		assert(not in_view(OBJ[watcher].pos,OBJ[marker].pos))
	end
end

function test(aoi)
	check_leave_aoi = true
	-- w(atcher) m(arker)
	init_obj(0,{40,0,0},{0,2,0},"wm")
	init_obj(1,{42,100,0},{0,-2,0},"wm")
	init_obj(2,{0,40,0},{2,0,0},"w")
	init_obj(3,{100,42,0},{-2,0,0},"w")
	init_obj(4,{42,40,1},{0,0,2},"wm")
	init_obj(5,{40,42,100},{0,0,-2},"w")
	init_obj(6,{40,42,100},{0,0,-2},"m")
	for i=0,6 do
		--laoi.enter(aoi,i,OBJ[i].pos[1],OBJ[i].pos[2],OBJ[i].pos[3],OBJ[i].mode)
		aoi:enter(i,OBJ[i].pos[1],OBJ[i].pos[2],OBJ[i].pos[3],OBJ[i].mode)
	end
	for i=1,100 do
		if i < 50 then
			for j=0,6 do
				update_obj(aoi,j)
			end
		elseif i == 50 then
			OBJ[6].mode = "wm"
			--laoi.change_mode(aoi,6,OBJ[6].mode)
			aoi:change_mode(6,OBJ[6].mode)
		else
			for j=0,6 do
				update_obj(aoi,j)
			end
		end
	end
	local range = {4,4,0}
	local pos = {40,4,0}
	--local ids = laoi.get_view_by_pos(aoi,pos[1],pos[2],pos[3],range[1],range[2],range[3])
	local ids = aoi:get_view_by_pos(pos[1],pos[2],pos[3],range[1],range[2],range[3])
	--local ids = aoi:get_view_by_pos(pos[1],pos[2],pos[3])
	if (#ids > 0) then
		print(string.format("op=get_view_by_pos,pos=(%.1f,%.1f,%.1f),range=(%.1f,%.1f,%.1f),ids=%s",
		pos[1],pos[2],pos[3],range[1],range[2],range[3],table.concat(ids,",")))
	end
	local id = 5
	--local ids = laoi.get_view(id,aoi,range[1],range[2],range[3])
	local ids = aoi:get_view(id,range[1],range[2],range[3])
	--local ids = aoi:get_view(id)
	if (#ids > 0) then
		print(string.format("op=get_view,id=%d,pos=(%.1f,%.1f,%.1f),range=(%.1f,%.1f,%.1f),ids=%s",
		id,OBJ[id].pos[1],OBJ[id].pos[2],OBJ[id].pos[3],range[1],range[2],range[3],table.concat(ids,",")))
	end

	check_leave_aoi = false
	for i=0,6 do
		--laoi.leave(aoi,i)
		aoi:leave(i)
	end
end

function main()
	local aoi = laoi.new(map_size[1],map_size[2],map_size[3],view_size[1],view_size[2],view_size[3],enterAOI,leaveAOI)
	test(aoi)
end

main()
