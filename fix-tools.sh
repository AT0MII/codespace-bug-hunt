#!/usr/bin/env bash
# Fix the four tools that failed in setup.sh: aderyn, medusa, hevm, mythril.
# Run in the codespace: bash fix-tools.sh
# Logs to ~/fix-tools.log and prints a verification summary.
set -u
export DEBIAN_FRONTEND=noninteractive
LOG="$HOME/fix-tools.log"
exec > >(tee -a "$LOG") 2>&1
export PATH="$HOME/.local/bin:$HOME/.foundry/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"

echo "=== Fix tools ==="
echo "Started: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# --- Aderyn: retired upstream (no official download); restore exact 0.6.8 binary hosted in this repo ---
echo "--- aderyn ---"
rm -f "$HOME/.local/bin/aderyn"
curl -fsSL "https://raw.githubusercontent.com/AT0MII/codespace-bug-hunt/main/bin/aderyn" -o "$HOME/.local/bin/aderyn" && chmod +x "$HOME/.local/bin/aderyn" || echo "WARN: aderyn download failed"
aderyn --version 2>&1 | head -2 || echo "WARN: aderyn not working"

# --- Medusa: correct asset name is medusa-linux-x64.tar.gz (not linux-amd64) ---
echo "--- medusa ---"
curl -fsSL "https://github.com/crytic/medusa/releases/download/v1.5.1/medusa-linux-x64.tar.gz" -o /tmp/medusa.tar.gz \
  && tar -xzf /tmp/medusa.tar.gz -C /tmp \
  && chmod +x /tmp/medusa \
  && mv -f /tmp/medusa "$HOME/.local/bin/medusa" \
  || echo "WARN: medusa install failed"
rm -f /tmp/medusa.tar.gz
medusa version 2>&1 | head -2 || echo "WARN: medusa not working"

# --- hevm: the binary inside the tarball is named hevm-linux-x64, not hevm ---
echo "--- hevm ---"
curl -fsSL "https://github.com/dapphub/hevm/releases/download/v0.12/hevm-v0.12-linux-x64.tar.gz" -o /tmp/hevm.tar.gz \
  && tar -xzf /tmp/hevm.tar.gz -C /tmp \
  && chmod +x /tmp/hevm-linux-x64 \
  && mv -f /tmp/hevm-linux-x64 "$HOME/.local/bin/hevm" \
  || echo "WARN: hevm install failed"
rm -f /tmp/hevm.tar.gz
hevm version 2>&1 | head -2 || echo "WARN: hevm not working"

# --- Mythril: the 3.14 venv never got the package; use a Python 3.12 venv via uv (mythril 0.24.8 targets 3.12) ---
echo "--- mythril ---"
rm -f "$HOME/.local/bin/myth"
rm -rf "$HOME/.venvs/mythril"
uv python install 3.12 2>&1 | tail -2 || echo "WARN: uv python install 3.12 failed"
uv venv --python 3.12 "$HOME/.venvs/mythril" 2>&1 | tail -2 || echo "WARN: mythril venv creation failed"
"$HOME/.venvs/mythril/bin/pip" install --upgrade pip "setuptools==80.9.0" 2>&1 | tail -3
"$HOME/.venvs/mythril/bin/pip" install mythril 2>&1 | tail -5 || echo "WARN: mythril pip install failed"
ln -sf "$HOME/.venvs/mythril/bin/myth" "$HOME/.local/bin/myth"
myth --version 2>&1 | head -3 || echo "WARN: myth not working"

# --- verification: full summary ---
echo "--- VERIFICATION ---"
for t in go cargo forge cast slither aderyn echidna medusa halmos hevm wake myth; do
  if command -v "$t" >/dev/null 2>&1; then echo "OK   $t"; else echo "MISS $t"; fi
done
echo "aderyn:"; aderyn --version 2>&1 | head -1
echo "medusa:"; medusa version 2>&1 | head -1
echo "hevm:"; hevm version 2>&1 | head -1
echo "myth:"; myth --version 2>&1 | head -2
df -h "$HOME" | tail -1
echo "Finished: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Full log: $LOG"
