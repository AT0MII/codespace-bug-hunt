#!/usr/bin/env bash
# Bug-hunt toolchain setup for a GitHub Codespace (2-core / 8 GB / 32 GB).
# Built for a Base chain audit: Go + Rust + Solidity.
# Non-interactive. Logs to ~/setup.log. Safe to re-run.
# Heavy formal tools (Certora, Kontrol, Gigahorse local build) are deliberately
# left out: they need far more disk/time than a 32 GB codespace allows.
# They stay on the main audit VM.

set -u
export DEBIAN_FRONTEND=noninteractive
LOG="$HOME/setup.log"
exec > >(tee -a "$LOG") 2>&1

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
export PATH="$HOME/.local/bin:$HOME/.foundry/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"

echo "=== Bug-hunt Codespace setup ==="
echo "Started: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
df -h "$HOME" | tail -1

# ---------- helpers ----------
ensure_path() {
  grep -qxF "$1" "$HOME/.bashrc" 2>/dev/null || echo "$1" >> "$HOME/.bashrc"
}

# gh_asset_url <owner/repo> <substring of asset name> -> download URL or empty
gh_asset_url() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | python3 -c "import sys,json; pat=sys.argv[1]; d=json.load(sys.stdin); print(next((a['browser_download_url'] for a in d.get('assets',[]) if pat in a['name']), ''))" "$2" 2>/dev/null || true
}

ok()   { command -v "$1" >/dev/null 2>&1 && echo "OK   $1" || echo "MISS $1"; }
note() { echo "--- $1 ---"; }

mkdir -p "$HOME/.local/bin" "$HOME/.venvs"

# ---------- system packages ----------
note "system packages"
$SUDO apt-get update -qq 2>/dev/null || true
$SUDO apt-get install -y -qq build-essential git curl wget jq unzip python3 python3-venv python3-pip 2>/dev/null || echo "WARN: apt install had errors (continuing)"

# ---------- Go (latest stable) ----------
note "Go"
if ! command -v go >/dev/null 2>&1; then
  GO_URL=$(curl -fsSL "https://go.dev/dl/?mode=json" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); f=next((x for x in d[0]['files'] if x['os']=='linux' and x['arch']=='amd64' and x['kind']=='archive'), None); print('https://go.dev/dl/'+f['filename'] if f else '')" 2>/dev/null || true)
  if [ -n "${GO_URL:-}" ]; then
    curl -fsSL "$GO_URL" -o /tmp/go.tgz && $SUDO tar -C /usr/local -xzf /tmp/go.tgz && rm -f /tmp/go.tgz
    export PATH="/usr/local/go/bin:$PATH"
    ensure_path 'export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"'
  else
    echo "WARN: could not resolve Go download URL"
  fi
fi
go version 2>/dev/null || echo "WARN: go not installed"

