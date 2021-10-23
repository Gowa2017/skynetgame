local service  = require("go.service")
local netproto = require("netproto")
netproto.init()

local cmd      = import("service.auth.cmds.lua.lua")
service.enableMessage("client")
service.setMessageCmds("lua", cmd)
service.setMessageCmds("client",
                       { login = import("service.auth.cmds.client.login") },
                       false, true)
service.start()
