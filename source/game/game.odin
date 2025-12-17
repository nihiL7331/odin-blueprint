// This file is the entry point for all gameplay code.

package game

import "../core"
import "../core/input"
import "../core/render"
import "../core/scene"
import "../core/ui"
import "../systems/camera"
import "../types/game"
import "../types/gmath"
import "scenes"

import "core:fmt"

VERSION :: "v0.0.0"
WINDOW_TITLE :: "Blueprint"

init :: proc() {
	ui.init()
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

	@(static) speed: f32 = 5.0
	@(static) stop: bool = false

	ui.begin(input.getScreenMousePos())
	if ui.Window("Debug", gmath.rectMake(gmath.Vec2{100, 100}, gmath.Vec2{50, 100})) {
		ui.Button("Test1")
		ui.Button("Test2")
		ui.Checkbox(&stop, "Stop time")
	}
	if ui.Window("Debug2", gmath.rectMake(gmath.Vec2{150, 100}, gmath.Vec2{50, 50})) {
		ui.Button("Test3")
		ui.Slider(&speed, 1.0, 10.0, "Value")
	}
	ui.end()

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
