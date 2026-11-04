# Xin tên miền miễn phí *.eu.org (dùng lâu dài thay cho địa chỉ .ts.net)

> ⚠️ 2026-11-04: EU.org **không nhận email Gmail**, đòi email doanh nghiệp/tổ chức → tạm gác.
> Phương án thay thế: **DigitalPlat FreeDomain** (`*.qzz.io`, `*.dpdns.org`), xem mục cuối file.

> Khi được duyệt: đưa DNS về Cloudflare → dùng Cloudflare Tunnel + Access với địa chỉ đẹp
> (vd `code.phuclt.net.eu.org`). Trong lúc chờ cứ dùng Tailscale Funnel (`./funnel.sh up`).

## Có hợp lệ không?
- EU.org dành chủ yếu cho **cá nhân và tổ chức phi lợi nhuận**, không cần ở châu Âu.
  Dùng làm editor nội bộ cá nhân là hợp lệ. Site thương mại chỉ được nhận khi không còn lựa chọn khác.
- Cấm: spam, phishing, phát tán malware, công cụ hỗ trợ những thứ đó.
- Chính sách: https://nic.eu.org/policy.html

## Bước 0: Chọn tên
EU.org khuyên **đăng ký dưới một miền con** thay vì trực tiếp `xxx.eu.org` (miền trực tiếp có chính sách
khắt khe hơn: https://nic.eu.org/top-policy.html). Một số miền đang mở:

| Miền | Ví dụ | Ghi chú |
|---|---|---|
| `NET.eu.org` | `phuclt.net.eu.org` | liên quan mạng/kỹ thuật, hợp nhất |
| `INT.eu.org` | `phuclt.int.eu.org` | "quốc tế" |
| `EU.org` trực tiếp | `phuclt.eu.org` | ngắn nhất, khó được duyệt hơn |

Danh sách đầy đủ: https://nic.eu.org/opendomains.html. Việt Nam (VN) chưa có trong danh sách.

Sau này mọi địa chỉ đều nằm dưới tên đó: `code.phuclt.net.eu.org`, `git.phuclt.net.eu.org`...

## Bước 1: Tạo DNS zone TRƯỚC khi nộp đơn (quan trọng)
EU.org yêu cầu nameserver **đã được cấu hình cho tên miền** lúc nộp đơn. Cloudflare lại không nhận tên miền
chưa tồn tại → dùng một DNS miễn phí làm trung gian, khi được duyệt thì chuyển sang Cloudflare.

**Hurricane Electric (miễn phí):**
1. Đăng ký tài khoản ở https://dns.he.net
2. **Add new domain** → nhập đúng tên định xin, vd `phuclt.net.eu.org`. HE có thể cảnh báo tên miền chưa
   được uỷ quyền, cứ tiếp tục.
3. Ghi lại các nameserver HE đưa: `ns2.he.net`, `ns3.he.net`, `ns4.he.net`, `ns5.he.net`.

(Cách khác: ClouDNS.net bản miễn phí cũng làm được, cách làm tương tự.)

## Bước 2: Tạo tài khoản ở EU.org
1. Vào https://nic.eu.org/arf/ → **Sign up** (tạo "handle" = hồ sơ liên hệ).
2. Điền **thông tin thật**: họ tên, địa chỉ, email (email nhận kết quả duyệt), có thể có số điện thoại.
   Thông tin giả là lý do hay bị từ chối.
3. Xác nhận email.

## Bước 3: Nộp đơn
1. Đăng nhập https://nic.eu.org/arf/ → **New domain**.
2. Điền tên miền (vd `phuclt.net.eu.org`), chọn handle của bạn làm liên hệ.
3. Phần nameserver: nhập `ns2.he.net` … `ns5.he.net` (đúng các NS ở bước 1).
4. Gửi. Hệ thống kiểm tra NS ngay. Nếu báo lỗi (vd NS không trả lời cho zone) → kiểm tra lại zone ở HE rồi gửi lại.

## Bước 4: Chờ
- Có người duyệt thủ công. Trang EU.org nói "vài ngày", nhưng thực tế **có thể vài tháng hoặc lâu hơn**,
  và có người chờ rất lâu không thấy. Kết quả gửi qua email.
- Không nộp nhiều đơn trùng nhau.

## Bước 5: Khi được duyệt → chuyển sang Cloudflare
1. Cloudflare Dashboard → **Add a domain** → nhập tên miền → chọn gói **Free**.
2. Cloudflare đưa 2 nameserver (vd `xxx.ns.cloudflare.com`).
3. Vào nic.eu.org/arf/ → tên miền của bạn → đổi nameserver từ HE sang 2 NS của Cloudflare.
4. Chờ Cloudflare báo **Active** → báo Claude để chuyển từ Funnel sang Cloudflare Tunnel + Access.

Nguồn: https://nic.eu.org/ · https://nic.eu.org/register.html · https://nic.eu.org/policy.html

---
## Phương án thay thế: DigitalPlat FreeDomain (miễn phí, dùng Gmail được)
- Tổ chức phi lợi nhuận, cấp tên miền con miễn phí: **`.qzz.io`**, **`.dpdns.org`** (miễn phí).
  `.us.kg`, `.xx.kg` phải trả tiền; `.qd.je` có người báo không thêm được vào Cloudflare.
- Đăng ký: https://dash.domain.digitalplat.org → chọn tên (vd `phuclt.qzz.io`).
- Hạn **1 năm**, gia hạn **miễn phí** nếu bấm gia hạn trong vòng **120 ngày trước khi hết hạn**
  → đặt nhắc lịch hằng năm (quên là mất tên miền).
- Nối Cloudflare: Cloudflare → Add a domain (gói Free) → lấy 2 nameserver → dán vào dashboard DigitalPlat
  → chờ Cloudflare báo Active → báo Claude chuyển sang Cloudflare Tunnel + Access.
- Rủi ro: tên miền nằm dưới miền chung của DigitalPlat; họ ngừng dịch vụ hoặc miền bị chặn do người khác
  lạm dụng (đuôi `.us.kg` từng bị khoá vì vậy) thì mất địa chỉ. Chỉ dùng nội bộ nên chấp nhận được;
  Funnel (`./funnel.sh`) luôn là phương án dự phòng.
