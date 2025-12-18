package tween

import "core:fmt"
import "core:hash"
import "core:math"

import "../../core"
import "../../types/gmath"
import "type"

@(private)
_pool: [type.MAX_TWEENS]type.Tween

//helpers
_getTween :: proc(handle: type.TweenHandle) -> ^type.Tween {
	if handle.index >= type.MAX_TWEENS do return nil

	tween := &_pool[handle.index]

	if !tween.active || tween.handle.id != handle.id {
		return nil
	}

	return tween
}

_applyValue :: proc(tween: ^type.Tween, value: type.TweenValue) {
	if tween.targetPointer == nil do return

	switch v in value {
	case f32:
		if tween.valueKind == f32 {
			pointer := cast(^f32)tween.targetPointer
			pointer^ = v
		}
	case gmath.Vec2:
		if tween.valueKind == gmath.Vec2 {
			pointer := cast(^gmath.Vec2)tween.targetPointer
			pointer^ = v
		}
	case gmath.Vec3:
		if tween.valueKind == gmath.Vec3 {
			pointer := cast(^gmath.Vec3)tween.targetPointer
			pointer^ = v
		}
	case gmath.Vec4:
		if tween.valueKind == gmath.Vec4 {
			pointer := cast(^gmath.Vec4)tween.targetPointer
			pointer^ = v
		}
	}
}

_freeSlot :: proc(index: u32) {
	if index >= type.MAX_TWEENS do return

	_pool[index].active = false
}

to :: proc {
	toF32,
	toVec2,
	toVec3,
	toVec4,
}

toF32 :: proc(
	pointer: ^f32,
	target: f32,
	duration: f32,
	group: string = "",
	ease := gmath.EaseName.Linear,
) -> type.TweenHandle {
	return _createTween(pointer, target, duration, group, ease, f32)
}

toVec2 :: proc(
	pointer: ^gmath.Vec2,
	target: gmath.Vec2,
	duration: f32,
	group: string = "",
	ease := gmath.EaseName.Linear,
) -> type.TweenHandle {
	return _createTween(pointer, target, duration, group, ease, gmath.Vec2)
}

toVec3 :: proc(
	pointer: ^gmath.Vec3,
	target: gmath.Vec3,
	duration: f32,
	group: string = "",
	ease := gmath.EaseName.Linear,
) -> type.TweenHandle {
	return _createTween(pointer, target, duration, group, ease, gmath.Vec3)
}

toVec4 :: proc(
	pointer: ^gmath.Vec4,
	target: gmath.Vec4,
	duration: f32,
	group: string = "",
	ease := gmath.EaseName.Linear,
) -> type.TweenHandle {
	return _createTween(pointer, target, duration, group, ease, gmath.Vec4)
}

@(private)
_createTween :: proc(
	pointer: rawptr,
	target: type.TweenValue,
	duration: f32,
	group: string = "",
	ease := gmath.EaseName.Linear,
	kind: typeid,
) -> type.TweenHandle {
	slotIndex := -1
	for i in 0 ..< type.MAX_TWEENS {
		if !_pool[i].active {
			slotIndex = i
			break
		}
	}

	if slotIndex == -1 {
		fmt.println("Tween pool full. Increase the size in systems/tween.odin.")
		return type.TweenHandle{}
	}

	tween := &_pool[slotIndex]
	tween.active = true
	tween.handle.index = u32(slotIndex)
	tween.handle.id += 1

	if group == "" {
		tween.groupId = 0
	} else {
		tween.groupId = getId(group)
	}

	tween.targetPointer = pointer

	switch kind {
	case f32:
		value := (cast(^f32)pointer)^
		tween.startValue = value

	case gmath.Vec2:
		value := (cast(^gmath.Vec2)pointer)^
		tween.startValue = value

	case gmath.Vec3:
		value := (cast(^gmath.Vec3)pointer)^
		tween.startValue = value

	case gmath.Vec4:
		value := (cast(^gmath.Vec4)pointer)^
		tween.startValue = value
	}

	tween.endValue = target
	tween.duration = duration
	tween.elapsed = 0
	tween.easeName = ease
	tween.valueKind = kind
	tween.startFromCurrent = true

	return tween.handle
}

then :: proc(current: type.TweenHandle, next: type.TweenHandle) -> type.TweenHandle {
	currentTween := _getTween(current)
	if currentTween == nil do return next

	currentTween.nextTween = next

	nextTween := _getTween(next)
	if nextTween != nil {
		nextTween.active = true
		nextTween.paused = true
		nextTween.elapsed = 0
	}

	return next
}

togglePause :: proc(handle: type.TweenHandle) -> Maybe(bool) {
	tween := _getTween(handle)
	if tween == nil do return nil
	tween.paused = !tween.paused
	return tween.paused
}

stop :: proc(handle: type.TweenHandle, mode: type.StopMode = type.StopMode.STAY) {
	tween := _getTween(handle)
	if tween == nil do return

	switch mode {
	case .STAY:

	case .END:
		_applyValue(tween, tween.endValue)

	case .START:
		_applyValue(tween, tween.startValue)
	}

	_freeSlot(tween.handle.index)
}

stopGroup :: proc(group: string, mode: type.StopMode = type.StopMode.STAY) {
	if group == "" do return

	groupHash := getId(group)
	for &tween in _pool {
		if tween.active && tween.groupId == groupHash {
			stop(tween.handle, mode)
		}
	}
}

getId :: proc(group: string) -> u32 {
	return hash.fnv32(transmute([]u8)group)
}

update :: proc() {
	deltaTime := core.getDeltaTime()

	for &tween in _pool {
		if !tween.active || tween.paused do continue

		if tween.elapsed == 0 && tween.startFromCurrent {
			switch tween.valueKind {
			case f32:
				tween.startValue = (cast(^f32)tween.targetPointer)^
			case gmath.Vec2:
				tween.startValue = (cast(^gmath.Vec2)tween.targetPointer)^
			case gmath.Vec3:
				tween.startValue = (cast(^gmath.Vec3)tween.targetPointer)^
			case gmath.Vec4:
				tween.startValue = (cast(^gmath.Vec4)tween.targetPointer)^
			}
			tween.startFromCurrent = false
		}

		tween.elapsed += deltaTime

		rawT := math.clamp(tween.elapsed / tween.duration, 0.0, 1.0)
		easeT := gmath.ease(tween.easeName, rawT)

		switch start in tween.startValue {
		case f32:
			if end, ok := tween.endValue.(f32); ok {
				value := math.lerp(start, end, easeT)
				_applyValue(&tween, value)
			}

		case gmath.Vec2:
			if end, ok := tween.endValue.(gmath.Vec2); ok {
				value := math.lerp(start, end, easeT)
				_applyValue(&tween, value)
			}

		case gmath.Vec3:
			if end, ok := tween.endValue.(gmath.Vec3); ok {
				value := math.lerp(start, end, easeT)
				_applyValue(&tween, value)
			}

		case gmath.Vec4:
			if end, ok := tween.endValue.(gmath.Vec4); ok {
				value := math.lerp(start, end, easeT)
				_applyValue(&tween, value)
			}
		}

		if tween.elapsed >= tween.duration {
			stop(tween.handle, type.StopMode.END)

			if tween.nextTween.id != 0 {
				next := _getTween(tween.nextTween)
				if next != nil do next.paused = false
			}
		}
	}
}
