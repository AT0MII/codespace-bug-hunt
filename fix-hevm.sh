#!/usr/bin/env bash
# Upgrade hevm from the old dapphub v0.12 to the current ethereum/hevm 0.58.0,
# then run a final full verification with correct version probes.
set -u
export PATH="$HOME/.local/bin:$HOME/.foundry/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"
LOG="$HOME/fix-hevm.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== Upgrade hevm to 0.58.0 ==="
echo "Started: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
curl -fsSL "https://github.com/ethereum/hevm/releases/download/release%2F0.58.0/hevm-x86_64-linux" -o /tmp/hevm-0.58.0 \
  && chmod +x /tmp/hevm-0.58.0 \
  && mv -f /tmp/hevm-0.58.0 "$HOME/.local/bin/hevm" \
  || echo "WARN: hevm 0.58.0 install failed"
hevm version 2>&1 | head -2 || echo "WARN: hevm not working"
echo "--- FINAL VERIFICATION ---"
for t in go cargo forge cast slither aderyn echidna medusa halmos hevm wake myth; do
  if command -v "$t" >/dev/null 2>&1; then echo "OK   $t"; else echo "MISS $t"; fi
done
echo "go:"; go version 2>&1 | head -1
echo "cargo:"; cargo --version 2>&1 | head -1
echo "forge:"; forge --version 2>&1 | head -1
echo "cast:"; cast --version 2>&1 | head -1
echo "slither:"; slither --version 2>&1 | head -1
echo "aderyn:"; aderyn --version 2>&1 | head -1
echo "echidna:"; echidna --version 2>&1 | head -1
echo "medusa:"; medusa --version 2>&1 | head -1
echo "halmos:"; halmos --version 2>&1 | head -1
echo "hevm:"; hevm version 2>&1 | head -1
echo "wake:"; wake --version 2>&1 | head -1
echo "myth:"; myth --version 2>&1 | grep -v SyntaxWarning | grep -v "tokens = re.split" | head -3
df -h "$HOME" | tail -1
echo "Finished: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Full log: $LOG"
