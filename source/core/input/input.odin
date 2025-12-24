package input

import sapp "../../libs/sokol/app"

import core ".."
import "../../types/gmath"
import "../render"

import "core:math/linalg"

MAX_KEYCODES :: 512

@(private)
_actualInputState: Input

Input :: struct {
	keys:             [MAX_KEYCODES]bit_set[InputFlag],
	mouseX, mouseY:   f32,
	scrollX, scrollY: f32,
}

InputFlag :: enum u8 {
	down,
	pressed,
	released,
	repeat,
}

actionMap: [InputAction]KeyCode = {
	.left     = .A,
	.right    = .D,
	.up       = .W,
	.down     = .S,
	.click    = .LEFT_MOUSE,
	.use      = .RIGHT_MOUSE,
	.interact = .E,
}

InputAction :: enum u8 {
	left,
	right,
	up,
	down,
	click,
	use,
	interact,
}

KeyCode :: enum {
	INVALID       = 0,
	SPACE         = 32,
	APOSTROPHE    = 39,
	COMMA         = 44,
	MINUS         = 45,
	PERIOD        = 46,
	SLASH         = 47,
	_0            = 48,
	_1            = 49,
	_2            = 50,
	_3            = 51,
	_4            = 52,
	_5            = 53,
	_6            = 54,
	_7            = 55,
	_8            = 56,
	_9            = 57,
	SEMICOLON     = 59,
	EQUAL         = 61,
	A             = 65,
	B             = 66,
	C             = 67,
	D             = 68,
	E             = 69,
	F             = 70,
	G             = 71,
	H             = 72,
	I             = 73,
	J             = 74,
	K             = 75,
	L             = 76,
	M             = 77,
	N             = 78,
	O             = 79,
	P             = 80,
	Q             = 81,
	R             = 82,
	S             = 83,
	T             = 84,
	U             = 85,
	V             = 86,
	W             = 87,
	X             = 88,
	Y             = 89,
	Z             = 90,
	LEFT_BRACKET  = 91,
	BACKSLASH     = 92,
	RIGHT_BRACKET = 93,
	GRAVE_ACCENT  = 96,
	WORLD_1       = 161,
	WORLD_2       = 162,
	ESC           = 256,
	ENTER         = 257,
	TAB           = 258,
	BACKSPACE     = 259,
	INSERT        = 260,
	DELETE        = 261,
	RIGHT         = 262,
	LEFT          = 263,
	DOWN          = 264,
	UP            = 265,
	PAGE_UP       = 266,
	PAGE_DOWN     = 267,
	HOME          = 268,
	END           = 269,
	CAPS_LOCK     = 280,
	SCROLL_LOCK   = 281,
	NUM_LOCK      = 282,
	PRINT_SCREEN  = 283,
	PAUSE         = 284,
	F1            = 290,
	F2            = 291,
	F3            = 292,
	F4            = 293,
	F5            = 294,
	F6            = 295,
	F7            = 296,
	F8            = 297,
	F9            = 298,
	F10           = 299,
	F11           = 300,
	F12           = 301,
	F13           = 302,
	F14           = 303,
	F15           = 304,
	F16           = 305,
	F17           = 306,
	F18           = 307,
	F19           = 308,
	F20           = 309,
	F21           = 310,
	F22           = 311,
	F23           = 312,
	F24           = 313,
	F25           = 314,
	KP_0          = 320,
	KP_1          = 321,
	KP_2          = 322,
	KP_3          = 323,
	KP_4          = 324,
	KP_5          = 325,
	KP_6          = 326,
	KP_7          = 327,
	KP_8          = 328,
	KP_9          = 329,
	KP_DECIMAL    = 330,
	KP_DIVIDE     = 331,
	KP_MULTIPLY   = 332,
	KP_SUBTRACT   = 333,
	KP_ADD        = 334,
	KP_ENTER      = 335,
	KP_EQUAL      = 336,
	LEFT_SHIFT    = 340,
	LEFT_CONTROL  = 341,
	LEFT_ALT      = 342,
	LEFT_SUPER    = 343,
	RIGHT_SHIFT   = 344,
	RIGHT_CONTROL = 345,
	RIGHT_ALT     = 346,
	RIGHT_SUPER   = 347,
	MENU          = 348,
	LEFT_MOUSE    = 400,
	RIGHT_MOUSE   = 401,
	MIDDLE_MOUSE  = 402,
}

state: ^Input
init :: proc() {
	state = &_actualInputState
}

resetInputState :: proc(input: ^Input) {
	for &key in input.keys {
		key -= ~{.down}
	}
	input.scrollX = 0
	input.scrollY = 0
}

