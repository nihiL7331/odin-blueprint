package game

import "../systems/input"
import "../systems/render"
import "../types/game"
import "../types/gmath"
import "../utils"

getPlayer :: proc() -> ^game.Entity {
	coreContext := utils.getCoreContext()
	return entityFromHandle(coreContext.gameState.playerHandle)
}

setupPlayer :: proc(e: ^game.Entity) {
	e.kind = game.EntityKind.player

	e.drawOffset = gmath.Vec2{0.5, 5}
	e.drawPivot = gmath.Pivot.bottomCenter

	e.updateProc = proc(e: ^game.Entity) {
		coreContext := utils.getCoreContext()

		inputDir := input.getInputVector()
		e.pos += inputDir * 100.0 * coreContext.deltaTime

		if inputDir.x != 0 {
			e.lastKnownXDir = inputDir.x
		}

		e.flipX = e.lastKnownXDir < 0

		if inputDir == {} {
			entitySetAnimation(e, .player_idle, 0.3)
		} else {
			entitySetAnimation(e, .player_run, 0.1)
		}

		e.scratch.colOverride = gmath.Vec4{0, 0, 1, 0.2}
	}

	e.drawProc = proc(e: ^game.Entity) {
		render.drawSprite(e.pos, .shadow_medium, col = {1, 1, 1, 0.2}, zLayer = game.ZLayer.shadow)
		drawEntityDefault(e)
	}
}

setupThing1 :: proc(using e: ^game.Entity) {
	e.kind = game.EntityKind.thing1

	e.drawOffset = gmath.Vec2{0.5, 5}
	e.drawPivot = gmath.Pivot.bottomCenter

	e.updateProc = proc(e: ^game.Entity) {
		entitySetAnimation(e, .player_idle, 0.3)
	}

	e.drawProc = proc(e: ^game.Entity) {
		render.drawSprite(e.pos, .shadow_medium, col = {1, 1, 1, 0.2}, zLayer = game.ZLayer.shadow)
		drawEntityDefault(e)
	}
}
