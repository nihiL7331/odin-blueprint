package tween_type

import "../../../types/gmath"

MAX_TWEENS :: 1024

StopMode :: enum {
	STAY,
	END,
	START,
}

TweenValue :: union {
	f32,
	gmath.Vec2,
	gmath.Vec3,
	gmath.Vec4,
}

TweenHandle :: struct {
	index: u32,
	id:    u32,
}

Tween :: struct {
	handle:           TweenHandle,
	active:           bool,
	paused:           bool,
	groupId:          u32, // hash
	nextTween:        TweenHandle, // for chaining
	targetPointer:    rawptr, // value we're animating
	valueKind:        typeid,
	startValue:       TweenValue,
	endValue:         TweenValue,
	elapsed:          f32,
	duration:         f32,
	easeName:         gmath.EaseName,
	startFromCurrent: bool,
}
