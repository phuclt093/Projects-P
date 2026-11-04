# TIẾN TRÌNH — Projects-P

> Cập nhật lần cuối: 2026-11-04

## Danh sách project
| Project | Mô tả | Ngày tạo | Trạng thái |
|---------|-------|----------|------------|
| LT_LocalLLM | Claude Code + Qwen local (Ollama) trên máy nhà RX 6700 XT, nối qua MCP | 2026-11-02 | Đang làm |
| LT_ChipmunkT | Chipmunk Chart — biểu đồ giá crypto realtime kiểu TradingView, web tĩnh (Cloudflare Pages) | 2026-11-04 (chuyển từ Projects) | ? |
| LT_ClickDeal | Tiện ích Chrome/Firefox: nút "Mua qua hoàn tiền" trên Shopee | 2026-11-04 (chuyển từ Projects) | ? |
| LT_TheWiki | Chợ Thẻ — tra giá thẻ & mini game mở pack, web tĩnh + Supabase | 2026-11-04 (chuyển từ Projects) | ? |
| LT_Titor | Web editor kiểu VS Code, GitHub làm ổ cứng, có AI agent (có CLAUDE.md riêng) | 2026-11-04 (chuyển từ Projects) | ? |
| LT_VetMa | _(thư mục trống)_ | 2026-11-04 (chuyển từ Projects) | ? |
| LT_Vitube | Xem YouTube không quảng cáo (web/desktop/mobile/TV) | 2026-11-04 (chuyển từ Projects) | ? |
| LT_AirdropTracker | Theo dõi airdrop (repo github.com/phuclt093/LT_AirdropTracker) | ? | ? |
| LT_GitServer | "GitHub riêng": Forgejo trên máy nhà (Docker + Tailscale), thay hẳn GitHub | 2026-11-04 | Đang làm |

## Đang làm
- [ ] LT_GitServer — Cài Forgejo trên máy nhà + chạy migrate.sh (theo `LT_GitServer/SETUP.md`). Làm SAU bước đẩy Projects-P lên GitHub.
- [ ] Đồng bộ Projects-P: tạo repo private `Projects-P` trên GitHub + push lần đầu (SYNC.md › Cài lần đầu), rồi clone ở máy nhà
- [ ] LT_LocalLLM — Cài đặt trên máy nhà theo `LT_LocalLLM/SETUP.md` (bước 1→6)

## Sắp làm
- [ ] LT_Titor — "Chế độ máy nhà": đọc/ghi qua titor-server + Forgejo, bỏ phụ thuộc GitHub (gửi thiết kế trước khi sửa)
- [ ] Thay các phụ thuộc GitHub còn lại (bảng cuối `LT_GitServer/SETUP.md`): ChipmunkT signals, AirdropTracker, Vitube Pages
- [ ] PJ_ (cơ quan) — chờ xác nhận quy định cơ quan + chọn cách (a) giữ SVN / (b) chuyển git
- [ ] LT_LocalLLM — Chạy thử thực tế, đo tốc độ 14b vs 7b, ghi kết quả vào SETUP.md

## Đã xong
- [x] 2026-11-04 — LT_GitServer: docker-compose, migrate.sh (test giả lập: chuyển repo, mirror, máy 2 tự đổi origin), sync.sh hỗ trợ đổi origin
- [x] 2026-11-04 — Viết `sync.sh`, `repos.txt`, `SYNC.md`, `.gitignore` (đã test pull/push/clone giữa 2 máy giả lập)
- [x] 2026-11-02 — LT_LocalLLM: viết SETUP.md + qwen_mcp.py (đã test import với mcp 1.x/2.x)
- [x] 2026-11-02 — Thiết lập thư mục `Projects-P`: tạo `QUY_UOC.md` và `TIEN_TRINH.md`

## Nhật ký
| Ngày | Project | Nội dung |
|------|---------|----------|
| 2026-11-02 | (chung) | Khởi tạo thư mục, ghi quy ước đặt tên `LT_`. |
| 2026-11-02 | LT_LocalLLM | Tạo project. Chọn qwen2.5-coder:14b (chính) + 7b (nhanh); RX 6700 XT cần HSA_OVERRIDE_GFX_VERSION=10.3.0. |
| 2026-11-04 | (chung) | Ghi nhận các project `LT_*` chuyển từ `Projects` sang; bổ sung LT_AirdropTracker vào danh sách. |
| 2026-11-04 | (chung) | Thiết lập đồng bộ qua GitHub: phần quản lý vào repo private Projects-P, 6 project LT_ giữ repo riêng. |
| 2026-11-04 | LT_GitServer | Tạo project. Forgejo 17 + SQLite, chỉ mở trên IP Tailscale; LT_Titor giữ GitHub. |
| 2026-11-04 | LT_GitServer | Quyết định bỏ GitHub: migrate.sh tắt mirror mặc định; liệt kê phụ thuộc GitHub cần thay. |
