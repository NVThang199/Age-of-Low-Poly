# Storage Pit, Granary & Tech Tree Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai hoàn chỉnh hai loại nhà kho chuyên biệt chuẩn Age of Empires 1 (Granary - BS và Storage Pit - BM) thay thế cho trạm mỏ tạm thời, tích hợp trọn vẹn cây công nghệ nghiên cứu nâng cấp chỉ số lính và mở khóa công trình, cùng hệ thống chống kẹt dân làng khi nộp tài nguyên theo kiến trúc Host-Authoritative Multiplayer.

**Architecture:** 
1. **TechManager (Autoload):** Trung tâm quản lý catalog công nghệ, theo dõi tiến độ nghiên cứu theo `peer_id`, tính toán cache stat modifiers và phát signal đồng bộ RPC Host-Authoritative.
2. **Dual-Queue BaseBuilding:** Hàng đợi thống nhất hỗ trợ cả huấn luyện đơn vị và nghiên cứu công nghệ có đồng bộ mạng an toàn (kiểm tra tài nguyên và điều kiện từ Server).
3. **Smart Villager Drop-off:** Tách biệt luồng nộp tài nguyên (Granary nhận Food; Storage Pit nhận Wood, Gold, Stone; Town Center nhận tất cả) kết hợp thuật toán slotting chu vi 8 hướng và touch-deposit chống kẹt dồn ứ.
4. **Blender MCP Low-Poly Assets:** Tạo 3D models `.glb` cho Granary và Storage Pit với visual chuẩn AoE1.

**Tech Stack:** Godot 4.3+ GDScript, Blender MCP (Python bpy script), Jolt Physics 3D, SteamMultiplayerPeer / ENet RPC.

**Spec:** Chuẩn gameplay Age of Empires 1 (Rise of Rome).

---

## Global Constraints

- **Zero Hardcoding**: Tuyệt đối không hardcode transform/rotation của model/tool. Mọi node con phải được thêm vào scene tree (`add_child`) trước khi gán `global_position` hoặc truy cập `global_transform`.
- **Server Authority**: Chỉ Server (`multiplayer.is_server()`) trừ tài nguyên, đưa vào queue nghiên cứu, đếm timer và hoàn tất công nghệ. Client chỉ gửi request và hiển thị dự đoán local/nhận kết quả sync.
- **RPC Safety**: Bắt buộc dùng `rpc_id(target_id, ...)` đích danh, không dùng `.rpc(...)` broadcast toàn mạng để tránh crash `Node not found`. Mọi hàm RPC phải có 4 lớp bảo vệ (scene tree, connection status, local_id > 0, node validity).
- **Safe Node Cleanup**: Luôn gọi `remove_child(node)` trước `queue_free()` và giải phóng `material_override = null` trước khi xóa mesh để bảo vệ engine Vulkan/D3D12.
- **UI Non-Piercing**: Mọi script bắt input 3D phải dùng `_unhandled_input` và kiểm tra `get_viewport().gui_get_hovered_control() == null`.

## Review Focus

1. **Villager Resource Mismatch**: Dân đang cầm Gỗ nhưng click phải vào Granary -> Không được nuốt mất gỗ hoặc nộp sai kho, chuyển thành lệnh di chuyển tới kho.
2. **Multi-Villager Jam at Dropoff**: 5-10 dân cùng lúc mang tài nguyên về 1 nhà kho -> Thuật toán slotting góc và touch collision phải đảm bảo dân nộp được ngay khi chạm rìa, không bị kẹt separation vô tận.
3. **Late-joiner Tech Desync**: Client vào sau hoặc tải scene chậm -> Handshake sync (`get_sync_state` / `apply_sync_state`) phải gửi trọn vẹn danh sách công nghệ đã nghiên cứu để lính client hiển thị đúng chỉ số.
4. **Concurrent Research Exploit**: Client spam click nút nghiên cứu khi mạng lag -> Server kiểm tra `can_research` (chưa nghiên cứu và chưa có trong queue), từ chối và không trừ tài nguyên lần 2.
5. **Ghost Preview for Locked Tech**: Nhà Wall hoặc Watch Tower chưa nghiên cứu -> Nút trên UI mờ/khóa, `BuildingPlacer` chặn không cho kích hoạt ghost placement.

