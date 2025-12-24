package splash

import "../../../core/input"
import "../../../core/render"
import "../../../core/scene"
import "../../../systems/tween"
import "../../../types/game"
import "../../../types/gmath"

Data :: struct {
	logoAlpha: f32,
}

init :: proc(data: rawptr) {
	state := (^Data)(data)
	state.logoAlpha = 0.0
	onEnd := proc(data: rawptr) {scene.change(game.SceneName.Gameplay)}
	t1 := tween.to(&state.logoAlpha, 1.0, 3.0, ease = gmath.EaseName.InSine)
	t2 := tween.to(&state.logoAlpha, 0.0, 2.0, ease = gmath.EaseName.OutSine, onEnd = onEnd)
	tween.then(t1, t2)
}

update :: proc(data: rawptr) {
	// state := (^Data)(data)

	if input.anyKeyPressAndConsume() {
		scene.change(game.SceneName.Gameplay)
	}
}

draw :: proc(data: rawptr) {
	state := (^Data)(data)
	render.setCoordSpace(render.getScreenSpace())

	centerCenter := render.screenPivot(gmath.Pivot.centerCenter)
	render.drawSprite(
		centerCenter,
		game.SpriteName.bonsai_logo,
		col = gmath.Vec4{1.0, 1.0, 1.0, state.logoAlpha},
	)
}

exit :: proc(data: rawptr) {
	// state := (^Data)(data)

}
