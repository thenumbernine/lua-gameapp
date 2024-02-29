local class = require 'ext.class'
local table = require 'ext.table'

-- Player class, right now only used for listing keys
local Player = class()

-- gameplay keys to record for demos (excludes pause)
Player.gameKeyNames = table{
	'up',
	'down',
	'left',
	'right',
	'jump',
	'attack',
}

-- all keys to capture via sdl events during gameplay
Player.keyNames = table(Player.gameKeyNames):append{
	'pause',
}

-- set of game keys (for set testing)
Player.gameKeySet = Player.gameKeyNames:mapi(function(k) 
	return true, k 
end):setmetatable(nil)

function Player:init(args)
	self.app = assert(args.app)
	self.index = assert(args.index)
	self.keyPress = {}
	self.keyPressLast = {}
	for _,k in ipairs(self.keyNames) do
		self.keyPress[k] = false
		self.keyPressLast[k] = false
	end
end

return Player 
