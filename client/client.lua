local Robot    = require("client.robot")
package.cpath = "./skynet/luaclib/?.so"
local socket   = require("client.socket")
local argparse = require "client.argparse"

local clients  = {}
local deaded   = {}
local function client(idx, conf)
  conf.user = conf.flag .. tostring(idx)
  conf.pass = conf.flag .. tostring(idx)
  local r  = Robot(conf)
  local co = coroutine.create(function()
    local ok, err = r:start()
    if not ok then
      print("robo err", err)
    end
  end)
  clients[co] = true
end

local function run()
  while true do
    for co, _ in pairs(clients) do
      if coroutine.status(co) == "dead" then
        deaded[co] = true
      else
        local ok, err = coroutine.resume(co)
        if not ok then
          print("ERROR:", err)
          deaded[co] = true
        end
      end

    end
    for co, _ in pairs(deaded) do
      clients[co] = nil
    end
    socket.usleep(1 * 1000 * 100)
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
