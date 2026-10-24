# Age of Empires (AOE) - 3D RTS in Godot 4

Một dự án game Chiến thuật Thời gian thực (RTS) 3D nhiều người chơi, lấy cảm hứng từ dòng game huyền thoại Age of Empires, được xây dựng trên nền tảng **Godot Engine 4.7** kết hợp vật lý **Jolt Physics** và hệ thống mạng **Steam / ENet**.

---

## 🌟 Tính Năng Nổi Bật (Key Features)

- **Lối chơi RTS Cổ Điển**:
  - **Khai thác tài nguyên**: Dân làng (Villager) tự động chặt cây (Wood), đào mỏ (Gold/Stone), hái lượm (Food) và mang về nhà chính (Town Center) hoặc trạm khai khoáng (Mining Camp).
  - **Hệ thống xây dựng**: Đặt móng công trình với preview trực quan (Ghost Preview), dân làng cùng nhau xây dựng công trình, hỗ trợ đa dân làng cùng xây.
  - **Huấn luyện quân đội**: Nhà chính sinh dân, Trại lính (Barracks) sản xuất Kiếm sĩ (Swordsman), Cung thủ (Archer).
  - **Chiến đấu & AI**: Cơ chế tấn công, phòng thủ, bắn tên có quỹ đạo đạn thực, chỉ số giáp chém/giáp tiễn theo chuẩn RTS.

- **Multiplayer Server-Authoritative**:
  - Hỗ trợ kết nối qua **Steam P2P (SteamMultiplayerPeer / AppID 480)** và chế độ mạng cục bộ **ENet (Port 7777)**.
  - Kiến trúc **Targeted RPC (`rpc_id`)** và quy trình **Handshake Scene Sync** chống rớt gói tin và triệt tiêu lỗi `Node not found`.
  - Đồng bộ lệnh điều khiển (Move, Gather, Build, Attack, Deposit) có đóng dấu tick mạng.
  - Cập nhật vị trí, hướng quay và animation của đơn vị theo thời gian thực.

- **Thiết Kế Linh Hoạt (Editor-Friendly & Zero Hardcoding)**:
  - Hệ thống Socket 3D (`RightHandSocket`, `LeftHandSocket`) gắn trực tiếp trên xương mô hình (`hand_r`, `hand_l`).
  - Dễ dàng căn chỉnh vị trí, góc cầm vũ khí và công cụ (Rìu, Cuốc, Dao, Búa, Kiếm, Cung, Khiên) trực quan bằng Gizmo 3D ngay trong Godot Editor.

- **Điều Khiển & Giao Diện**:
  - Camera RTS tự do (pan, zoom, xoay góc).
  - Chọn đơn vị đơn lẻ hoặc quét hộp chữ nhật (Box Selection).
  - Đội hình di chuyển thông minh (Formation Movement) khi điều khiển số lượng lớn quân.
  - Minimap thời gian thực, thanh máu và trạng thái công trình/quân đội.

---

## 🛠️ Công Nghệ Sử Dụng (Tech Stack)

- **Game Engine**: Godot Engine 4.7 (Forward+ / D3D12)
- **Vật lý**: Jolt Physics 3D
- **Ngôn ngữ**: GDScript
- **Mạng (Networking)**: GodotSteam (Steamworks API) & ENetMultiplayerPeer
- **Mô hình 3D & Animation**: UAL Standard Skeletons, FBX/GLTF Assets

---

## 📁 Cấu Trúc Dự Án (Project Structure)

```text
├── assets/                  # Tài nguyên đồ họa, âm thanh, 3D models
│   ├── animations/          # Rig & Animation chuẩn (UAL1, UAL2)
│   ├── buildings/           # Model công trình (Town Center, Barracks, House...)
│   ├── characters/          # Texture & phụ kiện nhân vật
│   ├── environment/         # Cây cối, mỏ đá, mỏ vàng
│   ├── tools/               # Công cụ (Axe, Pickaxe, Hammer, Knife)
│   └── weapons/             # Vũ khí (Sword, Shield, Bow)
├── scenes/                  # Cảnh game (.tscn)
│   ├── core/                # Scene chính (main.tscn)
│   ├── entities/            # Prefab đơn vị, công trình, đạn
│   └── ui/                  # Giao diện Lobby, HUD, Menu
├── scripts/                 # Mã nguồn GDScript
│   ├── autoload/            # Singletons (GameManager, NetworkManager, SteamManager...)
│   ├── camera/              # Điều khiển RTS Camera 3D
│   ├── entities/            # Logic Villager, Swordsman, Archer, BaseBuilding
│   ├── systems/             # BuildingPlacer, SelectionSystem, CommandManager
│   └── ui/                  # Logic HUD, LobbyUI, Minimap
├── CLAUDE.md                # Quy tắc thiết kế và tiêu chuẩn kiến trúc
└── AGENTS.md                # Hướng dẫn phát triển và quy ước multiplayer
```

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Game (Getting Started)

### Yêu Cầu Hệ Thống:
- Godot Engine 4.7 trở lên (bản hỗ trợ .NET hoặc standard).
- Steam Client đang mở (nếu muốn test tính năng Steam Lobby).

### Các Bước Thực Hiện:
1. **Clone repository**:
   ```bash
   git clone https://github.com/<your-username>/<repo-name>.git
   cd <repo-name>
   ```
2. **Mở dự án trong Godot**:
   - Mở Godot Engine -> Bấm **Import** -> Chọn đường dẫn tới thư mục dự án (`project.godot`).
3. **Chạy game**:
   - Nhấn **F5** để khởi động từ sảnh chờ (`res://scenes/ui/lobby.tscn`).
   - Chọn **Host** để mở phòng hoặc nhập mã phòng/IP để **Join**.

---

## 🎮 Hướng Dẫn Điều Khiển (Controls)

| Thao Tác | Phím / Chuột |
|---|---|
| **Chọn đơn vị** | Click chuột trái (LMB) hoặc kéo quét hộp |
| **Ra lệnh (Di chuyển / Tấn công / Khai thác)** | Click chuột phải (RMB) vào đất hoặc mục tiêu |
| **Xoay Camera** | Giữ chuột giữa (MMB) hoặc phím Q / E |
| **Di chuyển Camera** | Phím W, A, S, D hoặc mép màn hình |
| **Phóng to / Thu nhỏ** | Lăn con lăn chuột (Scroll Wheel) |
| **Đặt công trình** | Chọn công trình trên HUD -> Click LMB trên map |
| **Hủy đặt công trình** | Click chuột phải (RMB) hoặc nút Cancel trên HUD |

---

## 📜 Giấy Phép (License)

Dự án được phát hành dưới giấy phép [MIT License](LICENSE).
