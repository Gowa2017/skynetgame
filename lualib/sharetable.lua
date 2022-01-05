local sharetable = require("skynet.sharetable")

local _mt        = {
  __index = function(self, key)
    if self.version < self.box.version then
      self.box = sharetable.query(self.filename)
    end
    return self.box[key]
  end,
}

local M          = {}
function M.share(filename)
  sharetable.loadfile(filename)
end
function M.query(filename)
  local t = sharetable.query(filename)
  assert(t, string.format("No this sharetable %s", filename))
  return setmetatable({ filename = filename, box      = t }, _mt)
end

return M
