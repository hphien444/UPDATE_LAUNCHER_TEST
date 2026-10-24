# WESTSIDE TEST 1000076 - Chế độ tương thích máy net

## Trạng thái bàn giao

Hướng dẫn bản TEST 1000076 thử nghiệm, cập nhật trên repo TEST theo yêu cầu chủ dự án. Không sửa
ADMIN, CITY, backend, FXServer hoặc VPS. Chính sách IP bàn giao đang rỗng và
`enabled=false`; chưa có máy nào được cấp quyền bỏ EAC bằng chính sách này.

Đây là chế độ chạy không có bảo vệ EAC được admin cho phép, KHÔNG phải giả
mạo xác thực EAC. Anticheat DLL legacy vẫn được khởi tạo; anti-dump vẫn OFF.
Máy không có quyền tương thích, không có tín hiệu nguy cơ và không yêu cầu
dừng an toàn vẫn dùng EAC như bản thông thường.

## 1. Máy đã từng bị màn hình xanh

1. Dùng đầy đủ thư mục build mới, không ghép EXE/DLL với phiên bản cũ.
2. Đóng launcher/game khác rồi chạy `MO_MAY_NET_AN_TOAN.cmd` cạnh
   `WESTSIDE TEST.exe`. Không mở EXE thông thường trước trên máy đã biết có lỗi.
3. Khi chưa có quyền IP, launcher dừng trước EOS/EAC và hiện hộp hỗ trợ.
   Gửi admin **mã mạng** trong hộp và ảnh mã lỗi Windows; có thể dùng Ctrl+C
   trên hộp thông báo Windows để sao chép nội dung.
4. Admin xét duyệt IP, cập nhật chính sách có thời hạn, rồi mở lại bằng script.
   Nếu nhận được quyền hợp lệ, launcher chọn đường chạy không EAC; nếu không,
   nó vẫn dừng, không tự thử lại bằng EAC.

Script kiểm tra SHA-256 đúng EXE đã bàn giao, từ chối EXE cũ hoặc bị thay đổi.
Nó không tắt/xóa driver, service, phần mềm bảo vệ hoặc đổi cấu hình khởi động
Windows. Nếu bản mới hơn thay MAIN, cần helper tương ứng với bản mới đó.

Script tạo `WESTSIDE CITY.app\westside-eac-safety.hold`. File này giữ trạng thái
dừng an toàn khi lần sau người chơi mở EXE trực tiếp mà chưa có quyền. Bản build
không phát hành sẵn file hold để tránh khóa toàn bộ người dùng thông thường.
Chỉ bỏ/đổi tên file này sau khi admin kiểm tra nguyên nhân lỗi và quyết định
cho phép thử EAC trở lại. Không coi xóa hold là cách sửa màn hình xanh.

## 2. Admin cấp whitelist tạm thời

Chỉ người có quyền ghi repo TEST mới làm bước phát hành chính sách. Công cụ
Python đi kèm CHỈ GHI FILE LOCAL, không có chức năng upload, không chứa token.

Từ thư mục build, chọn một trong hai cách:

```powershell
# Thay bằng mã mạng 64 ký tự hex do người chơi gửi; ví dụ này không cấp quyền thật.
python .\admin-tools\quan_ly_whitelist.py --code "MA_MANG_64_KY_TU" --hours 4

# Hoặc thay bằng public IPv4 thật của tiệm net, không dùng IP LAN/CIDR.
python .\admin-tools\quan_ly_whitelist.py --ip "IP_PUBLIC_CUA_TIEM_NET" --hours 4
```

- Mặc định 4 giờ, tối đa 24 giờ; không cấp vĩnh viễn, không wildcard.
- File tạo ra: `admin-tools\policy\eac-cafe-1000076.json`.
- Có backup trước khi sửa. Không upload các file `.before-*`, file thử nghiệm
  hoặc cả workspace. Kiểm tra đồng hồ UTC của máy admin trước khi cấp quyền.
- Sau khi xét duyệt, chủ repo đưa đúng JSON vào
  `hphien444/UPDATE_LAUNCHER_TEST`, nhánh `main`, đường dẫn
  `policy/eac-cafe-1000076.json`.
- Launcher chỉ nhận chính sách tại URL HTTPS cố định:
  `https://raw.githubusercontent.com/hphien444/UPDATE_LAUNCHER_TEST/main/policy/eac-cafe-1000076.json`.
  File JSON để local cạnh EXE KHÔNG có tác dụng cấp quyền.
- Chế độ này chỉ áp dụng TEST 1000076, không cho ADMIN/CITY hoặc bản khác.

