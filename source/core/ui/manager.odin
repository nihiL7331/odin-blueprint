package ui

import "../../types/color"
import "../../types/gmath"
import "../input"

import "core:hash"

@(private)
_STYLE_TYPE :: enum {
	TEXT,
	WINDOW,
	BUTTON,
	HOVER_BUTTON,
	HOVER_TEXT,
	ACTIVE_BUTTON,
	ACTIVE_TEXT,
	SLIDER_BACKGROUND,
	SLIDER_FILL,
	CLOSE,
	CLOSE_TEXT,
	ACTIVE_CLOSE,
	HEADER,
	OUTLINE,
}

@(private)
_STYLE :: [_STYLE_TYPE]gmath.Vec4 {
	.TEXT              = color.WHITE,
	.WINDOW            = color.BLACK,
	.BUTTON            = color.GRAY,
	.HOVER_BUTTON      = color.WHITE,
	.HOVER_TEXT        = color.GRAY,
	.ACTIVE_BUTTON     = color.RED,
	.ACTIVE_TEXT       = color.BLACK,
	.SLIDER_BACKGROUND = color.GRAY,
	.SLIDER_FILL       = color.RED,
	.CLOSE             = color.RED,
	.CLOSE_TEXT        = color.WHITE,
	.ACTIVE_CLOSE      = color.BLACK,
	.HEADER            = color.GRAY,
	.OUTLINE           = color.GRAY,
}

@(private)
_HEADER_HEIGHT :: 10
@(private)
_SPACING :: 2
@(private)
_PADDING :: 1
@(private)
_BUTTON_HEIGHT :: 8
@(private)
_SLIDER_HEIGHT :: 6
@(private)
_CLOSE_SIZE :: 4

Container :: struct {
	id:     u32,
	rect:   gmath.Rect,
	cursor: gmath.Vec2,
	isOpen: bool,
}

// Core UI state
UI_State :: struct {
	hot:                    u32,
	active:                 u32,
	mouseX, mouseY:         f32,
	prevMouseX, prevMouseY: f32,
	containers:             map[u32]Container,
	currentContainer:       ^Container,
}

state: UI_State

getId :: proc(title: string) -> u32 {
	return hash.fnv32(transmute([]u8)title)
}

init :: proc() {
	state.containers = make(map[u32]Container)
	state.hot = 0
	state.active = 0
	state.mouseX = 0
	state.mouseY = 0
	state.prevMouseX = 0
	state.prevMouseY = 0
}

begin :: proc(mousePos: gmath.Vec2) {
	state.mouseX = mousePos.x
	state.mouseY = mousePos.y
}

end :: proc() {
	state.hot = 0
	if input.keyReleased(input.KeyCode.LEFT_MOUSE) {
		state.active = 0
	}
	state.prevMouseX = state.mouseX
	state.prevMouseY = state.mouseY
}


@(private)
_getMouseDelta :: proc() -> gmath.Vec2 {
	return gmath.Vec2{state.mouseX - state.prevMouseX, state.mouseY - state.prevMouseY}
}
