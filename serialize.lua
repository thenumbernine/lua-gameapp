local tolua = require 'ext.tolua'
local fromlua = require 'ext.fromlua'

local function safetolua(x)
	return tolua(x, {
		serializeForType = {
			cdata = function(state, x, ...)
				return tostring(x)
			end,
		}
	})
end

local function safefromlua(x)
	-- empty env ... sandboxed?
	return fromlua(x, nil, 't', {math={huge=math.huge}})
end

return {
	safetolua = safetolua,
	safefromlua = safefromlua,
}
