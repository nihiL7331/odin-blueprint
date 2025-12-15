package game_types

SceneKind :: enum {
	Splash,
	MainMenu,
	Gameplay,
}

Scene :: struct {
	init:   proc(),
	update: proc(),
	draw:   proc(),
	exit:   proc(),
}
