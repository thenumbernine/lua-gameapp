--[[
subclass of imguiapp
has stuff a game would want
- fixed framerate
- load/save config file
- menu system
- config menu
- key binding menu
- key handler
- handle sfx
- imgui w/ custom fonts
--]]
local ffi = require 'ffi'
local template = require 'template'
local table = require 'ext.table'
local range = require 'ext.range'
local path = require 'ext.path'
local getTime = require 'ext.timer'.getTime
local sdl = require 'ffi.req' 'sdl'
local ig = require 'imgui'

local gl = require 'gl'
local glreport = require 'gl.report'
local GLProgram = require 'gl.program'
local GLArrayBuffer = require 'gl.arraybuffer'
local GLGeometry = require 'gl.geometry'
local GLSceneObject = require 'gl.sceneobject'

local Audio = require 'audio'
local AudioSource = require 'audio.source'
local AudioBuffer = require 'audio.buffer'

local safetolua = require 'gameapp.serialize'.safetolua
local safefromlua = require 'gameapp.serialize'.safefromlua

-- TODO better way to set this?  like maybe as a ctor arg of something?
-- maybe as an arg of imguiapp.withorbit ?
require 'glapp.view'.useBuiltinMatrixMath = true


ffi.cdef[[
typedef uint64_t randSeed_t;
]]

-- I'm trying to make reproducible random #s
-- it is reproducible up to the generation of the next pieces
-- but the very next piece after will always be dif
-- this maybe is due to the sand toppling also using rand?
-- but why wouldn't that random() call even be part of the determinism?
-- seems something external must be contributing?
--[[ TODO put this in ext? or its own lib?
local class = require 'ext.class'
local RNG = class()
-- TODO max and the + and % constants are bad, fix them
RNG.max = 2147483647ull
require 'ffi.req' 'c.time'
function RNG:init(seed)
	self.seed = ffi.cast('uint64_t', tonumber(seed) or ffi.C.time(nil))
end
function RNG:next(max)
	self.seed = self.seed * 1103515245ull + 12345ull
	return self.seed % (self.max + 1)
end
function RNG:__call(max)
	if max then
		return tonumber(self:next() % max) + 1	-- +1 for lua compat
	else
		return tonumber(self:next()) / tonumber(self.max)
	end
end
--]]
-- [[ Lua code says: xoshira256** algorithm
-- but is only a singleton...
local class = require 'ext.class'
local RNG = class()
function RNG:init(seed)
	math.randomseed(tonumber(seed))
end
function RNG:__call(...)
	return math.random(...)
end
--]]



local GameApp = require 'imguiapp.withorbit'()

-- titlebar and menu title 
GameApp.title = 'GameApp'

-- menu "about"
GameApp.url = 'https://github.com/thenumbernine/lua-gameapp'

-- override in GLApp
GameApp.sdlInitFlags = bit.bor(
	GameApp.sdlInitFlags,	-- default is just SDL_INIT_VIDEO
	sdl.SDL_INIT_JOYSTICK
)

GameApp.RNG = RNG

GameApp.useAudio = true		-- set to false to disable audio altogether
GameApp.maxAudioDist = 10

GameApp.fontPath = nil	-- set to override font
GameApp.fontScale = 2

GameApp.configPath = 'config.lua'

-- override these ...
local Menu = require 'gameapp.menu.menu'
GameApp.Menu = Menu

-- override subclasses that the GameApp uses:
Menu.Splash = require 'gameapp.menu.splash'
Menu.Main = require 'gameapp.menu.main'
Menu.NewGame = require 'gameapp.menu.newgame'
Menu.Playing = require 'gameapp.menu.playing'

local Player = require 'gameapp.player'
GameApp.Player = Player

-- also needed / used by MainMenu:
--Menu.NewGame
Menu.Config = require 'gameapp.menu.config'
--Menu.HighScore = require 'gameapp.menu.highscore'

function GameApp:initGL(...)
	GameApp.super.initGL(self, ...)

