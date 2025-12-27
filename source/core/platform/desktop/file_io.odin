#+build !wasm32, !wasm64p32
package desktop

import "core:log"
import "core:mem"
import "core:os"
import "core:strings"

_ :: log
_ :: mem

@(require_results)
read_entire_file :: proc(
	name: string,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	data: []byte,
	success: bool,
) {
	return os.read_entire_file(name, allocator, loc)
}

write_entire_file :: proc(name: string, data: []byte, truncate := true) -> (success: bool) {
	return os.write_entire_file(name, data, truncate)
}

//
// functions declared below are used to create data that is meant to be used for storage used longer than one session,
// basically save states
//

SAVE_DIRECTORY :: "saves/"
SAVE_EXTENSION :: ".bin"

saveBytes :: proc(key: string, data: []byte) -> (success: bool) {
	if data == nil do return false
	if !os.exists(SAVE_DIRECTORY) {
		os.make_directory(SAVE_DIRECTORY)
	}

	path := strings.concatenate({SAVE_DIRECTORY, key, SAVE_EXTENSION}, context.temp_allocator)
	success = os.write_entire_file(path, data)

	if !success {
		log.errorf("Failed to save bytes: %v", path)
	}

	return success
}

loadBytes :: proc(key: string, allocator := context.allocator) -> (data: []byte, success: bool) {
	path := strings.concatenate({SAVE_DIRECTORY, key, SAVE_EXTENSION}, context.temp_allocator)

	data, success = os.read_entire_file(path, allocator)
	return data, success
}

saveStruct :: proc(key: string, data: ^$T) -> (success: bool) {
	if data == nil do return false
	if !os.exists(SAVE_DIRECTORY) {
		os.make_directory(SAVE_DIRECTORY)
	}

	path := strings.concatenate({SAVE_DIRECTORY, key, SAVE_EXTENSION}, context.temp_allocator)
	bytes := mem.slice_ptr(cast(^byte)data, size_of(T))
	success = os.write_entire_file(path, bytes)

	if !success {
		log.errorf("Failed to save struct: %v", path)
	}

	return success
}

loadStruct :: proc(key: string, data: ^$T) -> (success: bool) {
	if data == nil do return false
	path := strings.concatenate({SAVE_DIRECTORY, key, SAVE_EXTENSION}, context.temp_allocator)

	if !os.exists(path) {
		return false
	}

	bytes, ok := os.read_entire_file(path, context.allocator)
	if !ok {
		log.errorf("Failed to read file: %v", path)
		return false
	}
	defer delete(bytes)

	if len(bytes) != size_of(T) {
		log.warnf("Save file size mismatch: %v. Partial load.", path)
		copySize := min(len(bytes), size_of(T))
		mem.copy(data, raw_data(bytes), copySize)
		return true
	}

	mem.copy(data, raw_data(bytes), size_of(T))
	return true
}
