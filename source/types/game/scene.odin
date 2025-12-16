package game_types

Scene :: struct {
	data:   rawptr,
	init:   proc(data: rawptr),
	update: proc(data: rawptr),
	draw:   proc(data: rawptr),
	exit:   proc(data: rawptr),
}
