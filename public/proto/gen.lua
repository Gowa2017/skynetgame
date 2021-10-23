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

---To get a field like  a.b.c.d.e.f from a table
---@param T table
---@param k string a.b.c.d.e.f
local function getfield(T, k)
  local v = T -- start with the table of globals
  for w in string.gmatch(k, "[%a_][%w_]*") do
    v = v[w]
    if not v then return v end
  end
  return v
end
---To set a field like  a.b.c.d.e.f on a table
---@param T table
---@param k string a.b.d.c
---@param v any
local function setfield(T, k, v)
  local base = T
  for w, d in string.gmatch(k, "([%a_][%w_]*)(%.?)") do
    if d == "." then -- not last item
      base[w] = base[w] or {}
      base = base[w]
    else
      base[w] = v
    end
  end
end

local function genProtoMap()
  local ok, err = loadfile(protoMapFile, "bt")
  local def     = ok and ok() or
                    { s2c     = {}, c2s     = {}, c2sbyid = {}, s2cbyid = {} }

  local tablex  = require("pl.tablex")
  local plfile  = require("pl.file")
  local pretty  = require("pl.pretty")

  local seq     = {
    s2c = math.max(table.unpack(tablex.keys(def.s2cbyid)) or 10000),
    c2s = math.max(table.unpack(tablex.keys(def.c2sbyid)) or 20000),
  }

  for name, _, _ in pb.types() do
    local ttype, grp, message = name:match(".(%w+).(%w+).([%w%d]+)")
    local byid                = ttype .. "byid"
    if not def[byid] then def[byid] = {} end
    if not getfield(def, name) then
      local id = seq[ttype] + 1
      seq[ttype] = id
      setfield(def, name:sub(2), id)
      def[byid][id] = { grp, message }
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
