local config = {}
loadfile("./config.path.lua", "bt", config)()
package.path = package.path .. ";" .. config.lua_path
package.cpath = package.cpath .. ";" .. config.lua_cpath
