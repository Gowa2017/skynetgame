local skynet  = require("skynet")
local LOG     = require("go.logger")

--- 接收控制指令,主要接收：网关启动事件，slave 发过来关闭指令
local CMD     = {}
--- 接收套接字事件
local SOCKET  = {}
--- gatserver
local gate   
--- 套接字ID到认证服务映射
local agent   = {}
--- 认证服务表
local slave   = {}
--- 认证服务分派ID
local balance = 1

---当套接字关闭或者出错的时候，就会执行
---当 slave 发送 close 命令的时候也会执行
---通知网关关闭套接字
---通知 slave 套接字已关闭
---@param fd number
local function close_agent(fd)
  local a = agent[fd]
  agent[fd] = nil
  if a then
    skynet.call(gate, "lua", "kick", fd)
    -- disconnect never return
    skynet.send(a, "lua", "disconnected", fd)
  end
end

function SOCKET.open(fd, addr)
  local s = slave[balance]
  balance = balance + 1
  if balance > #slave then balance = 1 end
  agent[fd] = s
  LOG.info("New connection: %d,%s --> %s", fd, addr, skynet.address(s))
  skynet.send(s, "lua", "connected", fd, addr, gate)
end

function SOCKET.close(fd)
  LOG.info("socket close %d", fd)
  close_agent(fd)
end

function SOCKET.error(fd, msg)
  LOG.error("socket error %d: %s", fd, msg)
  close_agent(fd)
end

function SOCKET.warning(fd, size)
  -- size K bytes havn't send out in fd
  LOG.warning("socket warning: %d, %d", fd, size)
end

function SOCKET.data(fd, msg) assert(agent[fd], "no connections") end

function CMD.start(conf)
  local n = conf.slave or 8
  for i = 1, n do
    local s = skynet.newservice("auth", i)
    slave[#slave + 1] = s
    skynet.call(s, "lua", "start", skynet.self(), gate)
  end
  skynet.call(gate, "lua", "open", conf)
end

function CMD.close(fd)
  LOG.info("CMD:close %d", fd)
  close_agent(fd)
end

local service = require("go.service")
service.setMessageCmds("lua", { socket = SOCKET, cmd    = CMD }, true, false)
service.start(function() gate = skynet.newservice("gate") end)