addInput :: proc(dest: ^Input, source: Input) {
	dest.mouseX = source.mouseX
	dest.mouseY = source.mouseY
	dest.scrollX += source.scrollX
	dest.scrollY += source.scrollY

	for flags, key in source.keys {
		dest.keys[key] += flags
	}
}

keyPressed :: proc(code: KeyCode) -> bool {
	return .pressed in state.keys[code]
}

keyReleased :: proc(code: KeyCode) -> bool {
	return .released in state.keys[code]
}

keyDown :: proc(code: KeyCode) -> bool {
	return .down in state.keys[code]
}

keyRepeat :: proc(code: KeyCode) -> bool {
	return .repeat in state.keys[code]
}


consumeKeyPressed :: proc(code: KeyCode) {
	state.keys[code] -= {.pressed}
}

consumeKeyReleased :: proc(code: KeyCode) {
	state.keys[code] -= {.released}
}

anyKeyPressAndConsume :: proc() -> bool {
	for &flag, key in state.keys {
		if key >= int(KeyCode.LEFT_MOUSE) do continue

		if .pressed in flag {
			flag -= {.pressed}
			return true
		}
	}

	return false
}

isActionPressed :: proc(action: InputAction) -> bool {
	key := keyFromAction(action)
	return keyPressed(key)
}
isActionReleased :: proc(action: InputAction) -> bool {
	key := keyFromAction(action)
	return keyReleased(key)
}
isActionDown :: proc(action: InputAction) -> bool {
	key := keyFromAction(action)
	return keyDown(key)
}
consumeActionPressed :: proc(action: InputAction) {
	key := keyFromAction(action)
	consumeKeyPressed(key)
}
consumeActionReleased :: proc(action: InputAction) {
	key := keyFromAction(action)
	consumeKeyReleased(key)
}

keyFromAction :: proc(action: InputAction) -> KeyCode {
	return actionMap[action]
}

getInputVector :: proc() -> gmath.Vec2 {
	input: gmath.Vec2
	if isActionDown(InputAction.left) do input.x -= 1.0
	if isActionDown(InputAction.right) do input.x += 1.0
	if isActionDown(InputAction.down) do input.y -= 1.0
	if isActionDown(InputAction.up) do input.y += 1.0
	if input == {} {
		return {}
	} else {
		return linalg.normalize(input)
	}
}

inputEventCallback :: proc "c" (event: ^sapp.Event) {
	inputState := &_actualInputState

	#partial switch event.type {
	case .MOUSE_SCROLL:
		inputState.scrollX = event.scroll_x
		inputState.scrollY = event.scroll_y

	case .MOUSE_MOVE:
		inputState.mouseX = event.mouse_x
		inputState.mouseY = event.mouse_y

	case .MOUSE_UP:
		if .down in inputState.keys[mapSokolMouseButton(event.mouse_button)] {
			inputState.keys[mapSokolMouseButton(event.mouse_button)] -= {.down}
			inputState.keys[mapSokolMouseButton(event.mouse_button)] += {.released}
		}

	case .MOUSE_DOWN:
		if !(.down in inputState.keys[mapSokolMouseButton(event.mouse_button)]) {
			inputState.keys[mapSokolMouseButton(event.mouse_button)] += {.down, .pressed}
		}

	case .KEY_UP:
		if .down in inputState.keys[event.key_code] {
			inputState.keys[event.key_code] -= {.down}
			inputState.keys[event.key_code] += {.released}
		}

	case .KEY_DOWN:
		if !event.key_repeat && !(.down in inputState.keys[event.key_code]) {
			inputState.keys[event.key_code] += {.down, .pressed}
		}
		if event.key_repeat {
			inputState.keys[event.key_code] += {.repeat}
		}
	}
}

getScreenMousePos :: proc() -> gmath.Vec2 {
	drawFrame := render.getDrawFrame()
	coreContext := core.getCoreContext()
	proj := drawFrame.reset.coordSpace.proj

	mousePos := gmath.Vec2{_actualInputState.mouseX, _actualInputState.mouseY}

	normalX := (mousePos.x / (f32(coreContext.windowWidth) * 0.5)) - 1.0
	normalY := (mousePos.y / (f32(coreContext.windowHeight) * 0.5)) - 1.0
	normalY *= -1

	mouseNormal := gmath.Vec2{normalX, normalY}
	mouseWorld := gmath.Vec4{mouseNormal.x, mouseNormal.y, 0, 1}

	mouseWorld = linalg.inverse(proj) * mouseWorld

	return mouseWorld.xy
}

mapSokolMouseButton :: proc "c" (sokolMouseButton: sapp.Mousebutton) -> KeyCode {
	#partial switch sokolMouseButton {
	case .LEFT:
		return .LEFT_MOUSE
	case .RIGHT:
		return .RIGHT_MOUSE
	case .MIDDLE:
		return .MIDDLE_MOUSE
	}
	return nil
}
