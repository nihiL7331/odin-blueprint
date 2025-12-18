package render

import sg "../../libs/sokol/gfx"
import sglue "../../libs/sokol/glue"
import slog "../../libs/sokol/log"
import stbi "../../libs/stb/image"
import stbrp "../../libs/stb/rect_pack"
import tt "../../libs/stb/truetype"

import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"

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

fontBitmapW :: 256
fontBitmapH :: 256
charCount :: 96
Font :: struct {
	charData: [charCount]tt.bakedchar,
	sgView:   sg.View,
}
font: Font

@(private)
_drawFrame: gfx.DrawFrame

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

getFrameCount :: proc(sprite: game.SpriteName) -> int {
	frameCount := game.spriteData[sprite].frameCount
	if frameCount == 0 {
		frameCount = 1
	}
	return frameCount
}

getSpriteOffset :: proc(sprite: game.SpriteName) -> (offset: gmath.Vec2, pivot: gmath.Pivot) {
	data := game.spriteData[sprite]
	offset = data.offset
	pivot = data.pivot
	return
}

ySortCompare :: proc(a, b: gfx.Quad) -> bool {
	ay := min(a[0].pos.y, a[1].pos.y, a[2].pos.y, a[3].pos.y)
	by := min(b[0].pos.y, b[1].pos.y, b[2].pos.y, b[3].pos.y)
	return ay > by
}

