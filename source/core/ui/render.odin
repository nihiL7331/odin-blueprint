package ui

import "../../types/color"
import "../../types/game"
import "../../types/gmath"
import "../input"
import "../render"

import "core:log"
import "core:math"

Window :: proc(
	title: string,
	rect: gmath.Rect,
	pivot: gmath.Pivot = gmath.Pivot.centerCenter,
) -> bool {
	id := getId(title)
	if !(id in state.containers) {
		pivotOffset := -gmath.rectSize(rect) * gmath.scaleFromPivot(pivot)
		rect := rect
		rect.xy += pivotOffset
		rect.zw += pivotOffset
		state.containers[id] = Container {
			id     = id,
			rect   = rect,
			isOpen = true,
		}
	}
	container := &state.containers[id]

	if !container.isOpen do return false

	handleWindowMovement(id, &container.rect)
	renderWindow(title, container.rect)

	container.cursor.x = _PADDING
	container.cursor.y = _HEADER_HEIGHT

	state.currentContainer = container
	container.isOpen = CloseButton((id * 16777619) ~ 1) //seed random number generation

	return container.isOpen
}

handleWindowMovement :: proc(id: u32, rect: ^gmath.Rect) {
	headerRect := gmath.Rect{rect.x, rect.w - _HEADER_HEIGHT, rect.z, rect.w}

	if state.active == 0 || state.active == id {
		if gmath.rectContains(headerRect, gmath.Vec2{state.mouseX, state.mouseY}) &&
		   state.hot == 0 {
			state.hot = id

			if input.keyPressed(input.KeyCode.LEFT_MOUSE) {
				input.consumeKeyPressed(input.KeyCode.LEFT_MOUSE)
				state.active = id
			}
		}
	}

	if state.active == id {
		mouseDelta := _getMouseDelta()
		rect.xy += mouseDelta
		rect.zw += mouseDelta

		if input.keyReleased(input.KeyCode.LEFT_MOUSE) {
			state.active = 0
		}
	}
}

renderWindow :: proc(title: string, rect: gmath.Rect) {
	headerRect := gmath.Rect{rect.x, rect.w - _HEADER_HEIGHT, rect.z, rect.w}

	render.drawRect(
		rect,
		col = _STYLE[.WINDOW],
		zLayer = game.ZLayer.ui,
		outlineCol = _STYLE[.OUTLINE],
	)
	render.drawRect(headerRect, col = _STYLE[.HEADER], zLayer = game.ZLayer.ui)

	font, ok := render.getFont(.PixelCode, 12)
	if ok {
		render.drawText(
			gmath.Vec2{(rect.x + rect.z) / 2, (headerRect.y + headerRect.w) / 2},
			title,
			&font,
			col = _STYLE[.TEXT],
			zLayer = game.ZLayer.ui,
			scale = 0.5,
			pivot = gmath.Pivot.centerCenter,
		)
	}
}

Button :: proc(label: string) -> bool {
	parent := state.currentContainer

	if parent == nil {
		log.error("No parent container set. Button", label, "can't be drawn.")
		return false
	} else if parent.rect.y > parent.rect.w - parent.cursor.y { 	//TODO: add scrolling container here
		log.error("Button", label, "overflowed out of container.")
		return false
	}

	parent.cursor.y += _BUTTON_HEIGHT + _SPACING
	screenPos := gmath.Vec2{parent.rect.x + parent.cursor.x, parent.rect.w - parent.cursor.y}

	size := gmath.Vec2{parent.rect.z - parent.rect.x - _PADDING * 2, _BUTTON_HEIGHT}
	rect := gmath.rectMake(screenPos, size)
	rectColor := _STYLE[.BUTTON]
	textColor := _STYLE[.TEXT]

	result := false
	id := getId(label)

	if gmath.rectContains(rect, gmath.Vec2{state.mouseX, state.mouseY}) &&
	   (state.active == 0 || state.active == id) {
		rectColor = _STYLE[.HOVER_BUTTON]
		textColor = _STYLE[.HOVER_TEXT]
		state.hot = id

		if input.keyPressed(input.KeyCode.LEFT_MOUSE) {
			input.consumeKeyPressed(input.KeyCode.LEFT_MOUSE)
			state.active = id
		}
	}

	if state.active == id {
		rectColor = _STYLE[.ACTIVE_BUTTON]
		textColor = _STYLE[.ACTIVE_TEXT]

		if input.keyReleased(input.KeyCode.LEFT_MOUSE) {
			result = true
			state.active = 0
		}
	}

	render.drawRect(rect, col = rectColor, zLayer = game.ZLayer.ui)

	font, ok := render.getFont(.PixelCode, 12)
	if ok {
		render.drawText(
			screenPos + size / 2,
			label,
			&font,
			scale = 0.5,
			zLayer = game.ZLayer.ui,
			pivot = gmath.Pivot.centerCenter,
			col = textColor,
		)
	}

	return result
}

