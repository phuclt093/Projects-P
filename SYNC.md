# Đồng bộ Projects-P giữa máy nhà và máy cơ quan

## Cách hoạt động
- Repo **private** `phuclt093/Projects-P` chứa phần quản lý: `CLAUDE.md`, `QUY_UOC.md`,
  `TIEN_TRINH.md`, `repos.txt`, `sync.sh` và các project chưa có repo riêng (`LT_LocalLLM`, `LT_VetMa`).
- Project có repo riêng khai báo trong `repos.txt` → `sync.sh` tự clone/pull, và tự bỏ qua
  chúng trong repo Projects-P (không bị đẩy trùng, không đẩy `node_modules`/file build).

## Hằng ngày
```bash
cd ~/Projects-P
./sync.sh          # BẮT ĐẦU làm: kéo mọi thứ về
./sync.sh status   # xem còn gì chưa commit/push
./sync.sh push     # LÀM XONG, trước khi rời máy: đẩy lên
```
- Phần quản lý được commit tự động. **Code trong repo con thì phải tự commit** (hoặc nhờ Claude
  commit) — `sync.sh push` chỉ đẩy commit đã có và nhắc file nào còn chưa commit.
- Quên `push` ở máy này thì máy kia sẽ không thấy thay đổi.

## Cài lần đầu
### Máy đã có Projects-P (máy cơ quan) — làm 1 lần
1. Trên GitHub tạo repo **private** tên `Projects-P`, **không** tích README.
2. ```bash
   cd ~/Projects-P
   git init -b main && git add -A && git commit -m "Khởi tạo Projects-P"
   git remote add origin https://github.com/phuclt093/Projects-P.git
   git push -u origin main
   ./sync.sh status
   ```

### Máy mới (máy nhà)
```bash
cd ~
git clone https://github.com/phuclt093/Projects-P.git
cd Projects-P && ./sync.sh     # tự clone tất cả repo trong repos.txt
```
Sau đó chạy `npm install` trong project nào cần (node_modules không được đồng bộ).

## Thêm project mới
- Có repo GitHub riêng → thêm 1 dòng vào `repos.txt`, chạy `./sync.sh push`.
- Chưa có repo riêng → cứ để trong Projects-P, nó đi theo repo gốc (nhớ đừng để file > 50MB).

## Chuyển sang server Git riêng (Forgejo ở máy nhà)
Xem `LT_GitServer/SETUP.md`. Sau khi chạy `migrate.sh`, `sync.sh` ở máy kia tự đổi sang Forgejo — cách dùng hằng ngày không đổi.
