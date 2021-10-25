-- LuaFormatter off
root        = "./"
skynet      = root .. "skynet/"
skynetgo    = root .. "skynetgo/"
luaservice  = root .. "service/?.lua;" .. root .. "service/?/main.lua;" ..
              --skynetgo .. 'service/?.lua;' ..skynetgo .. 'service/?/main.lua;' ..
              skynet .. "service/?.lua;" .. skynet .. "service/?/main.lua;" ..
              root .. "test/service/?.lua"
lua_path    = root .. "lualib/?.lua;" .. root .. "lualib/?/init.lua;" ..
              skynet .. "lualib/?.lua;" ..
              skynetgo .. "?.lua"
lua_cpath   = root .. "luaclib/?.so;" .. skynet .. "luaclib/?.so;" ..
              skynetgo .. "luaclib/?.so"
cpath       = root .. "cservice/?.so;" .. skynet .. "cservice/?.so"
lualoader   = skynet .. "lualib/loader.lua"
-- LuaFormatter on
