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
	if kind == game.SceneName.nil {
		log.error("Initializing with an empty/nil scene is not supported.")
		return
	}

	startScene := &_scenes[kind]
	_getWorld().currentScene = startScene

	if startScene.init != nil {
		startScene.init(startScene.data)
	}
}

// called by automatically generated registry
register :: proc(kind: game.SceneName, scene: game.Scene) {
	_scenes[kind] = scene
}

//TODO: built-in scene change effect?
change :: proc(kind: game.SceneName) {
	nextScene := &_scenes[kind]

	if nextScene == nil || (nextScene.init == nil && nextScene.update == nil) {
		log.error("Attempted to load an unregistered scene.")
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
