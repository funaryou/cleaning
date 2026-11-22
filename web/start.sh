#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "http://127.0.0.1:8000/black.html をブラウザで開いてください（終了: Ctrl+C）。"
exec python3 -m http.server 8000 --bind 127.0.0.1 --directory "$SCRIPT_DIR"
