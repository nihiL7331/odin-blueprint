package scene_manager

import "../../core"

import "../../types/game"

import "core:log"


@(private)
_scenes: [game.SceneName]game.Scene

@(private)
_getWorld :: proc() -> ^game.WorldState {
	return core.getCoreContext().gameState.world
}

init :: proc(kind: game.SceneName) {
	if kind == game.SceneName.None {
		log.warn("Initializing with an empty/nil scene is not supported.")
		return
	}
	startScene := &_scenes[kind]
	_getWorld().currentScene = startScene

	if startScene.init != nil {
		startScene.init(startScene.data)
	}
}

register :: proc(kind: game.SceneName, s: game.Scene) {
	_scenes[kind] = s
}

change :: proc(kind: game.SceneName) {
	nextScene := &_scenes[kind]

	if nextScene.init == nil && nextScene.update == nil {
		log.warn("Attempted to load an unregistered scene.")
		return
	}

	_getWorld().nextScene = nextScene
}

update :: proc() {
	world := _getWorld()
	currentScene := world.currentScene
	nextScene := world.nextScene

	if nextScene != nil {
		if currentScene != nil && currentScene.exit != nil {
			currentScene.exit(currentScene.data)
		}

		world.currentScene = nextScene
		world.nextScene = nil
		currentScene = world.currentScene

		if currentScene.init != nil {
			currentScene.init(currentScene.data)
		}
	}

	if currentScene != nil && currentScene.update != nil {
		currentScene.update(currentScene.data)
	}
}

draw :: proc() {
	currentScene := _getWorld().currentScene
	if currentScene != nil && currentScene.draw != nil {
		currentScene.draw(currentScene.data)
	}
}
