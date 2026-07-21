"""Локальный сервер PWA + прокси API на khushrang.tj для тестов."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import urllib.request
import os

API_ORIGIN = "https://khushrang.tj"
WEB_DIR = os.path.dirname(os.path.abspath(__file__))
PORT = 8765

PROXY_PREFIXES = (
    "/products",
    "/masters",
    "/orders",
    "/site/",
    "/auth/",
    "/client/",
    "/chat/",
    "/brands",
    "/static/",
)


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        if self.path.startswith(PROXY_PREFIXES):
            return self._proxy()
        return super().do_GET()

    def do_POST(self):
        if self.path.startswith(PROXY_PREFIXES):
            return self._proxy()
        self.send_error(404)

    def do_OPTIONS(self):
        if self.path.startswith(PROXY_PREFIXES):
            self.send_response(204)
            self._cors_headers()
            self.end_headers()
            return
        self.send_error(404)

    def _proxy(self):
        url = API_ORIGIN + self.path
        body = None
        if self.command == "POST":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length) if length else None
        req = urllib.request.Request(
            url,
            data=body,
            method=self.command,
            headers={
                k: v
                for k, v in self.headers.items()
                if k.lower() not in {"host", "connection", "content-length"}
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    lk = k.lower()
                    if lk in {"transfer-encoding", "connection", "content-encoding"}:
                        continue
                    self.send_header(k, v)
                self._cors_headers()
                self.end_headers()
                self.wfile.write(data)
        except Exception as e:
            self.send_error(502, str(e))

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, Authorization",
        )

    def log_message(self, fmt, *args):
        print(f"[{self.command}] {args[0]}")


if __name__ == "__main__":
    os.chdir(WEB_DIR)
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"PWA dev server: http://127.0.0.1:{PORT}/  (API -> {API_ORIGIN})")
    server.serve_forever()
