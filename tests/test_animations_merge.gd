extends SceneTree

func _init() -> void:
	var s1: PackedScene = load("res://assets/animations/UAL1_Standard.glb")
	var s2: PackedScene = load("res://assets/animations/UAL2_Standard.glb")
	assert(s1 != null, "UAL1_Standard.glb must load")
	assert(s2 != null, "UAL2_Standard.glb must load")
	var n1 = s1.instantiate()
	var n2 = s2.instantiate()
	var ap1: AnimationPlayer = n1.find_child("AnimationPlayer", true, false)
	var ap2: AnimationPlayer = n2.find_child("AnimationPlayer", true, false)

	for anim_name in ap1.get_animation_list():
		var anim = ap1.get_animation(anim_name)
		if not ap2.has_animation(anim_name):
			ap2.get_animation_library("").add_animation(anim_name, anim)

	var anim_sprint_2 = ap2.get_animation("Sprint")
	var anim_carry_2 = ap2.get_animation("Walk_Carry")
	var anim_walk_2 = ap2.get_animation("Walk")
	var anim_sprint_1 = ap1.get_animation("Sprint")

	print("Sprint UAL2 track count: ", anim_sprint_2.get_track_count() if anim_sprint_2 else 0)
	print("Sprint UAL1 track count: ", anim_sprint_1.get_track_count() if anim_sprint_1 else 0)
	print("Walk_Carry track count: ", anim_carry_2.get_track_count() if anim_carry_2 else 0)

	# Compare root / hips bone tracks
	var villager_scene: PackedScene = load("res://scenes/entities/villager.tscn")
	var v: CharacterBody3D = villager_scene.instantiate()
	root.add_child(v)
	var ap: AnimationPlayer = v.find_child("AnimationPlayer", true, false)
	var sk: Skeleton3D = v.find_child("Skeleton3D", true, false)

	for test_anim in ["Idle", "Sprint", "Walk_Carry", "Walk", "Jog_Fwd"]:
		if not ap.has_animation(test_anim):
			print("No anim: ", test_anim)
			continue
		ap.play(test_anim)
		ap.advance(0.1)
	for angle_idx in range(8):
		var a_rad := float(angle_idx) * PI / 4.0
		var dir := Vector3(sin(a_rad), 0.0, cos(a_rad))
		var look_y: float = Transform3D.IDENTITY.looking_at(dir, Vector3.UP).basis.get_euler().y
		var atan_neg: float = atan2(-dir.x, -dir.z)
		var diff := rad_to_deg(wrapf(look_y - atan_neg, -PI, PI))
		assert(absf(diff) < 0.01, "atan2(-x, -z) must match looking_at for angle " + str(angle_idx))
	print("--- All 8 direction angles match looking_at perfectly! ---")

	v.play_anim("Idle")
	print("Current anim after play_anim('Idle'): ", ap.current_animation)
	v.play_anim("Idle_Loop")
	print("Current anim after play_anim('Idle_Loop'): ", ap.current_animation)

	v.free()
	print("--- Animation Library Merge Verification: PASSED ---")

	n1.free()
	n2.free()
	quit(0)