---

### Task 1: Tech Catalog & TechManager Autoload

**Files:**
- Create: `scripts/autoload/tech_manager.gd`
- Modify: `project.godot:17-25`
- Test: `tests/test_tech_manager.gd` (script kiểm tra độc lập các method tính modifier)

**Interfaces:**
- Consumes: `GameManager.spend_resource(peer_id, type, amount)`, `NetworkManager.synced_peers`
- Produces: 
  - `TechManager.is_tech_researched(peer_id: int, tech_id: String) -> bool`
  - `TechManager.is_building_unlocked(peer_id: int, b_type: String) -> bool`
  - `TechManager.get_unit_modifiers(peer_id: int, u_type: int) -> Dictionary`
  - `TechManager.can_research(peer_id: int, tech_id: String) -> bool`
  - Signal: `tech_completed(peer_id: int, tech_id: String)`
  - Signal: `building_unlocked(peer_id: int, building_type: String)`

- [ ] **Step 1: Viết test runner độc lập cho logic TechManager**
  Tạo `tests/test_tech_manager.gd` kế thừa `Node` với các assertion kiểm tra:
  - Khởi tạo ban đầu: chưa có tech nào, modifier = 0.
  - Sau khi `server_complete_tech(1, "toolworking")`: modifier `melee_attack` của Infantry tăng +2.
  - Sau khi `server_complete_tech(1, "small_wall")`: `is_building_unlocked(1, "small_wall")` trả về `true`.

- [ ] **Step 2: Tạo `scripts/autoload/tech_manager.gd`**
  Định nghĩa `TECH_DATABASE` hằng số gồm:
  - `"toolworking"` (Storage Pit): 100 Food, 30s, +2 melee attack (Infantry, Villager).
  - `"leather_armor_infantry"` (Storage Pit): 75 Food, 25s, +2 melee armor (Infantry).
  - `"bronze_shield"` (Storage Pit): 150 Food, 30s, +1 pierce armor (Infantry, Villager).
  - `"small_wall"` (Granary): 50 Food, 20s, mở khóa `"small_wall"`.
  - `"watch_tower"` (Granary): 50 Food, 100 Wood, 30s, mở khóa `"watch_tower"`.
  Cung cấp hàm cache modifiers theo `peer_id` và hàm RPC Host-Authoritative:
  `@rpc("authority", "call_local", "reliable") func sync_tech_completed(peer_id: int, tech_id: String)`.

- [ ] **Step 3: Đăng ký `TechManager` vào `project.godot`**
  Thêm `TechManager="*res://scripts/autoload/tech_manager.gd"` vào section `[autoload]` của `project.godot`.

- [ ] **Step 4: Chạy test xác nhận logic hoạt động đúng**
  Chạy Godot command line kiểm tra `test_tech_manager.gd`, đảm bảo tất cả assertions passed.

- [ ] **Step 5: Commit**
  ```bash
  git add scripts/autoload/tech_manager.gd project.godot tests/test_tech_manager.gd
  git commit -m "feat(tech): add TechManager autoload with AoE1 tech catalog and modifier cache"
  ```

---

### Task 2: BaseUnit Stat Modifiers & Dynamic Upgrades

**Files:**
- Modify: `scripts/entities/base_unit.gd:35-42, 60-80`
- Modify: `scripts/entities/swordsman.gd:10-25`
- Modify: `scripts/entities/villager.gd:18-25`
- Modify: `scripts/entities/archer.gd:10-25`

**Interfaces:**
- Consumes: `TechManager.get_unit_modifiers(peer_id, unit_type)`, `TechManager.tech_completed`
- Produces: `BaseUnit.apply_tech_modifiers() -> void`

