// nihiL's Blueprint
//
// naming convention:
// camelCase for variable names and functions,
// CAPS for static with underscore splits,
// first letter uppercase for type/struct declarations
// _camelCase for private variable names
//
// support:
// this blueprint is meant to run on web and desktop (linux, mac, windows and wasm).
//
// the core / systems / types / game split and their relation:
//  - core is where the main meat of the engine/blueprint lives. It contains things
// crucial to make a game, and depends just on external libraries and types.
//  - systems is a place for parts of the engine that aren't required to make a game run,
// but are worth abstracting out for repeated use in multiple projects. A good example
// would be a complex camera controller or a entities system. Systems depend on core and types.
//  - types are type definitions, structure definitions, small helpers that are used
// throughout the whole project. they dont depend on anything but external libraries.
//  - game is where, well, the game is. it is the glue to all previously mentioned parts,
// and with that it can depend on anything. the game directory consists of the main game.odin
// file as well as directories for defining custom objects from systems (and notably scenes
// from core).
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
// NOTE: you can also just disobey these limitations and have it not work on web:p
// but IMO this forces you to make cleaner code

package main

import "base:runtime"
import "core:log"

import sapp "libs/sokol/app"
import sg "libs/sokol/gfx"
import slog "libs/sokol/log"

import "core"
import "core/clock"
import "core/input"
import "core/render"

import "core/platform/web"
import gameapp "game"
import "types/game"

_ :: web

IS_WEB :: ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32


odinContext: runtime.Context

@(private)
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
	coreContext := core.initCoreContext()

	desc: sapp.Desc
	desc.init_cb = init
	desc.frame_cb = frame
	desc.event_cb = event
	desc.cleanup_cb = cleanup
	desc.width = coreContext.windowWidth
	desc.height = coreContext.windowHeight
	desc.sample_count = 4 //MSAA
	desc.window_title = gameapp.WINDOW_TITLE
	desc.icon.sokol_default = true
	desc.logger.func = slog.func
	desc.html5_update_document_title = true
	desc.high_dpi = true

	sapp.run(desc)
}


init :: proc "c" () {
	context = odinContext

	coreContext := core.getCoreContext()
	_actualGameState = new(game.GameState)
	_actualGameState.world = new(game.WorldState)
	coreContext.gameState = _actualGameState

	// we instantly update windowWidth and windowHeight to fix scale issues on web
	coreContext.windowWidth = sapp.width()
	coreContext.windowHeight = sapp.height()


	input.initState()
	render.init()
	gameapp.init()
}

frameTime: f64
lastFrameTime: f64

frame :: proc "c" () {
	context = odinContext

	{ 	// calculate the delta time
		currentTime := clock.secondsSinceInit()
		frameTime = currentTime - lastFrameTime
		lastFrameTime = currentTime

		MAX_FRAME_TIME :: 1.0 / 20.0
		if frameTime > MAX_FRAME_TIME {
			frameTime = MAX_FRAME_TIME
		}
	}

	coreContext := core.getCoreContext()

	coreContext.deltaTime = f32(frameTime)

	if input.keyPressed(.ENTER) && input.keyDown(.LEFT_ALT) {
		sapp.toggle_fullscreen()
	}

	coreContext.gameState.time.gameTimeElapsed += f64(coreContext.deltaTime)
	coreContext.gameState.time.ticks += 1

	render.coreRenderFrameStart()
	gameapp.update()


	gameapp.draw()
	render.coreRenderFrameEnd()

	input.resetInputState(input.state)

	free_all(context.temp_allocator)
}

event :: proc "c" (e: ^sapp.Event) {
	context = odinContext

	if e.type == .RESIZED {
		coreContext := core.getCoreContext()
		coreContext.windowWidth = sapp.width()
		coreContext.windowHeight = sapp.height()
	}

	input.inputEventCallback(e)
}

cleanup :: proc "c" () {
	context = odinContext

	sg.shutdown()

	free(_actualGameState.world)
	free(_actualGameState)

	when IS_WEB {
		runtime._cleanup_runtime()
	}
}
