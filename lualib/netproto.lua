local netpack      = require("skynet.netpack")
local skynet       = require("skynet")
local socketdriver = require("skynet.socketdriver")

local sfmt         = string.format
local spack        = string.pack
local sunpack      = string.unpack
local tunpack      = table.unpack
local M            = {}

local pb           = require("pb")
local protomap    

local function getfield(T, k)
  local v = T
  for w in string.gmatch(k, "[%a_][%w_]*") do
    v = v[w]
    if not v then return v end
  end
  return v
end
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

---@param protoFile? string pb二进制文件路径
---@param protoDef? string 协议号定义文件
function M.init(protoFile, protoDef)
  local pbio = require "pb.io"
  protoFile = protoFile or skynet.getenv("protoFile")
  protoDef = protoDef or skynet.getenv("protoMap")
  pb.load(pbio.read(protoFile))
  protomap = loadfile(protoDef, "bt")()
end

---重新初始化 Protobuff 模块
function M.update()
  package.loaded["base.proto.protobuf"] = nil
  M.init()
end

---通过协议ID查找到客户端到服务端的协议定义信息
---而此，就直接对应了服务内对应的处理的模块和方法
---@param iType number @协议号
---@return string, string
function M.c2sbyid(iType) return tunpack(protomap.c2sbyid[iType]) end

--- 通过协议ID查找到服务端到客户端的协议定义信息
---@param iType number @协议号
---@return string,string
function M.s2cbyid(iType) return tunpack(protomap.s2cbyid[iType]) end

--- 查找客户端到服务端协议名的 ID
---@param sName string @协议名
---@return number 协议号
function M.c2sbyname(sName) return getfield(protomap, sName) end

--- 查找服务端到客户端协议名的 ID
---@param sName string @协议名
---@return number @协议号
function M.s2cbyname(sName) return getfield(protomap, sName) end

---根据 protobuf 协议名来序列化数据
---* 首先会找到协议号，然后把协议号放在数据前面
---* 然后以大端字节序进行打包，包头是消息的长度
---@param sProtoName string @协议名
---@param data table @数据
---@return lightuserdata, number
function M.pack(sProtoName, data)
  local iProtoId  = assert(M.s2cbyname(sProtoName),
                           sfmt("proto %s not found", sProtoName))
  local sPackData = pb.encode(sProtoName, data)
  return netpack.pack(spack(">I2", iProtoId) .. sPackData)
end

---解包 协议ID + protobuf 序列化数据的 的字符串
---成功返回 table, group, cmd，失败了返回 false 和 字符串描述
---@param msg string @二进制字符串
---@param sz number
---@return table|boolean @数据或表示错误的false
---@return string @group 或错误消息
---@return string? cmd
function M.unpack(msg, sz)
  local s             = skynet.tostring(msg, sz)
  local iProtoId      = sunpack(">I2", s)
  local grp, cmd      = M.c2sbyid(iProtoId)
  assert(cmd, sfmt("proto %d not fuond", iProtoId))
  local mData, errMsg = pb.decode("c2s." .. grp .. "." .. cmd, s:sub(3))
  if mData then
    return table.concat({ grp, cmd }, "."), mData
  else
    return error(errMsg)
  end
end

function M.send(id, protoName, data)
  socketdriver.send(id, M.pack(protoName, data))
end

return M
