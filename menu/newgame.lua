local ffi = require 'ffi'
local table = require 'ext.table'
local range = require 'ext.range'
local math = require 'ext.math'
local vec3f = require 'vec-ffi.vec3f'
require 'ffi.req' 'c.stdlib'	-- strtoll, for editing randseed
local ig = require 'imgui'
local Menu = require 'gameapp.menu.menu'
local PlayerKeysEditor = require 'gameapp.menu.playerkeys'

local NewGameMenu = Menu:subclass()

function NewGameMenu:init(app, multiplayer)
	NewGameMenu.super.init(self, app)
	self.multiplayer = multiplayer
	if multiplayer then
		app.cfg.numPlayers = math.max(app.cfg.numPlayers, 2)
	else
		app.cfg.numPlayers = 1
	end

	-- TODO
	-- maybe putting the keys editor in the new game isn't a good idea
	-- but right now the keys editor needs to run once before a new game starts
	-- so that the default keys are filled out
	self.playerKeysEditor = PlayerKeysEditor(app)

	-- the newgame menu is init'd upon clicking 'single player' or 'multi player' in the main menu
	-- every time
	-- so re-randomize the game seed here
	app.cfg.randseed = ffi.cast('randSeed_t', bit.bxor(
		ffi.cast('randSeed_t', bit.bxor(os.time(), 0xdeadbeef)),
		bit.lshift(ffi.cast('randSeed_t', bit.bxor(os.time(), 0xdeadbeef)), 32)
	))
end

-- if we're editing keys then show keys
function NewGameMenu:update()
	self.playerKeysEditor:update()
end

local tmpcolor = ig.ImVec4()	-- for imgui button
local tmpcolorv = vec3f()		-- for imgui color picker

function NewGameMenu:goOrBack(bleh)
	local app = self.app

	ig.igPushID_Int(bleh)

	--ig.igSameLine() -- how to work with centered multiple widgets...
	if self:centerButton'Go!' then
		app:saveConfig()
		app.menu = app.playingMenu
		app.playingMenu:startNewGame()
	end
	if self:centerButton'Back' then
		-- save config upon 'back' ?
		app:saveConfig()
		app.menu = app.mainMenu
	end

	ig.igPopID()
end

local tmpbuf = ffi.new('char[256]')

function NewGameMenu:updateGUI()
	local app = self.app

	self:beginFullView(self.multiplayer and 'New Game Multiplayer' or 'New Game', 3 * 32)

	self:goOrBack(1)

	if self.multiplayer then
		self:centerText'Number of Players:'
		self:centerLuatableTooltipInputInt('Number of Players', app.cfg, 'numPlayers')
		app.cfg.numPlayers = math.max(app.cfg.numPlayers, 2)
	end

	self.playerKeysEditor:updateGUI()

	ig.igNewLine()

	-- looks like the standard printf is in the macro PRIx64 ... which I've gotta now make sure is in the ported header ...
	ffi.C.snprintf(tmpbuf, ffi.sizeof(tmpbuf), '%llx', app.cfg.randseed)
	if self:centerInputText('seed', tmpbuf, ffi.sizeof(tmpbuf)) then
		print('updating seed', ffi.string(tmpbuf))
		-- strtoll is long-long should be int64_t ... I could sizeof assert that but meh
		app.cfg.randseed = ffi.C.strtoll(tmpbuf, nil, 16),
		print('updated randseed to', app.cfg.randseed)
	end

	ig.igNewLine()
	self:goOrBack(2)

	self:endFullView()
end

return NewGameMenu
