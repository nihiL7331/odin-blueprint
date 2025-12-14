package game_types

windowWidth := 1280
windowHeight := 720
GAME_WIDTH :: 480
GAME_HEIGHT :: 270

CoreContext :: struct {
	gameState: ^GameState,
	deltaTime: f32,
	appTicks:  u64,
}
