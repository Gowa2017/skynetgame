local protopb   = require "client.protopb"
package.cpath = package.path .. ";./skynet/luaclib/?.so"
package.path = package.path .. ";3rd/Penlight/lua/?.lua"
local socket    = require "client.socket"
local crypt     = require "client.crypt"

local tinsert   = table.insert
local tremove   = table.remove
local tunpack   = table.unpack
local tconcat   = table.concat
local unpack    = require("client.unpack")
local protoline = require("client.protoline")

local function Trace(msg)
  print(debug.traceback(msg))
end

function safeCall(f, ...)
  return xpcall(f, Trace, ...)
end
---机器人包括了多个线程这执行
---至少包含：
---一个IO线程
---一个指定的脚本线程
---@class Robot
---@field host string
---@field port number
---@field fd number @到 host:port 的连接套接字
---@field last string @未解包的数据
---@field slient boolean @静默模式？
---@field coroutines table @线程列表
---@field timers table @定时器列表
---@field callers table @调用着
---@field server_request_handlers table @消息处理器
---@field running boolean @是否运行中
local Robot     = {}

function Robot.new(host, port, gamehost, gameport, opts)
  assert(host, "need host")
  assert(port, "need port")
  assert(gamehost, "need gamehost")
  assert(gameport, "need gameport")
  opts = opts or {}
  local obj = {
    gamehost                = gamehost,
    gameport                = gameport,
    host                    = host,
    port                    = port,
    fd                      = assert(socket.connect(host, port)),
    last                    = "",
    slient                  = opts.slient,
    -- shield = {},
    coroutines              = {},
    session_cos             = {},
    timers                  = {},
    callers                 = {},
    server_request_handlers = {},
    running                 = true,
    token                   = { server = "sample", user   = "a", pass   = "b" },
    index                   = 1,
    serial                  = opts.serial or "line",
  }
  setmetatable(obj, { __index = Robot })
  return obj
end

--- 建立一个协程来执行函数
--- 所有的线程（协程）都放到 Robot.coroutines 里面
function Robot:fork(func, ...)
  local args = { ... }
  local co   = coroutine.create(function()
    safeCall(func, tunpack(args))
  end)
  tinsert(self.coroutines, co)
end

--- 睡眠，放会由 timer 来唤醒
---@param n number
function Robot:sleep(n)
  local waiter = {
    co   = coroutine.running(),
    done = false,
    time = os.time() + n,
  }

  tinsert(self.timers, waiter)

  while true do
    if waiter.done then
      break
    end

    coroutine.yield()
  end
end

---响应服务端数据
---@param name string
---@param args boolean|table
function Robot:handle_server_request(name, args)
end

---parse commands
---@param input string
---@return boolean
---@return string
---@return any
function Robot:parse_cmd(input)
  local t    = {}
  for s in string.gmatch(input, "[%a%w%.]+") do
    table.insert(t, s)
  end
  if #t < 1 then
    return false, "非法指令"
  end

  if #t % 2 == 0 then
    return false, "指令必须是基数个"
  end
  if #t == 1 then
    return true, input
  end
  local args = {}
  for i = 2, #t, 2 do
    args[t[i]] = t[i + 1]
  end
  return true, t[1], args
end

--- 执行命令，实际上这个就是向服务端发送消息
---@param cmd string @协议名称
---@param args table | string @协议数据
---@return boolean
function Robot:run_cmd(cmd, args)
  -- self.index = self.index + 1
  local v = args and (cmd .. " " .. args) or cmd
  self.net.send_request(self.fd, v, self.index)
end

--- 这个执行脚本会在一个新线程中进行加载
function Robot:run_script(script)
  if not self.slient then
    print("[script]", script)
  end

  local env       = setmetatable({ client = self }, { __index = _ENV })

  local func, err = loadfile(script, "bt", env)
  if not func then
    print("load script fail, err", err)
    return
  end

  safeCall(func)
end

---检查网络数据
---当连接上服务器后服务会下发挑战或者握手信息，进行驱动
---* 经过几步来进行处理
---* 1 检查网络数据
---* 2 异或处理
---* 3 解包
---* 4 调用 handler
function Robot:check_net_package()
  while true do
    local ok, data                  = pcall(self.readpackage)
    if not ok then
      self.running = false
      print(data)
    end
    local resp, content, session, t = self.net.recv_response(data)
    local co                        = self.session_cos[session]
    coroutine.resume(co, content)
    self.session_cos[session] = nil
    -- coroutine.yield()
  end
end

