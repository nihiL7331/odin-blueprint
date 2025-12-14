package game_types

import "../gmath"

ViewHandle :: distinct u32

Sprite :: struct {
	width, height: i32,
	texIndex:      u8,
	sgView:        ViewHandle, // sg.View is generally just a struct with ID and that way we dont have to import sokol/gfx
	data:          [^]byte,
	atlasUvs:      gmath.Vec4,
}

spriteData: [SpriteName]SpriteData = #partial {
	SpriteName.player_idle = {frameCount = 2},
	SpriteName.player_run = {frameCount = 3},
}

QuadFlags :: enum u8 {
	backgroundPixels = (1 << 0),
	flag2            = (1 << 1),
	flag3            = (1 << 2),
}

ZLayer :: enum u8 {
	// quads drawn nil first
	nil,
	background,
	shadow,
	playspace,
	vfx,
	ui,
	tooltip,
	pause_menu,
	top,
}

SpriteData :: struct {
	frameCount: int,
	offset:     gmath.Vec2,
	pivot:      gmath.Pivot,
}