- [ ] **Step 1: Thêm Base Stats vào `BaseUnit`**
  Trong `scripts/entities/base_unit.gd`:
  - Khai báo các biến lưu chỉ số gốc:
    `var base_melee_attack: int = 5`, `var base_melee_armor: int = 0`, `var base_pierce_armor: int = 1`.
  - Viết hàm `apply_tech_modifiers()`:
    Lấy modifier từ `TechManager.get_unit_modifiers(owner_peer_id, unit_type)` và gán lại `melee_attack = base_melee_attack + mod_atk`, `melee_armor = base_melee_armor + mod_arm`, `pierce_armor = base_pierce_armor + mod_p_arm`.

- [ ] **Step 2: Kết nối signal nâng cấp động trong `_ready()` của `BaseUnit`**
  - Trong `_ready()`: gán base stats bằng giá trị export ban đầu, gọi `apply_tech_modifiers()`.
  - Kết nối `TechManager.tech_completed`:
    ```gdscript
    if TechManager:
        TechManager.tech_completed.connect(func(peer_id: int, _tech_id: String):
            if peer_id == owner_peer_id:
                apply_tech_modifiers()
        )
    ```

- [ ] **Step 3: Cập nhật các class con kế thừa**
  Trong `swordsman.gd`, `villager.gd`, `archer.gd`: đảm bảo các biến `base_...` được đồng bộ trong `_init()` hoặc `_ready()` để không bị override sai giá trị gốc khi nâng cấp nhiều lần.

- [ ] **Step 4: Chạy kiểm tra thủ công hoặc unit test**
  Tạo unit Swordsman, giả lập gọi `TechManager.server_complete_tech(1, "toolworking")`, xác nhận `melee_attack` của Swordsman tăng từ 8 lên 10 ngay lập tức.

- [ ] **Step 5: Commit**
  ```bash
  git add scripts/entities/base_unit.gd scripts/entities/swordsman.gd scripts/entities/villager.gd scripts/entities/archer.gd
  git commit -m "feat(units): apply dynamic tech modifiers to base and active units"
  ```

---

### Task 3: BaseBuilding Dual-Queue & Host-Authoritative RPC

**Files:**
- Modify: `scripts/entities/base_building.gd:7-25, 173-210`

**Interfaces:**
- Consumes: `GameManager.spend_resource`, `TechManager.can_research`, `TechManager.server_complete_tech`
- Produces: 
  - `BaseBuilding.queue_tech(tech_id: String, research_time: float) -> bool`
  - `@rpc("any_peer") func request_research(tech_id: String) -> void`
  - `@rpc("authority") func sync_production_queue(queue_data: Array) -> void`
  - `BuildingType.GRANARY = 4`, `BuildingType.STORAGE_PIT = 3` (thay thế `MINING_CAMP`)

- [ ] **Step 1: Cập nhật `BuildingType` enum trong `BaseBuilding`**
  Đổi:
  ```gdscript
  enum BuildingType {
      TOWN_CENTER = 0,
      HOUSE = 1,
      BARRACKS = 2,
      STORAGE_PIT = 3, # Thay cho MINING_CAMP
      GRANARY = 4,
      WATCH_TOWER = 5,
      SMALL_WALL = 6,
  }
  ```

- [ ] **Step 2: Hợp nhất cấu trúc `production_queue`**
  Chuẩn hóa phần tử trong hàng đợi:
  - Unit: `{"type": "unit", "scene": scene_path, "time": duration}`
  - Tech: `{"type": "tech", "tech_id": tech_id, "time": duration}`

