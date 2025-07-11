--[[
this isn't a menu state
but it's going to contain some controls used by both the NewGame and Config menu states
--]]
local table = require 'ext.table'
local class = require 'ext.class'
local ig = require 'imgui'
local sdl = require 'sdl'

local PlayerKeysEditor = class()

-- default key mappings for first few players
PlayerKeysEditor.defaultKeys = {
	{
		up = {sdl.SDL_EVENT_KEY_DOWN, sdl.SDLK_UP},
		down = {sdl.SDL_EVENT_KEY_DOWN, sdl.SDLK_DOWN},
		left = {sdl.SDL_EVENT_KEY_DOWN, sdl.SDLK_LEFT},
		right = {sdl.SDL_EVENT_KEY_DOWN, sdl.SDLK_RIGHT},
		pause = {sdl.SDL_EVENT_KEY_DOWN, sdl.SDLK_ESCAPE},
	},
	{
		up = {sdl.SDL_EVENT_KEY_DOWN, ('w'):byte()},
		down = {sdl.SDL_EVENT_KEY_DOWN, ('s'):byte()},
		left = {sdl.SDL_EVENT_KEY_DOWN, ('a'):byte()},
		right = {sdl.SDL_EVENT_KEY_DOWN, ('d'):byte()},
		pause = {},	-- sorry keypad player 2
	},
}

function PlayerKeysEditor:init(app)
	self.app = assert(app)
	local Player = app.Player
	--static-init after the app has been created
	if not select(2, next(self.defaultKeys[1])).name then
		local App = require 'gameapp'
		for _,keyEvents in ipairs(self.defaultKeys) do
			for keyName,event in pairs(keyEvents) do
				event.name = App:getEventName(table.unpack(event))
			end
		end
	end
	assert(select(2, next(self.defaultKeys[1])).name)

	-- initialize keys if necessary
	-- also in updateGUI
	for i=1,app.cfg.numPlayers do
		if not app.cfg.playerKeys[i] then
			app.cfg.playerKeys[i] = {}
			local defaultsrc = self.defaultKeys[i]
			for _,keyname in ipairs(Player.keyNames) do
				app.cfg.playerKeys[i][keyname] = defaultsrc and defaultsrc[keyname] or {}
			end
		end
	end
end

function PlayerKeysEditor:update()
	if self.currentPlayerIndex then
		self.app:drawTouchRegions()
	end
end

function PlayerKeysEditor:updateGUI()
	local app = self.app
	local Player = app.Player
	local multiplayer = app.cfg.numPlayers > 1	
	-- should player keys be here or config?
	-- config: because it is in every other game
	-- here: because key config is based on # players, and # players is set here.
	for i=1,app.cfg.numPlayers do
		if not app.cfg.playerKeys[i] then
			app.cfg.playerKeys[i] = {}
			local defaultsrc = self.defaultKeys[i]
			for _,keyname in ipairs(Player.keyNames) do
				app.cfg.playerKeys[i][keyname] = defaultsrc and defaultsrc[keyname] or {}
			end
		end
		if ig.igButton(not multiplayer and 'change keys' or 'change player '..i..' keys') then
			self.currentPlayerIndex = i
			ig.igOpenPopup_Str('Edit Keys', 0)
		end
	end
	if self.currentPlayerIndex then
		assert(self.currentPlayerIndex >= 1 and self.currentPlayerIndex <= app.cfg.numPlayers)
		-- this is modal but it makes the drawn onscreen gui hard to see
		if ig.igBeginPopupModal'Edit Keys' then
		-- this isn't modal so you can select off this window
		--if ig.igBeginPopup('Edit Keys', 0) then
			for _,keyname in ipairs(Player.keyNames) do
				ig.igPushID_Str(keyname)
				ig.igText(keyname)
				ig.igSameLine()
				local ev = app.cfg.playerKeys[self.currentPlayerIndex][keyname]
				if ig.igButton(
					app.waitingForEvent
					and app.waitingForEvent.key == keyname
					and app.waitingForEvent.playerIndex == self.currentPlayerIndex
					and 'Press Button...' or (ev and ev.name) or '?')
				then
					app.waitingForEvent = {
						key = keyname,
						playerIndex = self.currentPlayerIndex,
						callback = function(ev)
							--[[ always reserve escape?  or allow player to configure it as the pause key?
							if ev[1] == sdl.SDL_EVENT_KEY_DOWN and ev[2] == sdl.SDLK_ESCAPE then
								app.cfg.playerKeys[self.currentPlayerIndex][keyname] = {}
								return
							end
							--]]
							-- mouse/touch requires two clicks to determine size? meh... no, confusing.
							app.cfg.playerKeys[self.currentPlayerIndex][keyname] = ev
						end,
					}
				end
				ig.igPopID()
			end
			if ig.igButton'Done' then
				app:saveConfig()
				ig.igCloseCurrentPopup()
				self.currentPlayerIndex = nil
			end
			ig.igEnd()
		end
	end
end

return PlayerKeysEditor