-- [[ imgui custom font

	-- allow keys to navigate menu
	-- TODO how to make it so player keys choose menus, not just space bar/
	-- or meh?
	local igio = ig.igGetIO()
	igio[0].ConfigFlags = bit.bor(
		igio[0].ConfigFlags,
		ig.ImGuiConfigFlags_NavEnableKeyboard,
		ig.ImGuiConfigFlags_NavEnableGamepad
	)
	igio[0].FontGlobalScale = self.fontScale

	if self.fontPath then
		self.fontAtlas = ig.ImFontAtlas_ImFontAtlas()
		self.font = ig.ImFontAtlas_AddFontFromFileTTF(self.fontAtlas, self.fontPath, 16, nil, nil)
		-- just change the font, and imgui complains that you need to call FontAtlas::Build() ...
		assert(ig.ImFontAtlas_Build(self.fontAtlas))
		-- just call FontAtlas::Build() and you just get white blobs ...
		-- is this proper behavior?  or a bug in imgui?
		-- you have to download the font texture pixel data, make a GL texture out of it, and re-upload it
		local width = ffi.new('int[1]')
		local height = ffi.new('int[1]')
		local bpp = ffi.new('int[1]')
		local outPixels = ffi.new('unsigned char*[1]')
		-- GL_LUMINANCE textures are deprecated ... khronos says use GL_RED instead ... meaning you have to write extra shaders for greyscale textures to be used as greyscale in opengl ... ugh
		--ig.ImFontAtlas_GetTexDataAsAlpha8(self.fontAtlas, outPixels, width, height, bpp)
		ig.ImFontAtlas_GetTexDataAsRGBA32(self.fontAtlas, outPixels, width, height, bpp)
		self.fontTex = GLTex2D{
			internalFormat = gl.GL_RGBA,
			--internalFormat = gl.GL_RED,
			format = gl.GL_RGBA,
			--format = gl.GL_RED,
			width = width[0],
			height = height[0],
			type = gl.GL_UNSIGNED_BYTE,
			data = outPixels[0],
			minFilter = gl.GL_NEAREST,
			magFilter = gl.GL_NEAREST,
			wrap = {
				s = gl.GL_CLAMP_TO_EDGE,
				t = gl.GL_CLAMP_TO_EDGE,
			},
		}
		require 'ffi.req' 'c.stdlib'	-- free()
		ffi.C.free(outPixels[0])	-- just betting here I have to free this myself ...
		ig.ImFontAtlas_SetTexID(self.fontAtlas, ffi.cast('ImTextureID', self.fontTex.id))
	end
--]]

	-- config

	-- load config if it exists
	local configPath = path(self.configPath)
	if configPath:exists() then
		xpcall(function()
			self.cfg = safefromlua(assert(configPath:read()))
		end, function(err)
			print('failed to read lua from file '..tostring(self.configPath)..'\n'
				..tostring(err)..'\n'
				..debug.traceback())
		end)
	end
	self.cfg = self.cfg or {}
	-- make sure to run PlayerEditKeys:update() at least once to fill this out with defaults
	self.cfg.playerKeys = self.cfg.playerKeys or {}
	self.cfg.effectVolume = self.cfg.effectVolume or 1
	self.cfg.backgroundVolume = self.cfg.backgroundVolume or .3
	self.cfg.screenButtonRadius = self.cfg.screenButtonRadius or .05
	self.cfg.numPlayers = self.cfg.numPlayers or 1
	self.cfg.randseed = self.cfg.randseed or ffi.new('randSeed_t', -1)

	-- graphics

	local vtxbufCPU = ffi.new('float[8]', {
		0,0,
		1,0,
		0,1,
		1,1,
	})
	self.quadVertexBuf = GLArrayBuffer{
		size = ffi.sizeof(vtxbufCPU),
		data = vtxbufCPU,
	}:unbind()

	--self.glslVersion = 460	-- too new
	--self.glslVersion = 430
	--self.glslVersion = '320 es'	-- too new
	self.glslVersion = '300 es'
	self.shaderHeader =