- [ ] **Step 3: Triển khai RPC `request_research` & Server Validation**
  ```gdscript
  @rpc("any_peer", "call_local", "reliable")
  func request_research(tech_id: String) -> void:
      if not multiplayer.is_server():
          return
      var sender_id := multiplayer.get_remote_sender_id()
      if sender_id == 0: sender_id = 1
      if sender_id != owner_peer_id or not is_constructed:
          return
      # Kiểm tra hợp lệ tech với loại nhà và chi phí
      if not TechManager.can_research(owner_peer_id, tech_id):
          return
      # Kiểm tra tech có đang nằm trong queue chưa
      for item in production_queue:
          if item.get("type") == "tech" and item.get("tech_id") == tech_id:
              return
      var t_data: Dictionary = TechManager.TECH_DATABASE[tech_id]
      var costs: Dictionary = t_data.get("cost", {})
      var game_mgr = get_node_or_null("/root/GameManager")
      for res_type in costs:
          if game_mgr.get_resource(owner_peer_id, res_type) < costs[res_type]:
              return
      for res_type in costs:
          game_mgr.spend_resource(owner_peer_id, res_type, costs[res_type])
      
      production_queue.append({
          "type": "tech",
          "tech_id": tech_id,
          "time": t_data.get("research_time", 30.0)
      })
      _sync_queue_to_clients()
  ```

- [ ] **Step 4: Cập nhật `_process_production` xử lý Tech**
  Khi `production_timer >= current_item["time"]`:
  - Nếu `current_item["type"] == "tech"`:
    Gọi `TechManager.server_complete_tech(owner_peer_id, current_item["tech_id"])`.
  - Nếu `current_item["type"] == "unit"`:
    Gọi `_spawn_unit(current_item["scene"])`.
  Pop item khỏi queue và đồng bộ trạng thái mới qua RPC.

- [ ] **Step 5: Commit**
  ```bash
  git add scripts/entities/base_building.gd
  git commit -m "feat(building): implement unified production/tech research queue with RPC validation"
  ```

---

### Task 4: 3D Models & Scenes cho Granary và Storage Pit

**Files:**
- Create: `assets/models/granary.glb` (dùng Blender MCP Python script)
- Create: `assets/models/storage_pit.glb` (dùng Blender MCP Python script)
- Create: `scenes/entities/granary.tscn`
- Create: `scenes/entities/storage_pit.tscn`
- Delete / Obsolete: `scenes/entities/mine.tscn`

**Interfaces:**
- Consumes: Blender MCP (`execute_blender_code`), `BaseBuilding`
- Produces: `scenes/entities/granary.tscn`, `scenes/entities/storage_pit.tscn`

- [ ] **Step 1: Tạo model low-poly `granary.glb` bằng Blender MCP**
  Chạy script Python trong Blender MCP dựng kho thóc:
  - Bệ sàn gỗ nâng cao có 4 chân cọc.
  - Nhà chính mái rơm chóp nón.
  - 1 silo tròn đựng thóc bằng nan gỗ bên cạnh kèm vài bao tải ngũ cốc.
  - Palette màu: Gỗ mộc nâu, rơm vàng ấm, bao tải trắng ngà.
  - Export GLTF/GLB vào `assets/models/granary.glb`.

- [ ] **Step 2: Tạo model low-poly `storage_pit.glb` bằng Blender MCP**
  Chạy script Python trong Blender MCP dựng trạm công binh/hố chứa:
  - Hầm đất có mái che nghiêng 1 phía đỡ bằng cọc gỗ.
  - Đống súc gỗ xẻ tròn xếp chéo cạnh bên.
  - Đống đá tảng ghồ ghề và quặng vàng lấp lánh.
  - Đe đá và giá treo cuốc xẻng/vũ khí.
  - Export GLTF/GLB vào `assets/models/storage_pit.glb`.

- [ ] **Step 3: Tạo `scenes/entities/granary.tscn`**
  - Node gốc `StaticBody3D` gán script `res://scripts/entities/base_building.gd`.
  - `building_type = 4` (GRANARY), `max_hp = 500`.
  - `CollisionShape3D` kích thước `(3.4, 2.4, 3.4)`.
  - Instance `assets/models/granary.glb`.

