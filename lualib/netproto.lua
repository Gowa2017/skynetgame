local netpack      = require("skynet.netpack")
local skynet       = require("skynet")
local socketdriver = require("skynet.socketdriver")

local sfmt         = string.format
local spack        = string.pack
local sunpack      = string.unpack
local tunpack      = table.unpack

---We package our data in protobuf format, and, the final format is
---* | 2 byte        | 2 byte       |  < 65535 byte|
---* |package length | message type | message data |
---* If we use the gate or gateserver to receive data, the data we received
---from it does not include the package length, or we use the socket module,
---we need firest read the 2 bytes of package legnth the, the last continue
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
---**当使用 gateserver 的时候，我们应该使用 netpack.tostring，而不是 skynet.tostring**
---@param msg string @二进制字符串
---@param sz number
---@return table|boolean @数据或表示错误的false
---@return string @group 或错误消息
---@return string? cmd
function M.unpack(msg, sz)
  return M.unpackString(skynet.tostring(msg, sz))
end

function M.unpackString(msg)
  local iProtoId      = sunpack(">I2", msg)
  local cmd           = M.c2sbyid(iProtoId)
  assert(cmd, sfmt("protoId %d not fuond", iProtoId))
  local mData, errMsg = pb.decode(cmd, s:sub(3))
  if mData then
    return cmd:sub(5), mData
  else
    error(errMsg)
  end
end

function M.send(id, protoName, data)
  socketdriver.send(id, M.pack(protoName, data))
end

return M
