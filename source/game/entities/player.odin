package entityData

import "../../core"
import "../../core/input"
import "../../core/render"
import "../../systems/entities"
import "../../types/game"
import "../../types/gmath"

spawnPlayer :: proc() -> ^game.Entity {
	e := entities.create(game.EntityName.player)

	e.drawOffset = gmath.Vec2{0.5, 5}
	e.drawPivot = gmath.Pivot.bottomCenter

	e.updateProc = proc(e: ^game.Entity) {
		coreContext := core.getCoreContext()

		inputDir := input.getInputVector()
		e.pos += inputDir * 100.0 * coreContext.deltaTime

		if inputDir.x != 0 {
			e.lastKnownXDir = inputDir.x
		}

		e.flipX = e.lastKnownXDir < 0

		if inputDir == {} {
			entities.setAnimation(e, game.SpriteName.player_idle, 0.3)
		} else {
			entities.setAnimation(e, game.SpriteName.player_run, 0.1)
		}

		e.scratch.colOverride = gmath.Vec4{0, 0, 1, 0.2}
	}

	e.drawProc = proc(e: ^game.Entity) {
		render.drawSprite(
			e.pos,
			game.SpriteName.shadow_medium,
			col = {1, 1, 1, 0.2},
			zLayer = game.ZLayer.shadow,
		)
		entities.drawEntityDefault(e)
	}

	return e
}