- [ ] **Step 4: Tạo `scenes/entities/storage_pit.tscn`**
  - Node gốc `StaticBody3D` gán script `res://scripts/entities/base_building.gd`.
  - `building_type = 3` (STORAGE_PIT), `max_hp = 500`.
  - `CollisionShape3D` kích thước `(3.6, 2.2, 3.6)`.
  - Instance `assets/models/storage_pit.glb`.

- [ ] **Step 5: Commit**
  ```bash
  git add assets/models/granary.glb assets/models/storage_pit.glb scenes/entities/granary.tscn scenes/entities/storage_pit.tscn
  git commit -m "feat(assets): create low-poly models and scenes for Granary and Storage Pit"
  ```

---

### Task 5: BuildingPlacer Update & Tech Unlock Integration

**Files:**
- Modify: `scripts/systems/building_placer.gd:10-25, 75-125`

**Interfaces:**
- Consumes: `TechManager.is_building_unlocked`, `BUILDING_COSTS`, `BUILDING_SCENES`
- Produces: Khả năng đặt bóng (ghost) cho `granary`, `storage_pit`, và chặn công trình khi chưa nghiên cứu.

- [ ] **Step 1: Cập nhật hằng số công trình trong `BuildingPlacer`**
  - Thay thế `"mine"` bằng `"granary"` (120 Wood) và `"storage_pit"` (120 Wood).
  - Trỏ scene:
    `"granary": "res://scenes/entities/granary.tscn"`,
    `"storage_pit": "res://scenes/entities/storage_pit.tscn"`.

- [ ] **Step 2: Thêm kiểm tra điều kiện mở khóa công nghệ**
  Trong `_on_build_requested(building_type)`:
  - Nếu `building_type` là công trình yêu cầu công nghệ (như `"small_wall"`, `"watch_tower"`):
    Kiểm tra `TechManager.is_building_unlocked(my_id, building_type)`. Nếu `false` -> từ chối và in thông báo chưa nghiên cứu.

- [ ] **Step 3: Kiểm tra kích thước bounding box ghost của Granary và Storage Pit**
  Cập nhật hàm `_apply_ghost_material` và tính toán va chạm để kích thước ghost khớp với `CollisionShape3D` của 2 nhà kho mới.

- [ ] **Step 4: Chạy test đặt công trình thủ công trong scene Main**
  Kiểm tra bấm đặt Granary và Storage Pit: ghost hiển thị đúng model, chuyển màu xanh khi vị trí hợp lệ, trừ đúng 120 Gỗ khi đặt.

- [ ] **Step 5: Commit**
  ```bash
  git add scripts/systems/building_placer.gd
  git commit -m "feat(placer): support granary and storage pit placement with tech unlock check"
  ```

---

### Task 6: Villager Drop-off Routing & Anti-Stuck Improvements

**Files:**
- Modify: `scripts/entities/base_building.gd:220-255`
- Modify: `scripts/entities/villager.gd:110-125, 180-260`
- Modify: `scripts/systems/command_manager.gd:70-85, 245-255`

**Interfaces:**
- Consumes: `BaseBuilding.accepts_resource(res_type, is_meat)`, `ResourceSource.ResourceType`
- Produces:
  - `BaseBuilding.accepts_resource(type, is_meat) -> bool`
  - Khả năng nộp tài nguyên thủ công bất kỳ lúc nào (`carried_amount > 0`).
  - Thuật toán tiếp cận 8 slot quanh chu vi kho + Touch-deposit chống kẹt.

- [ ] **Step 1: Viết hàm `accepts_resource` trong `BaseBuilding`**
  ```gdscript
  func accepts_resource(res_type: int, is_meat: bool = false) -> bool:
      if not is_constructed:
          return false
      match building_type:
          BuildingType.TOWN_CENTER:
              return true
          BuildingType.GRANARY:
              return res_type == ResourceSource.ResourceType.FOOD and not is_meat
          BuildingType.STORAGE_PIT:
              if res_type in [ResourceSource.ResourceType.WOOD, ResourceSource.ResourceType.GOLD, ResourceSource.ResourceType.STONE]:
                  return true
              return res_type == ResourceSource.ResourceType.FOOD and is_meat
      return false
  ```
  Và đảm bảo `GRANARY` và `STORAGE_PIT` tự thêm vào nhóm `"dropoffs"` khi hoàn thành xây dựng.

