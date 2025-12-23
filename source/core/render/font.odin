package render

import sg "../../libs/sokol/gfx"
import tt "../../libs/stb/truetype"

import game "../../types/game"
import io "../platform"

import "core:fmt"
import "core:strings"

BITMAP_WIDTH :: 512
BITMAP_HEIGHT :: 512

Font :: struct {
	texture:  sg.Image,
	view:     sg.View,
	charData: [96]tt.bakedchar,
	height:   f32,
	name:     string,
}

@(private)
_fontCache: map[string]Font

getFont :: proc(id: game.FontName, size: int) -> (Font, bool) {
	if id == .nil do return {}, false

	name := fmt.tprintf("%v", id)
	key := fmt.tprintf("%s_%d", name, size)

	if key in _fontCache {
		setFontTexture(_fontCache[key].view)
		return _fontCache[key], true
	}

	filename := game.fontFilename[id]
	path := fmt.tprintf("assets/fonts/%s", filename)

	ttfData, success := io.read_entire_file(path)
	assert(success, "Could not find font file.")
	defer delete(ttfData)

	bitmap := make([]u8, BITMAP_WIDTH * BITMAP_HEIGHT)
	defer delete(bitmap)

	font := Font {
		height = f32(size),
		name   = strings.clone(name),
	}

	ret := tt.BakeFontBitmap(
		raw_data(ttfData),
		0,
		f32(size),
		raw_data(bitmap),
		BITMAP_WIDTH,
		BITMAP_HEIGHT,
		32,
		96,
		&font.charData[0],
	)
	assert(ret > 0, "Bitmap too small for font size.")

	description := sg.Image_Desc {
		width        = BITMAP_WIDTH,
		height       = BITMAP_HEIGHT,
		pixel_format = .R8,
		label        = "font_texture",
	}
	description.data.subimage[0][0] = {
		ptr  = raw_data(bitmap),
		size = len(bitmap),
	}

	font.texture = sg.make_image(description)
	assert(font.texture.id != sg.INVALID_ID, "Failed to create font image.")

	font.view = sg.make_view({texture = sg.Texture_View_Desc{image = font.texture}})
	assert(font.view.id != sg.INVALID_ID, "Failed to create font view.")

	setFontTexture(font.view)

	_fontCache[strings.clone(key)] = font

	return font, true
}

destroyFonts :: proc() {
	for key, font in _fontCache {
		sg.destroy_image(font.texture)
		delete(font.name)
		delete(key)
	}
	delete(_fontCache)
}
