package render

import sg "../../libs/sokol/gfx"
import sglue "../../libs/sokol/glue"
import slog "../../libs/sokol/log"
import stbi "../../libs/stb/image"

import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"

import "../../shaders"
import "../../types/color"
import "../../types/game"
import "../../types/gfx"
import "../../types/gmath"
import io "../platform"

RenderState :: struct {
	passAction: sg.Pass_Action,
	pip:        sg.Pipeline, //TODO: separate pipeline for shadows so that their alpha dont add
	bind:       sg.Bindings,
}
renderState: RenderState

Atlas :: struct {
	w, h:   int,
	sgView: sg.View,
}
atlas: Atlas

@(private)
_drawFrame: gfx.DrawFrame
@(private)
_clearedFrame: bool

MAX_QUADS :: 8192
MAX_VERTS :: MAX_QUADS * 4
DEFAULT_UV :: gmath.Vec4{0, 0, 1, 1}
CLEAR_COL: gmath.Vec4 = color.BLACK

actualQuadData: [MAX_QUADS]gfx.Quad


sprites: [game.SpriteName]game.Sprite

getDrawFrame :: proc() -> ^gfx.DrawFrame {
	return &_drawFrame
}

@(private)
_setCoordSpaceDefault :: proc() {
	_drawFrame.reset.coordSpace = {
		proj     = gmath.Mat4(1),
		camera   = gmath.Mat4(1),
		viewProj = gmath.Mat4(1),
	}
}

@(private)
_setCoordSpaceValue :: proc(coordSpace: gfx.CoordSpace) {
	_drawFrame.reset.coordSpace = coordSpace
}

setCoordSpace :: proc {
	_setCoordSpaceValue,
	_setCoordSpaceDefault,
}

ySortCompare :: proc(a, b: gfx.Quad) -> bool {
	ay := min(a[0].pos.y, a[1].pos.y, a[2].pos.y, a[3].pos.y)
	by := min(b[0].pos.y, b[1].pos.y, b[2].pos.y, b[3].pos.y)
	return ay > by
}

init :: proc() {
	sg.setup(
		{
			environment = sglue.environment(),
			logger = {func = slog.func},
			d3d11_shader_debugging = ODIN_DEBUG,
		},
	)

	loadSpritesIntoAtlas()

	// make the vertex buffer
	renderState.bind.vertex_buffers[0] = sg.make_buffer(
		{usage = {stream_update = true}, size = size_of(actualQuadData)},
	)

	// make and fill the index buffer
	indexBufferCount :: MAX_QUADS * 6
	indices, _ := mem.make([]u16, indexBufferCount, allocator = context.allocator)
	for i := 0; i < indexBufferCount; i += 6 {
		// { 0, 1, 2,  0, 2, 3 }
		indices[i + 0] = u16((i / 6) * 4 + 0)
		indices[i + 1] = u16((i / 6) * 4 + 1)
		indices[i + 2] = u16((i / 6) * 4 + 2)
		indices[i + 3] = u16((i / 6) * 4 + 0)
		indices[i + 4] = u16((i / 6) * 4 + 2)
		indices[i + 5] = u16((i / 6) * 4 + 3)
	}
	renderState.bind.index_buffer = sg.make_buffer(
		{
			usage = {index_buffer = true},
			data = {ptr = raw_data(indices), size = size_of(u16) * indexBufferCount},
		},
	)

	renderState.bind.samplers[shaders.SMP_uDefaultSampler] = sg.make_sampler({})

	// setup pipeline
	pipelineDesc: sg.Pipeline_Desc = {
		shader = sg.make_shader(shaders.quad_shader_desc(sg.query_backend())),
		index_type = .UINT16,
		layout = {
			attrs = {
				shaders.ATTR_quad_aPosition = {format = .FLOAT2},
				shaders.ATTR_quad_aColor = {format = .FLOAT4},
				shaders.ATTR_quad_aUv = {format = .FLOAT2},
				shaders.ATTR_quad_aLocalUv = {format = .FLOAT2},
				shaders.ATTR_quad_aSize = {format = .FLOAT2},
				shaders.ATTR_quad_aBytes = {format = .UBYTE4N},
				shaders.ATTR_quad_aColorOverride = {format = .FLOAT4},
				shaders.ATTR_quad_aParams = {format = .FLOAT4},
			},
		},
	}
	blendState: sg.Blend_State = {
		enabled          = true,
		src_factor_rgb   = .SRC_ALPHA,
		dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
		op_rgb           = .ADD,
		src_factor_alpha = .ONE,
		dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
		op_alpha         = .ADD,
	}
	pipelineDesc.colors[0] = {
		blend = blendState,
	}
	renderState.pip = sg.make_pipeline(pipelineDesc)


	// default pass action
	renderState.passAction = {
		colors = {0 = {load_action = .CLEAR, clear_value = transmute(sg.Color)(CLEAR_COL)}},
	}
}

