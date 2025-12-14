package platform

IS_WEB :: ODIN_ARCH == .wasm64p32 || ODIN_ARCH == .wasm32

import "desktop"
import "web"

_ :: desktop
_ :: web

@(require_results)
read_entire_file :: proc(
	name: string,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	data: []byte,
	success: bool,
) {
	when IS_WEB {
		return web.read_entire_file(name, allocator, loc)
	} else {
		return desktop.read_entire_file(name, allocator, loc)
	}
}

write_entire_file :: proc(name: string, data: []byte, truncate := true) -> (success: bool) {
	when IS_WEB {
		return web.write_entire_file(name, data, truncate)
	} else {
		return desktop.write_entire_file(name, data, truncate)
	}
}
