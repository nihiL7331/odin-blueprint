// nihiL's Blueprint
//
// naming convention:
// camelCase for variable names and functions,
// CAPS for static with underscore splits,
// first letter uppercase for type/struct declarations
// _camelCase for private variable names
//
// core concept:
// blueprint is an abstraction layer, that has an expected use of
// being expanded on using packages to split each game system.
//
// additional info:
// game is meant to be built in strict and using vet to make clean
// and optimal code.
//
// support:
// this blueprint is meant to run on web and desktop (linux, mac and windows).
//
// limitations:
// due to it being targeted for web, there are a few limitations/requirements for it to work.
// they are:
// |-> you have to link c libraries for external libs in build_web.*
// |-> you can't use #+feature dynamic-literals
// |-> you can't have global dynamic variables
// |-> you should use heap instead of stack due to stack size constraints on web
// (stack size can be modified, but its recommended to use more heap instead)
// |-> avoid @(deferred_out) if possible, send pointers instead

package main

import "base:runtime"
import "core:log"

import sapp "sokol/app"
import sg "sokol/gfx"
import slog "sokol/log"

import gameapp "game"
import "platform/web"
import "systems/input"
import "systems/render"
import "types/game"
import "utils"

_ :: web

IS_WEB :: ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32


odinContext: runtime.Context

_actualGameState: ^game.GameState

main :: proc() {
	when IS_WEB { 	// via karl zylinski's odin-sokol-web
		// The WASM allocator doesn't seem to work properly in combination with
		// emscripten. There is some kind of conflict with how they manage
		// memory. So this sets up an allocator that uses emscripten's malloc.
		context.allocator = web.emscripten_allocator()

		// Make temp allocator use new `context.allocator` by re-initing it.
		runtime.init_global_temporary_allocator(1 * runtime.Megabyte)
	}

	context.logger = log.create_console_logger(
		lowest = .Info,
		opt = {.Level, .Short_File_Path, .Line, .Procedure},
	)
	odinContext = context

	desc: sapp.Desc
	desc.init_cb = init
	desc.frame_cb = frame
	desc.event_cb = event
	desc.cleanup_cb = cleanup
	desc.width = i32(game.windowWidth)
	desc.height = i32(game.windowHeight)
	desc.sample_count = 4
	desc.window_title = gameapp.WINDOW_TITLE
	desc.icon.sokol_default = true
	desc.logger.func = slog.func
	desc.html5_update_document_title = true
	desc.high_dpi = true

	sapp.run(desc)
}


init :: proc "c" () {
	context = odinContext

	_actualGameState = new(game.GameState)

	// we instantly update windowWidth and windowHeight to fix scale issues on web
	w := sapp.width()
	h := sapp.height()
	game.windowWidth = int(w)
	game.windowHeight = int(h)

	input.initState()
	render.renderInit()
}

frameTime: f64
lastFrameTime: f64

frame :: proc "c" () {
	context = odinContext

	{ 	// calculate the delta time
		currentTime := utils.secondsSinceInit()
		frameTime = currentTime - lastFrameTime
		lastFrameTime = currentTime

		MAX_FRAME_TIME :: 1.0 / 20.0
		if frameTime > MAX_FRAME_TIME {
			frameTime = MAX_FRAME_TIME
		}
	}

	coreContext := utils.getCoreContext()

	coreContext.deltaTime = f32(frameTime)
	coreContext.gameState = _actualGameState

	if input.keyPressed(.ENTER) && input.keyDown(.LEFT_ALT) {
		sapp.toggle_fullscreen()
	}

	render.coreRenderFrameStart()
	gameapp.appFrame()
	render.coreRenderFrameEnd()

	input.resetInputState(input.state)

	free_all(context.temp_allocator)
}

event :: proc "c" (e: ^sapp.Event) {
	context = odinContext

	if e.type == .RESIZED {
		game.windowWidth = int(e.window_width)
		game.windowHeight = int(e.window_height)
	}

	input.inputEventCallback(e)
}

cleanup :: proc "c" () {
	context = odinContext

	sg.shutdown()

	when IS_WEB {
		runtime._cleanup_runtime()
	}
}