'#version '..self.glslVersion..'\n'
..'precision highp float;\n'

	self.guiButtonShader = GLProgram{
		vertexCode = self.shaderHeader..[[
in vec2 vertex;
out vec2 texcoordv;
uniform mat4 mvProjMat;
void main() {
	texcoordv = vertex;
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
}
]],
		fragmentCode = self.shaderHeader..[[
in vec2 texcoordv;
out vec4 fragColor;
void main() {
	vec2 u = (texcoordv - .5) * 2.;
	float r2 = dot(u,u);
	fragColor = (r2 < 1. && r2 > (.9*.9))
		? vec4(1.)
		: vec4(0.);
}
]],
	}:useNone()

	self.quadGeom = GLGeometry{
		mode = gl.GL_TRIANGLE_STRIP,
		count = 4,
	}

	self.guiButtonSceneObj = GLSceneObject{
		geometry = self.quadGeom,
		program = self.guiButtonShader,
		attrs = {
			vertex = self.quadVertexBuf,
		},
	}

	-- audio 

	self.audioBuffers = {}
	if self.useAudio then
		xpcall(function()
			self.audio = Audio()
			self.audioSources = table()
			self.audioSourceIndex = 0
			self.audio:setDistanceModel'linear clamped'
			for i=1,31 do	-- 31 for DirectSound, 32 for iphone, infinite for all else?
				local src = AudioSource()
				src:setReferenceDistance(1)
				src:setMaxDistance(self.maxAudioDist)
				src:setRolloffFactor(1)
				self.audioSources[i] = src
			end

			-- TODO how about picking just one file?
			self.bgMusicFiles = table()
			if path'music':isdir() then
				for f in path'music':dir() do
					if f.path:match'%.ogg$' then
						self.bgMusicFiles:insert('music/'..f)
					end
				end
			end
			self.bgMusicFileName = self.bgMusicFiles:pickRandom()
			if self.bgMusicFileName then
				self.bgMusic = self:loadSound(self.bgMusicFileName)
				self.bgAudioSource = AudioSource()
				self.bgAudioSource:setBuffer(self.bgMusic)
				self.bgAudioSource:setLooping(true)
				-- self.usercfg
				self.bgAudioSource:setGain(self.cfg.backgroundVolume)
				self.bgAudioSource:play()
			end
		end, function(err)
			print('failed to init audio'
				..tostring(err)..'\n'
				..debug.traceback())
			self.audio = nil
			self.useAudio = false	-- or just test audio's existence?
		end)
	end

	-- menu

	self.splashMenu = self.Menu.Splash(self)
	self.mainMenu = self.Menu.Main(self)
	self.playingMenu = self.Menu.Playing(self)
	self.menu = self.splashMenu
	

	-- SandAttack used :reset()
	-- Zelda4D used .game = Game()
	-- which should I stick with?
	-- TODO put this in whichever.
	-- probaby going to be .game = Game()
	-- put this in Game ctor
	-- and have specific app subclass Game
end

function GameApp:exit()
	if self.audio then
		self.audio:shutdown()
	end
	GameApp.super.exit(self)
end

function GameApp:resetGame()
	-- NOTICE THIS IS A SHALLOW COPY
	-- that means subtables (player keys, custom colors) won't be copied
	-- not sure if i should bother since neither of those things are used by playcfg but ....
	self.playcfg = table(self.cfg):setmetatable(nil)

	self.players = range(self.playcfg.numPlayers):mapi(function(i)
		return self.Player{index=i, app=self}
	end)
	
	-- TODO put this in parent class
	self.rng = self.RNG(self.playcfg.randseed)
end

function GameApp:saveConfig()
	path(self.configPath):write(safetolua(self.cfg))
end


function GameApp:loadSound(filename)
	if not filename then error("warning: couldn't find sound file "..searchfilename) end
	local audioBuffer = self.audioBuffers[filename]
	if not audioBuffer then
		audioBuffer = AudioBuffer(filename)
		self.audioBuffers[filename] = audioBuffer
	end
	return audioBuffer
end

function GameApp:getNextAudioSource()
	if #self.audioSources == 0 then return end
	local startIndex = self.audioSourceIndex
	repeat
		self.audioSourceIndex = self.audioSourceIndex % #self.audioSources + 1
		local source = self.audioSources[self.audioSourceIndex]
		if not source:isPlaying() then
			return source
		end
	until self.audioSourceIndex == startIndex
