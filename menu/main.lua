local ffi = require 'ffi'
local table = require 'ext.table'
local ig = require 'imgui'
local Menu = require 'gameapp.menu.menu'


local MainMenu = Menu:subclass()

function MainMenu:init(app, ...)
	MainMenu.super.init(self, app, ...)
	app.paused = false
	-- play a demo in the background ...
	-- and merge in splash-screen with the first demo's game start

	self.menuOptions = table{
		{
			name = 'New Game',
			click = function(self)
				app.menu = app.Menu.NewGame(app)
			end,
		},
		{
			name = 'New Game Co-op',
			click = function(self)
				app.menu = app.Menu.NewGame(app, true)
				-- TODO pick same as before except pick # of players
			end,
		},
		-- TODO ADD A RESUME GAME here
		{
			name = 'Config',
			click = function(self)
				-- pushMenu only used for entering config menu
				-- if I need any more 'back' options than this then i'll turn the menu into a stack
				app.pushMenu = app.menu
				app.menu = app.Menu.Config(app)
			end,
		},
		{
			name = 'High Scores',
			click = function(self)
				app.menu = app.Menu.HighScore(app)
			end,
		},
		{
			name = 'About',
			click = function(self)
				if ffi.os == 'Windows' then
					os.execute('explorer "'..url..'"')
				elseif ffi.os == 'OSX' then
					os.execute('open "'..url..'"')
				else
					os.execute('xdg-open "'..url..'"')
				end
			end,
			after = function(self)
				local url = app.url or ''
				if ig.igIsItemHovered(ig.ImGuiHoveredFlags_None) then
					ig.igSetMouseCursor(ig.ImGuiMouseCursor_Hand)
					ig.igBeginTooltip()
					ig.igText('by Christopher Moore')
					ig.igText('click to go to')
					ig.igText(url)
					ig.igEndTooltip()
				end
			end,
		},
		{
			name = 'Exit',
			click = function(self)
				app:requestExit()
			end,
		},
	}
end

function MainMenu:updateGUI()
	local app = self.app
	self:beginFullView(app.title, 6 * 32)

	for _,opt in ipairs(self.menuOptions) do
		if self:centerButton(opt.name) then
			opt.click(self)
		end
		if opt.after then
			opt.after(self)
		end
	end

	self:endFullView()
end

return MainMenu
