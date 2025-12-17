package gmath

Shape :: union {
	Rect,
	Circle,
}

Circle :: struct {
	pos:    Vec2,
	radius: f32,
}

Rect :: Vec4

rectContains :: proc(rect: Rect, point: Vec2) -> bool { 	//useful for mouse events
	return (point.x >= rect.x) && (point.x <= rect.z) && (point.y >= rect.y) && (point.y <= rect.w)
}

rectGetCenter :: proc(rect: Rect) -> Vec2 {
	min := rect.xy
	max := rect.zw
	return {min.x + 0.5 * (max.x - min.x), min.y + 0.5 * (max.y - min.y)}
}

rectMakeWithPos :: proc(pos: Vec2, size: Vec2, pivot := Pivot.bottomLeft) -> Rect {
	rect := Vec4{0, 0, size.x, size.y}
	rect = rectShift(rect, pos - scaleFromPivot(pivot) * size)
	return rect
}

rectMakeWithSize :: proc(size: Vec2, pivot: Pivot) -> Rect {
	return rectMake({}, size, pivot)
}

rectMake :: proc {
	rectMakeWithPos,
	rectMakeWithSize,
}

rectShift :: proc(rect: Rect, amount: Vec2) -> Rect {
	return {rect.x + amount.x, rect.y + amount.y, rect.z + amount.x, rect.w + amount.y}
}

rectSize :: proc(rect: Rect) -> Vec2 {
	return {abs(rect.x - rect.z), abs(rect.y - rect.w)}
}

rectScale :: proc(rect: Rect, scale: f32) -> Rect {
	rect := rect
	origin := rect.xy
	rect = rectShift(rect, -origin)
	scaleAmount := (rect.zw * scale) - rect.zw
	rect.xy -= scaleAmount / 2
	rect.zw += scaleAmount / 2
	rect = rectShift(rect, origin)
	return rect
}

rectScaleVec2 :: proc(rect: Rect, scale: Vec2) -> Rect {
	rect := rect
	origin := rect.xy
	rect = rectShift(rect, -origin)

	scaleAmount := (rect.zw * scale) - rect.zw

	rect.xy -= scaleAmount / 2
	rect.zw += scaleAmount / 2

	rect = rectShift(rect, origin)
	return rect
}

rectExpand :: proc(rect: Rect, amount: f32) -> Rect {
	rect := rect
	rect.xy -= amount
	rect.zw += amount
	return rect
}

circleShift :: proc(circle: Circle, amount: Vec2) -> Circle {
	circle := circle
	circle.pos += amount
	return circle
}

shift :: proc(s: Shape, amount: Vec2) -> Shape {
	if s == {} || amount == {} {
		return s
	}

	switch shape in s {
	case Rect:
		return rectShift(shape, amount)
	case Circle:
		return circleShift(shape, amount)
	case:
		{
			assert(false, "Unsupported shape shift")
			return {}
		}}
}