end

function GameApp:playSound(name, volume, pitch)
	if not self.useAudio then return end
	local source = self:getNextAudioSource()
	if not source then
		print('all audio sources used')
		return
	end

	local sound = self:loadSound(name)
	source:setBuffer(sound)
	source.volume = volume	-- save for later
	source:setGain((volume or 1) * self.cfg.effectVolume)
	source:setPitch(pitch or 1)
	source:setPosition(0, 0, 0)
	source:setVelocity(0, 0, 0)
	source:play()

	return source
end

-- static, used by gamestate and app
function GameApp:getEventName(sdlEventID, a,b,c)
	if not a then return '?' end
	local function dir(d)
		local s = table()
		local ds = 'udlr'
		for i=1,4 do
			if 0 ~= bit.band(d,bit.lshift(1,i-1)) then
				s:insert(ds:sub(i,i))
			end
		end
		return s:concat()
	end
	local function key(k)
		return ffi.string(sdl.SDL_GetKeyName(k))
	end
	return template(({
		[sdl.SDL_JOYHATMOTION] = 'joy<?=a?> hat<?=b?> <?=dir(c)?>',
		[sdl.SDL_JOYAXISMOTION] = 'joy<?=a?> axis<?=b?> <?=c?>',
		[sdl.SDL_JOYBUTTONDOWN] = 'joy<?=a?> button<?=b?>',
		[sdl.SDL_CONTROLLERAXISMOTION] = 'gamepad<?=a?> axis<?=b?> <?=c?>',
		[sdl.SDL_CONTROLLERBUTTONDOWN] = 'gamepad<?=a?> button<?=b?>',
		[sdl.SDL_KEYDOWN] = 'key <?=key(a)?>',
		[sdl.SDL_MOUSEBUTTONDOWN] = 'mouse <?=c?> x<?=math.floor(a*100)?> y<?=math.floor(b*100)?>',
		[sdl.SDL_FINGERDOWN] = 'finger x<?=math.floor(a*100)?> y<?=math.floor(b*100)?>',
	})[sdlEventID], {
		a=a, b=b, c=c,
		dir=dir, key=key,
	})
end

-- called from PlayingMenu:update, PlayerKeysEditor:update
-- because it's a ui / input feature I'll use app.cfg instead of app.playcfg
function GameApp:drawTouchRegions()
	local Player = self.Player
	local view = self.view

	local buttonRadius = self.width * self.cfg.screenButtonRadius

	local sceneObj = self.guiButtonSceneObj
	local shader = sceneObj.program

	gl.glEnable(gl.GL_BLEND)
	gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE)
	shader:use()
	sceneObj:enableAndSetAttrs()
	view.projMat:setOrtho(0, self.width, self.height, 0, -1, 1)
	for i=1,self.cfg.numPlayers do
		for _,keyname in ipairs(Player.keyNames) do
			local e = self.cfg.playerKeys[i][keyname]
			if e	-- might not exist for new players >2 ...
			and (e[1] == sdl.SDL_MOUSEBUTTONDOWN
				or e[1] == sdl.SDL_FINGERDOWN
			) then
				local x = e[2] * self.width
				local y = e[3] * self.height
				view.mvMat:setTranslate(
					x-buttonRadius,
					y-buttonRadius)
					:applyScale(2*buttonRadius, 2*buttonRadius)
				view.mvProjMat:mul4x4(view.projMat, view.mvMat)
				gl.glUniformMatrix4fv(shader.uniforms.mvProjMat.loc, 1, gl.GL_FALSE, self.mvProjMat.ptr)
				sceneObj.geometry:draw()
			end
		end
	end
	sceneObj:disableAttrs()
	shader:useNone()
	gl.glDisable(gl.GL_BLEND)
end



