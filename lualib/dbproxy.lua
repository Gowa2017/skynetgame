local skynet     = require("skynet")
local proxy_meta = {}
proxy_meta.__index = proxy_meta

---@param query table  query conditiron
---@param selector table fields to be returned
---@return boolean #whether call ok
---@return table|string # success data or error message
function proxy_meta:find(query, selector)
  return skynet.call(self.addr, "lua", "find", query, selector)
end

---@param query table  query conditiron
---@param selector table fields to be returned
---@return boolean #whether call ok
---@return table|string # success data or error message
function proxy_meta:findOne(tableName, query, selector)
  return skynet.call(self.addr, "lua", "findOne", tableName, query, selector)
end

function proxy_meta:update(tableName, selector, update, upsert, multi)
  return skynet.call(self.addr, "lua", "update", tableName, selector, update,
                     upsert, multi)
end

function proxy_meta:delete(tableName, selector, single)
  return skynet.call(self.addr, "lua", "delete", tableName, selector, single)
end

function proxy_meta:insert(tableName, document)
  return skynet.call(self.addr, "lua", "insert", tableName, document)
end

---This can start a service or wrapper to call to a db proxy service
local M          = {}

---Used to start a db proxy service
function M.mongo(conf)
  skynet.start(function()
    local mongo = require("skynet.db.mongo")
    ---@type mongo_db
    local db    = mongo.client(conf):getDB("mud")
    local cmd   = {}
    function cmd.find(c, query, selector)
      ---@type mongo_cursor
      local cur = db[c]:find(query, selector)
      if cur:count() < 1 then
        cur:close()
        return skynet.retpack(false, "No data")
      end

      local res = {}
      while cur:hasNext() do
        res[#res + 1] = cur:next()
      end
      cur:close()
      skynet.retpack(true, res)
    end
    function cmd.findOne(c, query, selector)
      local r = db[c]:findOne(query, selector)
      if r then
        skynet.retpack(true, r)
      else
        skynet.retpack(false, "No data")
      end
    end
    function cmd.update(c, selector, update, upsert, multi)
      local ok, err, r = db[c]:safe_update(selector, { ["$set"] = update },
                                           upsert, multi)
      if not ok then
        skynet.retpack(ok, err)
      else
        skynet.retpack(ok, r)
      end
    end
    function cmd.delete(c, selector, single)
      local ok, err, r = db[c]:safe_delete(selector, single)
      if ok then
        skynet.retpack(ok, r)
      else
        skynet.retpack(ok, err)
      end
    end
    function cmd.insert(c, doc)
      local ok, err, r = db[c]:safe_insert(doc)
      if ok then
        skynet.retpack(ok, r)
      else
        skynet.retpack(ok, err)
      end
    end
    skynet.dispatch("lua", function(_, _, action, ...)
      cmd[action](...)
    end)

  end)

end

---Used to wrappe a db proxy service, will can direct call it
---@param addr any
function M.wrap(addr)
  return setmetatable({ addr = addr }, proxy_meta)
end

return M
