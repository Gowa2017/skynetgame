local netpack      = require("skynet.netpack")
local skynet       = require("skynet")
local socketdriver = require("skynet.socketdriver")

local sfmt         = string.format
local spack        = string.pack
local sunpack      = string.unpack
local tunpack      = table.unpack
local tconcat      = table.concat

---We package our data in protobuf format, and, the final format is
---* | 2 byte        | 2 byte       |  < 65535 byte|
---* |package length | message type | message data |
---* If we use the msgserver or gateserver to receive data, the data we received
---from it does not include the package length, or we use the socket module,
---we need first read the 2 bytes of package legnth the, then last continue
---bytes is data and session
---* The module need a pb binary file, and a table or module which defined the
---message type's integer ID which we will use to unpack the probobuff package.
local M            = {}

local pb           = require("pb")
local protomap    

---If we does not give the two paramters, it will use protoFile, protoMap to call
---skynet.getenv to find.
---@param protoFile? string pb二进制文件路径
---@param protoDef? string 协议号定义文件
function M.init(protoFile, protoDef)
  assert(protoFile and type(protoFile) == "string",
         "Need protoFile and must a string")
  protoDef = protoDef or skynet.getenv("protoMap")
  pb.load(protoFile)
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
function M.c2sbyid(iType)
  return protomap.c2sbyid[iType]
end

--- 通过协议ID查找到服务端到客户端的协议定义信息
---@param iType number @协议号
---@return string,string
function M.s2cbyid(iType)
  return protomap.s2cbyid[iType]
end

--- 查找客户端到服务端协议名的 ID
---@param sName string @协议名
---@return number 协议号
function M.c2sbyname(sName)
  return protomap.c2s[sName]
end

--- 查找服务端到客户端协议名的 ID
---@param sName string @协议名
---@return number @协议号
function M.s2cbyname(sName)
  return protomap.s2c[sName]
end

---Pack a message as a packge with 2byte length header
---@param sProtoName string @协议名
---@param data table @数据
---@return lightuserdata, number
function M.pack(sProtoName, data)
  return netpack.pack(M.packString(sProtoName, data))
end

---Pack a protbuf message as a string
---@param sProtoName string
---@param data table
---@return string binary
function M.packString(sProtoName, data)
  local iProtoId  = assert(M.s2cbyname(sProtoName),
                           sfmt("proto %s not found", sProtoName))
  local sPackData = pb.encode(sProtoName, data)
  return spack(">I2", iProtoId) .. sPackData
end

---解包 协议ID + protobuf 序列化数据的 的字符串
---成功返回 table, group, cmd，失败了返回 false 和 字符串描述
---**当使用 gateserver 的时候，我们应该使用 netpack.tostring，而不是 skynet.tostring**
---@param msg string @二进制字符串
---@param sz number
---@return table|boolean @数据或表示错误的false
---@return string @group 或错误消息
---@return string? cmd
function M.unpack(msg, sz)
  if type(msg) ~= "string" then
    msg = netpack.tostring(msg, sz)
  end
  return M.unpackString(msg)
end

function M.unpackString(msg)
  local iProtoId      = sunpack(">I2", msg)
  local module        = M.c2sbyid(iProtoId)
  local mData, errMsg = pb.decode(tconcat(module, "."), msg:sub(3))
  if mData then
    return module[2], module[3], mData
  else
    error(errMsg)
  end
end

function M.send(id, protoName, data)
  socketdriver.send(id, M.pack(protoName, data))
end

return M