ColorPicker :: proc(val: ^gmath.Vec4, label: string, showAlpha: bool = false) {
	Slider(&val.x, 0.0, 1.0, "Red", color.RED)
	Slider(&val.y, 0.0, 1.0, "Blue", color.BLUE)
	Slider(&val.z, 0.0, 1.0, "Green", color.GREEN)
	if showAlpha {
		Slider(&val.w, 0.0, 1.0, "Alpha", color.hexToRGBA(0xaaaaaaff))
	}
}

Slider :: proc(
	value: ^f32,
	min, max: f32,
	label: string,
	fillColor: gmath.Vec4 = _STYLE[.SLIDER_FILL],
) {
	parent := state.currentContainer

	if parent == nil {
		log.error("No parent container set. Slider", label, "can't be drawn.")
		return
	} else if parent.rect.y > parent.rect.w - parent.cursor.y {
		log.error("Slider", label, "overflowed out of container.")
		return
	}

	parent.cursor.y += _SLIDER_HEIGHT + _SPACING
	screenPos := gmath.Vec2{parent.rect.x + parent.cursor.x, parent.rect.w - parent.cursor.y}

	size := gmath.Vec2{parent.rect.z - parent.rect.x - _PADDING * 2, _SLIDER_HEIGHT}
	rect := gmath.rectMake(screenPos, size)
	backgroundColor := _STYLE[.SLIDER_BACKGROUND]

	id := getId(label)
	if gmath.rectContains(rect, gmath.Vec2{state.mouseX, state.mouseY}) &&
	   (state.active == 0 || state.active == id) {
		state.hot = id

		if input.keyPressed(input.KeyCode.LEFT_MOUSE) {
			input.consumeKeyPressed(input.KeyCode.LEFT_MOUSE)
			state.active = id
		}
	}

	if state.active == id {
		mouseX := state.mouseX
		ratio := (mouseX - rect.x) / (rect.z - rect.x)
		ratio = math.clamp(ratio, 0.0, 1.0)

		value^ = min + (ratio * (max - min))

		if input.keyReleased(.LEFT_MOUSE) {
			state.active = 0
		}
	}

	render.drawRect(rect, col = backgroundColor, zLayer = game.ZLayer.ui)

	currentRatio := (value^ - min) / (max - min)
	fillWidth := (rect.z - rect.x) * currentRatio
	fillRect := gmath.Rect{rect.x, rect.y, rect.x + fillWidth, rect.w}
	render.drawRect(fillRect, col = fillColor, zLayer = game.ZLayer.ui)

	font, ok := render.getFont(.PixelCode, 12)
	if ok {
		render.drawText(
			screenPos + size / 2,
			label,
			&font,
			dropShadowCol = color.TRANSPARENT,
			col = gmath.Vec4{1, 1, 1, 0.5},
			scale = 0.5,
			pivot = gmath.Pivot.centerCenter,
			zLayer = game.ZLayer.ui,
		)
	}
}

