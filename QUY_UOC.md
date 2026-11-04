# QUY ƯỚC LÀM VIỆC — Projects-P

> File này ghi lại các quy ước khi làm việc với thư mục `Projects-P`.
> Mỗi khi có quy ước mới, bổ sung vào đây (kèm ngày).

## 1. Cấu trúc thư mục
```
Projects-P/
├── CLAUDE.md         # Hướng dẫn Claude tự đọc mỗi phiên
├── QUY_UOC.md        # Quy ước làm việc (file này)
├── TIEN_TRINH.md     # Theo dõi task / tiến trình đang làm
├── SYNC.md, sync.sh  # Đồng bộ 2 máy qua GitHub
├── repos.txt         # Danh sách project có repo GitHub riêng
└── LT_<TenProject>/  # Mỗi project là một thư mục riêng
```

## 2. Đặt tên project
- Mỗi project là **một thư mục riêng** nằm trực tiếp trong `Projects-P`.
- Tên project **bắt buộc có tiền tố `LT_`**.
  - Ví dụ: `LT_Website`, `LT_QuanLyKho`, `LT_AppBanHang`

## 3. Theo dõi tiến trình
- Mọi task đang làm / sắp làm / đã xong được ghi vào `TIEN_TRINH.md`.
- Khi bắt đầu hoặc hoàn thành một việc, cập nhật trạng thái trong file đó.

## 4. Đề xuất đưa vào CLAUDE.md
- Khi Claude thấy một điều được nhắc lại **nhiều lần** (yêu cầu, cách làm, lưu ý lặp lại),
  Claude **hỏi lại** xem có muốn đưa vào `CLAUDE.md` không. Chỉ thêm khi được đồng ý.
- Mặc định đề xuất vào `Projects-P/CLAUDE.md` (áp dụng cho cả thư mục); nếu là thói quen
  dùng chung mọi nơi thì đề xuất `~/.claude/CLAUDE.md`.

## 6. Đồng bộ giữa máy nhà và máy cơ quan
- Projects-P là repo private trên GitHub; các project có repo riêng khai báo trong `repos.txt`.
- Bắt đầu làm: `./sync.sh`. Làm xong: commit code repo con rồi `./sync.sh push`. Chi tiết: `SYNC.md`.
- Không để file > 50MB trong phần thuộc repo Projects-P (GitHub chặn file > 100MB).
- Project mới có repo GitHub riêng → thêm vào `repos.txt`.
- **Bỏ GitHub** (2026-11-04): nơi lưu code là Forgejo ở máy nhà (`LT_GitServer`). Thứ cần công khai (web, dữ liệu web đọc) đặt trên Cloudflare. `LT_Titor` tạm giữ GitHub tới khi có "chế độ máy nhà".

## Lịch sử thay đổi quy ước
| Ngày | Nội dung |
|------|----------|
| 2026-11-02 | Tạo file. Quy ước tiền tố `LT_` cho tên project; mỗi project một thư mục riêng; theo dõi task trong `TIEN_TRINH.md`. |
| 2026-11-03 | Thêm mục 4: điều gì được nhắc nhiều lần thì Claude hỏi lại có đưa vào `CLAUDE.md` không. |
| 2026-11-03 | Tạo `CLAUDE.md`: đầu phiên đọc QUY_UOC + TIEN_TRINH, sau thay đổi cập nhật TIEN_TRINH. |
| 2026-11-04 | Thêm mục 6: đồng bộ 2 máy qua GitHub bằng `sync.sh` + `repos.txt`. |
| 2026-11-04 | Thêm kế hoạch server Git riêng (Forgejo, `LT_GitServer`); `LT_Titor` giữ GitHub. |
| 2026-11-04 | Bỏ GitHub: code lưu ở Forgejo, phần công khai trên Cloudflare; không mirror sang GitHub. |
