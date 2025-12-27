package core

import game "../types/game"

@(private)
_coreContext: game.CoreContext

initCoreContext :: proc() -> ^game.CoreContext {
	_coreContext.windowWidth = 1280
	_coreContext.windowHeight = 720
	return &_coreContext
}

setCoreContext :: proc(ctx: game.CoreContext) {
	_coreContext = ctx // abbreviation since 'context' cant be used:p
}

getCoreContext :: proc() -> ^game.CoreContext {
	return &_coreContext
}

getDeltaTime :: proc() -> f32 {
	return _coreContext.deltaTime
}
