# Fact 1: Called by archer.gd, watch_tower.gd, and enemy_ai.gd
# Fact 2: Verified existing sound_manager.gd via Glob in scripts/autoload/
# Fact 3: Autoload Node class providing play_sound stub
# Fact 4: User request: "ok nếu cần dùng animation thì dùng trong folder C:\Users\nguye\Godot_v4.7.2-stable_win64.exe\git\Age-of-Low-Poly\assets\animations nếu không có thì tự làm cho tôi dùng blender mcp và godot mcp"

extends Node

## SoundManager: Tạm thời tắt toàn bộ procedural SFX chờ asset âm thanh chính thức
func play_sound(_sound_type: String) -> void:
	pass
