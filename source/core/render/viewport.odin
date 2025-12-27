package render

import core ".."
import "../../types/game"
import "../../types/gfx"
import "../../types/gmath"

import "core:math/linalg"

getWorldSpace :: proc() -> gfx.CoordSpace {
	proj := getWorldSpaceProj()
	camera := getWorldSpaceCamera()
	inverseCamera := linalg.inverse(camera)

	return {proj = proj, camera = camera, viewProj = proj * inverseCamera}
}
getScreenSpace :: proc() -> gfx.CoordSpace {
	proj := getScreenSpaceProj()
	camera := gmath.Mat4(1)

	return {proj = proj, camera = camera, viewProj = proj}
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

	camera := gmath.Mat4(1)
	camera *= gmath.xFormTranslate(coreContext.gameState.world.cameraPosition)
	camera *= gmath.xFormScale(getCameraZoom())
	return camera
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

screenPivot :: proc(pivot: gmath.Pivot) -> gmath.Vec2 {
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
		return gmath.Vec2{left, top}
	case gmath.Pivot.topCenter:
		return gmath.Vec2{centerX, top}
	case gmath.Pivot.topRight:
		return gmath.Vec2{right, top}
	case gmath.Pivot.centerLeft:
		return gmath.Vec2{left, centerY}
	case gmath.Pivot.centerCenter:
		return gmath.Vec2{centerX, centerY}
	case gmath.Pivot.centerRight:
		return gmath.Vec2{right, centerY}
	case gmath.Pivot.bottomLeft:
		return gmath.Vec2{left, bottom}
	case gmath.Pivot.bottomCenter:
		return gmath.Vec2{centerX, bottom}
	case gmath.Pivot.bottomRight:
		return gmath.Vec2{right, bottom}
	}
	return gmath.Vec2{0.0, 0.0}
}
