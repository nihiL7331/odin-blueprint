// This file is the entry point for all gameplay code.

package game

import "../core"
import "../core/input"
import "../core/render"
import "../core/scene"
import "../core/ui"
import "../systems/entities"
import "../systems/tween"
import "../types/color"
import "../types/game"
import "../types/gmath"
import "scenes"

import "core:fmt"

VERSION :: "v0.0.0"
WINDOW_TITLE :: "Blueprint"

init :: proc() {
	ui.init()
	scenes.initRegistry()
	scene.init(game.SceneName.Gameplay)
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

	render.setCoordSpace(render.getScreenSpace())

	bottomLeft := render.screenPivot(gmath.Pivot.bottomLeft)

	ui.begin(input.getScreenMousePos())
	if ui.Window(
		"Debug Player",
		gmath.rectMake(bottomLeft, gmath.Vec2{80, 100}),
		pivot = gmath.Pivot.bottomLeft,
	) {
		if ui.Button("Reset Player Pos") {
			tween.to(&player.pos, gmath.Vec2{0.0, 0.0}, 1.0, ease = gmath.EaseName.InOutQuad)
		}
		ui.Button("Test2")
	}
	ui.end()

	render.setCoordSpace(render.getScreenSpace())

	font, ok := render.getFont(.alagard, 15)
	if ok {
		topRight := render.screenPivot(gmath.Pivot.topRight)
		fpsText := fmt.tprintf("FPS: %.2f", 1.0 / coreContext.deltaTime)
		render.drawText(
			topRight - 2,
			fpsText,
			&font,
			scale = 0.5,
			zLayer = game.ZLayer.ui,
			pivot = gmath.Pivot.topRight,
			col = color.WHITE,
		)
	}
}
