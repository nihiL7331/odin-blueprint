package camera

import "../../core"
import "../../types/game"
import "../../types/gfx"
import "../../types/gmath"

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
	coreContext := core.getCoreContext()
	return linalg.matrix_ortho3d_f32(
		f32(coreContext.windowWidth) * -0.5,
		f32(coreContext.windowWidth) * 0.5,
		f32(coreContext.windowHeight) * -0.5,
		f32(coreContext.windowHeight) * 0.5,
		-1,
		1,
	)
}
getWorldSpaceCamera :: proc() -> gmath.Mat4 {
	coreContext := core.getCoreContext()

	cam := gmath.Mat4(1)
	cam *= gmath.xFormTranslate(coreContext.gameState.world.camPos)
	cam *= gmath.xFormScale(getCameraZoom())
	return cam
}
getCameraZoom :: proc() -> f32 {
	coreContext := core.getCoreContext()
	return f32(game.GAME_HEIGHT) / f32(coreContext.windowHeight)
}

getScreenSpaceProj :: proc() -> gmath.Mat4 {
	coreContext := core.getCoreContext()
	aspect := f32(coreContext.windowWidth) / f32(coreContext.windowHeight)

	viewHeight := f32(game.GAME_HEIGHT)
	viewWidth := viewHeight * aspect

	viewLeft := (f32(game.GAME_WIDTH) * 0.5) - (viewWidth * 0.5)
	viewRight := viewLeft + viewWidth

	return linalg.matrix_ortho3d_f32(viewLeft, viewRight, 0, viewHeight, -1, 1)
}

screenPivot :: proc(pivot: gmath.Pivot) -> (x, y: f32) {
	coreContext := core.getCoreContext()
	aspect := f32(coreContext.windowWidth) / f32(coreContext.windowHeight)

	viewHeight := f32(game.GAME_HEIGHT)
	viewWidth := viewHeight * aspect

	left: f32 = (f32(game.GAME_WIDTH) * 0.5) - (viewWidth * 0.5)
	right: f32 = left + viewWidth
	top: f32 = viewHeight
	bottom: f32 = 0.0

	centerX: f32 = (left + right) * 0.5
	centerY: f32 = (top + bottom) * 0.5

	switch pivot {
	case gmath.Pivot.topLeft:
		return left, top
	case gmath.Pivot.topCenter:
		return centerX, top
	case gmath.Pivot.topRight:
		return right, top
	case gmath.Pivot.centerLeft:
		return left, centerY
	case gmath.Pivot.centerCenter:
		return centerX, centerY
	case gmath.Pivot.centerRight:
		return right, centerY
	case gmath.Pivot.bottomLeft:
		return left, bottom
	case gmath.Pivot.bottomCenter:
		return centerX, bottom
	case gmath.Pivot.bottomRight:
		return right, bottom
	}
	return 0, 0
}

screenPivotVec2 :: proc(pivot: gmath.Pivot) -> gmath.Vec2 {
	pivotX, pivotY := screenPivot(pivot)
	return gmath.Vec2{pivotX, pivotY}
}

follow :: proc(target: gmath.Vec2, rate: f32 = 10.0) {
	_camera.target = target
	_camera.followRate = rate
}

init :: proc() {
	_camera = defaultCamera()
}

update :: proc() {
	coreContext := core.getCoreContext()

	if _camera.followRate > 0 {
		t := 1.0 - math.exp_f32(-_camera.followRate * coreContext.deltaTime)
		_camera.position = math.lerp(_camera.position, _camera.target, t)
	} else {
		_camera.position = _camera.target
	}

	bounds, ok := _camera.bounds.?
	if ok {
		aspect := f32(coreContext.windowWidth) / f32(coreContext.windowHeight)

		halfW := f32(game.GAME_HEIGHT) / 2
		halfH := halfW * aspect

		_camera.position = gmath.Vec2 {
			math.clamp(_camera.position.x, bounds.x + halfW, bounds.z - halfW),
			math.clamp(_camera.position.y, bounds.y + halfH, bounds.w - halfH),
		}
	}

	coreContext.gameState.world.camPos = _camera.position

	//TODO:
	// if _camera.shakeTimer > 0 {
	//   _camera.shakeTimer -= dt
	// }
}
