// General purpose of this file is to generate paths to assets used in the game.
// It takes names of files from assets/ and creates:
// for sprites: SpriteName in generated_sprite.odin
// for audio: TODO:
// for fonts: TODO:
//TODO: rewrite this code its nasty right now

package utils

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

SearchContext :: struct {
	files:       ^[dynamic]string,
	isDirectory: bool,
}


main :: proc() {
	generateDataFile("assets/images", "source/types/game/generated_sprite.odin", "SpriteName")
	// generateDataFile("assets/audio", "source/types/game/generated_audio.odin", "AudioName")
	generateDataFile("assets/fonts", "source/types/game/generated_font.odin", "FontName")
	files := generateSceneFile(
		"source/game/scenes",
		"source/game/scenes/generated_registry.odin",
		"SceneName",
		{"scenes"},
	)
	generateSceneHelpers(files, "source/types/game/generated_scene.odin", "SceneName")
}

getData :: proc(info: os.File_Info, inErr: os.Error, userData: rawptr) -> (os.Error, bool) {
	if inErr != os.ERROR_NONE {
		fmt.eprintln("Error accessing ", info.fullpath)
		return inErr, false
	}

	ctx := cast(^SearchContext)userData

	if info.is_dir == ctx.isDirectory {
		name := filepath.stem(info.fullpath)
		append(ctx.files, name)
	}

	return os.ERROR_NONE, false
}

generateSceneFile :: proc(src, dst, type: string, flaggedFiles: []string) -> [dynamic]string {
	foundFiles := make([dynamic]string)

	ctx := SearchContext {
		files       = &foundFiles,
		isDirectory = true,
	}

	filepath.walk(src, getData, &ctx)

	for name, index in foundFiles {
		//filter
		for flag in flaggedFiles {
			if name == flag {
				unordered_remove(&foundFiles, index)
				break
			}
		}
	}

	if len(foundFiles) == 0 {
		fmt.println("No files found in: ", src)
		return {}
	}

	f, err := os.open(dst, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	if err != nil {
		fmt.eprintln("Error on generating scene registry output file. ", err)
	}
	defer os.close(f)

	fmt.fprintln(f, "//NOTE: Machine generated in generateAssets.odin")
	fmt.fprintln(f, "")
	fmt.fprintln(f, "package scenes")
	fmt.fprintln(f, "")
	fmt.fprintln(f, "import \"../../core/scene\"")
	fmt.fprintln(f, "import \"../../types/game\"")
	for name in foundFiles {
		fmt.fprintln(f, "import \"", name, "\"", sep = "")
	}
	fmt.fprintln(f, "")
	for name in foundFiles {
		fmt.fprintln(f, "@(private)")
		fmt.fprintln(f, "_", name, "Data: ", name, ".Data", sep = "")
	}
	fmt.fprintln(f, "")
	fmt.fprintln(f, "initRegistry :: proc() {")
	for name in foundFiles {
		fmt.fprintln(f, "\tscene.register(")
		fmt.fprintln(f, "\t\t", "game.", type, ".", strings.to_pascal_case(name), ",", sep = "")
		fmt.fprintln(f, "\t\tgame.Scene {")
		fmt.fprintln(f, "\t\t\tdata = &_", name, "Data,", sep = "")
		fmt.fprintln(f, "\t\t\tinit = ", name, ".init,", sep = "")
		fmt.fprintln(f, "\t\t\tupdate = ", name, ".update,", sep = "")
		fmt.fprintln(f, "\t\t\tdraw = ", name, ".draw,", sep = "")
		fmt.fprintln(f, "\t\t\texit = ", name, ".exit,", sep = "")
		fmt.fprintln(f, "\t\t},")
		fmt.fprintln(f, "\t)")
	}
	fmt.fprintln(f, "}")

	return foundFiles
}

generateSceneHelpers :: proc(files: [dynamic]string, dst, type: string) {
	f, err := os.open(dst, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	if err != nil {
		fmt.eprintln("Error on generating scene helpers output file. ", err)
	}
	defer os.close(f)

	fmt.fprintln(f, "//NOTE: Machine generated in generateAssets.odin")
	fmt.fprintln(f, "")
	fmt.fprintln(f, "package game_types")
	fmt.fprintln(f, "")
	fmt.fprintln(f, type, ":: enum {")
	fmt.fprintln(f, "\tNone,")
	for name in files {
		fmt.fprintln(f, "\t", strings.to_pascal_case(name), ",", sep = "")
	}
	fmt.fprintln(f, "}")
}

generateDataFile :: proc(src, dst, type: string) -> [dynamic]string {
	foundFiles := make([dynamic]string)

	ctx := SearchContext {
		files       = &foundFiles,
		isDirectory = false,
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

	fmt.fprintln(f, "//NOTE: Machine generated in generateAssets.odin")
	fmt.fprintln(f, "")
	fmt.fprintln(f, "package game_types")
	fmt.fprintln(f, "")
	fmt.fprintln(f, type, ":: enum {")
	fmt.fprintln(f, "\tnil,")
	for name in foundFiles {
		fmt.fprintln(f, "  ", name, ",", sep = "")
	}
	fmt.fprintln(f, "}")

	return foundFiles
}