getSpriteCenterMass :: proc(sprite: game.SpriteName) -> gmath.Vec2 {
	size := getSpriteSize(sprite)
	offset, pivot := getSpriteOffset(sprite)

	center := size * gmath.scaleFromPivot(pivot)
	center -= offset

	return center
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
	loadFont()

	// make the vertex buffer
	renderState.bind.vertex_buffers[0] = sg.make_buffer(
		{usage = {dynamic_update = true}, size = size_of(actualQuadData)},
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

	renderState.bind.samplers[SMP_uDefaultSampler] = sg.make_sampler({})

	// setup pipeline
	pipelineDesc: sg.Pipeline_Desc = {
		shader = sg.make_shader(quad_shader_desc(sg.query_backend())),
		index_type = .UINT16,
		layout = {
			attrs = {
				ATTR_quad_aPosition = {format = .FLOAT2},
				ATTR_quad_aColor = {format = .FLOAT4},
				ATTR_quad_aUv = {format = .FLOAT2},
				ATTR_quad_aLocalUv = {format = .FLOAT2},
				ATTR_quad_aSize = {format = .FLOAT2},
				ATTR_quad_aBytes = {format = .UBYTE4N},
				ATTR_quad_aColorOverride = {format = .FLOAT4},
				ATTR_quad_aParams = {format = .FLOAT4},
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
}

coreRenderFrameEnd :: proc() {
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

	renderState.bind.views[VIEW_uTex] = atlas.sgView
	renderState.bind.views[VIEW_uFontTex] = font.sgView

	sg.update_buffer(
		renderState.bind.vertex_buffers[0],
		{ptr = raw_data(actualQuadData[:]), size = auto_cast quadIndex * size_of(gfx.Quad)},
	)

	sg.begin_pass({action = renderState.passAction, swapchain = sglue.swapchain()})
	sg.apply_pipeline(renderState.pip)
	sg.apply_bindings(renderState.bind)

	sg.apply_uniforms(
		UB_ShaderData,
		{ptr = &drawFrame.reset.shaderData, size = size_of(Shaderdata)},
	)

	sg.draw(0, 6 * quadIndex, 1)
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

loadSpritesIntoAtlas :: proc() {
	imgDir := "assets/images/"

	for imgName in game.SpriteName {
		if imgName == .nil do continue

		path := fmt.tprint(imgDir, imgName, ".png", sep = "")
		pngData, succ := io.read_entire_file(path)
		assert(succ, fmt.tprint(path, "not found."))

		defer delete(pngData)

		assert(raw_data(pngData) != nil, "load image failed")


		stbi.set_flip_vertically_on_load(1)
		width, height, channels: i32
		imgData := stbi.load_from_memory(
			raw_data(pngData),
			auto_cast len(pngData),
			&width,
			&height,
			&channels,
			4,
		)
		assert(imgData != nil, "stbi load failed. (invalid image?)")

		img: game.Sprite
		img.width = width
		img.height = height
		img.data = imgData

		sprites[imgName] = img
	}

	{ 	// pack sprites into atlas
		SIZE :: 1024
		atlas.w = SIZE
		atlas.h = SIZE

		cont: stbrp.Context
		nodesSlice, _ := make([]stbrp.Node, SIZE, context.temp_allocator)
		stbrp.init_target(&cont, i32(atlas.w), i32(atlas.h), raw_data(nodesSlice), i32(atlas.w))

		rects: [dynamic]stbrp.Rect
		rects.allocator = context.temp_allocator

		for img, id in sprites {
			if img.width == 0 do continue

			append(
				&rects,
				stbrp.Rect {
					id = i32(id),
					w  = stbrp.Coord(img.width + 2), // padding to not get visual bugs
					h  = stbrp.Coord(img.height + 2),
				},
			)
		}

		succ := stbrp.pack_rects(&cont, &rects[0], i32(len(rects)))
		assert(succ != 0, "Failed to pack sprites into atlas.")

		rawData, err := mem.alloc(atlas.w * atlas.h * 4, allocator = context.temp_allocator)
		assert(err == .None, "Failed to allocate memory for sprite atlas.")

		for rect in rects {
			img := &sprites[game.SpriteName(rect.id)]

			rectW := int(rect.w) - 2
			rectH := int(rect.h) - 2

			for row in 0 ..< rectH {
				srcRow := mem.ptr_offset(&img.data[0], int(row) * rectW * 4)
				destRow := mem.ptr_offset(
					cast(^u8)rawData,
					((int(rect.y + 1) + row) * int(atlas.w) + int(rect.x + 1)) * 4,
				)
				mem.copy(destRow, srcRow, rectW * 4)
			}

			stbi.image_free(img.data)
			img.data = nil

			img.atlasUvs.x = (f32(rect.x + 1)) / (f32(atlas.w))
			img.atlasUvs.y = (f32(rect.y + 1)) / (f32(atlas.h))
			img.atlasUvs.z = img.atlasUvs.x + f32(img.width) / (f32(atlas.w))
			img.atlasUvs.w = img.atlasUvs.y + f32(img.height) / (f32(atlas.h))
		}

		desc: sg.Image_Desc
		desc.width = i32(atlas.w)
		desc.height = i32(atlas.h)
		desc.pixel_format = .RGBA8
		desc.data.subimage[0][0] = {
			ptr  = rawData,
			size = uint(atlas.w * atlas.h * 4),
		}
		sgImg := sg.make_image(desc)
		if sgImg.id == sg.INVALID_ID do log.error("Failed to make an image.")

		atlas.sgView = sg.make_view({texture = sg.Texture_View_Desc({image = sgImg})})
	}
}

loadFont :: proc() { 	//TODO: abstract this out, fix the wrong fontHeight issue
	bitmap, err := mem.alloc(fontBitmapW * fontBitmapH)
	assert(err == .None, "Failed to allocate bitmap memory (font).")
	fontHeight := 15
	path := "assets/fonts/alagard.ttf"
	ttfData, succ := io.read_entire_file(path)
	assert(succ, "Failed to read font data.")

	ret := tt.BakeFontBitmap(
		raw_data(ttfData),
		0,
		f32(fontHeight),
		auto_cast bitmap,
		fontBitmapW,
		fontBitmapH,
		32,
		charCount,
		&font.charData[0],
	)
	assert(ret > 0, "Not enough space in the font bitmap.")

	desc: sg.Image_Desc
	desc.width = fontBitmapW
	desc.height = fontBitmapH
	desc.pixel_format = .R8
	desc.data.subimage[0][0] = {
		ptr  = bitmap,
		size = fontBitmapW * fontBitmapH,
	}
	sgImg := sg.make_image(desc)
	if sgImg.id == sg.INVALID_ID do log.error("Failed to make a font image.")

	font.sgView = sg.make_view({texture = sg.Texture_View_Desc({image = sgImg})})
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
	return sprites[sprite].atlasUvs
}

getSpriteSize :: proc(sprite: game.SpriteName) -> gmath.Vec2 {
	return {f32(sprites[sprite].width), f32(sprites[sprite].height)}
}
