# Codespace Bug Hunt

Bug-hunting toolchain for a GitHub Codespace, built for a Base chain audit
(Go + Rust + Solidity). Run `setup.sh` once in a blank codespace and it
installs the toolchain. Rebuilding the codespace from this repo's devcontainer
runs the same script automatically.

## What gets installed

| Tool | Purpose |
| --- | --- |
| Go (latest stable) | Base chain code (consensus / execution clients) |
| Rust stable + clippy | reth / Kona / Rust components |
| Foundry (forge, cast, anvil, chisel) | Solidity PoCs — the tool that decides what's real |
| solc 0.8.30 + 0.8.28 (solc-select) | Solidity compilers |
| Slither + crytic-compile | Static analysis (Tier 4 hints, never verdicts) |
| Aderyn | Static analysis |
| Echidna | Property fuzzing |
| Medusa | Property fuzzing |
| Halmos | Symbolic testing |
| hevm | Symbolic execution |
| Wake | Static analysis |
| Mythril | Symbolic analysis |

## What is deliberately NOT here

Certora, Kontrol and a local Gigahorse build. They need far more disk and
time than a 32 GB codespace allows. They stay on the main audit VM, which
has 150 GB and runs continuously.

## Usage

In the codespace terminal:

```bash
bash setup.sh
```

It logs to `~/setup.log` and prints a version summary at the end.
Re-running is safe.

## Free-tier budget (GitHub Free)

120 core-hours a month = 60 hours on this 2-core box, plus 15 GB storage.
The codespace disk is 32 GB, so part of it sits outside the free storage
allowance. It also stops after 30 idle minutes by default and after 12 hours
max. Use the codespace for focused interactive hunting; run long fuzz and
formal jobs on the main VM.

## When the audit drops

Clone the in-scope repos into the codespace, then hunt by the audit skill:
recon first, invariants first, Foundry PoC before any severity claim.
