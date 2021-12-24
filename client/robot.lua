package.cpath = package.path .. ";./skynet/luaclib/?.so"
print(package.cpath)
local socket  = require "client.socket"
local crypt   = require "client.crypt"
local tinsert = table.insert
local tremove = table.remove
local tunpack = table.unpack
local proto   = require("client.proto")

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
local Robot   = {}

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
    timers                  = {},
    callers                 = {},
    server_request_handlers = {},
    running                 = true,
    token                   = { server = "sample", user   = "a", pass   = "b" },
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

function Robot:parse_cmd(s)
  if s == "" or s == nil then
    return false
  end

  local cmd       = ""
  local args_data = nil
  local b, e      = string.find(s, " ")
  if b then
    cmd = s:sub(0, b - 1)
    args_data = s:sub(e + 1)
  else
    cmd = s
  end
  if cmd == "script" then
    if not args_data then
      print("illegal cmd", s)
      return false
    end
    return true, cmd, args_data
  end

  local args     
  if args_data then
    local f, err    = load("return " .. args_data)
    if f == nil then
      print("illegal cmd", s)
      return false
    end

    local ok, _args = pcall(f)
    if (not ok) or (type(_args) ~= "table") then
      print("illegal cmd", s)
      return false
    end

    args = _args
  end

  return true, cmd, args
end

local session = 0
--- 执行命令，实际上这个就是向服务端发送消息
---@param cmd string @协议名称
---@param args table | string @协议数据
---@return boolean
function Robot:run_cmd(cmd, args)
  session = session + 1
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
end

---读取标准输入的数据
function Robot:check_console()
  local s = socket.readstdin()
  if s == "quit" then
    self.running = false
    return
  end
  if s == "." then
    s = [[C2GSGMCmd {cmd="runtest"}]]
  end
  if (s ~= nil and s ~= "") then
    local ok, cmd, args = self:parse_cmd(s)
    if ok then
      if cmd == "script" then
        self:fork(self.run_script, self, args)
      else
        self:fork(self.run_cmd, self, cmd, args)
      end
    end
  end
end

---读取网络和标准输入的输入
function Robot:check_io()
  local ok, err = pcall(function()
    while self.running do
      self:check_net_package()
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
  self.readline = proto.unpacker_line(self.fd)
  local challenge = crypt.base64decode(self.readline())
  print("chanllenge", challenge)
  local clientkey = crypt.randomkey()
  proto.writeline(self.fd, crypt.base64encode(crypt.dhexchange(clientkey)))
  local secret    = crypt.dhsecret(crypt.base64decode(self.readline()),
                                   clientkey)

  self.secret = secret
  print("sceret is ", crypt.hexencode(secret))

  local hmac      = crypt.hmac64(challenge, secret)
  proto.writeline(self.fd, crypt.base64encode(hmac))

  local function encode_token(token)
    return string.format("%s@%s:%s", crypt.base64encode(token.user),
                         crypt.base64encode(token.server),
                         crypt.base64encode(token.pass))
  end

  local etoken    = crypt.desencode(secret, encode_token(self.token))
  local b         = crypt.base64encode(etoken)
  proto.writeline(self.fd, crypt.base64encode(etoken))

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
  self.index = 0

  local handshake = string.format("%s@%s#%s:%d",
                                  crypt.base64encode(self.token.user),
                                  crypt.base64encode(self.token.server),
                                  crypt.base64encode(self.subid), self.index)
  local hmac      = crypt.hmac64(crypt.hashkey(handshake), self.secret)

  self.readpackage = proto.unpacker_package(self.fd)
  proto.send_package(self.fd, handshake .. ":" .. crypt.base64encode(hmac))

  print(self.readpackage())
  print("===>", proto.send_request(self.fd, "echo", self.index))
  -- don't recv response
  -- print("<===",recv_response(readpackage()))

  print("disconnect")
  socket.close(self.fd)

  self.index = self.index + 1

  print("connect again")
  self.fd = assert(socket.connect("127.0.0.1", 8888))
  self.last = ""

  local handshake = string.format("%s@%s#%s:%d",
                                  crypt.base64encode(self.token.user),
                                  crypt.base64encode(self.token.server),
                                  crypt.base64encode(self.subid), self.index)
  local hmac      = crypt.hmac64(crypt.hashkey(handshake), self.secret)

  proto.send_package(self.fd, handshake .. ":" .. crypt.base64encode(hmac))

  print(self.readpackage())
  print("===>", proto.send_request(self.fd, "fake", 0)) -- request again (use last session 0, so the request message is fake)
  print("===>", proto.send_request(self.fd, "again", 1)) -- request again (use new session)
  print("<===", proto.recv_response(self.readpackage()))
  print("<===", proto.recv_response(self.readpackage()))

  print("disconnect")
  socket.close(self.fd)

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
