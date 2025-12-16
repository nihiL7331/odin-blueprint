// This file is the entry point for all gameplay code.

package game

import "../core"
import "../core/render"
import "../core/scene"
import "../systems/camera"
import "../types/game"
import "../types/gmath"
import "scenes"

import "core:fmt"

VERSION :: "v0.0.0"
WINDOW_TITLE :: "Blueprint"

init :: proc() {
	scenes.initRegistry()
	scene.init(game.SceneName.Splash)
}

update :: proc() {
	scene.update()
}

draw :: proc() {
	scene.draw()
	drawUiLayer()
}


drawUiLayer :: proc() {
	coreContext := core.getCoreContext()

	render.setCoordSpace(camera.getScreenSpace())

	x, y := camera.screenPivot(gmath.Pivot.topRight)
	fpsText := fmt.tprintf("FPS: %.2f", 1.0 / coreContext.deltaTime)
	render.drawText(
		{x - 2, y - 2},
		fpsText,
		zLayer = game.ZLayer.ui,
		pivot = gmath.Pivot.topRight,
		scale = 0.5,
	)
}