---读取标准输入的数据
---. will run the default cmd
---script will run a script
---other will be a command
function Robot:check_console()
  local s             = socket.readstdin()
  if not s or #s == 0 then
    return
  end
  if s == "quit" then
    self.running = false
    return
  end
  if s == "." then
    s = "c2s.game.Enter map \"1001\""
  end
  if not s:find("%.") then
    s = "c2s.game." .. s
  end
  local ok, cmd, args = self:parse_cmd(s)
  if not ok then
    return
  end
  self.index = self.index + 1
  local co            = coroutine.create(function(...)
    print("run command", ...)
    local ok, r = pcall(self.net.send_request, ...)
    if not ok then
      print(r)
      return
    end
    local resp  = coroutine.yield()
    for k, v in pairs(resp) do
      print(k, v)
    end
  end)
  self.session_cos[self.index] = co
  coroutine.resume(co, self.fd, args, self.index, cmd)
end

---读取网络和标准输入的输入
function Robot:check_io()
  local ok, err = pcall(function()
    while self.running do
      self:check_console()
      coroutine.yield()
      -- wait next
    end
  end)
  if not ok then
    print("[ERROR]:", err)
    self.running = false
  end
end
function Robot:login()
  print("login....", self.fd)
  self.readline = unpack(protoline.unpack_line, self.fd)
  local challenge = crypt.base64decode(self.readline())
  print("chanllenge", challenge)
  local clientkey = crypt.randomkey()
  protoline.writeline(self.fd, crypt.base64encode(crypt.dhexchange(clientkey)))
  local secret    = crypt.dhsecret(crypt.base64decode(self.readline()),
                                   clientkey)

  self.secret = secret
  print("sceret is ", crypt.hexencode(secret))

  local hmac      = crypt.hmac64(challenge, secret)
  protoline.writeline(self.fd, crypt.base64encode(hmac))

  local function encode_token(token)
    return string.format("%s@%s:%s", crypt.base64encode(token.user),
                         crypt.base64encode(token.server),
                         crypt.base64encode(token.pass))
  end

  local etoken    = crypt.desencode(secret, encode_token(self.token))
  local b         = crypt.base64encode(etoken)
  protoline.writeline(self.fd, crypt.base64encode(etoken))

  local result    = self.readline()
  print(result)
  local code      = tonumber(string.sub(result, 1, 3))
  assert(code == 200)
  socket.close(self.fd)
  local subid     = crypt.base64decode(string.sub(result, 5))
  self.subid = subid
  print("login ok, subid=", subid)
  self:fork(self.game, self)

end

function Robot:game()
  print("connect to game server")
  self.fd = assert(socket.connect(self.gamehost, self.gameport))
  self.last = ""

  local handshake = string.format("%s@%s#%s:%d",
                                  crypt.base64encode(self.token.user),
                                  crypt.base64encode(self.token.server),
                                  crypt.base64encode(self.subid), self.index)
  local hmac      = crypt.hmac64(crypt.hashkey(handshake), self.secret)
  self.net = self.serial == "pb" and protopb or require("client.protopackage")

  self.readpackage = unpack(self.net.unpack_package, self.fd)
  self.net.send_package(self.fd, handshake .. ":" .. crypt.base64encode(hmac))

  print(self.readpackage())
  -- proto.send_request(self.fd, "echo", self.index)
  -- self.index = self.index + 1
  self:fork(self.check_net_package, self)
end
---主循环，执行换一个循环后即让出，由 client 再次调度过来
function Robot:start()
  print("start...")
  self:fork(self.check_io, self)
  self:fork(self.login, self)
  while self.running do
    -- check coroutine
    local co_normal  = {}
    -- copy before iter
    local co_deaded  = {}

    for _, co in ipairs(self.coroutines) do
      if coroutine.status(co) == "dead" then
        co_deaded[co] = true
      else
        tinsert(co_normal, co)
      end
    end

    for _, co in ipairs(co_normal) do
      -- double check co status
      if coroutine.status(co) ~= "dead" then
        coroutine.resume(co)
      end
    end

    for co, _ in pairs(co_deaded) do
      local target_idx
      for idx, co2 in ipairs(self.coroutines) do
        if co == co2 then
          target_idx = idx
          break
        end
      end
      if target_idx then
        tremove(self.coroutines, target_idx)
      end
    end

    -- check timer
    local awake_list = {}
    -- copy before iter
    local t_now      = os.time()

    for idx = #self.timers, 1, -1 do
      local item = self.timers[idx]
      if coroutine.status(item.co) == "dead" then
        tremove(self.timers, idx)
      elseif item.time <= t_now then
        tremove(self.timers, idx)
        tinsert(awake_list, item)
      end
    end

    for _, waiter in ipairs(awake_list) do
      if coroutine.status(waiter.co) ~= "dead" then
        waiter.done = true
        coroutine.resume(waiter.co)
      end
    end

    coroutine.yield()
  end
end

function Robot:stop()
  self.running = false
end

return Robot
