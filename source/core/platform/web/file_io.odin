#+build wasm32, wasm64p32

//
//NOTE: these functions use the virtual file system. data written and read via
//these functions dont persist through sessions, it's mostly used for loading preloaded (via Emscripten)
//assets to the game.
//

package web

import "base:runtime"
import "core:c"
import "core:encoding/base64"
import "core:log"
import "core:mem"
import "core:strings"

@(default_calling_convention = "c")
foreign _ {
	fopen :: proc(filename, mode: cstring) -> ^FILE ---
	fseek :: proc(stream: ^FILE, offset: c.long, whence: Whence) -> c.int ---
	ftell :: proc(stream: ^FILE) -> c.long ---
	fclose :: proc(stream: ^FILE) -> c.int ---
	fread :: proc(ptr: rawptr, size: c.size_t, nmemb: c.size_t, stream: ^FILE) -> c.size_t ---
	fwrite :: proc(ptr: rawptr, size: c.size_t, nmemb: c.size_t, stream: ^FILE) -> c.size_t ---
}

FILE :: struct {}

Whence :: enum c.int {
	SET,
	CUR,
	END,
}

read_entire_file :: proc(
	name: string,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	data: []byte,
	success: bool,
) {
	if name == "" {
		log.error("No file name provided")
		return nil, false
	}

	file := fopen(strings.clone_to_cstring(name, context.temp_allocator), "rb")

	if file == nil {
		log.errorf("Failed to open file %v", name)
		return nil, false
	}

	defer fclose(file)

	fseek(file, 0, .END)
	size := ftell(file)
	fseek(file, 0, .SET)

	if size <= 0 {
		log.errorf("Failed to read file %v", name)
		return nil, false
	}

	data_err: runtime.Allocator_Error
	data, data_err = make([]byte, size, allocator, loc)

	if data_err != nil {
		log.errorf("Error allocating memory: %v", data_err)
		return nil, false
	}

	read_size := fread(raw_data(data), 1, c.size_t(size), file)

	if read_size != c.size_t(size) {
		log.errorf("File %v didn't load correctly.", name)
		return nil, false
	}

	log.debugf("Successfully loaded %v", name)
	return data, true
}

write_entire_file :: proc(name: string, data: []byte, truncate := true) -> (success: bool) {
	if name == "" {
		log.error("No file name provided")
		return
	}

	file := fopen(strings.clone_to_cstring(name, context.temp_allocator), truncate ? "wb" : "ab")
	defer fclose(file)

	if file == nil {
		log.errorf("Failed to open '%v' for writing", name)
		return
	}

	bytes_written := fwrite(raw_data(data), 1, len(data), file)

	if bytes_written == 0 {
		log.errorf("Failed to write file %v", name)
		return
	} else if bytes_written != len(data) {
		log.errorf("File partially written, wrote %v out of %v bytes", bytes_written, len(data))
		return
	}

	log.debugf("File written successfully: %v", name)
	return true
}

//
//NOTE: these functions allow to operate on the LocalStorage in the web to create save states.
//It's a HTML5 feature, so it doesn't work on some extremely old browsers.
//

foreign import "js"
foreign js {
	js_save :: proc "contextless" (key_ptr: rawptr, key_len: int, data_ptr: rawptr, data_len: int) ---
	js_load_size :: proc "contextless" (key_ptr: rawptr, key_len: int) -> int ---
	js_load :: proc "contextless" (key_ptr: rawptr, key_len: int, dest_ptr: rawptr, dest_len: int) ---
}

saveStruct :: proc(key: string, data: ^$T) -> (success: bool) {
	if data == nil do return false
	rawBytes := mem.ptr_to_bytes(data)
	encoded, error := base64.encode(rawBytes)
	defer delete(encoded)
	if error != .None do return false

	js_save(raw_data(key), len(key), raw_data(encoded), len(encoded))
	return true
}

loadStruct :: proc(key: string, data: ^$T) -> (success: bool) {
	if data == nil do return false
	size := js_load_size(raw_data(key), len(key))
	if size == 0 do return false

	buf := make([]byte, size)
	defer delete(buf)

	js_load(raw_data(key), len(key), raw_data(buf), size)
	decodedBytes, error := base64.decode(string(buf))
	defer delete(decodedBytes)
	if error != .None do return false

	if len(decodedBytes) != size_of(T) {
		log.warnf(
			"Save data size mismatch. Partial load. decodedBytes length: %v, T size: %v",
			len(decodedBytes),
			size_of(T),
		)
		copySize := min(len(decodedBytes), size_of(T))
		mem.copy(data, raw_data(decodedBytes), copySize)
		return true
	}

	mem.copy(data, raw_data(decodedBytes), size_of(T))
	return true
}

saveBytes :: proc(key: string, data: []byte) -> (success: bool) {
	if data == nil do return false
	encoded := base64.encode(data)
	defer delete(encoded)

	js_save(raw_data(key), len(key), raw_data(encoded), len(encoded))
	return true
}

loadBytes :: proc(key: string, allocator := context.allocator) -> (data: []byte, success: bool) {
	size := js_load_size(raw_data(key), len(key))
	if size == 0 do return nil, false

	base64Buffer := make([]byte, size, allocator)
	defer delete(base64Buffer)
	js_load(raw_data(key), len(key), raw_data(base64Buffer), size)

	rawData, error := base64.decode(string(base64Buffer))
	if error != .None do return nil, false

	return rawData, true
}
