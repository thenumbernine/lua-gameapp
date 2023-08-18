local ffi = require 'ffi'
local path = require 'ext.path'
local ig = require 'imgui'
local Menu = require 'gameapp.menu.menu'


local MainMenu = Menu:subclass()

function MainMenu:init(app, ...)
	MainMenu.super.init(self, app, ...)
	app.paused = false
	-- play a demo in the background ...
	-- and merge in splash-screen with the first demo's game start
end

function MainMenu:updateGUI()
	local app = self.app
	self:beginFullView(app.title, 6 * 32)

	if self:centerButton'New Game' then
		app.menu = app.Menu.NewGame(app)
	end
	if self:centerButton'New Game Co-op' then
		app.menu = app.Menu.NewGame(app, true)
		-- TODO pick same as before except pick # of players
	end
	-- TODO ADD A RESUME GAME here
	if self:centerButton'Config' then
		-- pushMenu only used for entering config menu
		-- if I need any more 'back' options than this then i'll turn the menu into a stack
		app.pushMenu = app.menu
		app.menu = app.Menu.Config(app)
	end
	if self:centerButton'High Scores' then
		app.menu = app.Menu.HighScore(app)
	end
	local url = app.url
	if self:centerButton'About' then
		if ffi.os == 'Windows' then
			os.execute('explorer "'..url..'"')
		elseif ffi.os == 'OSX' then
			os.execute('open "'..url..'"')
		else
			os.execute('xdg-open "'..url..'"')
		end
	end
	if ig.igIsItemHovered(ig.ImGuiHoveredFlags_None) then
		ig.igSetMouseCursor(ig.ImGuiMouseCursor_Hand)
		ig.igBeginTooltip()
		ig.igText('by Christopher Moore')
		ig.igText('click to go to')
		ig.igText(url)
		ig.igEndTooltip()
	end

	if self:centerButton'Exit' then
		app:requestExit()
	end

	self:endFullView()
end

return MainMenu
