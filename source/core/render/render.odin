package render

import sg "../../libs/sokol/gfx"
import sglue "../../libs/sokol/glue"
import slog "../../libs/sokol/log"
import stbi "../../libs/stb/image"

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
	pipeline:   sg.Pipeline, //TODO: separate pipeline for shadows so that their alpha dont add
	bindings:   sg.Bindings,
}

// at build-time all sprites are packed to one atlas
Atlas :: struct {
	width:  int,
	height: int,
	view:   sg.View,
}

@(private)
_renderState: RenderState
@(private)
_atlas: Atlas
@(private)
_drawFrame: gfx.DrawFrame
@(private)
_clearedFrame: bool
@(private)
_actualQuadData: [MAX_QUADS]gfx.Quad

MAX_QUADS :: 8192 // edit this as needed. greater amount - worse performance
DEFAULT_UV :: gmath.Vec4{0, 0, 1, 1}
CLEAR_COLOR :: color.BLACK // default background value

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

@(private)
_ySortCompare :: proc(a, b: gfx.Quad) -> bool {
	aY := min(a[0].position.y, a[1].position.y, a[2].position.y, a[3].position.y)
	bY := min(b[0].position.y, b[1].position.y, b[2].position.y, b[3].position.y)
	return aY > bY
}

init :: proc() {
	sg.setup(
		{
			environment = sglue.environment(),
			logger = {func = slog.func},
			d3d11_shader_debugging = ODIN_DEBUG,
		},
	)

	// load the atlas generated at build-time
	loadAtlas()

	// make the vertex buffer
	_renderState.bindings.vertex_buffers[0] = sg.make_buffer(
		{usage = {stream_update = true}, size = size_of(_actualQuadData)},
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
	_renderState.bindings.index_buffer = sg.make_buffer(
		{
			usage = {index_buffer = true},
			data = {ptr = raw_data(indices), size = size_of(u16) * indexBufferCount},
		},
	)

	_renderState.bindings.samplers[shaders.SMP_uDefaultSampler] = sg.make_sampler({})

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
	_renderState.pipeline = sg.make_pipeline(pipelineDesc)


	// default pass action
	_renderState.passAction = {
		colors = {0 = {load_action = .CLEAR, clear_value = transmute(sg.Color)(CLEAR_COLOR)}},
	}

	_initDrawFrameLayers()
}

coreRenderFrameStart :: proc() {
	resetDrawFrame()

	if _atlas.view.id != sg.INVALID_ID {
		_renderState.bindings.views[shaders.VIEW_uTex] = _atlas.view
		_renderState.bindings.views[shaders.VIEW_uFontTex] = _atlas.view //HACK: do that to avoid crash when font isnt loaded
	}

	_renderState.passAction.colors[0].load_action = .CLEAR

	sg.begin_pass({action = _renderState.passAction, swapchain = sglue.swapchain()})

	sg.apply_pipeline(_renderState.pipeline)

	_clearedFrame = false
}

coreRenderFrameEnd :: proc() {
	flushBatch()
	sg.end_pass()
	sg.commit()
}

@(private)
_initDrawFrameLayers :: proc() {
	drawFrame := getDrawFrame()

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

resetDrawFrame :: proc() {
	drawFrame := getDrawFrame()
	drawFrame.reset = {}

	for &layer in drawFrame.reset.quads {
		clear(&layer)
	}
}

setFontTexture :: proc(view: sg.View) {
	currentId := _renderState.bindings.views[shaders.VIEW_uFontTex].id

	if currentId != view.id {
		flushBatch()
		_renderState.bindings.views[shaders.VIEW_uFontTex] = view
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
			slice.sort_by(quadsInLayer[:], _ySortCompare)
		}

		spaceLeft := MAX_QUADS - quadIndex
		if count > spaceLeft {
			count = spaceLeft
			log.warn("Quad buffer full.")
		}

		if count <= 0 do break

		destPtr := &_actualQuadData[quadIndex]
		srcPtr := raw_data(quadsInLayer)

		mem.copy(destPtr, srcPtr, count * size_of(gfx.Quad))

		quadIndex += count
		if quadIndex >= MAX_QUADS do break
	}

	if quadIndex == 0 do return

	offset := sg.append_buffer(
		_renderState.bindings.vertex_buffers[0],
		{ptr = raw_data(_actualQuadData[:]), size = uint(quadIndex) * size_of(gfx.Quad)},
	)

	_renderState.bindings.vertex_buffer_offsets[0] = offset
	sg.apply_bindings(_renderState.bindings)

	sg.apply_uniforms(
		shaders.UB_ShaderData,
		{ptr = &drawFrame.reset.shaderData, size = size_of(shaders.Shaderdata)},
	)

	sg.draw(0, 6 * i32(quadIndex), 1)

	for &quadsInLayer in drawFrame.reset.quads {
		clear(&quadsInLayer)
	}
}

loadAtlas :: proc() {
	pngData, success := io.read_entire_file("assets/images/atlas.png")
	if !success {
		log.errorf("Failed to read file %v.", pngData)
		return
	}
	defer delete(pngData)

	width, height, channels: i32
	imageData := stbi.load_from_memory(
		raw_data(pngData),
		i32(len(pngData)),
		&width,
		&height,
		&channels,
		4,
	)
	if imageData == nil {
		log.error("STB image failed to load the image. (atlas didn't generate?)")
		return
	}
	defer stbi.image_free(imageData)

	_atlas.width = int(width)
	_atlas.height = int(height)

	description: sg.Image_Desc
	description.width = i32(_atlas.width)
	description.height = i32(_atlas.height)
	description.pixel_format = .RGBA8
	description.data.subimage[0][0] = {
		ptr  = imageData,
		size = uint(_atlas.width * _atlas.height * 4),
	}
	sgImage := sg.make_image(description)
	if sgImage.id == sg.INVALID_ID {
		log.error("Failed to make an image.")
		return
	}

	_atlas.view = sg.make_view({texture = sg.Texture_View_Desc({image = sgImage})})
}

drawQuadProjected :: proc(
	worldToClip: gmath.Mat4,
	positions: [4]gmath.Vec2,
	colors: [4]gmath.Vec4,
	uvs: [4]gmath.Vec2,
	textureIndex: u8,
	spriteSize: gmath.Vec2,
	colorOverride: gmath.Vec4,
	zLayer: game.ZLayer = game.ZLayer.nil,
	flags: game.QuadFlags,
	parameters := gmath.Vec4{},
	zLayerQueue := -1,
) {
	drawFrame := getDrawFrame()

	zLayer0 := zLayer
	if zLayer0 == .nil { 	// default value for zLayer
		zLayer0 = drawFrame.reset.activeZLayer
	}

	vertices: [4]gfx.Vertex
	defer {
		quadArray := &drawFrame.reset.quads[zLayer0]
		quadArray.allocator = context.temp_allocator

		if zLayerQueue == -1 {
			append(quadArray, vertices)
		} else {
			assert(zLayerQueue < len(quadArray), "No elements pushed after the zLayerQueue.")

			resize_dynamic_array(quadArray, len(quadArray) + 1)
			oldRange := quadArray[zLayerQueue:len(quadArray) - 1]
			newRange := quadArray[zLayerQueue + 1:len(quadArray)]
			copy(newRange, oldRange)

			quadArray[zLayerQueue] = vertices
		}
	}

	vertices[0].position = (worldToClip * gmath.Vec4{positions[0].x, positions[0].y, 0.0, 1.0}).xy
	vertices[1].position = (worldToClip * gmath.Vec4{positions[1].x, positions[1].y, 0.0, 1.0}).xy
	vertices[2].position = (worldToClip * gmath.Vec4{positions[2].x, positions[2].y, 0.0, 1.0}).xy
	vertices[3].position = (worldToClip * gmath.Vec4{positions[3].x, positions[3].y, 0.0, 1.0}).xy

	vertices[0].color = colors[0]
	vertices[1].color = colors[1]
	vertices[2].color = colors[2]
	vertices[3].color = colors[3]

	vertices[0].uv = uvs[0]
	vertices[1].uv = uvs[1]
	vertices[2].uv = uvs[2]
	vertices[3].uv = uvs[3]

	vertices[0].localUv = {0, 0}
	vertices[1].localUv = {0, 1}
	vertices[2].localUv = {1, 1}
	vertices[3].localUv = {1, 0}

	vertices[0].textureIndex = textureIndex
	vertices[1].textureIndex = textureIndex
	vertices[2].textureIndex = textureIndex
	vertices[3].textureIndex = textureIndex

	vertices[0].size = spriteSize
	vertices[1].size = spriteSize
	vertices[2].size = spriteSize
	vertices[3].size = spriteSize

	vertices[0].colorOverride = colorOverride
	vertices[1].colorOverride = colorOverride
	vertices[2].colorOverride = colorOverride
	vertices[3].colorOverride = colorOverride

	vertices[0].zLayer = u8(zLayer0)
	vertices[1].zLayer = u8(zLayer0)
	vertices[2].zLayer = u8(zLayer0)
	vertices[3].zLayer = u8(zLayer0)

	_flags := flags | drawFrame.reset.activeFlags
	vertices[0].quadFlags = _flags
	vertices[1].quadFlags = _flags
	vertices[2].quadFlags = _flags
	vertices[3].quadFlags = _flags

	vertices[0].parameters = parameters
	vertices[1].parameters = parameters
	vertices[2].parameters = parameters
	vertices[3].parameters = parameters
}

atlasUvFromSprite :: proc(sprite: game.SpriteName) -> gmath.Vec4 {
	return game.getSpriteData(sprite).uv
}

getSpriteSize :: proc(sprite: game.SpriteName) -> gmath.Vec2 {
	return game.getSpriteData(sprite).size
}
