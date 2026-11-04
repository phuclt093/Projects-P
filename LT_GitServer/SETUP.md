# LT_GitServer: "GitHub riêng" bằng Forgejo trên máy nhà

```
 Máy cơ quan ──┐
               ├── Tailscale ──> Forgejo (máy nhà, 200GB, Git LFS cho file nặng)
 Máy nhà ──────┘
```

- **Forgejo là nơi chính.** Không giới hạn 100MB/file, dung lượng = ổ cứng máy nhà.
- **Không dùng GitHub nữa** (quyết định 2026-11-04). Mirror sang GitHub vẫn bật được nếu cần
  (`MIRROR_GITHUB=1` trong `migrate.env`), mặc định tắt.
- Chuyển repo **không làm hỏng** gì đang chạy: site và cron trên GitHub vẫn chạy bản cũ, chỉ là
  thay đổi mới sẽ không lên đó nữa. Các phần phụ thuộc GitHub cần thay dần — xem bảng cuối file.
- `LT_Titor` tạm giữ trên GitHub (cột 3 = `github` trong `repos.txt`) cho tới khi Titor có
  "chế độ máy nhà"; xong thì bỏ chữ `github` và chạy lại `migrate.sh`.

Yêu cầu: máy nhà bật 24/7 (tắt máy = máy cơ quan không pull/push được; vẫn code bình thường,
lúc máy nhà bật lại thì push sau), có Docker, đã cài Tailscale (xem `../LT_LocalLLM/SETUP.md`
hoặc: `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`).

---

## Bước 1 — Cài Docker (máy nhà, nếu chưa có)
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER     # đăng xuất/đăng nhập lại
```

## Bước 2 — Chạy Forgejo
```bash
cd ~/Projects-P/LT_GitServer
cp .env.example .env
tailscale ip -4                   # điền IP này vào BIND_IP, DOMAIN, ROOT_URL trong .env
docker compose up -d
```
Mở `http://<IP-tailscale>:3000` → trang cài đặt: giữ **SQLite**, kéo xuống
**Administrator account settings** tạo tài khoản admin (vd `phuclt`) → **Install Forgejo**.

## Bước 3 — Cho git nhớ đăng nhập (cả 2 máy)
```bash
git config --global credential.helper store
```
Lần đầu clone/push lên Forgejo, git hỏi user + mật khẩu (dùng token Forgejo thay mật khẩu cũng được),
sau đó tự nhớ.

## Bước 4 — Chuyển các repo sang Forgejo (làm 1 lần, ở máy đang có đủ bản clone)
```bash
cd ~/Projects-P && ./sync.sh                 # đảm bảo mọi repo mới nhất
cd LT_GitServer
cp migrate.env.example migrate.env         # điền token Forgejo
DRY=1 ./migrate.sh                           # chạy thử: xem sẽ làm gì
./migrate.sh                                 # chạy thật — chạy lại nhiều lần vẫn an toàn
```
Script làm cho từng repo: tạo repo private trên Forgejo → đẩy mọi branch + tag → đổi `origin`
sang Forgejo (URL GitHub cũ giữ ở remote `github` để tham khảo) → sửa `repos.txt`
(thêm dòng `@root` cho chính Projects-P) và đẩy lên.

## Bước 5 — Máy còn lại
```bash
cd ~/Projects-P && ./sync.sh
```
`sync.sh` đọc `repos.txt` mới và **tự đổi origin** của Projects-P và các repo con sang Forgejo.

---

## File nặng (> 50MB): dùng Git LFS
```bash
sudo apt install git-lfs && git lfs install          # 1 lần mỗi máy
cd <repo> && git lfs track "*.AppImage" "*.deb" "*.gguf"
git add .gitattributes && git commit -m "Dùng LFS cho file nặng"
```
LFS trên Forgejo không giới hạn ngoài dung lượng ổ cứng.

## Sao lưu
Toàn bộ dữ liệu nằm trong `LT_GitServer/data/` (đã .gitignore). Định kỳ:
```bash
docker compose stop && tar czf ~/forgejo-backup-$(date +%F).tar.gz data && docker compose start
```
Nên chép file backup sang chỗ khác (ổ ngoài, hoặc máy cơ quan) — không còn GitHub làm bản sao.

## Cập nhật Forgejo
```bash
docker compose pull && docker compose up -d
```
Lên phiên bản major mới (vd 17 → 18): sửa `FORGEJO_VERSION` trong `.env`, đọc release notes trước.

## Thêm project mới
- Tạo trên Forgejo: chỉ cần `git remote add origin http://<IP>:3000/phuclt/LT_Moi.git && git push -u origin main`
  (Forgejo tự tạo repo private khi push lần đầu), rồi thêm dòng vào `repos.txt`.

## Sự cố
| Triệu chứng | Xử lý |
|---|---|
| Máy cơ quan không vào được `http://100.x.x.x:3000` | `tailscale status` trên cả 2 máy; máy nhà có bật không |
| `docker compose up` báo lỗi cổng | Sai `BIND_IP` — phải đúng IP `tailscale ip -4` |
| migrate.sh báo HTTP 401 | Sai `FORGEJO_TOKEN` hoặc token thiếu quyền `write:repository` |

## Những chỗ đang phụ thuộc GitHub (thay dần khi sửa từng project)
⚠️ Forgejo chỉ mở trong Tailscale → **người ngoài không truy cập được**. Thứ gì công khai
(trang web, dữ liệu cho web đọc) phải chuyển sang **Cloudflare** (bạn đã dùng sẵn), không phải Forgejo.

| Project | Đang dùng GitHub cho | Thay bằng |
|---|---|---|
| LT_ChipmunkT | Actions `signals.yml` chạy mỗi giờ, ghi `signals.json` vào repo `LT_ChipmunkT-data`; web + worker đọc qua `raw.githubusercontent.com` | Cron Trigger của Cloudflare Worker (hoặc systemd timer máy nhà) ghi vào Cloudflare R2/KV; đổi `signalsUrl` |
| LT_ChipmunkT | `worker/mexc-proxy.js` cho phép origin `phuclt093.github.io` | Thêm domain Cloudflare Pages mới |
| LT_AirdropTracker | GitHub Pages (`pages.yml`), Actions `remind.yml` hằng ngày, `index.html` gọi `api.github.com` | Cloudflare Pages (`wrangler pages deploy`), Worker Cron; thay chỗ gọi API GitHub |
| LT_AirdropTracker | `sync/wrangler.jsonc` ALLOWED_ORIGINS = `phuclt093.github.io` | Domain mới |
| LT_Vitube | GitHub Pages (`pages.yml`) | Cloudflare Pages |
| LT_Titor | GitHub làm ổ cứng, GitHub Pages, đăng nhập GitHub, @claude qua Issues (`claude.yml`) | "Chế độ máy nhà": titor-server + Forgejo; Claude CLI có sẵn trong titor-server |
| (máy nhà) | Self-hosted GitHub runner (`setup-runner.sh`) | Forgejo Actions runner, nếu còn cần |