- [ ] **Step 2: Cập nhật hàm tìm kho gần nhất `_find_nearest_dropoff()` trong `Villager`**
  - Duyệt toàn bộ node trong nhóm `"dropoffs"`.
  - Kiểm tra chủ sở hữu: `building.owner_peer_id == owner_peer_id` (sửa lỗi Host nhầm phe).
  - Kiểm tra `building.accepts_resource(carried_type, carried_is_meat)`.
  - Chọn kho có khoảng cách ngắn nhất.

- [ ] **Step 3: Triển khai Slotting chu vi & Touch-Deposit chống kẹt**
  Trong `_return_to_dropoff(delta)`:
  - Tính điểm đến theo góc slot riêng của từng dân:
    `var base_angle := float(get_instance_id() % 8) * (PI / 4.0)`
    `target_position = target_dropoff.global_position + Vector3(cos(base_angle), 0.0, sin(base_angle)) * stop_dist`
  - Bổ sung kiểm tra va chạm vật lý: nếu trong lúc di chuyển có va chạm (`get_slide_collision`) với `target_dropoff` hoặc khoảng cách tới rìa < 1.2m khi `stuck_timer > 0.08` -> Hoàn tất nộp ngay lập tức (`deposit_resource`), không bắt buộc đứng khựng đúng tâm.
  - Nộp xong: set vận tốc lùi nhẹ ra ngoài trong 0.15s để tránh chắn đường dân phía sau, rồi quay lại mỏ khai thác tiếp.

- [ ] **Step 4: Cải tiến lệnh click chuột phải nộp tài nguyên thủ công**
  Trong `Villager.return_resources_to(dropoff)`:
  - Nếu `carried_amount > 0` và kho chấp nhận loại hàng: ngay lập tức set `is_delivering = true`, chuyển hướng chạy về kho nộp (dù chưa đầy 10 tải).
  - Nếu `carried_amount == 0` hoặc kho không nhận loại hàng: chuyển thành lệnh di chuyển thường tới vị trí kho.

- [ ] **Step 5: Commit**
  ```bash
  git add scripts/entities/base_building.gd scripts/entities/villager.gd scripts/systems/command_manager.gd
  git commit -m "fix(villager): improve drop-off routing with resource filtering, perimeter slots and touch deposit"
  ```

---

### Task 7: HUD ActionPanel, Tech Grid & BuildMenu UI

**Files:**
- Modify: `scenes/ui/hud.tscn`
- Modify: `scripts/ui/hud.gd:10-65, 105-180`

**Interfaces:**
- Consumes: `TechManager.TECH_DATABASE`, `TechManager.can_research`, `TechManager.is_tech_researched`
- Produces: Giao diện chọn nhà kho trên BuildMenu và giao diện nghiên cứu công nghệ trong ActionPanel.

- [ ] **Step 1: Cập nhật cụm nút `BuildMenu` trong `hud.tscn`**
  - Thay thế `BuildMineBtn` bằng 2 nút:
    - `BuildGranaryBtn`: text "Granary (120W) [BS]"
    - `BuildStoragePitBtn`: text "Storage Pit (120W) [BM]"

- [ ] **Step 2: Nâng cấp `ActionPanel` trong `hud.tscn`**
  - Thêm `GridContainer` đặt tên `TechGrid` (2 cột) chứa các nút công nghệ được sinh động hoặc cố định.
  - Thêm `ProgressBar` đặt tên `ProductionProgressBar` hiển thị tiến độ % sản xuất/nghiên cứu mượt mà.

