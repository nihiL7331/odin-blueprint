// This file is the entry point for all gameplay code.

package game

import "../core"
import "../core/input"
import "../core/render"
import "../core/scene"
import "../core/ui"
import "../systems/camera"
import "../systems/entities"
import "../systems/tween"
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
	tween.update()
}

draw :: proc() {
	scene.draw()
	drawUiLayer()
}


drawUiLayer :: proc() {
	coreContext := core.getCoreContext()
	player := entities.getPlayer()

	render.setCoordSpace(camera.getScreenSpace())

	@(static) textColor: gmath.Vec4 = gmath.Vec4{1.0, 1.0, 1.0, 1.0}
	@(static) stop: bool = false
	topLeftX, topLeftY := camera.screenPivot(gmath.Pivot.topLeft) //NOTE: this is hacky, might want to add pivoting
	ui.begin(input.getScreenMousePos())
	if ui.Window(
		"Debug",
		gmath.rectMake(gmath.Vec2{topLeftX, topLeftY - 100}, gmath.Vec2{80, 100}),
	) {
		if ui.Button("Reset Player Pos") {
			tween.to(&player.pos, gmath.Vec2{0.0, 0.0}, 1.5, ease = .InElastic)
		}
		ui.Button("Test2")
		ui.Header("Checkboxes")
		ui.Checkbox(&stop, "Stop time")
	}
	if ui.Window("Debug2", gmath.rectMake(gmath.Vec2{150, 100}, gmath.Vec2{50, 55})) {
		if ui.Button("Clear") {
			textColor = gmath.Vec4{1.0, 1.0, 1.0, 1.0}
		}
		ui.ColorPicker(&textColor, "Color", true)
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
		col = textColor,
	)
}
