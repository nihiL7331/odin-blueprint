package entities

import "core:fmt"

import "../../core/clock"
import "../../core/render"
import "../../types/color"
import "../../types/game"
import "../../types/gmath"
import "type"

@(private)
_zeroEntity: type.Entity
@(private)
_noopUpdate :: proc(e: ^type.Entity) {}
@(private)
_noopDraw :: proc(e: ^type.Entity) {}
@(private)
_entityStorage: ^type.EntityStorage
@(private)
_allEntities: []type.EntityHandle

getPlayer :: proc() -> ^type.Entity {
	if _entityStorage == nil do return &_zeroEntity
	return entityFromHandle(_entityStorage.playerHandle)
}

setPlayerHandle :: proc(playerHandle: type.EntityHandle) {
	_entityStorage.playerHandle = playerHandle
}

isValid :: proc {
	entityIsValid,
	entityIsValidPtr,
}
entityIsValid :: proc(entity: type.Entity) -> bool {
	return entity.handle.id != 0
}
entityIsValidPtr :: proc(entity: ^type.Entity) -> bool {
	return entity != nil && entityIsValid(entity^)
}

entityInitCore :: proc() {
	_zeroEntity.kind = .nil
	_zeroEntity.updateProc = _noopUpdate
	_zeroEntity.drawProc = _noopDraw
	_entityStorage = new(type.EntityStorage)
}

updateAll :: proc() {
	rebuildScratchHelpers()

	for handle in _allEntities {
		e := entityFromHandle(handle)

		updateAnimation(e)

		if e.updateProc == nil do continue
		e.updateProc(e)
	}
}

drawAll :: proc() {
	for handle in _allEntities {
		e, ok := entityFromHandle(handle)
		if !ok do continue

		if e.drawProc == nil do continue
		e.drawProc(e)
	}
}

cleanup :: proc() {
	free(_entityStorage)
}

entityFromHandle :: proc(
	handle: type.EntityHandle,
) -> (
	entity: ^type.Entity,
	ok: bool,
) #optional_ok {
	if handle.index <= 0 || handle.index > _entityStorage.topCount {
		return &_zeroEntity, false
	}

	returnEntity := &_entityStorage.data[handle.index]
	if returnEntity.handle.id != handle.id {
		return &_zeroEntity, false
	}

	return returnEntity, true
}

rebuildScratchHelpers :: proc() {
	allEntities := make(
		[dynamic]type.EntityHandle,
		0,
		len(_entityStorage.data),
		allocator = context.temp_allocator,
	)
	for &entity in _entityStorage.data {
		if !isValid(entity) do continue
		append(&allEntities, entity.handle)
	}
	_allEntities = allEntities[:]
}


create :: proc(kind: type.EntityName) -> ^type.Entity {
	index := -1
	if len(_entityStorage.freeList) > 0 {
		index = pop(&_entityStorage.freeList)
	}

	if index == -1 {
		assert(_entityStorage.topCount + 1 < type.MAX_ENTITIES, "Ran out of entities.")
		_entityStorage.topCount += 1
		index = _entityStorage.topCount
	}

	ent := &_entityStorage.data[index]
	ent.handle.index = index
	ent.handle.id = _entityStorage.latestId + 1
	_entityStorage.latestId = ent.handle.id

	ent.kind = kind
	ent.drawPivot = gmath.Pivot.bottomCenter
	ent.drawProc = drawEntityDefault

	fmt.assertf(ent.kind != nil, "Entity %v needs to define a kind during setup", kind)

	return ent
}

destroy :: proc(e: ^type.Entity) {
	append(&_entityStorage.freeList, e.handle.index)
	e^ = {}
}

drawEntityDefault :: proc(e: ^type.Entity) {
	if e.sprite == nil {
		return
	}

	xForm := gmath.xFormRotate(e.rotation)

	drawSpriteEntity(
		e,
		e.pos,
		e.sprite,
		xForm = xForm,
		animIndex = e.animIndex,
		drawOffset = e.drawOffset,
		flipX = e.flipX,
		pivot = e.drawPivot,
		zLayer = game.ZLayer.playspace,
	)
}

drawSpriteEntity :: proc(
	entity: ^type.Entity,
	pos: gmath.Vec2,
	sprite: game.SpriteName,
	pivot := gmath.Pivot.centerCenter,
	flipX := false,
	drawOffset := gmath.Vec2{},
	xForm := gmath.Mat4(1),
	animIndex := 0,
	col := color.WHITE,
	colOverride := gmath.Vec4{},
	zLayer := game.ZLayer{},
	flags := game.QuadFlags{},
	params := gmath.Vec4{},
	cropTop: f32 = 0.0,
	cropLeft: f32 = 0.0,
	cropBottom: f32 = 0.0,
	cropRight: f32 = 0.0,
	zLayerQueue := -1,
) {
	colOverride := colOverride

	colOverride = entity.scratch.colOverride
	if entity.hitFlash.a != 0 {
		colOverride.xyz = entity.hitFlash.xyz
		colOverride.a = max(colOverride.a, entity.hitFlash.a)
	}

	render.drawSprite(
		pos,
		sprite,
		pivot,
		flipX,
		drawOffset,
		xForm,
		animIndex,
		col,
		colOverride,
		zLayer,
		flags,
		params,
		cropTop,
		cropLeft,
		cropBottom,
		cropRight,
	)
}

setAnimation :: proc(
	e: ^type.Entity,
	sprite: game.SpriteName,
	frameDuration: f32,
	looping := true,
) {
	if e.sprite != sprite {
		e.sprite = sprite
		e.loop = looping
		e.frameDuration = frameDuration
		e.animIndex = 0
		e.nextFrameEndTime = 0
	}
}

updateAnimation :: proc(e: ^type.Entity) {
	if e.frameDuration == 0 do return

	frameCount := render.getFrameCount(e.sprite)

	isPlaying := true
	if !e.loop {
		isPlaying = e.animIndex + 1 <= frameCount
	}

	if isPlaying {
		if e.nextFrameEndTime == 0 {
			e.nextFrameEndTime = clock.now() + f64(e.frameDuration)
		}

		if clock.endTimeUp(e.nextFrameEndTime) {
			e.animIndex += 1
			e.nextFrameEndTime = 0

			if e.animIndex >= frameCount && e.loop {
				e.animIndex = 0
			}
		}
	}
}
