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
---@param conf table {host, port, username, password, db}
function M.mongo(conf, handler)
  skynet.start(function()
    local mongo = require("skynet.db.mongo")
    ---@type mongo_db
    local db    = mongo.client(conf):getDB(conf.db)
    local cmd   = {}
    function cmd.find(c, query, selector)
      ---@type mongo_cursor
      local cur = db[c]:find(query, selector)
      if cur:count() < 1 then
        cur:close()
        return false, "No data"
      end

      local res = {}
      while cur:hasNext() do
        res[#res + 1] = cur:next()
      end
      cur:close()
      return true, res
    end
    function cmd.findOne(c, query, selector)
      local r = db[c]:findOne(query, selector)
      return r and true or false, r or false
    end
    function cmd.update(c, selector, update, upsert, multi)
      local ok, err, r = db[c]:safe_update(selector, { ["$set"] = update },
                                           upsert, multi)
      return ok, ok and r or err
    end
    function cmd.delete(c, selector, single)
      local ok, err, r = db[c]:safe_delete(selector, single)
      return ok, ok and r or err
    end
    function cmd.insert(c, doc)
      local ok, err, r = db[c]:safe_insert(doc)
      return ok, ok and r or err
    end
    skynet.dispatch("lua", function(_, _, action, ...)
      local ok, res
      if handler and handler[action] then
        ok, res = pcall(handler[action], db, ...)
      else
        ok, res = pcall(cmd[action], ...)
      end
      skynet.retpack(ok, res)
    end)

  end)

end

---comment
---@param opts table {database,host, port, user, password,charset }
function M.mysql(opts, handler)
  skynet.start(function()
    local mysql        = require("skynet.db.mysql")
    ---@type MySQL
    local db           = mysql.connect(opts)
    local tconcat      = table.concat
    local sfmt         = string.format
    local cmd          = {}
    local type_fmt_map = { string = "%s = %s", number = "%s = %d" }

    local function kv_list(document)
      local kf, vf = {}, {}
      for k, v in pairs(document) do
        kf[#kf + 1] = k
        vf[#vf + 1] = type(v) == "string" and mysql.quote_sql_str(v) or v
      end
      return tconcat(kf, ","), tconcat(vf, ",")
    end

    local function kv_equal(t)
      local cond = {}
      for k, v in pairs(t) do
        cond[#cond + 1] = sfmt(type_fmt_map[type(v)], k, type(v) == "string" and
                                 mysql.quote_sql_str(v) or v)
      end
      return cond
    end
    function cmd.find(c, query, selector)
      local sql = sfmt("select %%s from  %s where %%s", c)
      sql = sfmt(sql, selector and tconcat(selector, ",") or "*",
                 tconcat(kv_equal(query), " and "))
      return db:query(sql)
    end
    function cmd.findOne(c, query, selector)
      local sql = sfmt("select %%s from  %s where %%s limit 1", c)
      sql = sfmt(sql, selector and tconcat(selector, ",") or "*",
                 tconcat(kv_equal(query), " and "))
      return db:query(sql)
    end
    function cmd.update(c, selector, update, upsert, multi)
      local sql = multi and sfmt("update %s set %%s where %%s", c) or
                    sfmt("update %s set %%s where %%s limit 1", c)
      sql = sfmt(sql, tconcat(kv_equal(update)),
                 tconcat(kv_equal(selector), " and "))
      print(sql)
      return db:query(sql)
    end
    function cmd.delete(c, selector, single)
      local sql = single and sfmt("delete from  %s where %%s limit 1", c) or
                    sfmt("delete from  %s where %%s", c)
      sql = sfmt(sql, tconcat(kv_equal(selector), " and "))
      return db:query(sql)
    end
    function cmd.insert(c, document)
      local sql = sfmt("insert into %s(%%s) values(%%s)", c)
      sql = sfmt(sql, kv_list(document))
      return db:query(sql)
    end
    skynet.dispatch("lua", function(_, _, action, ...)
      local ok, res
      if handler and handler[action] then
        ok, res = pcall(handler[action], db, ...)
      else
        ok, res = pcall(cmd[action], ...)
      end
      if not ok then
        return skynet.retpack(ok, res)
      end
      if res.badresult then
        return skynet.retpack(false, res.err)
      end

      return skynet.retpack(true, res)

    end)
  end)

end
---Used to wrappe a db proxy service, will can direct call it
---@param addr any
function M.wrap(addr)
  return setmetatable({ addr = addr }, proxy_meta)
end

return M
