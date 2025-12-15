package game_types

import "../gmath"

MAX_ENTITIES :: 2048

EntityHandle :: struct {
	index: int,
	id:    int,
}

EntityKind :: enum {
	nil,
	player,
	thing,
}

Entity :: struct {
	handle:           EntityHandle,
	kind:             EntityKind,
	updateProc:       proc(_: ^Entity),
	drawProc:         proc(_: ^Entity),
	pos:              gmath.Vec2,
	lastKnownXDir:    f32,
	flipX:            bool,
	drawOffset:       gmath.Vec2,
	drawPivot:        gmath.Pivot,
	rotation:         f32,
	hitFlash:         gmath.Vec4,
	sprite:           SpriteName,
	animIndex:        int,
	nextFrameEndTime: f64,
	loop:             bool,
	frameDuration:    f32,
	scratch:          struct {
		colOverride: gmath.Vec4,
	},
}
