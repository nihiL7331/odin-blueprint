package main

import "core:math/linalg"

import "types/gfx"
import "types/gmath"
import "utils"

// TODO: move this to another file
import "core:os"
import "web"
_ :: os
_ :: web

getWorldSpace :: proc() -> gfx.CoordSpace {
	return {proj = getWorldSpaceProj(), camera = getWorldSpaceCamera()}
}
getScreenSpace :: proc() -> gfx.CoordSpace {
	return {proj = getScreenSpaceProj(), camera = gmath.Mat4(1)}
}

getWorldSpaceProj :: proc() -> gmath.Mat4 {
	return linalg.matrix_ortho3d_f32(
		f32(windowWidth) * -0.5,
		f32(windowWidth) * 0.5,
		f32(windowHeight) * -0.5,
		f32(windowHeight) * 0.5,
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
	return f32(GAME_HEIGHT) / f32(windowHeight)
}

getScreenSpaceProj :: proc() -> gmath.Mat4 {
	aspect := f32(windowWidth) / f32(windowHeight)

	viewHeight := f32(GAME_HEIGHT)
	viewWidth := viewHeight * aspect

	viewLeft := (f32(GAME_WIDTH) * 0.5) - (viewWidth * 0.5)
	viewRight := viewLeft + viewWidth

	return linalg.matrix_ortho3d_f32(viewLeft, viewRight, 0, viewHeight, -1, 1)
}

screenPivot :: proc(pivot: gmath.Pivot) -> (x, y: f32) {
	#partial switch (pivot) {
	case .topLeft:
		x = 0
		y = f32(windowHeight)

	case .topCenter:
		x = f32(windowWidth) / 2
		y = f32(windowHeight)

	case .bottomLeft:
		x = 0
		y = 0

	case .centerCenter:
		x = f32(windowWidth) / 2
		y = f32(windowHeight) / 2

	case .topRight:
		x = f32(windowWidth)
		y = f32(windowHeight)

	case .bottomCenter:
		x = f32(windowWidth) / 2
		y = 0
	//TODO: rest
	}

	ndcX := (x / (f32(windowWidth) * 0.5)) - 1.0
	ndcY := (y / (f32(windowHeight) * 0.5)) - 1.0

	mouseNdc := gmath.Vec2{ndcX, ndcY}

	mouseWorld := gmath.Vec4{mouseNdc.x, mouseNdc.y, 0, 1}

	mouseWorld = linalg.inverse(getScreenSpaceProj()) * mouseWorld
	x = mouseWorld.x
	y = mouseWorld.y

	return
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
	// key, found := actionMap[action]
	// if !found {
	// 	log.debugf("Action %v not bound to any key.", action)
	// }
	// return key
	return actionMap[action] //TODO: make a check without using a map here
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

appNow :: utils.secondsSinceInit

now :: proc() -> f64 {
	coreContext := utils.getCoreContext()

	return coreContext.gameState.gameTimeElapsed
}
endTimeUp :: proc(endTime: f64) -> bool {
	return endTime == -1 ? false : now() >= endTime
}
timeSince :: proc(time: f64) -> f32 {
	if time == 0 {
		return 99999999.0
	}
	return f32(now() - time)
}

// read and write files. Works with both desktop OS and also emscripten virtual
// file system.
// TODO: move this to another file, separate for web build and desktop build
@(require_results)
read_entire_file :: proc(
	name: string,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	data: []byte,
	success: bool,
) {
	when IS_WEB {
		return web.read_entire_file(name, allocator, loc)
	} else {
		return os.read_entire_file(name, allocator, loc)
	}
}

write_entire_file :: proc(name: string, data: []byte, truncate := true) -> (success: bool) {
	when IS_WEB {
		return web.write_entire_file(name, data, truncate)
	} else {
		return os.write_entire_file(name, data, truncate)
	}
}
