local ig = require 'imgui'
local sdl = require 'ffi.req' 'sdl'
local Menu = require 'gameapp.menu.menu'

local PlayingMenu = Menu:subclass()

function PlayingMenu:init(app)
	PlayingMenu.super.init(self, app)
end

-- called from gameapp.menu.newgame
function PlayingMenu:startNewGame()
	self.app.paused = false
	self.app:resetGame()
end

function PlayingMenu:resumeGame()
	self.app.paused = false
end

function PlayingMenu:update()
	self.app:drawTouchRegions()
end

-- escape to toggle menu
-- TODO use whatever is bound to the player's pause key
-- and TODO change the imgui menu buttons as well
function PlayingMenu:event(e)
	local app = self.app
	if e.type == sdl.SDL_KEYDOWN
	and e.key.keysym.sym == sdl.SDLK_ESCAPE
	and app.game
	then
		app.paused = true
		app.menu = app.mainMenu
	end
end

return PlayingMenu
