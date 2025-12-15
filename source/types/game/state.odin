package game_types

import "../gmath"

GameState :: struct {
	time:     TimeState,
	scratch:  ScratchState,
	entities: ^EntityStorage,
	world:    ^WorldState,
}

TimeState :: struct {
	ticks:           u64,
	gameTimeElapsed: f64,
}

ScratchState :: struct {
	// rebuilt every frame
	allEntities: []EntityHandle,
}

EntityStorage :: struct {
	topCount: int,
	latestId: int,
	data:     [MAX_ENTITIES]Entity,
	freeList: [dynamic]int,
}

WorldState :: struct {
	playerHandle: EntityHandle,
	camPos:       gmath.Vec2,
	currentScene: ^Scene,
	nextScene:    ^Scene,
}
