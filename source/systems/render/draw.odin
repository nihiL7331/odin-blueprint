package render

import "../../types/color"
import "../../types/game"
import "../../types/gmath"
import "../../utils"
import "../../utils/shape"

drawSprite :: proc(
	pos: gmath.Vec2,
	sprite: game.SpriteName,
	pivot := gmath.Pivot.centerCenter,
	flipX := false,
	drawOffset := gmath.Vec2{},
	xForm := gmath.Mat4(1),
	animIndex := 0,
	col := color.WHITE,
	colOverride := gmath.Vec4{},
	zLayer := game.ZLayer{},
	flags := game.QuadFlags{},
	params := gmath.Vec4{},
	cropTop: f32 = 0.0,
	cropLeft: f32 = 0.0,
	cropBottom: f32 = 0.0,
	cropRight: f32 = 0.0,
	zLayerQueue := -1,
) {
	rectSize := getSpriteSize(sprite)
	frameCount := getFrameCount(sprite)
	rectSize.x /= f32(frameCount)

	_xForm := gmath.Mat4(1)
	_xForm *= utils.xFormTranslate(pos)
	_xForm *= utils.xFormScale(gmath.Vec2{flipX ? -1.0 : 1.0, 1.0})
	_xForm *= xForm
	_xForm *= utils.xFormTranslate(rectSize * -utils.scaleFromPivot(pivot))
	_xForm *= utils.xFormTranslate(-drawOffset)

	drawRectXForm(
		_xForm,
		rectSize,
		sprite,
		animIndex = animIndex,
		col = col,
		colOverride = colOverride,
		zLayer = zLayer,
		flags = flags,
		params = params,
		cropTop = cropTop,
		cropLeft = cropLeft,
		cropBottom = cropBottom,
		cropRight = cropRight,
		zLayerQueue = zLayerQueue,
	)
}

drawRect :: proc(
	rect: gmath.Rect,
	sprite := game.SpriteName.nil,
	uv := DEFAULT_UV,
	outlineCol := gmath.Vec4{},
	col := color.WHITE,
	colOverride := gmath.Vec4{},
	zLayer := game.ZLayer{},
	flags := game.QuadFlags{},
	params := gmath.Vec4{},
	cropTop: f32 = 0.0,
	cropLeft: f32 = 0.0,
	cropBottom: f32 = 0.0,
	cropRight: f32 = 0.0,
	zLayerQueue := -1,
) {
	xForm := utils.xFormTranslate(rect.xy)
	size := shape.rectSize(rect)

	if outlineCol != {} {
		size := size
		xForm := xForm
		size += gmath.Vec2(2)
		xForm *= utils.xFormTranslate(gmath.Vec2(-1))
		drawRectXForm(
			xForm,
			size,
			col = outlineCol,
			uv = uv,
			colOverride = colOverride,
			zLayer = zLayer,
			flags = flags,
			params = params,
		)
	}

	drawRectXForm(
		xForm,
		size,
		sprite,
		uv,
		0,
		0,
		col,
		colOverride,
		zLayer,
		flags,
		params,
		cropTop,
		cropLeft,
		cropBottom,
		cropRight,
		zLayerQueue,
	)
}

