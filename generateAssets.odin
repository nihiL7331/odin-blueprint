// General purpose of this file is to generate paths to assets used in the game.
// It takes names of files from assets/ and creates:
// for sprites: SpriteName in generated_sprite.odin
// for audio: TODO:
// for fonts: TODO:

package utils

import "core:fmt"
import "core:os"
import "core:path/filepath"

SearchContext :: struct {
	files: ^[dynamic]string,
}

main :: proc() {
	generateData("assets/images", "source/types/game/generated_sprite.odin", "SpriteName")
	generateData("assets/audio", "source/types/game/generated_audio.odin", "AudioName")
	generateData("assets/fonts", "source/types/game/generated_font.odin", "FontName")
}

getData :: proc(info: os.File_Info, inErr: os.Error, userData: rawptr) -> (os.Error, bool) {
	if inErr != os.ERROR_NONE {
		fmt.eprintln("Error accessing ", info.fullpath)
		return inErr, false
	}

	ctx := cast(^SearchContext)userData

	if !info.is_dir {
		name := filepath.stem(info.fullpath)
		append(ctx.files, name)
	}

	return os.ERROR_NONE, false
}

generateData :: proc(src, dst, type: string) -> [dynamic]string {
	foundFiles := make([dynamic]string)

	ctx := SearchContext {
		files = &foundFiles,
	}

	filepath.walk(src, getData, &ctx)

	if len(foundFiles) == 0 {
		fmt.println("No files found in: ", src)
		return {}
	}

	f, err := os.open(dst, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	if err != nil {
		fmt.eprintln("Error on asset generation output: ", err)
	}
	defer os.close(f)

	fmt.fprintln(f, "// NOTE: MACHINE GENERATED IN generateAssets.odin")
	fmt.fprintln(f, "")
	fmt.fprintln(f, "package game_types")
	fmt.fprintln(f, "")
	fmt.fprintln(f, type, ":: enum {")
	fmt.fprintln(f, "  nil,")
	for name in foundFiles {
		fmt.fprintln(f, "  ", name, ",", sep = "")
	}
	fmt.fprintln(f, "}")

	return foundFiles
}
