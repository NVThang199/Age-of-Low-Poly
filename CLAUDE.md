# AOE Project Rules & Guidelines

## 1. Nguyên Tắc Thiết Kế: Ưu Tiên Tùy Biến Thủ Công (Zero Hardcoding)
- **Transform & Placement**: Tuyệt đối KHÔNG hardcode vị trí (`position`), góc xoay (`rotation`, `rotation_degrees`), tỷ lệ (`scale`) của tool, vũ khí, hiệu ứng trực tiếp trong mã nguồn GDScript.
- **Socket / Node3D**: Luôn cung cấp điểm neo Socket (`Node3D` / `Marker3D` con của `BoneAttachment3D` hoặc node cha) hoặc biến `@export var ..._offset: Vector3` và `@export var ..._rotation: Vector3` trên Inspector để người dùng có thể dùng Gizmo 3D tự do căn chỉnh trong Godot Editor.
- **Thứ tự thêm vào Scene Tree**: Luôn gọi `parent.add_child(node)` TRƯỚC KHI gán `node.global_position = pos` hoặc truy cập `global_transform` để tránh lỗi C++ engine: `Condition "!is_inside_tree()" is true`.
- **Xử lý Input Viewport & UI**: Các script bắt click chuột 3D (BuildingPlacer, SelectionSystem, CommandManager) PHẢI dùng `_unhandled_input(event)` và kiểm tra `get_viewport().gui_get_hovered_control() == null` để tránh đục xuyên qua các nút bấm 2D UI (Cancel, Build, Minimap).

---

## 2. Chuẩn Mực Kiến Trúc Multiplayer (Kế Thừa Từ PanicParty)

### A. Quyền Hạn Server & Hướng RPC (Server Authority)
- **Server Authority**: Chỉ Server (`multiplayer.is_server()`) tính toán logic game cốt lõi: trừ tài nguyên, đặt móng nhà, tính sát thương, tạo unit, trừ máu mỏ/cây. Client chỉ gửi request và interpolate state.
- **RPC Direction**:
  - `@rpc("authority", ...)`: Server → Client (đồng bộ kết quả, sự kiện trận đấu).
  - `@rpc("any_peer", ...)`: Client → Server (yêu cầu di chuyển, yêu cầu đặt nhà, yêu cầu huấn luyện lính).
  - Gọi hàm trực tiếp `method(...)` chỉ chạy local, **KHÔNG** gửi qua mạng dù có khai báo `@rpc`.

### B. Chính Sách Target RPC: Chống Lỗi `Node not found`
- **TUYỆT ĐỐI KHÔNG DÙNG `.rpc(...)` broadcast toàn mạng**: Trong mạng p2p/Steam/ENet, broadcast toàn mạng sẽ gửi gói tin tới cả các peer đang load scene, đang ở menu lobby, làm sập C++ engine: `Node not found` và `Failed to get path from RPC`.
- **BẮT BUỘC DÙNG `rpc_id(target_id, ...)` ĐÍCH DANH**:
  - Duyệt danh sách peer hợp lệ trong trận: `for pid in active_peers: if pid != 1: method.rpc_id(pid, ...)`.
  - Khởi tạo trận bằng Handshake: Client load xong màn chơi chủ động gửi `request_game_sync.rpc_id(1)`. Server ghi nhận client vào `synced_peers` rồi mới gửi danh sách nhà, tài nguyên, lính đã có (Late-join & Slow-load safe).

### C. Quy Tắc An Toàn Khi Nhận RPC (Safe State Sync)
Trong mọi hàm nhận RPC state/vị trí đơn vị qua mạng, **BẮT BUỘC** kiểm tra 4 lớp bảo vệ trước khi xử lý:
```gdscript
@rpc("any_peer", "unreliable")
func sync_unit_state(unit_id: int, pos: Vector3, rot_y: float, anim: String) -> void:
    # 1. Bảo vệ scene tree
    if not is_inside_tree():
        return
    # 2. Bảo vệ kết nối multiplayer
    if not multiplayer or not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
        return
    # 3. Lấy local_id an toàn
    var local_id := multiplayer.get_unique_id()
    if local_id == 0:
        return
    # 4. Kiểm tra node mục tiêu hợp lệ
    var unit = units.get(unit_id)
    if unit and is_instance_valid(unit) and unit.is_inside_tree():
        unit.apply_network_state(pos, rot_y, anim)
```

### D. Quy Trình Chuyển Scene 2 Giai Đoạn (Two-Phase Scene Transition)
- **Giai đoạn 1 (Freeze traffic)**: Server gửi RPC đóng băng cho các client. Toàn bộ client tắt `set_process(false)`, `set_physics_process(false)`, ngừng gửi input và state.
- **Xả mạng (Drain)**: Server chờ `await get_tree().create_timer(0.1).timeout` để xả hết các gói tin in-flight trên đường truyền.
- **Giai đoạn 2 (Switch scene)**: Server phát lệnh chuyển cảnh rồi đổi scene. Server luôn tải scene mới trước hoặc cùng lúc với Client để sẵn sàng đón nhận `request_game_sync`.

### E. Dọn Dẹp Node & Bộ Nhớ An Toàn
- **Xóa Node đồng bộ mạng**: Luôn gọi `remove_child(node)` trước `node.queue_free()` khi thay thế hoặc despawn thực thể để tránh Godot đổi tên node thành `@Node3D@...` gây lệch NodePath giữa các máy.
- **Dọn dẹp Material Vulkan**: Gỡ bỏ hoặc set `null` các `material_override` / `surface_override_material` trước khi giải phóng node mesh để tránh crash C++ engine Vulkan (`material_casts_shadows: Parameter "material" is null`).
- **Tránh await animation trần trụi**: Tuyệt đối không dùng `await anim_player.animation_finished` trần trụi vì nếu animation bị ngắt bởi đòn đánh khác, signal sẽ không phát và làm treo logic/state vĩnh viễn. Luôn có fallback timeout timer.

---

## 3. Ràng Buộc Gameplay Hiện Tại
- **Âm thanh**: Toàn bộ Procedural Sound Effects tạm thời tắt hoàn toàn (người dùng sẽ tự import sau).
- **Quái vật / Spawner**: Tạm thời tắt toàn bộ monster/spawner.

## 4. Quy Ước Thư Mục Dự Án
- `assets/`: Model 3D (`.glb`, `.fbx`), texture, animation.
- `scenes/`: Cảnh game (`core/`, `entities/`, `ui/`).
- `scripts/`: Logic GDScript (`core/`, `entities/`, `systems/`, `ui/`).
