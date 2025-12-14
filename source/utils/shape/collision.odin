package shape

import "core:math"
import "core:math/linalg"

import "../../types/gmath"

collide :: proc(a, b: gmath.Shape) -> (colliding: bool, depth: gmath.Vec2) {
	if a == nil || b == nil {
		return false, {}
	}

	switch aShape in a {
	case gmath.Rect:
		switch bShape in b {
		case gmath.Rect:
			return rectCollideRect(aShape, bShape)
		case gmath.Circle:
			return rectCollideCircle(aShape, bShape)
		}
	case gmath.Circle:
		switch bShape in b {
		case gmath.Rect:
			hit, normal := rectCollideCircle(bShape, aShape)
			return hit, -normal
		case gmath.Circle:
			return circleCollideCircle(aShape, bShape)
		}
	}

	return false, {}
}

rectCollideCircle :: proc(aabb: gmath.Rect, circle: gmath.Circle) -> (bool, gmath.Vec2) {
	closestPoint := gmath.Vec2 {
		math.clamp(circle.pos.x, aabb.x, aabb.z),
		math.clamp(circle.pos.y, aabb.y, aabb.w),
	}

	diff := circle.pos - closestPoint
	distanceSquared := linalg.length2(diff)
	if distanceSquared > (circle.radius * circle.radius) {
		return false, {}
	}

	distance := math.sqrt(distanceSquared)
	if distance == 0 {
		return true, {circle.radius, 0}
	}

	penetrationDepth := circle.radius - distance
	normal := diff / distance

	return true, normal * penetrationDepth
}

circleCollideCircle :: proc(a, b: gmath.Circle) -> (bool, gmath.Vec2) {
	diff := a.pos - b.pos
	distanceSquared := linalg.length2(diff)
	radiusSum := a.radius + b.radius

	if distanceSquared >= (radiusSum * radiusSum) {
		return false, {}
	}

	distance := math.sqrt(distanceSquared)
	if distance == 0 {
		return true, {radiusSum, 0}
	}

	penetrationDepth := radiusSum - distance
	normal := diff / distance

	return true, normal * penetrationDepth
}

rectCollideRect :: proc(a, b: gmath.Rect) -> (bool, gmath.Vec2) {
	dx := (a.z + a.x) / 2 - (b.z + b.x) / 2
	dy := (a.w + a.y) / 2 - (b.w + b.y) / 2

	overlapX := (a.z - a.x) / 2 + (b.z - b.x) / 2 - abs(dx)
	overlapY := (a.w - a.y) / 2 + (b.w - b.y) / 2 - abs(dy)

	if overlapX <= 0 || overlapY <= 0 {
		return false, {}
	}

	penetration := gmath.Vec2{}
	if overlapX < overlapY {
		penetration.x = overlapX if dx > 0 else -overlapX
	} else {
		penetration.y = overlapY if dy > 0 else -overlapY
	}

	return true, penetration
}