- [ ] **Step 3: Cập nhật logic hiển thị trong `hud.gd`**
  Khi `current_selected_building` thay đổi:
  - Nếu là `GRANARY`: hiển thị các công nghệ của Granary (`small_wall`, `watch_tower`).
  - Nếu là `STORAGE_PIT`: hiển thị các công nghệ của Storage Pit (`toolworking`, `leather_armor_infantry`, `bronze_shield`).
  - Cập nhật trạng thái nút:
    - `disabled = true` nếu đang nghiên cứu hoặc đã nghiên cứu xong hoặc không đủ tài nguyên.
    - Hover hiển thị Tooltip: Tên, Chi phí (Food/Wood), Thời gian và Tác dụng.
  - Trong `_process`: đồng bộ `ProductionProgressBar.value` theo tỷ lệ `production_timer / current_item["time"]`.

- [ ] **Step 4: Chạy test UI trong game**
  Bấm chọn dân xây Granary và Storage Pit -> Click chọn từng nhà -> Bấm nghiên cứu công nghệ -> Thanh progress bar chạy -> Sau khi xong, nút bị vô hiệu hóa kèm nhãn "(Researched)".

- [ ] **Step 5: Commit**
  ```bash
  git add scenes/ui/hud.tscn scripts/ui/hud.gd
  git commit -m "feat(ui): update HUD with Granary/Storage Pit buttons and interactive Tech ActionPanel"
  ```

---

### Task 8: End-to-End Integration & Multi-Peer Verification

**Files:**
- Modify: `scripts/systems/enemy_ai.gd` (cập nhật nếu AI có tham chiếu `MINING_CAMP`)
- Test / Verify: Chạy trận thử nghiệm trong `scenes/core/main.tscn` và kiểm tra multiplayer handshake sync.

**Interfaces:**
- Consumes: Toàn bộ hệ thống từ Task 1 đến Task 7
- Produces: Trận đấu hoạt động ổn định, gameplay khai thác và nâng cấp tương đồng 90% game gốc AoE 1.

- [ ] **Step 1: Quét và dọn dẹp các tham chiếu cũ của `MINING_CAMP` / `mine.tscn`**
  Kiểm tra toàn bộ project qua grep, thay thế triệt để các vị trí còn sót `MINING_CAMP` sang `STORAGE_PIT` hoặc `GRANARY`.

- [ ] **Step 2: Kiểm tra kịch bản khai thác tài nguyên tổng thể**
  - Cho dân chặt gỗ: đầy 10 tải tự chạy về Storage Pit (hoặc Town Center nếu gần hơn).
  - Cho dân đào vàng / đá: nộp vào Storage Pit.
  - Cho dân hái quả: nộp vào Granary.
  - Kiểm tra 5 dân cùng nộp vào 1 kho: không có dân nào bị đứng kẹt vô tận.

- [ ] **Step 3: Kiểm tra kịch bản nghiên cứu công nghệ**
  - Bấm nghiên cứu `Toolworking` tại Storage Pit.
  - Kiểm tra tài nguyên Food bị trừ đúng 100.
  - Chờ 30s hoàn tất: kiểm tra lính Swordsman và Dân làng nhận thêm +2 công cận chiến. HUD cập nhật ATK từ 8 lên 10.
  - Tạo thêm lính Swordsman mới sinh ra từ Barracks: tự động có sẵn 10 công cận chiến.

- [ ] **Step 4: Kiểm tra đồng bộ Multiplayer Host & Client**
  - Host nghiên cứu công nghệ -> Client không bị ảnh hưởng chỉ số của quân mình nhưng thấy đúng chỉ số quân địch (nếu soi).
  - Client nghiên cứu công nghệ -> Host xác thực thành công, Client được buff chỉ số.

- [ ] **Step 5: Commit & Final Tag**
  ```bash
  git add -A
  git commit -m "chore(integration): complete storage and tech tree integration with full AoE1 loop"
  ```
