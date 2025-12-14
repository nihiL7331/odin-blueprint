package gfx

import "../game"
import "../gmath"

ShaderGlobals :: struct {
	ndcToWorldXForm:    gmath.Mat4,
	bgRepeatTexAtlasUv: gmath.Vec4,
}

DrawFrame :: struct {
	reset: struct {
		quads:         [game.ZLayer][dynamic]Quad,
		coordSpace:    CoordSpace,
		activeZLayer:  game.ZLayer,
		activeScissor: gmath.Rect,
		activeFlags:   game.QuadFlags,
		shaderData:    ShaderGlobals,
	},
}

CoordSpace :: struct {
	proj:     gmath.Mat4,
	camera:   gmath.Mat4,
	viewProj: gmath.Mat4,
}

Quad :: [4]Vertex
Vertex :: struct {
	pos:           gmath.Vec2,
	col:           gmath.Vec4,
	uv:            gmath.Vec2,
	localUv:       gmath.Vec2,
	size:          gmath.Vec2,
	texIndex:      u8,
	zLayer:        u8,
	quadFlags:     game.QuadFlags,
	_:             [1]u8,
	colorOverride: gmath.Vec4,
	params:        gmath.Vec4,
}