Thu hồi một mạng hoặc toàn bộ quyền (sau đó xét duyệt/upload JSON mới):

```powershell
python .\admin-tools\quan_ly_whitelist.py --remove-code "MA_MANG_64_KY_TU"
python .\admin-tools\quan_ly_whitelist.py --disable-all
```

Chưa upload chính sách thì whitelist chưa có hiệu lực. Bản phát hành này đưa policy rỗng và helper lên repo để tải riêng;
updater runtime KHÔNG tự chép helper cạnh EXE và KHÔNG cấp quyền cho IP nào. Cần gửi
helper cùng bản build cho máy đã từng gặp lỗi trước lần mở đầu tiên.

## 3. Hành vi và giới hạn quan trọng

- Dò tên service phần mềm phòng net/diskless chỉ là tín hiệu dừng an toàn,
  không tự cấp quyền bỏ EAC. Không nhận diện được mọi phòng net hoặc phần mềm.
- Có dấu phiên EAC đang chạy và sự kiện Windows BugCheck sau dấu đó thì lần
  mở sau có thể chuyển sang dừng an toàn. Chỉ xét sự kiện 7 ngày, khi đọc được
  Windows Event Log. Chỉ áp dụng phiên do bản mới ghi dấu, không bảo đảm nhận
  ra sự cố của các phiên bản cũ hoặc Windows bị đóng băng/hoàn tác ổ đĩa.
- Chưa có stop code, driver gây lỗi hoặc minidump của máy net. Không kết luận
  EAC là nguyên nhân, không thể bắt ngoại lệ để cứu Windows sau khi BSOD đã xảy ra.
- Không có mạng, không lấy được public IPv4, policy thiếu/sai/hết hạn không
  cấp quyền bỏ EAC. Với máy có hold/tín hiệu nguy cơ hoặc yêu cầu an toàn, dừng
  trước EAC. Với máy bình thường không có các tín hiệu đó, vẫn chạy EAC.
- Public IP được hỏi qua HTTPS tới `api.ipify.org`. Máy chỉ IPv6 không được
  cấp quyền bằng cơ chế IPv4 này. IP đổi thì cần duyệt mã mới khi mở lại.
- Quyền theo public IP áp dụng toàn bộ máy cùng NAT, không phải từng máy.
  Mã SHA-256 không chứa IP dạng rõ nhưng không phải cơ chế ẩn danh IP mạnh.
- Quyền được lưu trong bộ nhớ từng tiến trình đến hạn; không thăm dò thu hồi
  hoặc kiểm tra IP liên tục khi chơi. Thu hồi áp dụng ở lần mở mới hoặc hết hạn
  quyền hiện có, có thể thêm độ trễ cache phía nhà cung cấp. Không quảng cáo
  là thu hồi tức thì. Khi hết hạn, DLL yêu cầu ngắt kết nối, không bật EAC giữa game.
- Kiểm tra HTTPS phía client KHÔNG thay thế IP whitelist/xác thực phía server.
  Không thay đổi `enforce` trên server. Server bắt buộc EAC vẫn có thể từ chối
  người chơi chế độ tương thích; không giả trạng thái `authenticated` để né.
- Chưa thử phiên game thật đã được cấp quyền, máy net đang lỗi, đăng nhập EOS,
  EAC RemoteAuth/0r_AC phía server hoặc chơi dài hạn. Cần thử có giám sát trước
  khi phát hành rộng; không cam kết đã sửa dứt điểm màn hình xanh.

## 4. Dấu hiệu kiểm tra

Chế độ EAC thường: log EAC vendor có
`Launcher finished with: 301, 'Easy Anti-Cheat successfully loaded in-game'.`
Log DLL có `build=1000076-test-compatible-dual-ac`, `InitScanner OK`,
`InitProcessDeepScan (WMI) OK`, `EAC + legacy scanners selected; anti-dump OFF`.
Các dòng này không chứng minh xác thực server đã thành công.

Chế độ được duyệt: dự kiến log có
`compatibility-admin-approved-EAC-OFF`, `mode=admin-approved-EAC-OFF`,
`child claimed EAC-OFF`, và
`admin IP lease approved; EAC OFF, NOT authenticated; legacy scanners ON.`
Hai dòng khởi tạo scanner legacy vẫn phải xuất hiện. Đây là chuỗi theo source,
chưa có bằng chứng một phiên thật đã được cấp quyền chạy hết đường này.

Các file kiểm tra trên máy chạy: `.app\westside-eac-bootstrap.log`,
`.app\logs\CitizenFX_log*.log`, `.app\citizen-anticheat-diag.log`.
Không đưa log, token đăng nhập, dump, khóa ký hoặc cache GTA vào gói public.