Checkbox :: proc(val: ^bool, label: string) {
	parent := state.currentContainer

	if parent == nil {
		log.error("No parent container set. Checkbox", label, "can't be drawn.")
		return
	} else if parent.rect.y > parent.rect.w - parent.cursor.y {
		log.error("Checkbox", label, "overflowed out of container.")
		return
	}
	parent.cursor.y += _BUTTON_HEIGHT + _SPACING
	screenPos := gmath.Vec2 {
		parent.rect.z - parent.cursor.x - _BUTTON_HEIGHT,
		parent.rect.w - parent.cursor.y,
	}

	size := gmath.Vec2{_BUTTON_HEIGHT, _BUTTON_HEIGHT}
	rect := gmath.rectMake(screenPos, size)
	rectColor := _STYLE[.BUTTON]

	id := getId(label)

	if gmath.rectContains(rect, gmath.Vec2{state.mouseX, state.mouseY}) &&
	   (state.active == 0 || state.active == id) {
		state.hot = id

		if input.keyPressed(input.KeyCode.LEFT_MOUSE) {
			input.consumeKeyPressed(input.KeyCode.LEFT_MOUSE)
			state.active = id
		}
	}

	if state.active == id {
		rectColor = _STYLE[.ACTIVE_BUTTON]

		if input.keyReleased(input.KeyCode.LEFT_MOUSE) {
			log.info("clicked")
			val^ = !val^
			state.active = 0
		}
	}

	render.drawRect(rect, col = rectColor, zLayer = game.ZLayer.ui)
	font, ok := render.getFont(.PixelCode, 12)
	if ok {
		render.drawText(
			gmath.Vec2{parent.rect.x + parent.cursor.x, screenPos.y + size.y / 2},
			label,
			&font,
			col = _STYLE[.TEXT],
			scale = 0.5,
			pivot = gmath.Pivot.centerLeft,
		)
		if val^ {
			render.drawText(
				screenPos + size / 2,
				"X",
				&font,
				zLayer = game.ZLayer.ui,
				scale = 0.5,
				pivot = gmath.Pivot.centerCenter,
				col = _STYLE[.TEXT],
			)
		}
	}
}

Header :: proc(label: string) { 	// technically a subheader, this one isn't draggable
	parent := state.currentContainer

	if parent == nil {
		log.error("No parent container set. Checkbox", label, "can't be drawn.")
		return
	} else if parent.rect.y > parent.rect.w - parent.cursor.y {
		log.error("Header", label, "overflowed out of container.")
		return
	}
	parent.cursor.y += _HEADER_HEIGHT + _SPACING
	screenPos := gmath.Vec2 {
		(parent.rect.x + parent.rect.z) / 2,
		parent.rect.w - parent.cursor.y + _HEADER_HEIGHT / 2,
	}


	textColor := _STYLE[.HEADER]
	font, ok := render.getFont(.PixelCode, 12)
	if ok {
		render.drawText(
			screenPos,
			label,
			&font,
			col = textColor,
			scale = 0.5,
			pivot = gmath.Pivot.centerCenter,
		)
	}
}

CloseButton :: proc(id: u32) -> bool { 	//we separate this from button for easier positioning
	parent := state.currentContainer

	screenPos := gmath.Vec2 {
		parent.rect.z - _PADDING - _CLOSE_SIZE,
		parent.rect.w - _PADDING - _CLOSE_SIZE,
	}

	size := gmath.Vec2{_CLOSE_SIZE, _CLOSE_SIZE}
	rect := gmath.rectMake(screenPos, size)
	rectColor := _STYLE[.CLOSE]
	textColor := _STYLE[.CLOSE_TEXT]

	if gmath.rectContains(rect, gmath.Vec2{state.mouseX, state.mouseY}) {
		rectColor = _STYLE[.CLOSE_TEXT]
		textColor = _STYLE[.CLOSE] // just flipping colors, seems pointless to add more colors
		state.hot = id

		if input.keyPressed(input.KeyCode.LEFT_MOUSE) {
			input.consumeKeyPressed(input.KeyCode.LEFT_MOUSE)
			log.info("clicked")
			state.active = 0
			return false
		}
	}

	render.drawRect(rect, col = rectColor, zLayer = game.ZLayer.ui)
	font, ok := render.getFont(.PixelCode, 12)
	if ok {
		render.drawText(
			screenPos + size / 2,
			"X",
			&font,
			zLayer = game.ZLayer.ui,
			scale = 0.25,
			pivot = gmath.Pivot.centerCenter,
			col = textColor,
		)
	}

	return true
}