coreRenderFrameStart :: proc() {
	resetDrawFrame()

	if atlas.sgView.id != sg.INVALID_ID {
		renderState.bind.views[shaders.VIEW_uTex] = atlas.sgView
		renderState.bind.views[shaders.VIEW_uFontTex] = atlas.sgView
	}

	renderState.passAction.colors[0].load_action = .CLEAR

	sg.begin_pass({action = renderState.passAction, swapchain = sglue.swapchain()})

	sg.apply_pipeline(renderState.pip)

	_clearedFrame = false
}

coreRenderFrameEnd :: proc() {
	flushBatch()
	sg.end_pass()
	sg.commit()
}

resetDrawFrame :: proc() {
	drawFrame := getDrawFrame()

	drawFrame.reset = {}

	drawFrame.reset.quads[game.ZLayer.background] = make(
		[dynamic]gfx.Quad,
		0,
		512,
		allocator = context.temp_allocator,
	)
	drawFrame.reset.quads[game.ZLayer.shadow] = make(
		[dynamic]gfx.Quad,
		0,
		128,
		allocator = context.temp_allocator,
	)
	drawFrame.reset.quads[game.ZLayer.playspace] = make(
		[dynamic]gfx.Quad,
		0,
		256,
		allocator = context.temp_allocator,
	)
	drawFrame.reset.quads[game.ZLayer.tooltip] = make(
		[dynamic]gfx.Quad,
		0,
		256,
		allocator = context.temp_allocator,
	)
	drawFrame.reset.quads[game.ZLayer.ui] = make(
		[dynamic]gfx.Quad,
		0,
		1024,
		allocator = context.temp_allocator,
	)
}

setFontTexture :: proc(view: sg.View) {
	currentId := renderState.bind.views[shaders.VIEW_uFontTex].id

	if currentId != view.id {
		flushBatch()
		renderState.bind.views[shaders.VIEW_uFontTex] = view
	}
}

flushBatch :: proc() {
	drawFrame := getDrawFrame()

	quadIndex := 0

	for &quadsInLayer, layerIndex in drawFrame.reset.quads {
		count := len(quadsInLayer)
		if count == 0 do continue

		currentLayer := game.ZLayer(layerIndex)
		if currentLayer in drawFrame.reset.sortedLayers {
			slice.sort_by(quadsInLayer[:], ySortCompare)
		}

		spaceLeft := MAX_QUADS - quadIndex
		if count > spaceLeft {
			count = spaceLeft
			log.warn("Quad buffer full.")
		}

		if count <= 0 do break

		destPtr := &actualQuadData[quadIndex]
		srcPtr := raw_data(quadsInLayer)

		mem.copy(destPtr, srcPtr, count * size_of(gfx.Quad))

		quadIndex += count
		if quadIndex >= MAX_QUADS do break
	}

	if quadIndex == 0 do return

	offset := sg.append_buffer(
		renderState.bind.vertex_buffers[0],
		{ptr = raw_data(actualQuadData[:]), size = uint(quadIndex) * size_of(gfx.Quad)},
	)

	renderState.bind.vertex_buffer_offsets[0] = offset
	sg.apply_bindings(renderState.bind)

	sg.apply_uniforms(
		shaders.UB_ShaderData,
		{ptr = &drawFrame.reset.shaderData, size = size_of(shaders.Shaderdata)},
	)

	sg.draw(0, 6 * i32(quadIndex), 1)

	for &quadsInLayer in drawFrame.reset.quads {
		clear(&quadsInLayer)
	}
}

