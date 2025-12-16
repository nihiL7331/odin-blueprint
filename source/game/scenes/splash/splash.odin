package splash

import "../../../core/input"
import "../../../core/render"
import "../../../core/scene"

import "../../../systems/camera"

import "../../../types/game"
import "../../../types/gmath"

Data :: struct {}

init :: proc(data: rawptr) {
	// state := (^Data)(data)
}

update :: proc(data: rawptr) {
	// state := (^Data)(data)

	if input.anyKeyPressAndConsume() {
		scene.change(game.SceneName.Gameplay)
	}
}

draw :: proc(data: rawptr) {
	// state := (^Data)(data)
	render.setCoordSpace(camera.getScreenSpace())

	x, y := camera.screenPivot(gmath.Pivot.centerCenter)
	render.drawText(
		{x, y},
		"press any button",
		zLayer = game.ZLayer.ui,
		pivot = gmath.Pivot.centerCenter,
	)
}

exit :: proc(data: rawptr) {
	// state := (^Data)(data)

}
