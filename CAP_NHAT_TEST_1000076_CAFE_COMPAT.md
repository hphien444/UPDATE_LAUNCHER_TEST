# WESTSIDE TEST 1000076 - Tương thích máy net (thử nghiệm)

Cập nhật client TEST theo yêu cầu chủ dự án ngày 24/10/2026. Không đổi ADMIN/CITY,
FXServer, backend hoặc VPS. Giữ anticheat DLL legacy; anti-dump OFF.

- Máy thường vẫn dùng EAC. Nhận diện phòng net chỉ là tín hiệu dừng an toàn,
  không tự cấp quyền bỏ EAC. Chỉ IP có quyền admin còn hạn mới chạy EAC-OFF.
- Policy phát hành đang rỗng, enabled=false: KHÔNG whitelist IP nào.
- Máy đã bị BSOD: dùng MAIN 1000076 cùng `MO_MAY_NET_AN_TOAN.cmd`, đọc
  `HUONG_DAN_MAY_NET_1000076.md`; không mở EXE thường trước để thử vận may.
  Helper từ chối MAIN cũ; nó cần nằm cạnh EXE mới, không nằm trong .app.
- Helper và công cụ admin tải riêng từ repo; updater không tự cài helper.
- Catalog EAC đã ký/verify; 437 runtime + MAIN. 434/438 file giữ nguyên hash.
  Chỉ MAIN, sticky.dll, citizen-anticheat.dll và base.bin thay đổi.
- Giữ pure2/build3258, whitelist mod, camera/UI, pure handoff và auto-repair.
- 9 suite regression và 4 kịch bản native QA đạt trên máy build: upgrade,
  repair, nested EXE, safe hold khi chưa có quyền. EAC loaded-in-game và hai
  scanner legacy khởi tạo trong chế độ thông thường.
- Chưa thử máy net bị BSOD, phiên thật được duyệt EAC-OFF, đăng nhập/kết nối
  server EAC/0r_AC, Windows sạch hoặc chơi dài hạn. Không khẳng định hết BSOD.
- Chế độ EAC-OFF không được xác thực EAC; server bắt buộc EAC có thể từ chối.
  Quyền IP áp dụng cả NAT, tối đa 24h; thu hồi ở lần mở mới hoặc hết hạn,
  không phải kiểm tra IP liên tục hay whitelist cưỡng chế từ server.

MAIN SHA-256: 34939e1011812259e3ffb5447a5aa1d9e5c225f059e4ea800c837a4d3e89e101
Bootstrap FULL local SHA-256: ea6fc630d44f9aa6fbbb4dffb6c5f3489ddc9a0fec379b16cdc49138b47904af

Các object cũ được giữ. Hạ head không tự hạ EXE đã cập nhật; rollback cần bộ
MAIN/runtime/catalog đồng bộ hoặc forward-fix. Không khuyến nghị mở EAC cũ
trên máy đã bị BSOD. Không có khóa ký, token, log/dump hay GTA game-storage
mới được đưa lên repo trong lần phát hành này.
