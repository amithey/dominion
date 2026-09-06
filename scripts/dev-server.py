"""Serve the local game without stale development assets. Localhost only."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


if __name__ == '__main__':
    root = Path(__file__).resolve().parent.parent
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8771
    server = ThreadingHTTPServer(('127.0.0.1', port), partial(Handler, directory=str(root)))
    print(f'Dominion: http://127.0.0.1:{port}/index.html', flush=True)
    server.serve_forever()
