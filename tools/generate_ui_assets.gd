# Fact 1: Called via CLI standalone execution: godot --headless -s tools/generate_ui_assets.gd
# Fact 2: Verified no existing UI texture generator via Glob in tools/
# Fact 3: Writes PNG image textures to res://assets/ui/
# Fact 4: User request: "bạn thiết kế lại UI UX cho tôi bạn phải làm sao để giống game gốc [Image #1] nó rất đơn giản nhưng lại có mọi thứ và phải lên đời/ research thì mới hiện các côgn trình chứ hiện tại bạn cứ để bừa trên màn hình là không được"

extends SceneTree

const OUT_DIR := "res://assets/ui/"

func _init() -> void:
	print("--- Generating AoE 1 Authentic UI Icons and Textures ---")
	_gen_resource_icons()
	_gen_command_icons()
	_gen_building_icons()
	_gen_pharaoh_relief()
	print("--- UI Assets Generated Successfully ---")
	quit(0)

func _create_img(w: int, h: int, bg: Color = Color(0, 0, 0, 0)) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	return img

func _draw_rect(img: Image, rx: int, ry: int, rw: int, rh: int, col: Color) -> void:
	for y in range(maxi(0, ry), mini(img.get_height(), ry + rh)):
		for x in range(maxi(0, rx), mini(img.get_width(), rx + rw)):
			img.set_pixel(x, y, col)