loadSpritesIntoAtlas :: proc() {
	pngData, succ := io.read_entire_file("assets/images/atlas.png")
	assert(succ, fmt.tprint(pngData, "failed to read."))


	assert(raw_data(pngData) != nil, "load atlas image failed")

	width, height, channels: i32
	imgData := stbi.load_from_memory(
		raw_data(pngData),
		i32(len(pngData)),
		&width,
		&height,
		&channels,
		4,
	)
	assert(imgData != nil, "stbi load failed. (atlas didn't generate?)")

	atlas.w = int(width)
	atlas.h = int(height)

	desc: sg.Image_Desc
	desc.width = i32(atlas.w)
	desc.height = i32(atlas.h)
	desc.pixel_format = .RGBA8
	desc.data.subimage[0][0] = {
		ptr  = imgData,
		size = uint(atlas.w * atlas.h * 4),
	}
	sgImg := sg.make_image(desc)
	if sgImg.id == sg.INVALID_ID do log.error("Failed to make an image.")

	atlas.sgView = sg.make_view({texture = sg.Texture_View_Desc({image = sgImg})})
}

drawQuadProjected :: proc(
	worldToClip: gmath.Mat4,
	positions: [4]gmath.Vec2,
	colors: [4]gmath.Vec4,
	uvs: [4]gmath.Vec2,
	texIndex: u8,
	spriteSize: gmath.Vec2,
	colOverride: gmath.Vec4,
	zLayer: game.ZLayer = game.ZLayer.nil,
	flags: game.QuadFlags,
	params := gmath.Vec4{},
	zLayerQueue := -1,
) {
	drawFrame := getDrawFrame()

	zLayer0 := zLayer
	if zLayer0 == .nil {
		zLayer0 = drawFrame.reset.activeZLayer
	}

	verts: [4]gfx.Vertex
	defer {
		quadArray := &drawFrame.reset.quads[zLayer0]
		quadArray.allocator = context.temp_allocator

		if zLayerQueue == -1 {
			append(quadArray, verts)
		} else {
			assert(zLayerQueue < len(quadArray), "No elements pushed after the zLayerQueue.")

			resize_dynamic_array(quadArray, len(quadArray) + 1)
			oldRange := quadArray[zLayerQueue:len(quadArray) - 1]
			newRange := quadArray[zLayerQueue + 1:len(quadArray)]
			copy(newRange, oldRange)

			quadArray[zLayerQueue] = verts
		}
	}

	verts[0].pos = (worldToClip * gmath.Vec4{positions[0].x, positions[0].y, 0.0, 1.0}).xy
	verts[1].pos = (worldToClip * gmath.Vec4{positions[1].x, positions[1].y, 0.0, 1.0}).xy
	verts[2].pos = (worldToClip * gmath.Vec4{positions[2].x, positions[2].y, 0.0, 1.0}).xy
	verts[3].pos = (worldToClip * gmath.Vec4{positions[3].x, positions[3].y, 0.0, 1.0}).xy

	verts[0].col = colors[0]
	verts[1].col = colors[1]
	verts[2].col = colors[2]
	verts[3].col = colors[3]

	verts[0].uv = uvs[0]
	verts[1].uv = uvs[1]
	verts[2].uv = uvs[2]
	verts[3].uv = uvs[3]

	verts[0].localUv = {0, 0}
	verts[1].localUv = {0, 1}
	verts[2].localUv = {1, 1}
	verts[3].localUv = {1, 0}

	verts[0].texIndex = texIndex
	verts[1].texIndex = texIndex
	verts[2].texIndex = texIndex
	verts[3].texIndex = texIndex

	verts[0].size = spriteSize
	verts[1].size = spriteSize
	verts[2].size = spriteSize
	verts[3].size = spriteSize

	verts[0].colorOverride = colOverride
	verts[1].colorOverride = colOverride
	verts[2].colorOverride = colOverride
	verts[3].colorOverride = colOverride

	verts[0].zLayer = u8(zLayer0)
	verts[1].zLayer = u8(zLayer0)
	verts[2].zLayer = u8(zLayer0)
	verts[3].zLayer = u8(zLayer0)

	_flags := flags | drawFrame.reset.activeFlags
	verts[0].quadFlags = _flags
	verts[1].quadFlags = _flags
	verts[2].quadFlags = _flags
	verts[3].quadFlags = _flags

	verts[0].params = params
	verts[1].params = params
	verts[2].params = params
	verts[3].params = params
}

atlasUvFromSprite :: proc(sprite: game.SpriteName) -> gmath.Vec4 {
	return game.getSpriteData(sprite).uv
}

getSpriteSize :: proc(sprite: game.SpriteName) -> gmath.Vec2 {
	return game.getSpriteData(sprite).size
}