-- this is used for player input, not for demo playback, so it'll use .cfg instead of .playcfg
function GameApp:processButtonEvent(press, ...)
	local Player = self.Player
	local buttonRadius = self.width * self.cfg.screenButtonRadius

	-- TODO put the callback somewhere, not a global
	-- it's used by the New Game menu
	if self.waitingForEvent then
		-- this callback system is only used for editing keyboard binding
		if press then
			local ev = {...}
			ev.name = self:getEventName(...)
			self.waitingForEvent.callback(ev)
			self.waitingForEvent = nil
		end
	else
		-- this branch is only used in gameplay
		-- for that reason, if we're not in the gameplay menu-state then bail
		--if not PlayingMenu:isa(self.menu) then return end

		local etype, ex, ey = ...
		local descLen = select('#', ...)
		for playerIndex, playerConfig in ipairs(self.cfg.playerKeys) do
			for buttonName, buttonDesc in pairs(playerConfig) do
				-- special case for mouse/touch, test within a distanc
				local match = descLen == #buttonDesc
				if match then
					local istart = 1
					-- special case for mouse/touch, click within radius ...
					if etype == sdl.SDL_MOUSEBUTTONDOWN
					or etype == sdl.SDL_FINGERDOWN
					then
						match = etype == buttonDesc[1]
						if match then
							local dx = (ex - buttonDesc[2]) * self.width
							local dy = (ey - buttonDesc[3]) * self.height
							if dx*dx + dy*dy >= buttonRadius*buttonRadius then
								match = false
							end
							-- skip the first 2 for values
							istart = 4
						end
					end
					if match then
						for i=istart,descLen do
							if select(i, ...) ~= buttonDesc[i] then
								match = false
								break
							end
						end
					end
				end
				if match 
				and self.players	-- not created until resetGame
				then
					local player = self.players[playerIndex]
					if player
					and (
						not self.playingDemo
						or not Player.gameKeySet[buttonName]
					) then
						player.keyPress[buttonName] = press
					end
				end
			end
		end
	end
end

