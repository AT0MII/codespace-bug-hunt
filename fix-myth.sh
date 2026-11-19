#!/usr/bin/env bash
# Fix Mythril: the uv venv (Python 3.12) has no pip, so use uv pip (which installs
# into the venv without needing pip inside it).
set -u
export PATH="$HOME/.local/bin:$HOME/.foundry/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"
LOG="$HOME/fix-myth.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== Fix mythril ==="
echo "Started: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
rm -f "$HOME/.local/bin/myth"
uv pip install --python "$HOME/.venvs/mythril/bin/python" --upgrade pip "setuptools==80.9.0" 2>&1 | tail -3
uv pip install --python "$HOME/.venvs/mythril/bin/python" mythril 2>&1 | tail -5
ln -sf "$HOME/.venvs/mythril/bin/myth" "$HOME/.local/bin/myth"
echo "--- VERIFICATION ---"
for t in go cargo forge cast slither aderyn echidna medusa halmos hevm wake myth; do
  if command -v "$t" >/dev/null 2>&1; then echo "OK   $t"; else echo "MISS $t"; fi
done
echo "aderyn:"; aderyn --version 2>&1 | head -1
echo "medusa:"; medusa --version 2>&1 | head -1
echo "hevm:"; hevm --version 2>&1 | head -1; hevm --help 2>&1 | head -2
echo "myth:"; myth --version 2>&1 | head -2
df -h "$HOME" | tail -1
echo "Finished: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Full log: $LOG"