func _draw_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var r2 := r * r
	for y in range(maxi(0, cy - r), mini(img.get_height(), cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(img.get_width(), cx + r + 1)):
			var d2 := (x - cx) * (x - cx) + (y - cy) * (y - cy)
			if d2 <= r2:
				img.set_pixel(x, y, col)

func _gen_resource_icons() -> void:
	# 1. Wood Icon (Logs)
	var wood := _create_img(32, 32)
	_draw_rect(wood, 4, 10, 24, 7, Color(0.45, 0.28, 0.14))
	_draw_rect(wood, 6, 18, 22, 7, Color(0.38, 0.22, 0.10))
	_draw_circle(wood, 6, 13, 3, Color(0.72, 0.52, 0.32))
	_draw_circle(wood, 6, 13, 1, Color(0.45, 0.28, 0.14))
	_draw_circle(wood, 8, 21, 3, Color(0.72, 0.52, 0.32))
	_draw_circle(wood, 8, 21, 1, Color(0.38, 0.22, 0.10))
	wood.save_png(OUT_DIR + "icon_wood.png")

	# 2. Food Icon (Meat on Bone)
	var food := _create_img(32, 32)
	_draw_circle(food, 14, 15, 8, Color(0.78, 0.18, 0.18))
	_draw_circle(food, 18, 14, 7, Color(0.85, 0.25, 0.25))
	_draw_rect(food, 20, 16, 8, 4, Color(0.92, 0.90, 0.85))
	_draw_circle(food, 28, 16, 2, Color(0.92, 0.90, 0.85))
	_draw_circle(food, 28, 20, 2, Color(0.92, 0.90, 0.85))
	food.save_png(OUT_DIR + "icon_food.png")

	# 3. Gold Icon (Gold Nuggets)
	var gold := _create_img(32, 32)
	_draw_circle(gold, 12, 19, 6, Color(0.85, 0.65, 0.12))
	_draw_circle(gold, 20, 18, 7, Color(0.95, 0.78, 0.15))
	_draw_circle(gold, 16, 12, 5, Color(1.0, 0.88, 0.25))
	_draw_circle(gold, 14, 11, 2, Color(1.0, 1.0, 0.65))
	gold.save_png(OUT_DIR + "icon_gold.png")

	# 4. Stone Icon (Stone Blocks)
	var stone := _create_img(32, 32)
	_draw_rect(stone, 4, 15, 12, 10, Color(0.55, 0.55, 0.58))
	_draw_rect(stone, 17, 13, 11, 12, Color(0.62, 0.62, 0.65))
	_draw_rect(stone, 10, 7, 13, 8, Color(0.70, 0.70, 0.72))
	stone.save_png(OUT_DIR + "icon_stone.png")

	# 5. Pop Icon (Bronze Helmet)
	var pop := _create_img(32, 32)
	_draw_circle(pop, 16, 14, 8, Color(0.80, 0.52, 0.22))
	_draw_rect(pop, 10, 14, 12, 8, Color(0.70, 0.45, 0.18))
	_draw_rect(pop, 15, 8, 2, 14, Color(0.95, 0.80, 0.35))
	pop.save_png(OUT_DIR + "icon_pop.png")

	# 6. Sword (Attack) & Shield (Armor)
	var sword := _create_img(24, 24)
	for i in range(12):
		sword.set_pixel(6 + i, 18 - i, Color(0.85, 0.88, 0.92))
		sword.set_pixel(7 + i, 18 - i, Color(0.70, 0.75, 0.80))
	_draw_rect(sword, 5, 17, 5, 2, Color(0.82, 0.65, 0.15))
	_draw_rect(sword, 4, 19, 3, 3, Color(0.40, 0.25, 0.12))
	sword.save_png(OUT_DIR + "icon_sword.png")

	var shield := _create_img(24, 24)
	_draw_circle(shield, 12, 12, 9, Color(0.72, 0.50, 0.22))
	_draw_circle(shield, 12, 12, 7, Color(0.58, 0.38, 0.16))
	_draw_circle(shield, 12, 12, 3, Color(0.88, 0.72, 0.32))
	shield.save_png(OUT_DIR + "icon_shield.png")

func _gen_command_icons() -> void:
	# Hammer Economic (Stone background + Wood Mallet)
	var hammer_econ := _create_img(48, 48, Color(0.18, 0.15, 0.12))
	_draw_rect(hammer_econ, 2, 2, 44, 44, Color(0.24, 0.20, 0.16))
	# Handle
	for i in range(22):
		var x := 12 + i
		var y := 36 - i
		_draw_rect(hammer_econ, x, y, 3, 3, Color(0.60, 0.40, 0.22))
	# Head
	_draw_rect(hammer_econ, 24, 8, 16, 12, Color(0.45, 0.45, 0.48))
	_draw_rect(hammer_econ, 26, 10, 12, 8, Color(0.58, 0.58, 0.62))
	hammer_econ.save_png(OUT_DIR + "icon_hammer_econ.png")

	# Hammer Military (Wood background + Iron War Hammer + Red Banner)
	var hammer_mil := _create_img(48, 48, Color(0.18, 0.15, 0.12))
	_draw_rect(hammer_mil, 2, 2, 44, 44, Color(0.26, 0.20, 0.16))
	# Yellow banner triangle on bottom
	for by in range(24, 44):
		for bx in range(24, 44):
			if bx + by > 52:
				hammer_mil.set_pixel(bx, by, Color(0.85, 0.72, 0.20))
	# Handle
	for i in range(22):
		var x := 10 + i
		var y := 36 - i
		_draw_rect(hammer_mil, x, y, 3, 3, Color(0.55, 0.35, 0.18))
	# Pick / War Hammer Head
	_draw_rect(hammer_mil, 22, 6, 18, 14, Color(0.35, 0.36, 0.40))
	_draw_rect(hammer_mil, 24, 8, 14, 10, Color(0.65, 0.68, 0.72))
	hammer_mil.save_png(OUT_DIR + "icon_hammer_mil.png")

	# Repair (Stone Hand / Wrench)
	var repair := _create_img(48, 48, Color(0.18, 0.15, 0.12))
	_draw_rect(repair, 2, 2, 44, 44, Color(0.22, 0.18, 0.14))
	_draw_circle(repair, 24, 24, 11, Color(0.72, 0.55, 0.38))
	_draw_rect(repair, 18, 24, 12, 14, Color(0.65, 0.48, 0.32))
	# Fingers
	for f in [16, 20, 24, 28]:
		_draw_rect(repair, f, 12, 3, 10, Color(0.72, 0.55, 0.38))
	repair.save_png(OUT_DIR + "icon_repair.png")

	# Cancel (Prominent Red 'X' square from Image #1)
	var cancel := _create_img(48, 48, Color(0.12, 0.10, 0.08))
	_draw_rect(cancel, 2, 2, 44, 44, Color(0.20, 0.16, 0.12))
	_draw_rect(cancel, 4, 4, 40, 40, Color(0.10, 0.08, 0.06))
	# Thick Red X
	for i in range(26):
		var x1 := 11 + i
		var y1 := 11 + i
		var x2 := 36 - i
		var y2 := 11 + i
		_draw_rect(cancel, x1 - 2, y1 - 2, 5, 5, Color(0.92, 0.08, 0.08))
		_draw_rect(cancel, x2 - 2, y2 - 2, 5, 5, Color(0.92, 0.08, 0.08))
	cancel.save_png(OUT_DIR + "icon_cancel.png")

	# Villager Portrait
	var port_v := _create_img(48, 48, Color(0.08, 0.06, 0.05))
	_draw_circle(port_v, 24, 16, 8, Color(0.76, 0.56, 0.38)) # Face
	_draw_rect(port_v, 16, 12, 16, 3, Color(0.25, 0.20, 0.15)) # Hair/Band
	_draw_rect(port_v, 14, 24, 20, 18, Color(0.68, 0.48, 0.30)) # Body
	_draw_rect(port_v, 16, 34, 16, 8, Color(0.22, 0.45, 0.75)) # Blue loincloth
	port_v.save_png(OUT_DIR + "portrait_villager.png")

func _gen_building_icons() -> void:
	var b_defs = {
		"icon_house.png": Color(0.65, 0.45, 0.25),
		"icon_barracks.png": Color(0.75, 0.25, 0.20),
		"icon_granary.png": Color(0.80, 0.60, 0.20),
		"icon_storage.png": Color(0.45, 0.45, 0.50),
		"icon_farm.png": Color(0.35, 0.65, 0.25),
		"icon_archery.png": Color(0.60, 0.50, 0.30),
		"icon_stable.png": Color(0.55, 0.35, 0.20),
		"icon_market.png": Color(0.85, 0.70, 0.25),
		"icon_temple.png": Color(0.90, 0.85, 0.75),
		"icon_siege.png": Color(0.40, 0.30, 0.20),
		"icon_tower.png": Color(0.60, 0.60, 0.65),
		"icon_wall.png": Color(0.50, 0.50, 0.55),
	}
	for b_name in b_defs:
		var img := _create_img(40, 40, Color(0.18, 0.15, 0.12))
		_draw_rect(img, 2, 2, 36, 36, Color(0.24, 0.20, 0.16))
		_draw_rect(img, 8, 14, 24, 18, b_defs[b_name])
		_draw_rect(img, 12, 8, 16, 6, Color(0.85, 0.80, 0.70))
		img.save_png(OUT_DIR + b_name)

func _gen_pharaoh_relief() -> void:
	# Sandstone Pharaoh face relief carving for center panel
	var relief := _create_img(256, 128, Color(0.78, 0.66, 0.48))
	var carve_dark := Color(0.62, 0.50, 0.34)
	var carve_light := Color(0.88, 0.78, 0.62)

	# Decorative hieroglyphic border top & bottom
	for x in range(0, 256, 16):
		_draw_rect(relief, x, 4, 12, 3, carve_dark)
		_draw_rect(relief, x + 1, 5, 10, 2, carve_light)
		_draw_rect(relief, x, 121, 12, 3, carve_dark)
		_draw_rect(relief, x + 1, 122, 10, 2, carve_light)

	# Pharaoh Profile (Center)
	var cx := 128
	var cy := 64
	# Nemes Headdress
	_draw_circle(relief, cx, cy - 8, 28, carve_dark)
	_draw_circle(relief, cx, cy - 8, 26, Color(0.76, 0.64, 0.46))
	# Headdress stripes
	for s in [-20, -12, -4, 4, 12, 20]:
		_draw_rect(relief, cx + s, cy - 30, 4, 24, carve_dark)
	# Face Profile
	_draw_circle(relief, cx - 4, cy + 4, 18, carve_light)
	_draw_circle(relief, cx - 2, cy + 4, 16, Color(0.82, 0.70, 0.52))
	# Eye of Horus outline
	_draw_rect(relief, cx - 12, cy, 8, 3, carve_dark)
	_draw_circle(relief, cx - 8, cy + 1, 2, carve_dark)
	# Beard
	_draw_rect(relief, cx - 14, cy + 18, 6, 18, carve_dark)
	_draw_rect(relief, cx - 13, cy + 19, 4, 16, carve_light)

	relief.save_png(OUT_DIR + "pharaoh_relief.png")