function GameApp:event(e, ...)
	-- handle UI
	GameApp.super.event(self, e, ...)
	
	-- if ui handling then return
	-- TODO this might cancel events when menu.playing is open
	local canHandleKeyboard = not ig.igGetIO()[0].WantCaptureKeyboard
	local canHandleMouse = not ig.igGetIO()[0].WantCaptureMouse

	if self.menu.event then
		if self.menu:event(e, ...) then return end
	end

	-- handle any kind of sdl button event
	if e.type == sdl.SDL_JOYHATMOTION then
		--if e.jhat.value ~= 0 then
			-- TODO make sure all hat value bits are cleared
			-- or keep track of press/release
			for i=0,3 do
				local dirbit = bit.lshift(1,i)
				local press = bit.band(dirbit, e.jhat.value) ~= 0
				self:processButtonEvent(press, sdl.SDL_JOYHATMOTION, e.jhat.which, e.jhat.hat, dirbit)
			end
			--[[
			if e.jhat.value == sdl.SDL_HAT_CENTERED then
				for i=0,3 do
					local dirbit = bit.lshift(1,i)
					self:processButtonEvent(false, sdl.SDL_JOYHATMOTION, e.jhat.which, e.jhat.hat, dirbit)
				end
			end
			--]]
		--end
	elseif e.type == sdl.SDL_JOYAXISMOTION then
		-- -1,0,1 depend on the axis press
		local lr = math.floor(3 * (tonumber(e.jaxis.value) + 32768) / 65536) - 1
		local press = lr ~= 0
		if not press then
			-- clear both left and right movement
			self:processButtonEvent(press, sdl.SDL_JOYAXISMOTION, e.jaxis.which, e.jaxis.axis, -1)
			self:processButtonEvent(press, sdl.SDL_JOYAXISMOTION, e.jaxis.which, e.jaxis.axis, 1)
		else
			-- set movement for the lr direction
			self:processButtonEvent(press, sdl.SDL_JOYAXISMOTION, e.jaxis.which, e.jaxis.axis, lr)
		end
	elseif e.type == sdl.SDL_JOYBUTTONDOWN or e.type == sdl.SDL_JOYBUTTONUP then
		-- e.jbutton.menu is 0/1 for up/down, right?
		local press = e.type == sdl.SDL_JOYBUTTONDOWN
		self:processButtonEvent(press, sdl.SDL_JOYBUTTONDOWN, e.jbutton.which, e.jbutton.button)
	elseif e.type == sdl.SDL_CONTROLLERAXISMOTION then
		-- -1,0,1 depend on the axis press
		local lr = math.floor(3 * (tonumber(e.caxis.value) + 32768) / 65536) - 1
		local press = lr ~= 0
		if not press then
			-- clear both left and right movement
			self:processButtonEvent(press, sdl.SDL_CONTROLLERAXISMOTION, e.caxis.which, e.jaxis.axis, -1)
			self:processButtonEvent(press, sdl.SDL_CONTROLLERAXISMOTION, e.caxis.which, e.jaxis.axis, 1)
		else
			-- set movement for the lr direction
			self:processButtonEvent(press, sdl.SDL_CONTROLLERAXISMOTION, e.caxis.which, e.jaxis.axis, lr)
		end
	elseif e.type == sdl.SDL_CONTROLLERBUTTONDOWN or e.type == sdl.SDL_CONTROLLERBUTTONUP then
		local press = e.type == sdl.SDL_CONTROLLERBUTTONDOWN
		self:processButtonEvent(press, sdl.SDL_CONTROLLERBUTTONDOWN, e.cbutton.which, e.cbutton.button)
	-- always handle release button events or else we get into trouble
	elseif (canHandleKeyboard and e.type == sdl.SDL_KEYDOWN) or e.type == sdl.SDL_KEYUP then
		local press = e.type == sdl.SDL_KEYDOWN
		self:processButtonEvent(press, sdl.SDL_KEYDOWN, e.key.keysym.sym)
	elseif (canHandleMouse and e.type == sdl.SDL_MOUSEBUTTONDOWN) or e.type == sdl.SDL_MOUSEBUTTONUP then
		local press = e.type == sdl.SDL_MOUSEBUTTONDOWN
		self:processButtonEvent(press, sdl.SDL_MOUSEBUTTONDOWN, tonumber(e.button.x)/self.width, tonumber(e.button.y)/self.height, e.button.button)
	--elseif e.type == sdl.SDL_MOUSEWHEEL then
	-- how does sdl do mouse wheel events ...
	elseif e.type == sdl.SDL_FINGERDOWN or e.type == sdl.SDL_FINGERUP then
		local press = e.type == sdl.SDL_FINGERDOWN
		self:processButtonEvent(press, sdl.SDL_FINGERDOWN, e.tfinger.x, e.tfinger.y)
	end
end

GameApp.lastFrameTime = 0
GameApp.fpsSampleCount = 0
function GameApp:update(...)
	self.thisTime = getTime()

	gl.glClearColor(.5, .5, .5, 1)
	gl.glClear(gl.GL_COLOR_BUFFER_BIT)
	
	self:updateGame()

	-- update GUI
	GameApp.super.update(self, ...)
	glreport'here'

	-- draw menu over gui?
	-- right now it's just the splash screen and the touch buttons
	if self.menu.update then
		self.menu:update()
	end

	if self.showFPS then
		self.fpsSampleCount = self.fpsSampleCount + 1
		if self.thisTime - self.lastFrameTime >= 1 then
			local deltaTime = self.thisTime - self.lastFrameTime
			self.fps = self.fpsSampleCount / deltaTime
print('fps', self.fps)
--print('dt', 1/self.fps)
			self.lastFrameTime = self.thisTime
			self.fpsSampleCount = 0
		end
	end
end
		
-- TODO update game
-- or maybe make this another object?
function GameApp:updateGame()
end

-- TODO hmm I now have push/pop wrappers around updateGUI, how to subclass it further ...
-- either 1) let the child class call push/pop font
-- or 2) call a new child subclass here
-- or 3) route all GameApp gui stuff through the menu
function GameApp:updateGUI()
	if self.font then
		ig.igPushFont(self.font)
	end
	if self.menu.updateGUI then
		self.menu:updateGUI()
	end
	if self.font then
		ig.igPopFont()
	end
end

return GameApp
