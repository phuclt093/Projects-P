# ✅ VIỆC CẦN LÀM Ở NHÀ — dựng "cloud riêng" trên máy nhà

> Soạn 2026-11-04. Làm **theo thứ tự**, tick `[x]` từng ô. Máy nhà: Linux (Ubuntu), RX 6700 XT, 200GB trống.
> Kẹt bước nào: mở Claude (app desktop) → chat mới **trong project "Quản lý project P"** → chọn máy nhà +
> thư mục `~/Projects-P` → gửi nội dung lỗi. Claude sẽ đọc file này và `TIEN_TRINH.md` để biết đang ở đâu.

**Kết quả sau khi xong:**
- `https://git.woe.dpdns.org` → Forgejo ("GitHub riêng", không giới hạn dung lượng) ✅ dùng được ngay
- `https://woe.dpdns.org` → server của CodeCraft (sau lớp đăng nhập email + mã PIN) ⏳ giao diện editor có sau
  khi Claude làm xong CodeCraft bước 2. Trong lúc chờ vẫn dùng Titor trên GitHub Pages như cũ.
- Mọi project chuyển từ GitHub sang Forgejo, 2 máy đồng bộ bằng `./sync.sh`

⏱ Ước tính: 1–2 tiếng (chưa tính phần Ollama/Qwen tuỳ chọn).

---

## 0. TRƯỚC KHI RỜI CƠ QUAN (5 phút, ở máy cơ quan)
Phần quản lý đã lên GitHub, nhưng mấy file mới viết hôm nay chưa được đẩy.
- [ ] Đẩy bản thiết kế CodeCraft (đang nằm chưa commit trong repo Titor):
  ```bash
  cd ~/Projects-P/LT_Titor
  git add docs && git commit -m "Thiết kế CodeCraft: chế độ máy nhà" && git push
  ```
- [ ] Đẩy phần quản lý (file này, `tunnel.sh`, `funnel.sh`, `EU_ORG.md`…):
  ```bash
  cd ~/Projects-P && ./sync.sh push
  ./sync.sh status        # mọi dòng phải ✓
  ```
- [ ] `LT_ClickDeal/platform/server/.env` **không** lên git (đúng, vì chứa bí mật). Nếu ở nhà cần chạy server
      ClickDeal thì tự chép file này sang (USB / gửi riêng), **không** đẩy lên git.

---

## 1. Chuẩn bị máy nhà (15 phút)
- [ ] Công cụ cơ bản:
  ```bash
  sudo apt update && sudo apt install -y git curl python3 tmux
  ```
- [ ] Docker (để chạy Forgejo):
  ```bash
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
  ```
  → **Đăng xuất rồi đăng nhập lại** (hoặc khởi động lại máy), sau đó kiểm tra: `docker run --rm hello-world`
- [ ] Git nhớ đăng nhập (khỏi gõ lại mật khẩu/token):
  ```bash
  git config --global credential.helper store
  git config --global user.name "Le Phuc"
  git config --global user.email "phuclt093@gmail.com"
  ```
- [ ] Máy nhà **bật 24/7**: Settings → Power → tắt tự Suspend/Sleep.

## 2. Kéo Projects-P về (5 phút)
- [ ] ```bash
  cd ~ && git clone https://github.com/phuclt093/Projects-P.git
  cd ~/Projects-P && ./sync.sh          # tự clone 6 project LT_*
  ```
  (git hỏi đăng nhập GitHub: user `phuclt093`, mật khẩu = **Personal Access Token** GitHub.)
- [ ] Mở `TIEN_TRINH.md`, `QUY_UOC.md` lướt qua cho nhớ.

## 3. Server của editor (Titor → CodeCraft) (10 phút)
Có thể máy nhà **đã cài** titor-server rồi. Kiểm tra trước:
- [ ] `systemctl --user status titor-server`
  - Đang chạy (active) → bỏ qua bước cài.
  - Chưa có → cài:
    ```bash
    cd ~/Projects-P/LT_Titor && bash server/setup.sh
    ```
    Script tự cài Node.js, tmux, Claude Code CLI và in ra **URL + token**. Lưu token lại (dùng cho Titor ⚙ → Titor server).
- [ ] Chạy `claude` một lần để đăng nhập gói Pro/Max (nếu script nhắc).

## 4. Forgejo + Cloudflare Tunnel (20 phút)
- [ ] Chuẩn bị cấu hình Forgejo:
  ```bash
  cd ~/Projects-P/LT_GitServer
  cp .env.example .env
  id -u                      # nếu KHÔNG phải 1000 → sửa UID_GID trong .env cho đúng
  ```
- [ ] Dựng tunnel (tự khởi động Forgejo luôn):
  ```bash
  ./tunnel.sh up
  ```
  Lần đầu sẽ in ra 1 link → mở link, đăng nhập Cloudflare, **chọn `woe.dpdns.org`** → Authorize.
  Cuối cùng phải thấy: `Xong: https://woe.dpdns.org/ · https://git.woe.dpdns.org/`
- [ ] Mở **https://git.woe.dpdns.org** → trang cài đặt Forgejo:
  - Database: giữ **SQLite**
  - Kéo xuống **Administrator account settings** → tạo admin (vd `phuclt`, **mật khẩu mạnh**)
  - Bấm **Install Forgejo**
- [ ] Tạo token cho script chuyển repo: Forgejo → avatar → **Settings → Applications → Generate token**
      (quyền: `repository: Read and write`, `user: Read`). **Chép token lại ngay** (chỉ hiện 1 lần).

