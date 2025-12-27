package platform

IS_WEB :: ODIN_ARCH == .wasm64p32 || ODIN_ARCH == .wasm32

import "desktop"
import "web"

_ :: desktop
_ :: web

// this one doesn't folow the naming convention since it's meant to "override" a built-in function
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

@(require_results)
loadStruct :: proc(key: string, value: ^$T) -> (success: bool) {
	when IS_WEB {
		return web.loadStruct(key, value)
	} else {
		return desktop.loadStruct(key, value)
	}
}

saveStruct :: proc(key: string, value: ^$T) -> (success: bool) {
	when IS_WEB {
		return web.saveStruct(key, value)
	} else {
		return desktop.saveStruct(key, value)
	}
}

@(require_results)
loadBytes :: proc(key: string, allocator := context.allocator) -> (data: []byte, success: bool) {
	when IS_WEB {
		return web.loadBytes(key, allocator)
	} else {
		return desktop.loadBytes(key, allocator)
	}
}

saveBytes :: proc(key: string, data: []byte) -> (success: bool) {
	when IS_WEB {
		return web.saveBytes(key, data)
	} else {
		return desktop.saveBytes(key, data)
	}
}
