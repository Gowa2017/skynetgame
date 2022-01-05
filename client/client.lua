local Robot    = require("client.robot")
package.cpath = "./skynet/luaclib/?.so"
local socket   = require("client.socket")
local argparse = require "client.argparse"

local clients  = { n = 0 }
local deaded   = {}
local function client(idx, conf)
  conf.user = conf.flag .. tostring(idx)
  conf.pass = conf.flag .. tostring(idx)
  local r  = Robot(conf)
  local co = coroutine.create(function()
    r:start()
  end)
  clients[co] = conf.user
  clients.n = clients.n + 1
end

local function run()
  while true do
    for co, _ in pairs(clients) do
      if type(co) ~= "thread" then
        goto continue
      end
      if coroutine.status(co) == "dead" then
        deaded[co] = true
      else
        --- here we catch the robot's error
        local ok, err = coroutine.resume(co)
        if not ok then
          print(clients[co], err)
          deaded[co] = true
        end
      end
      ::continue::
    end
    for co, _ in pairs(deaded) do
      clients[co] = nil
      clients.n = clients.n - 1
    end
    deaded = {}
    if clients.n < 1 then
      return
    end
    print("Clients:", clients.n)
    socket.usleep(1 * 1000 * 1000)
  end
end

local function main()
  local parser = argparse()
  parser:description("Cmd Client")

  parser:option("-l", "--loginhost"):default("127.0.0.1"):description(
    "Login Server IP")
  parser:option("-lp", "--loginport"):default("8001"):description(
    "Login Server Port"):convert(tonumber)
  parser:option("-g", "--gamehost"):default("127.0.0.1"):description(
    "Game Server IP")
  parser:option("-p", "--proto"):default("line"):description("Net proto")
  parser:option("-gp", "--gameport"):default("8888"):description(
    "Game Server Port"):convert(tonumber)
  parser:option("-s", "--script"):description("Script")
  parser:option("-c", "--number"):default("1"):description("Concurrency")
    :convert(tonumber)
  parser:option("-f", "--flag"):default("default"):description("Robot Flag")

  local args   = parser:parse()
  local pretty = require("pl.pretty")
  pretty.dump(args)
  for i = 1, args.number do
    client(i, args)
  end
  run()

end

main()
