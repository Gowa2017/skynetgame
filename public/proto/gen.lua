--- used to gen proto message's lua presention
package.cpath = package.cpath .. ";../../luaclib/?.so"
local pb             = require("pb")
local pbio           = require("pb.io")

local protoFile      = "proto.pb"
local protoClassFile = "proto.lua"
local protoMapFile   = "protomap.lua"
local data           = assert(pbio.read(protoFile))
local ok, n          = pb.load(data)
assert(ok, n)
---@version >5.3
local typeConv       = {
  bool     = "boolean",
  int32    = "integer",
  uint32   = "integer",
  sint32   = "integer",
  int64    = "integer",
  uint64   = "integer",
  sint64   = "integer",
  float    = "number",
  fixed32  = "integer",
  sfixed32 = "integer",
  double   = "number",
  fixed64  = "integer",
  sfixed64 = "integer",
  bytes    = "string",
  string   = "string",
  message  = "table",
  enum     = "string", -- affect by enum_as_name or  enum_as_value
}

local function genProtoClass()
  local of = io.open(protoClassFile, "w")
  of:write("--- Gen by gen.lua \n")
  of:write("--- Runtime will not use the file.\n")
  of:write("--- But the lua language need it to help we write cmds.\n")
  for name, basename, tt in pb.types() do
    of:write(string.format("---@class %s\n", name:sub(2)))
    for field, id, tt in pb.fields(name) do
      _, _, ftype, default, tag = pb.field(name, field)
      of:write(string.format("---@field %s%s %s%s %s\n", field,
                             tag == "optional" and "?" or "",
                             typeConv[ftype] or ftype:sub(2),
                             tag == "repeated" and "[]" or "",
                             not default and default or ""))
    end
    of:write("\n")
  end
  os.execute("lua-format -i " .. protoClassFile)
end

local function genProtoMap()
  local ok, err = loadfile(protoMapFile, "bt")
  local def     = ok and ok() or
                    { s2c     = {}, c2s     = {}, c2sbyid = {}, s2cbyid = {} }

  local tablex  = require("pl.tablex")
  local plfile  = require("pl.file")
  local pretty  = require("pl.pretty")

  local seq     = {}
  seq.s2c = math.max(10000, table.unpack(tablex.keys(def.s2cbyid)))
  seq.c2s = math.max(20000, table.unpack(tablex.keys(def.c2sbyid)))
  --- 这个 MAP 应该是一个平坦的映射，从消息类型到ID的映射，或从消息ID到消息类型的映射
  --- 键应该是 package.消息名的形式，强制要求，报名必须是 s2c.login  s2c.game 的形式
  --- 的消息类型， 报名必须只能包含字母和 '.' 号，消息名只能是数字和字母
  for name, _, _ in pb.types() do
    local ttype, grp, message = name:match(".(%w+).(%w+).([%w%d]+)")
    local byid                = ttype .. "byid"
    def[ttype] = def[ttype] or {}
    def[byid] = def[byid] or {}
    if not def[ttype][name:sub(2)] then
      local id = seq[ttype] + 1
      seq[ttype] = id
      def[ttype][name:sub(2)] = id
      def[byid][id] = { ttype, grp, message }
    end
  end

  plfile.write(protoMapFile, "return " .. pretty.write(def))
  print(" Use lua-format to format the generate file")
  os.execute("lua-format -i " .. protoMapFile)

end

print(" Generate the proto message class define of Lua")
genProtoClass()
print(" Generate message ids and map")
genProtoMap()
