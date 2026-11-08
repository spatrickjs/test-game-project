class_name NavigationEnums
extends RefCounted
## Shared identifiers for scene management and navigation. Preserve numeric values for future save compatibility.

enum Screen {
	MAIN_MENU = 0,
	SETTINGS = 1,
	ABOUT_US = 2,
	PLAY_MENU = 3,
	DISCARD_DIALOG = 4,
	EXIT_DIALOG = 5,
	GAME_SCENE = 6,
}

enum SettingsTab {
	SOUND = 0,
	GRAPHICS = 1,
	DIFFICULTY = 2,
}

enum GraphicsQuality {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
}

enum Difficulty {
	EASY = 0,
	NORMAL = 1,
	HARD = 2,
}