## 5. Cloudflare Access — lớp đăng nhập trước editor (10 phút, trên web)
- [ ] dash.cloudflare.com → **Zero Trust** (lần đầu: chọn gói **Free**, đặt tên team tuỳ ý)
- [ ] **Access → Applications → Add an application → Self-hosted**
  - Application domain: `woe.dpdns.org` · Tên: `CodeCraft`
  - Policy: **Allow** → Include → **Emails** → `phuclt093@gmail.com` (+ email người được mời sau này)
  - Login method: **One-time PIN**
- [ ] Thử: mở `https://woe.dpdns.org` bằng tab ẩn danh → phải hỏi email + mã PIN.
- ⚠️ **Không** đặt Access cho `git.woe.dpdns.org` (để `git push` qua dòng lệnh chạy được).

## 6. Chuyển các repo từ GitHub sang Forgejo (15 phút)
- [ ] Tạo file cấu hình:
  ```bash
  cd ~/Projects-P/LT_GitServer
  cp migrate.env.example migrate.env
  nano migrate.env
  ```
  Điền:
  ```
  FORGEJO_URL=https://git.woe.dpdns.org      ← DÙNG ĐỊA CHỈ NÀY, KHÔNG dùng 127.0.0.1 (máy cơ quan cần truy cập được)
  FORGEJO_USER=phuclt                        ← tên admin đã tạo ở bước 4
  FORGEJO_TOKEN=<token bước 4>
  ```
- [ ] Chạy thử (không thay đổi gì, chỉ in ra sẽ làm gì):
  ```bash
  DRY=1 ./migrate.sh
  ```
- [ ] Chạy thật:
  ```bash
  ./migrate.sh
  ```
  git có thể hỏi đăng nhập Forgejo: user `phuclt`, mật khẩu = **token Forgejo**.
  `LT_Titor` được **giữ trên GitHub** (cố ý, tới khi CodeCraft xong). Các repo khác + Projects-P chuyển sang Forgejo.
- [ ] Kiểm tra: mở https://git.woe.dpdns.org → thấy các repo `LT_*` + `Projects-P`, đủ branch.
- [ ] `cd ~/Projects-P && ./sync.sh status` → mọi dòng ✓
- ❗ **Chưa xoá** các repo trên GitHub: web (GitHub Pages) và cron (Actions) của ChipmunkT / AirdropTracker /
  Vitube vẫn đang chạy từ đó, sẽ thay dần sang Cloudflare sau (bảng cuối `LT_GitServer/SETUP.md`).
  Chỉ repo tạm `Projects-P` trên GitHub là xoá được sau khi bước 7 xong.

## 7. Kiểm tra từ bên ngoài (5 phút)
- [ ] Trên **điện thoại dùng 4G** (không Wi-Fi nhà):
  - `https://git.woe.dpdns.org` → vào được Forgejo, đăng nhập được
  - `https://woe.dpdns.org` → hỏi email + PIN của Cloudflare Access
- [ ] (Ngày mai ở **máy cơ quan**) đồng bộ sang Forgejo:
  ```bash
  cd ~/Projects-P && ./sync.sh     # tự đổi origin sang git.woe.dpdns.org
  ```
  git hỏi đăng nhập: user `phuclt`, mật khẩu = token Forgejo.
- [ ] Xong hết → xoá repo tạm **Projects-P** trên GitHub (Settings → Delete this repository).

---

## 8. (Tuỳ chọn) AI local: Ollama + Qwen trên RX 6700 XT (30 phút + thời gian tải ~15GB)
Làm theo `LT_LocalLLM/SETUP.md`. Tóm tắt:
- [ ] `curl -fsSL https://ollama.com/install.sh | sh`
- [ ] `sudo systemctl edit ollama` → thêm `Environment="HSA_OVERRIDE_GFX_VERSION=10.3.0"` dưới `[Service]` → `sudo systemctl restart ollama`
- [ ] `ollama pull qwen2.5-coder:14b && ollama pull qwen2.5-coder:7b`
- [ ] `ollama run qwen2.5-coder:7b "hello"` rồi `ollama ps` → cột PROCESSOR phải là **100% GPU**
- [ ] Gắn MCP `qwen-local` vào Claude Code (bước 5–6 trong `LT_LocalLLM/SETUP.md`)

## 9. Việc nhỏ khác
- [ ] DigitalPlat → `woe.dpdns.org` → tab **Renewal**: xem có ngày hết hạn không (nhãn "Permanent").
      Có ngày hết hạn → đặt nhắc lịch gia hạn (miễn phí, trong 120 ngày trước hạn).
- [ ] Ghi kết quả vào `TIEN_TRINH.md` (hoặc nhờ Claude ghi), rồi `./sync.sh push`.

---

## Gặp lỗi thường gặp
| Triệu chứng | Xử lý |
|---|---|
| `docker: permission denied` | Chưa đăng xuất/đăng nhập lại sau `usermod -aG docker` |
| `tunnel.sh` báo trỏ DNS lỗi | Cloudflare › woe.dpdns.org › DNS: xoá bản ghi cũ trùng tên (`woe.dpdns.org` / `git`) rồi chạy lại |
| https://git.woe.dpdns.org báo 502 / 1033 | Forgejo chưa chạy: `cd LT_GitServer && docker compose ps` / `docker compose logs` · tunnel: `./tunnel.sh status` |
| `migrate.sh` báo HTTP 401 | Sai `FORGEJO_TOKEN` / thiếu quyền repository write |
| `git push` hỏi mật khẩu liên tục | Chưa chạy `git config --global credential.helper store` |
| `ollama ps` hiện CPU | Kiểm tra lại dòng `HSA_OVERRIDE_GFX_VERSION=10.3.0`, restart ollama |
