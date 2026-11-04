# LT_LocalLLM: Claude Code + Qwen local (máy nhà, RX 6700 XT)

Mục tiêu: Claude Code làm "não chính", giao việc vặt cho Qwen chạy trên GPU ở nhà
để tiết kiệm token và tăng tốc.

```
Claude Code ──(MCP)──> qwen_mcp.py ──(HTTP localhost:11434)──> Ollama ──> Qwen trên RX 6700 XT
```

Giả định: máy nhà chạy **Linux** (Ubuntu hoặc tương tự). Nếu là Windows thì bỏ bước 2
(ROCm override chỉ áp dụng cho Linux), các bước còn lại tương tự.

---

## Bước 1: Cài Ollama
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

## Bước 2: Cho Ollama dùng GPU (bắt buộc với RX 6700 XT)
RX 6700 XT (gfx1031) không có trong danh sách hỗ trợ sẵn → không cấu hình thì Ollama chạy bằng CPU.
```bash
sudo systemctl edit ollama
```
Dán vào giữa 2 dòng chú thích:
```
[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=10.3.0"
```
```bash
sudo systemctl restart ollama
```

## Bước 3: Tải model
```bash
ollama pull qwen2.5-coder:14b   # model chính (~9GB, vừa 12GB VRAM)
ollama pull qwen2.5-coder:7b    # model nhanh cho việc vặt (~4.7GB)
```
Kiểm tra có chạy trên GPU không:
```bash
ollama run qwen2.5-coder:7b "viết hàm python cộng 2 số"
ollama ps        # cột PROCESSOR phải là "100% GPU"
```
Nếu hiện CPU → xem `journalctl -u ollama -n 50`. Nếu ROCm vẫn lỗi, thử bản Vulkan của Ollama.

## Bước 4: Cài Claude Code (nếu máy nhà chưa có)
```bash
npm install -g @anthropic-ai/claude-code
claude   # đăng nhập lần đầu
```

## Bước 5: Cài MCP server qwen-local
Copy thư mục `LT_LocalLLM` này về máy nhà (vd `~/Projects-P/LT_LocalLLM`), rồi:
```bash
python3 -m venv ~/.venvs/qwen-mcp
~/.venvs/qwen-mcp/bin/pip install mcp

claude mcp add --scope user qwen-local \
  -e QWEN_MODEL=qwen2.5-coder:14b \
  -e QWEN_FAST_MODEL=qwen2.5-coder:7b \
  -- ~/.venvs/qwen-mcp/bin/python ~/Projects-P/LT_LocalLLM/qwen_mcp.py
```
Kiểm tra: `claude mcp list` → thấy `qwen-local ✓ Connected`.
Trong Claude Code gõ: *"gọi qwen_status"* → phải liệt kê được 2 model.

Server có 3 tool:
| Tool | Dùng để |
|---|---|
| `ask_qwen` | Giao một yêu cầu cho Qwen |
| `qwen_on_file` | Qwen tự đọc file rồi xử lý. Nội dung file không đi qua Claude → **tiết kiệm nhiều nhất** |
| `qwen_status` | Kiểm tra Ollama/model |

## Bước 6: Dặn Claude khi nào giao việc cho Qwen
Thêm đoạn sau vào `~/.claude/CLAUDE.md` (áp dụng cho mọi project):
```markdown
## Phối hợp với Qwen local (MCP qwen-local)
- Giao cho Qwen (ask_qwen / qwen_on_file): viết test, thêm comment/docstring, boilerplate,
  đổi định dạng, dịch, tóm tắt file dài. Với file dài, ưu tiên qwen_on_file thay vì tự đọc file.
- Việc rất nhỏ/cần nhanh: dùng fast=true.
- Claude tự làm: thiết kế/kiến trúc, debug khó, quyết định quan trọng, review lại kết quả của Qwen.
- Luôn kiểm tra lại output của Qwen trước khi ghi vào file.
```

---

## Xử lý sự cố nhanh
| Triệu chứng | Cách xử lý |
|---|---|
| `ollama ps` hiện CPU | Kiểm tra lại bước 2, `sudo systemctl restart ollama` |
| qwen-local không Connected | Chạy thử `~/.venvs/qwen-mcp/bin/python qwen_mcp.py` xem lỗi |
| Trả lời rất chậm | Dùng `fast=true` (model 7b), hoặc chia nhỏ việc |
| Hết VRAM | Không chạy 2 model lớn cùng lúc; đừng dùng `qwen3-coder:30b` (19GB) trừ khi RAM ≥ 32GB |

## Ghi chú
- `qwen_mcp.py` chạy được với cả thư viện `mcp` bản 1.x và 2.x.
- Đổi model: sửa biến `QWEN_MODEL` / `QWEN_FAST_MODEL` (gỡ ra rồi chạy lại `claude mcp add`).
