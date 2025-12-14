package camera

import "../../types/game" // for window size in globals
import "../../types/gfx"
import "../../types/gmath"
import "../../utils"

import "core:math/linalg"

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

screenPivot :: proc(pivot: gmath.Pivot) -> (x, y: f32) {
	aspect := f32(game.windowWidth) / f32(game.windowHeight)

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