drawSpriteInRect :: proc(
	sprite: game.SpriteName,
	pos: gmath.Vec2,
	size: gmath.Vec2,
	xForm := gmath.Mat4(1),
	col := color.WHITE,
	colOverride := gmath.Vec4{0, 0, 0, 0},
	zLayer := game.ZLayer.nil,
	flags := game.QuadFlags(0),
	paddingPercent: f32 = 0.1,
) {
	imgSize := getSpriteSize(sprite)

	rect := shape.rectMake(pos, size)

	{ 	// padding
		rect = shape.rectShift(rect, -rect.xy)
		rect.xy += size * paddingPercent * 0.5
		rect.zw -= size * paddingPercent * 0.5
		rect = shape.rectShift(rect, pos)
	}

	{ 	//shrink rect if sprite is too small
		rectSize := shape.rectSize(rect)
		sizeDiffX := rectSize.x - imgSize.x
		if sizeDiffX < 0 {
			sizeDiffX = 0
		}

		sizeDiffY := rectSize.y - imgSize.y
		if sizeDiffY < 0 {
			sizeDiffY = 0
		}
		sizeDiff := gmath.Vec2{sizeDiffX, sizeDiffY}

		offset := rect.xy
		rect = shape.rectShift(rect, -rect.xy)
		rect.xy += sizeDiff * 0.5
		rect.zw -= sizeDiff * 0.5
		rect = shape.rectShift(rect, offset)
	}

	if imgSize.x > imgSize.y {
		rectSize := shape.rectSize(rect)
		rect.w = rect.y + (rectSize.x * (imgSize.y / imgSize.x))

		newHeight := rect.w - rect.y
		rect = shape.rectShift(rect, gmath.Vec2{0, (rectSize.y - newHeight) * 0.5})
	} else if imgSize.y > imgSize.x {
		rectSize := shape.rectSize(rect)
		rect.z = rect.x + (rectSize.y * (imgSize.x / imgSize.y))

		newWidth := rect.z - rect.x
		rect = shape.rectShift(rect, gmath.Vec2{0, (rectSize.x - newWidth) * 0.5})
	}

	drawRect(
		rect,
		col = col,
		sprite = sprite,
		colOverride = colOverride,
		zLayer = zLayer,
		flags = flags,
	)
}

drawRectXForm :: proc(
	xForm: gmath.Mat4,
	size: gmath.Vec2,
	sprite := game.SpriteName.nil,
	uv := DEFAULT_UV,
	texIndex: u8 = 0,
	animIndex := 0,
	col := color.WHITE,
	colOverride := gmath.Vec4{},
	zLayer := game.ZLayer{},
	flags := game.QuadFlags{},
	params := gmath.Vec4{},
	cropTop: f32 = 0.0,
	cropLeft: f32 = 0.0,
	cropBottom: f32 = 0.0,
	cropRight: f32 = 0.0,
	zLayerQueue := -1,
) {
	size := size
	col := col
	uv := uv
	texIndex := texIndex // to mut later

	drawFrame := getDrawFrame()

	if uv == DEFAULT_UV {
		uv = atlasUvFromSprite(sprite)

		frameCount := getFrameCount(sprite)
		frameSize := size
		frameSize.x /= f32(frameCount)
		uvSize := shape.rectSize(uv)
		uvFrameSize := uvSize * gmath.Vec2{frameSize.x / size.x, 1.0}
		uv.zw = uv.xy + uvFrameSize
		uv = shape.rectShift(uv, gmath.Vec2{f32(animIndex) * uvFrameSize.x, 0})
	}

	assert(drawFrame.reset.coordSpace != {}, "No coord space set.")

	localToClipSpace := drawFrame.reset.coordSpace.viewProj * xForm

	{
		if cropTop != 0.0 {
			newHeight := size.y * (1.0 - cropTop)
			uvSize := shape.rectSize(uv)

			uv.w -= uvSize.y * cropTop
			size.y = newHeight
		}
		if cropLeft != 0.0 {
			crop := size.x * cropLeft
			size.x -= crop

			uvSize := shape.rectSize(uv)
			uv.x += uvSize.x * cropLeft

			localToClipSpace *= utils.xFormTranslate(gmath.Vec2{crop, 0})
		}
		if cropBottom != 0.0 {
			crop := size.y * (1.0 - cropBottom)
			diff: f32 = crop - size.y
			size.y = crop
			uvSize := shape.rectSize(uv)

			uv.y += uvSize.y * cropBottom
			localToClipSpace *= utils.xFormTranslate(gmath.Vec2{0, -diff})
		}
		if cropRight != 0.0 {
			size.x *= 1.0 - cropRight
			uvSize := shape.rectSize(uv)
			uv.z -= uvSize.x * cropRight
		}
	}

	bl := gmath.Vec2{0, 0}
	tl := gmath.Vec2{0, size.y}
	tr := gmath.Vec2{size.x, size.y}
	br := gmath.Vec2{size.x, 0}

	if texIndex == 0 && sprite == .nil {
		texIndex = 255
	}

	drawQuadProjected(
		localToClipSpace,
		{bl, tl, tr, br},
		{col, col, col, col},
		{uv.xy, uv.xw, uv.zw, uv.zy},
		texIndex,
		size,
		colOverride,
		zLayer,
		flags,
		params,
		zLayerQueue,
	)
}
