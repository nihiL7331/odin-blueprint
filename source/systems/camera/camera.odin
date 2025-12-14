package camera

import "../../types/game" // for window size in globals
import "../../types/gfx"
import "../../types/gmath"
import "../../utils"

import "core:math"
import "core:math/linalg"

Camera :: struct {
	position:    gmath.Vec2,
	target:      gmath.Vec2,
	followRate:  f32,
	bounds:      Maybe(gmath.Rect),
	shakeAmount: f32,
	shakeTimer:  f32,
}

defaultCamera :: proc() -> Camera {
	return Camera{position = {0, 0}, target = {0, 0}, followRate = 10.0}
}
@(private)
_camera: Camera

getWorldSpace :: proc() -> gfx.CoordSpace {
	p := getWorldSpaceProj()
	c := getWorldSpaceCamera()
	invC := linalg.inverse(c)

	return {proj = p, camera = c, viewProj = p * invC}
}
getScreenSpace :: proc() -> gfx.CoordSpace {
	p := getScreenSpaceProj()
	c := gmath.Mat4(1)

	return {proj = p, camera = c, viewProj = p}
}

getWorldSpaceProj :: proc() -> gmath.Mat4 {
	return linalg.matrix_ortho3d_f32(
		f32(game.windowWidth) * -0.5,
		f32(game.windowWidth) * 0.5,
		f32(game.windowHeight) * -0.5,
		f32(game.windowHeight) * 0.5,
		-1,
		1,
	)
}
getWorldSpaceCamera :: proc() -> gmath.Mat4 {
	coreContext := utils.getCoreContext()

	cam := gmath.Mat4(1)
	cam *= utils.xFormTranslate(coreContext.gameState.camPos)
	cam *= utils.xFormScale(getCameraZoom())
	return cam
}
getCameraZoom :: proc() -> f32 {
	return f32(game.GAME_HEIGHT) / f32(game.windowHeight)
}

getScreenSpaceProj :: proc() -> gmath.Mat4 {
	aspect := f32(game.windowWidth) / f32(game.windowHeight)

	viewHeight := f32(game.GAME_HEIGHT)
	viewWidth := viewHeight * aspect

	viewLeft := (f32(game.GAME_WIDTH) * 0.5) - (viewWidth * 0.5)
	viewRight := viewLeft + viewWidth

	return linalg.matrix_ortho3d_f32(viewLeft, viewRight, 0, viewHeight, -1, 1)
}

followCamera :: proc(target: gmath.Vec2, rate: f32 = 10.0) {
	_camera.target = target
	_camera.followRate = rate
}

initCamera :: proc() {
	_camera = defaultCamera()
}

updateCamera :: proc() {
	coreContext := utils.getCoreContext()

	if _camera.followRate > 0 {
		t := 1.0 - math.exp_f32(-_camera.followRate * coreContext.deltaTime)
		_camera.position = math.lerp(_camera.position, _camera.target, t)
	} else {
		_camera.position = _camera.target
	}

	bounds, ok := _camera.bounds.?
	if ok {
		aspect := f32(game.windowWidth) / f32(game.windowHeight)

		halfW := f32(game.GAME_HEIGHT) / 2
		halfH := halfW * aspect

		_camera.position = gmath.Vec2 {
			math.clamp(_camera.position.x, bounds.x + halfW, bounds.z - halfW),
			math.clamp(_camera.position.y, bounds.y + halfH, bounds.w - halfH),
		}
	}

	coreContext.gameState.camPos = _camera.position

	//TODO:
	// if _camera.shakeTimer > 0 {
	//   _camera.shakeTimer -= dt
	// }
}
