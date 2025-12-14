package game

import "../systems/camera"
import "../systems/render"
import "../types/game"
import "../types/gmath"
import "../utils"

import "core:fmt"
import "core:math/linalg"

VERSION :: "v0.0.0"
WINDOW_TITLE :: "Blueprint"

appFrame :: proc() {
	coreContext := utils.getCoreContext()
	drawFrame := render.getDrawFrame()

	// right now we are just calling the game update, but in future this is where you'd do a big
	// "UX" switch for startup splash, main menu, settings, in-game, etc

	{
		// ui space example
		drawFrame.reset.coordSpace = camera.getScreenSpace()

		x, y := camera.screenPivot(gmath.Pivot.topRight)

		x -= 2
		y -= 2

		fpsText := fmt.tprintf("FPS: %.2f", 1.0 / coreContext.deltaTime)

		render.drawText(
			{x, y},
			fpsText,
			zLayer = game.ZLayer.ui,
			pivot = gmath.Pivot.topRight,
			scale = 0.5,
		)
	}

	gameUpdate()
	gameDraw()
}

gameUpdate :: proc() {
	coreContext := utils.getCoreContext()
	drawFrame := render.getDrawFrame()

	coreContext.gameState.scratch = {}
	defer {
		coreContext.gameState.gameTimeElapsed += f64(coreContext.deltaTime)
		coreContext.gameState.ticks += 1
	}

	drawFrame.reset.coordSpace = camera.getWorldSpace()

	if coreContext.gameState.ticks == 0 {
		player := entityCreate(.player)
		thing1 := entityCreate(.thing1)
		thing1.pos.x = 30
		coreContext.gameState.playerHandle = player.handle
	}

	rebuildScratchHelpers()

	for handle in getAllEnts() {
		e := entityFromHandle(handle)

		updateEntityAnimation(e)

		if e.updateProc == nil do continue
		e.updateProc(e)
	}

	utils.animateToTargetVec2(
		&coreContext.gameState.camPos,
		getPlayer().pos,
		coreContext.deltaTime,
		rate = 10,
	)
}

gameDraw :: proc() {
	drawFrame := render.getDrawFrame()

	drawFrame.reset.shaderData.ndcToWorldXForm =
		camera.getWorldSpaceCamera() * linalg.inverse(camera.getWorldSpaceProj())
	drawFrame.reset.shaderData.bgRepeatTexAtlasUv = render.atlasUvFromSprite(
		game.SpriteName.bg_repeat_tex0,
	)

	{
		drawFrame.reset.coordSpace = {
			proj     = gmath.Mat4(1),
			camera   = gmath.Mat4(1),
			viewProj = gmath.Mat4(1),
		}

		render.drawRect(
			gmath.Rect{-1, -1, 1, 1},
			flags = game.QuadFlags.backgroundPixels,
			zLayer = game.ZLayer.background,
		)
	}

	{
		drawFrame.reset.coordSpace = camera.getWorldSpace()

		render.drawText(
			{0, -50},
			"odin on the web",
			pivot = gmath.Pivot.bottomCenter,
			dropShadowCol = {},
			zLayer = game.ZLayer.background,
		)

		for handle in getAllEnts() {
			e := entityFromHandle(handle)
			if e.drawProc == nil do continue
			e.drawProc(e)
		}
	}
}
