// This file is the entry point for all gameplay code.

package game

import "../core"
import "../core/render"
import "../systems/camera"
import "../systems/entities"
import "../types/game"
import "../types/gmath"
import "../utils"
import "entityData"

import "core:fmt"
import "core:math/linalg"

VERSION :: "v0.0.0"
WINDOW_TITLE :: "Blueprint"

init :: proc() {
	coreContext := core.getCoreContext()

	player := entityData.spawnPlayer()
	coreContext.gameState.playerHandle = player.handle

	entityData.spawnThing()

	camera.init()
}

update :: proc() {
	coreContext := core.getCoreContext()

	entities.updateAll()

	player := entities.entityFromHandle(coreContext.gameState.playerHandle)
	camera.follow(player.pos)
	camera.update()
}

draw :: proc() {
	render.getDrawFrame().reset.sortedLayers = {.playspace, .shadow}

	drawBackgroundLayer()

	render.setCoordSpace(camera.getWorldSpace())
	entities.drawAll()

	drawUiLayer()
}

drawBackgroundLayer :: proc() {
	drawFrame := render.getDrawFrame()

	drawFrame.reset.shaderData.ndcToWorldXForm =
		camera.getWorldSpaceCamera() * linalg.inverse(camera.getWorldSpaceProj())
	drawFrame.reset.shaderData.bgRepeatTexAtlasUv = render.atlasUvFromSprite(
		game.SpriteName.bg_repeat_tex0,
	)
	render.setCoordSpace()

	render.drawRect(
		gmath.Rect{-1, -1, 1, 1},
		flags = game.QuadFlags.backgroundPixels,
		zLayer = game.ZLayer.background,
	)
}

drawUiLayer :: proc() {
	coreContext := core.getCoreContext()

	render.setCoordSpace(camera.getScreenSpace())

	x, y := utils.screenPivot(gmath.Pivot.topRight)
	fpsText := fmt.tprintf("FPS: %.2f", 1.0 / coreContext.deltaTime)
	render.drawText(
		{x - 2, y - 2},
		fpsText,
		zLayer = game.ZLayer.ui,
		pivot = gmath.Pivot.topRight,
		scale = 0.5,
	)
}
