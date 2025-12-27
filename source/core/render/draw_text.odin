package render

import "../../types/color"
import "../../types/game"
import "../../types/gmath"

import tt "../../libs/stb/truetype"

drawText :: drawTextWithDropShadow

drawTextWrapped :: proc(
	pos: gmath.Vec2,
	text: string,
	font: ^Font,
	wrapWidth: f32,
	col := color.WHITE,
	scale := 1.0,
	pivot := gmath.Pivot.bottomLeft,
	zLayer := game.ZLayer.nil,
	colOverride := gmath.Vec4{0, 0, 0, 0},
) -> gmath.Vec2 {
	//TODO: wrapping text
	return drawTextNoDropShadow(pos, text, font, col, scale, pivot, zLayer, colOverride)
}

drawTextWithDropShadow :: proc(
	pos: gmath.Vec2,
	text: string,
	font: ^Font,
	dropShadowCol := color.BLACK,
	col := color.WHITE,
	scale := 1.0,
	pivot := gmath.Pivot.bottomLeft,
	zLayer := game.ZLayer.nil,
	colOverride := gmath.Vec4{0, 0, 0, 0},
) -> gmath.Vec2 {
	offset := gmath.Vec2{1, -1} * f32(scale)

	drawTextNoDropShadow(
		pos + offset,
		text,
		font = font,
		col = dropShadowCol * col,
		scale = scale,
		pivot = pivot,
		zLayer = zLayer,
		colOverride = colOverride,
	)

	dim := drawTextNoDropShadow(
		pos,
		text,
		font = font,
		col = col,
		scale = scale,
		pivot = pivot,
		zLayer = zLayer,
		colOverride = colOverride,
	)

	return dim
}

drawTextNoDropShadow :: proc(
	pos: gmath.Vec2,
	text: string,
	font: ^Font,
	col := color.WHITE,
	scale := 1.0,
	pivot := gmath.Pivot.bottomLeft,
	zLayer := game.ZLayer.nil,
	colOverride := gmath.Vec4{0, 0, 0, 0},
) -> (
	textBounds: gmath.Vec2,
) {
	if zLayer != game.ZLayer.nil {
		getDrawFrame().reset.activeZLayer = zLayer
	}

	// find size
	totalSize: gmath.Vec2
	for char, i in text {
		advanceX: f32
		advanceY: f32

		q: tt.aligned_quad
		tt.GetBakedQuad(
			&font.charData[0],
			BITMAP_WIDTH,
			BITMAP_HEIGHT,
			cast(i32)char - 32,
			&advanceX,
			&advanceY,
			&q,
			false,
		)
		// x0, y0,  s0, t0 <=> top-left
		// x1, y1,  s1, t1 <=> bottom-right

		size := gmath.Vec2{abs(q.x0 - q.x1), abs(q.y0 - q.y1)}

		bottomLeft := gmath.Vec2{q.x0, -q.y1}
		topRight := gmath.Vec2{q.x1, -q.y0}
		assert(bottomLeft + size == topRight, "Font sizing error (find size)")

		if i == len(text) - 1 {
			totalSize.x += size.x
		} else {
			totalSize.x += advanceX
		}

		totalSize.y = max(totalSize.y, topRight.y)
	}

	pivotOffset := totalSize * -gmath.scaleFromPivot(pivot)

	x: f32
	y: f32

	//draw
	for char in text {
		advanceX: f32
		advanceY: f32
		q: tt.aligned_quad
		tt.GetBakedQuad(
			&font.charData[0],
			BITMAP_WIDTH,
			BITMAP_HEIGHT,
			cast(i32)char - 32,
			&advanceX,
			&advanceY,
			&q,
			false,
		)
		// x0, y0,  s0, t0 <=> top-left
		// x1, y1,  s1, t1 <=> bottom-right

		size := gmath.Vec2{abs(q.x0 - q.x1), abs(q.y0 - q.y1)}

		bottomLeft := gmath.Vec2{q.x0, -q.y1}
		topRight := gmath.Vec2{q.x1, -q.y0}
		assert(bottomLeft + size == topRight, "Font sizing error (draw)")

		offsetToRenderAt := gmath.Vec2{x, y} + bottomLeft
		offsetToRenderAt += pivotOffset

		uv := gmath.Vec4{q.s0, q.t1, q.s1, q.t0}

		xForm := gmath.Mat4(1)
		xForm *= gmath.xFormTranslate(pos)
		xForm *= gmath.xFormScale(gmath.Vec2{f32(scale), f32(scale)})
		xForm *= gmath.xFormTranslate(offsetToRenderAt)

		drawRectXForm(xForm, size, uv = uv, texIndex = 1, colOverride = colOverride, col = col)

		x += advanceX
		y += -advanceY
	}

	return totalSize * f32(scale)
}
