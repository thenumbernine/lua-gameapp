local getTime = require 'ext.timer'.getTime
local sdl = require 'ffi.req' 'sdl'
local gl = require 'gl'
local GLProgram = require 'gl.program'
local GLSceneObject = require 'gl.sceneobject'
local Menu = require 'gameapp.menu.menu'

local SplashMenu = Menu:subclass()

SplashMenu.duration = 3

-- TODO cool sand effect or something
function SplashMenu:init(app, ...)
	SplashMenu.super.init(self, app, ...)
	self.startTime = getTime()
	app.paused = true

	self.splashShader = GLProgram{
		vertexCode = app.shaderHeader..[[
in vec2 vertex;
out vec2 texcoordv;
uniform mat4 mvProjMat;
void main() {
	texcoordv = vertex;
	gl_Position = mvProjMat * vec4(vertex, 0., 1.);
}
]],
		fragmentCode = app.shaderHeader..[[
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

	local shader = self.splashShader
	local sceneObj = self.splashSceneObj
	shader:use()
	sceneObj:enableAndSetAttrs()

	local aspectRatio = app.width / app.height
	view.projMat:setOrtho(-.5 * aspectRatio, .5 * aspectRatio, -.5, .5, -1, 1)
	view.mvMat
		:setTranslate(-.5 * aspectRatio, -.5)
		:applyScale(aspectRatio, 1)
	view.mvProjMat:mul4x4(view.projMat, view.mvMat)
	gl.glUniformMatrix4fv(shader.uniforms.mvProjMat.loc, 1, gl.GL_FALSE, view.mvProjMat.ptr)

	sceneObj.geometry:draw()

	sceneObj:disableAttrs()
	shader:useNone()

	if getTime() - self.startTime > self.duration then
		self:endSplashScreen()
	end
end

function SplashMenu:event(e)
	local app = self.app
	if e.type == sdl.SDL_JOYHATMOTION
	or e.type == sdl.SDL_JOYAXISMOTION
	or e.type == sdl.SDL_JOYBUTTONDOWN
	or e.type == sdl.SDL_CONTROLLERAXISMOTION
	or e.type == sdl.SDL_CONTROLLERBUTTONDOWN
	or e.type == sdl.SDL_KEYDOWN
	or e.type == sdl.SDL_MOUSEBUTTONDOWN
	or e.type == sdl.SDL_FINGERDOWN
	then
		self:endSplashScreen()
	end
end

function SplashMenu:endSplashScreen()
	local app = self.app
	-- play the demo
	app.paused = false
	app.menu = app.Menu.Main(app)
end

return SplashMenu
