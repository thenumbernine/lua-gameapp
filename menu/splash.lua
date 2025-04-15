local getTime = require 'ext.timer'.getTime
local sdl = require 'sdl'
local gl = require 'gl'
local GLProgram = require 'gl.program'
local GLSceneObject = require 'gl.sceneobject'
local Menu = require 'gameapp.menu.menu'

local SplashMenu = Menu:subclass()

SplashMenu.duration = 3

function SplashMenu:init(app, ...)
	SplashMenu.super.init(self, app, ...)
	self.startTime = getTime()
	app.paused = true

	self.splashShader = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
in vec2 vertex;
out vec2 texcoordv;
uniform mat4 mvProjMat;
void main() {
	texcoordv = vertex;
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
}
]],
		fragmentCode = [[
in vec2 texcoordv;
out vec4 fragColor;
void main() {
	fragColor = vec4(texcoordv, 0., 1.);
}
]],
	}:useNone()

	self.splashSceneObj = GLSceneObject{
		geometry = app.quadGeom,
		program = self.splashShader,
		attrs = {
			vertex = app.quadVertexBuf,
		},
	}
end

function SplashMenu:update()
	local app = self.app
	local view = app.view

	local aspectRatio = app.width / app.height
	view.projMat:setOrtho(-.5 * aspectRatio, .5 * aspectRatio, -.5, .5, -1, 1)
	view.mvMat
		:setTranslate(-.5 * aspectRatio, -.5)
		:applyScale(aspectRatio, 1)
	view.mvProjMat:mul4x4(view.projMat, view.mvMat)

	local sceneObj = self.splashSceneObj
	sceneObj.uniforms.mvProjMat = view.mvProjMat.ptr
	sceneObj:draw()

	if getTime() - self.startTime > self.duration then
		self:endSplashScreen()
	end
end

function SplashMenu:event(e)
	local app = self.app
	if e[0].type == sdl.SDL_JOYHATMOTION
	or e[0].type == sdl.SDL_JOYAXISMOTION
	or e[0].type == sdl.SDL_JOYBUTTONDOWN
	or e[0].type == sdl.SDL_CONTROLLERAXISMOTION
	or e[0].type == sdl.SDL_CONTROLLERBUTTONDOWN
	or e[0].type == sdl.SDL_KEYDOWN
	or e[0].type == sdl.SDL_MOUSEBUTTONDOWN
	or e[0].type == sdl.SDL_FINGERDOWN
	then
		self:endSplashScreen()
	end
end

function SplashMenu:endSplashScreen()
	local app = self.app
	-- play the demo
	app.paused = false
	app.menu = app.mainMenu
end

return SplashMenu
