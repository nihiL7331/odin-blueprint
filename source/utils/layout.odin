package utils

import "../types/game"
import "../types/gmath"

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
