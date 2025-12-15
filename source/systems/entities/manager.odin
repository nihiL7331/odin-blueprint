package entities

import "core:fmt"

import "../../core"
import "../../core/render"
import "../../types/color"
import "../../types/game"
import "../../types/gmath"
import "../../utils"

@(private)
_zeroEntity: game.Entity
_noopUpdate :: proc(e: ^game.Entity) {}
_noopDraw :: proc(e: ^game.Entity) {}

getAllEntities :: proc() -> []game.EntityHandle {
	return core.getCoreContext().gameState.scratch.allEntities
}

isValid :: proc {
	entityIsValid,
	entityIsValidPtr,
}
entityIsValid :: proc(entity: game.Entity) -> bool {
	return entity.handle.id != 0
}
entityIsValidPtr :: proc(entity: ^game.Entity) -> bool {
	return entity != nil && entityIsValid(entity^)
}

entityInitCore :: proc() {
	_zeroEntity.kind = .nil
	_zeroEntity.updateProc = _noopUpdate
	_zeroEntity.drawProc = _noopDraw
}

entityFromHandle :: proc(
	handle: game.EntityHandle,
) -> (
	entity: ^game.Entity,
	ok: bool,
) #optional_ok {
	coreContext := core.getCoreContext()

	if handle.index <= 0 || handle.index > coreContext.gameState.entityTopCount {
		return &_zeroEntity, false
	}

	ent := &coreContext.gameState.entities[handle.index]
	if ent.handle.id != handle.id {
		return &_zeroEntity, false
	}

	return ent, true
}

rebuildScratchHelpers :: proc() {
	coreContext := core.getCoreContext()

	allEnts := make(
		[dynamic]game.EntityHandle,
		0,
		len(coreContext.gameState.entities),
		allocator = context.temp_allocator,
	)
	for &e in coreContext.gameState.entities {
		if !isValid(e) do continue
		append(&allEnts, e.handle)
	}
	coreContext.gameState.scratch.allEntities = allEnts[:]
}

create :: proc(kind: game.EntityKind) -> ^game.Entity {
	coreContext := core.getCoreContext()
	index := -1
	if len(coreContext.gameState.entityFreeList) > 0 {
		index = pop(&coreContext.gameState.entityFreeList)
	}

	if index == -1 {
		assert(
			coreContext.gameState.entityTopCount + 1 < game.MAX_ENTITIES,
			"Ran out of entities.",
		)
		coreContext.gameState.entityTopCount += 1
		index = coreContext.gameState.entityTopCount
	}

	ent := &coreContext.gameState.entities[index]
	ent.handle.index = index
	ent.handle.id = coreContext.gameState.latestEntityId + 1
	coreContext.gameState.latestEntityId = ent.handle.id

	ent.kind = kind
	ent.drawPivot = gmath.Pivot.bottomCenter
	ent.drawProc = drawEntityDefault

	fmt.assertf(ent.kind != nil, "Entity %v needs to define a kind during setup", kind)

	return ent
}

drawEntityDefault :: proc(e: ^game.Entity) {
	if e.sprite == nil {
		return
	}

	xForm := utils.xFormRotate(e.rotation)

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
	entity: ^game.Entity,
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
	e: ^game.Entity,
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

updateAnimation :: proc(e: ^game.Entity) {
	if e.frameDuration == 0 do return

	frameCount := render.getFrameCount(e.sprite)

	isPlaying := true
	if !e.loop {
		isPlaying = e.animIndex + 1 <= frameCount
	}

	if isPlaying {
		if e.nextFrameEndTime == 0 {
			e.nextFrameEndTime = utils.now() + f64(e.frameDuration)
		}

		if utils.endTimeUp(e.nextFrameEndTime) {
			e.animIndex += 1
			e.nextFrameEndTime = 0

			if e.animIndex >= frameCount && e.loop {
				e.animIndex = 0
			}
		}
	}
}

destroy :: proc(e: ^game.Entity) {
	coreContext := core.getCoreContext()

	append(&coreContext.gameState.entityFreeList, e.handle.index)
	e^ = {}
}

updateAll :: proc() {
	rebuildScratchHelpers()

	for handle in getAllEntities() {
		e := entityFromHandle(handle)

		updateAnimation(e)

		if e.updateProc == nil do continue
		e.updateProc(e)
	}
}

drawAll :: proc() {
	for handle in getAllEntities() {
		e := entityFromHandle(handle)
		if e.drawProc == nil do continue
		e.drawProc(e)
	}
}
