package utils

import "core:math"
import "core:math/linalg"

import "../types/gmath"

scaleFromPivot :: proc(pivot: gmath.Pivot) -> gmath.Vec2 {
	switch pivot {
	case .bottomLeft:
		return gmath.Vec2{0.0, 0.0}
	case .bottomCenter:
		return gmath.Vec2{0.5, 0.0}
	case .bottomRight:
		return gmath.Vec2{1.0, 0.0}
	case .centerLeft:
		return gmath.Vec2{0.0, 0.5}
	case .centerCenter:
		return gmath.Vec2{0.5, 0.5}
	case .centerRight:
		return gmath.Vec2{1.0, 0.5}
	case .topLeft:
		return gmath.Vec2{0.0, 1.0}
	case .topCenter:
		return gmath.Vec2{0.5, 1.0}
	case .topRight:
		return gmath.Vec2{1.0, 1.0}
	}
	return {}
}

hexToRGBA :: proc(v: u32) -> gmath.Vec4 {
	return gmath.Vec4 {
		cast(f32)((v & 0xff000000) >> 24) / 255.0,
		cast(f32)((v & 0x00ff0000) >> 16) / 255.0,
		cast(f32)((v & 0x0000ff00) >> 8) / 255.0,
		cast(f32)((v & 0x000000ff)) / 255.0,
	}
}

xFormTranslate :: proc(pos: gmath.Vec2) -> gmath.Mat4 {
	return linalg.matrix4_translate(gmath.Vec3{pos.x, pos.y, 0})
}
xFormRotate :: proc(angle: f32) -> gmath.Mat4 {
	return linalg.matrix4_rotate(math.to_radians(angle), gmath.Vec3{0, 0, 1})
}
xFormScale :: proc(scale: gmath.Vec2) -> gmath.Mat4 {
	return linalg.matrix4_scale(gmath.Vec3{scale.x, scale.y, 1})
}

animateToTargetF32 :: proc(
	value: ^f32,
	target: f32,
	deltaTime: f32,
	rate: f32 = 15.0,
	goodEnough: f32 = 0.001,
) -> bool {
	value^ += (target - value^) * (1.0 - math.pow_f32(2.0, -rate * deltaTime))
	if almostEquals(value^, target, goodEnough) {
		value^ = target
		return true
	}
	return false
}

animateToTargetVec2 :: proc(
	value: ^gmath.Vec2,
	target: gmath.Vec2,
	deltaTime: f32,
	rate: f32 = 15.0,
	goodEnough: f32 = 0.001,
) -> bool {
	reachedX := animateToTargetF32(&value.x, target.x, deltaTime, rate, goodEnough)
	reachedY := animateToTargetF32(&value.y, target.y, deltaTime, rate, goodEnough)
	return reachedX && reachedY
}

almostEquals :: proc(a: f32, b: f32, epsilon: f32 = 0.001) -> bool {
	return abs(a - b) <= epsilon
}