# ---------- Rust (stable + clippy) ----------
note "Rust"
if ! command -v cargo >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable 2>&1 | tail -2 || echo "WARN: rustup install had errors"
  # shellcheck disable=SC1091
  [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
  rustup component add clippy 2>/dev/null || echo "WARN: clippy install failed"
fi
ensure_path 'export PATH="$HOME/.cargo/bin:$PATH"'
cargo --version 2>/dev/null; rustc --version 2>/dev/null

# ---------- Foundry ----------
note "Foundry"
if ! command -v forge >/dev/null 2>&1; then
  curl -fsSL https://foundry.paradigm.xyz | bash 2>&1 | tail -2 || echo "WARN: foundry installer had errors"
  export PATH="$HOME/.foundry/bin:$PATH"
  "$HOME/.foundry/bin/foundryup" 2>&1 | tail -3 || echo "WARN: foundryup had errors"
fi
ensure_path 'export PATH="$HOME/.foundry/bin:$PATH"'
forge --version 2>/dev/null; cast --version 2>/dev/null

# ---------- Python venvs: solc-select, Slither, Wake, Mythril ----------
note "Python toolchains"
python3 -m venv "$HOME/.venvs/audit-tools" 2>/dev/null || true
"$HOME/.venvs/audit-tools/bin/pip" install -q --upgrade pip setuptools 2>&1 | tail -1 || true
"$HOME/.venvs/audit-tools/bin/pip" install -q solc-select slither-analyzer crytic-compile 2>&1 | tail -1 || echo "WARN: audit-tools pip install had errors"
ln -sf "$HOME/.venvs/audit-tools/bin/slither" "$HOME/.local/bin/slither" 2>/dev/null || true
ln -sf "$HOME/.venvs/audit-tools/bin/solc-select" "$HOME/.local/bin/solc-select" 2>/dev/null || true
ln -sf "$HOME/.venvs/audit-tools/bin/crytic-compile" "$HOME/.local/bin/crytic-compile" 2>/dev/null || true
# solc versions (0.8.30 current, 0.8.28 for older audit pragmas)
"$HOME/.venvs/audit-tools/bin/solc-select" install 0.8.30 0.8.28 2>&1 | tail -2 || echo "WARN: solc install had errors"
"$HOME/.venvs/audit-tools/bin/solc-select" use 0.8.30 2>/dev/null || true

python3 -m venv "$HOME/.venvs/wake" 2>/dev/null || true
"$HOME/.venvs/wake/bin/pip" install -q --upgrade pip 2>&1 | tail -1 || true
"$HOME/.venvs/wake/bin/pip" install -q eth-wake 2>&1 | tail -1 || echo "WARN: wake install had errors"
ln -sf "$HOME/.venvs/wake/bin/wake" "$HOME/.local/bin/wake" 2>/dev/null || true

python3 -m venv "$HOME/.venvs/mythril" 2>/dev/null || true
"$HOME/.venvs/mythril/bin/pip" install -q --upgrade pip "setuptools==80.9.0" 2>&1 | tail -1 || true
"$HOME/.venvs/mythril/bin/pip" install -q mythril 2>&1 | tail -1 || echo "WARN: mythril install had errors"
ln -sf "$HOME/.venvs/mythril/bin/myth" "$HOME/.local/bin/myth" 2>/dev/null || true

# ---------- uv + Halmos ----------
note "uv + Halmos"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh 2>&1 | tail -2 || echo "WARN: uv install had errors"
  export PATH="$HOME/.local/bin:$PATH"
fi
uv tool install halmos 2>&1 | tail -2 || echo "WARN: halmos install had errors"

# ---------- prebuilt binaries: Aderyn, Echidna, Medusa, hevm ----------
note "Aderyn / Echidna / Medusa / hevm"
install_bin() {
  # $1 = owner/repo, $2 = asset substring, $3 = binary name inside tarball (or '' if the asset IS the binary)
  local url bin="$3"
  url=$(gh_asset_url "$1" "$2")
  if [ -z "$url" ]; then echo "WARN: no release asset found for $1 ($2)"; return 0; fi
  echo "fetching $url"
  curl -fsSL "$url" -o /tmp/dl-asset || { echo "WARN: download failed: $url"; return 0; }
  case "$url" in
    *.tar.gz|*.tgz) tar -xzf /tmp/dl-asset -C /tmp || { echo "WARN: extract failed: $url"; return 0; } ;;
    *.tar.xz)       tar -xJf /tmp/dl-asset -C /tmp || { echo "WARN: extract failed: $url"; return 0; } ;;
    *.zip)          unzip -o -q /tmp/dl-asset -d /tmp || { echo "WARN: extract failed: $url"; return 0; } ;;
    *)              cp /tmp/dl-asset "/tmp/$bin" ;;
  esac
  if [ -n "$bin" ] && [ -f "/tmp/$bin" ]; then
    chmod +x "/tmp/$bin"; mv -f "/tmp/$bin" "$HOME/.local/bin/$bin"
  fi
  rm -f /tmp/dl-asset
}
install_bin "Cyfrin/aderyn" "x86_64-unknown-linux-gnu.tar.xz" "aderyn"
install_bin "crytic/echidna" "x86_64-linux.tar.gz" "echidna"
install_bin "crytic/medusa" "linux-amd64.tar.gz" "medusa"
install_bin "dapphub/hevm" "linux" "hevm"

# ---------- environment ----------
note "environment"
ensure_path 'export PATH="$HOME/.local/bin:$HOME/.foundry/bin:$HOME/go/bin:$HOME/.cargo/bin:$PATH"'
echo "docker:"; docker --version 2>/dev/null || echo "WARN: docker not available"
echo "node:"; node --version 2>/dev/null || echo "node not present (optional)"

# ---------- summary ----------
note "SUMMARY (versions)"
ok go; go version 2>/dev/null
ok cargo; cargo --version 2>/dev/null
ok forge; forge --version 2>/dev/null | head -1
ok cast; cast --version 2>/dev/null | head -1
ok slither; slither --version 2>/dev/null
ok aderyn; aderyn --version 2>/dev/null | head -1
ok echidna; echidna --version 2>/dev/null | head -1
ok medusa; medusa version 2>/dev/null | head -1
ok halmos; halmos --version 2>/dev/null | head -1
ok hevm; hevm version 2>/dev/null | head -1
ok wake; wake --version 2>/dev/null | head -1
ok myth; myth --version 2>/dev/null | head -1
echo "--- disk ---"
df -h "$HOME" | tail -1
echo "Finished: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Full log: $LOG"
