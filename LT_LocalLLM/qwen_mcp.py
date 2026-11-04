#!/usr/bin/env python3
"""
qwen-local: MCP server cho phép Claude Code giao việc cho Qwen chạy local qua Ollama.

Tool:
  - ask_qwen      : gửi một yêu cầu/prompt cho Qwen.
  - qwen_on_file  : Qwen tự đọc file trên máy rồi xử lý. Nội dung file KHÔNG đi
                    qua Claude -> đây là chỗ tiết kiệm token nhiều nhất.
  - qwen_status   : kiểm tra Ollama có chạy không, đang có model nào.

Biến môi trường (tuỳ chọn):
  OLLAMA_URL        mặc định http://localhost:11434
  QWEN_MODEL        mặc định qwen2.5-coder:14b   (model chính)
  QWEN_FAST_MODEL   mặc định qwen2.5-coder:7b    (việc vặt, cần nhanh)
  QWEN_TIMEOUT      mặc định 600 (giây)
"""
import json
import os
import urllib.error
import urllib.request

try:  # mcp 2.x
    from mcp.server.mcpserver import MCPServer as FastMCP
except ImportError:  # mcp 1.x
    from mcp.server.fastmcp import FastMCP

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434").rstrip("/")
MODEL = os.environ.get("QWEN_MODEL", "qwen2.5-coder:14b")
FAST_MODEL = os.environ.get("QWEN_FAST_MODEL", "qwen2.5-coder:7b")
TIMEOUT = int(os.environ.get("QWEN_TIMEOUT", "600"))
MAX_FILE_CHARS = 120_000  # tránh nhồi file quá lớn vào context của Qwen

mcp = FastMCP("qwen-local")


def _post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(
        f"{OLLAMA_URL}{path}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.loads(r.read())


def _chat(prompt: str, system: str = "", fast: bool = False) -> str:
    model = FAST_MODEL if fast else MODEL
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})
    try:
        data = _post("/api/chat", {"model": model, "messages": messages, "stream": False})
        return data["message"]["content"]
    except urllib.error.URLError as e:
        return f"[qwen-local] Không gọi được Ollama ở {OLLAMA_URL}: {e}. Kiểm tra `systemctl status ollama`."
    except Exception as e:  # noqa: BLE001
        return f"[qwen-local] Lỗi khi gọi model {model}: {e}"


@mcp.tool()
def ask_qwen(prompt: str, system: str = "", fast: bool = False) -> str:
    """Giao một việc đơn giản cho Qwen chạy local (miễn phí, không tốn token Claude).
    Hợp với: viết boilerplate, viết test, thêm comment/docstring, dịch, đổi định dạng,
    tóm tắt đoạn văn. KHÔNG dùng cho: thiết kế kiến trúc, debug khó, quyết định quan trọng.
    fast=True dùng model nhỏ (nhanh hơn, kém hơn). Luôn xem lại kết quả trước khi dùng."""
    return _chat(prompt, system, fast)


@mcp.tool()
def qwen_on_file(path: str, instruction: str, fast: bool = False) -> str:
    """Để Qwen tự đọc một file trên máy và xử lý theo instruction (vd: 'tóm tắt file này',
    'viết unit test cho các hàm', 'thêm docstring'). Nội dung file không đi qua Claude nên
    tiết kiệm token rất nhiều với file dài. path nên là đường dẫn tuyệt đối."""
    path = os.path.expanduser(path)
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            content = f.read()
    except OSError as e:
        return f"[qwen-local] Không đọc được file {path}: {e}"
    note = ""
    if len(content) > MAX_FILE_CHARS:
        content = content[:MAX_FILE_CHARS]
        note = f"\n(Lưu ý: file dài, chỉ gửi {MAX_FILE_CHARS} ký tự đầu.)"
    prompt = f"{instruction}\n\n--- FILE: {path} ---\n{content}\n--- HẾT FILE ---{note}"
    return _chat(prompt, fast=fast)


@mcp.tool()
def qwen_status() -> str:
    """Kiểm tra Ollama có đang chạy không và liệt kê các model đã tải."""
    try:
        req = urllib.request.Request(f"{OLLAMA_URL}/api/tags")
        with urllib.request.urlopen(req, timeout=10) as r:
            models = [m["name"] for m in json.loads(r.read()).get("models", [])]
        return f"Ollama OK tại {OLLAMA_URL}. Model: {', '.join(models) or '(chưa có)'}. " \
               f"Đang dùng: chính={MODEL}, nhanh={FAST_MODEL}"
    except Exception as e:  # noqa: BLE001
        return f"[qwen-local] Ollama không phản hồi ở {OLLAMA_URL}: {e}"


if __name__ == "__main__":
    mcp.run()
