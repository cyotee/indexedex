#!/usr/bin/env bash
# Sync Bankr skills for the parent DeFi workspace — NOT into IndexedEx skill trees.
#
# Canonical store (still vendored here for refresh): lib/bankr-skills/
# Destinations (parent workspace, so IndexedEx sessions stay lean):
#   ../../.claude/skills/   — Claude Code under projects-defi
#   ../../.opencode/skills/ — OpenCode under projects-defi
#   ../../.grok/skills/     — Grok Build under projects-defi
#
# IndexedEx keeps only Crane + IndexedEx-local skills under .claude/.grok/.opencode.
# Override dest with BANKR_SKILLS_DEST_ROOT if needed.
#
# Usage:
#   ./scripts/sync-bankr-skills.sh              # sync from vendored lib/bankr-skills
#   ./scripts/sync-bankr-skills.sh --expand-stubs  # expand external stubs, then sync
#   ./scripts/sync-bankr-skills.sh --refresh     # re-clone Bankr + expand stubs + sync
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CANON="$ROOT/lib/bankr-skills"
REPO_URL="https://github.com/BankrBot/skills.git"
ETHSKILLS_URL="https://github.com/austintgriffith/ethskills.git"
BASE_SKILLS_URL="https://github.com/base/base-skills.git"
UNISWAP_AI_URL="https://github.com/Uniswap/uniswap-ai.git"
# Parent of daosys/lib/indexedex → projects-defi (…/projects-defi/daosys/lib/indexedex)
DEFAULT_DEST_ROOT="$(cd "$ROOT/../../.." && pwd)"
DEST_ROOT="${BANKR_SKILLS_DEST_ROOT:-$DEFAULT_DEST_ROOT}"
DESTS=(
  "$DEST_ROOT/.claude/skills"
  "$DEST_ROOT/.opencode/skills"
  "$DEST_ROOT/.grok/skills"
)

rewrite_skill_name() {
  local path="$1" name="$2"
  python3 - "$path" "$name" <<'PY'
import sys, re
path, name = sys.argv[1], sys.argv[2]
text = open(path).read()
if text.startswith("---"):
    parts = text.split("---", 2)
    if len(parts) >= 3:
        fm, body = parts[1], parts[2]
        if re.search(r"(?m)^name:\s*", fm):
            fm = re.sub(r"(?m)^name:\s*.*$", f"name: {name}", fm, count=1)
        else:
            fm = f"\nname: {name}" + fm
        open(path, "w").write(f"---{fm}\n---{body}")
PY
}

refresh_vendor() {
  local tmp
  tmp="$(mktemp -d)"
  echo "Cloning $REPO_URL (shallow)..."
  git clone --depth 1 "$REPO_URL" "$tmp/bankr-skills"
  rm -rf "$CANON"
  mkdir -p "$CANON"
  local count=0
  for dir in "$tmp/bankr-skills"/*/; do
    name="$(basename "$dir")"
    if [[ -f "$dir/SKILL.md" ]]; then
      cp -R "$dir" "$CANON/$name"
      count=$((count + 1))
    fi
  done
  cat > "$CANON/SOURCE.md" << 'EOF'
# Bankr Skills (vendored)

Source: https://github.com/BankrBot/skills
Install / refresh: `./scripts/sync-bankr-skills.sh`

These skill packages are synced into the parent DeFi workspace
(projects-defi/.claude|/.opencode|/.grok/skills), not into IndexedEx agent dirs.

External stubs (EthSkills, Base, Uniswap) are expanded from their upstream repos
via `./scripts/sync-bankr-skills.sh --expand-stubs` (also runs on `--refresh`).

Do not edit skill content here for long-lived customizations; re-sync will overwrite.
IndexedEx-local skills stay under IndexedEx `.claude/skills/` (mirrored to OpenCode/Grok).
EOF
  (
    cd "$tmp/bankr-skills"
    echo "repo=https://github.com/BankrBot/skills"
    echo "commit=$(git rev-parse HEAD)"
    echo "date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  ) > "$CANON/SOURCE.lock"
  rm -rf "$tmp"
  echo "Vendored $count skills into $CANON"
}

# Fill Bankr external stubs with full content from upstream skill repos.
expand_stubs() {
  if [[ ! -d "$CANON" ]]; then
    echo "Missing vendored skills at $CANON; run --refresh first" >&2
    exit 1
  fi

  local tmp eth base uni
  tmp="$(mktemp -d)"
  echo "Cloning external skill sources for stub expansion..."
  git clone --depth 1 "$ETHSKILLS_URL" "$tmp/ethskills"
  git clone --depth 1 "$BASE_SKILLS_URL" "$tmp/base-skills"
  git clone --depth 1 "$UNISWAP_AI_URL" "$tmp/uniswap-ai"
  eth="$tmp/ethskills"
  base="$tmp/base-skills"
  uni="$tmp/uniswap-ai"

  {
    echo "expanded_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "ethskills_repo=$ETHSKILLS_URL"
    (cd "$eth" && echo "ethskills_commit=$(git rev-parse HEAD)")
    echo "base_skills_repo=$BASE_SKILLS_URL"
    (cd "$base" && echo "base_skills_commit=$(git rev-parse HEAD)")
    echo "uniswap_ai_repo=$UNISWAP_AI_URL"
    (cd "$uni" && echo "uniswap_ai_commit=$(git rev-parse HEAD)")
  } > "$CANON/SOURCE-STUBS.lock"

  # --- EthSkills catalog stubs ---
  local pairs=(
    "ethskills-addresses:addresses"
    "ethskills-audit:audit"
    "ethskills-building-blocks:building-blocks"
    "ethskills-frontend-playbook:frontend-playbook"
    "ethskills-frontend-ux:frontend-ux"
    "ethskills-gas:gas"
    "ethskills-indexing:indexing"
    "ethskills-l2s:l2s"
    "ethskills-orchestration:orchestration"
    "ethskills-qa:qa"
    "ethskills-security:security"
    "ethskills-standards:standards"
    "ethskills-testing:testing"
    "ethskills-tools:tools"
    "ethskills-wallets:wallets"
    "ethskills-why:why"
  )
  local pair bankr_name src_name src dest tmp_keep f
  for pair in "${pairs[@]}"; do
    bankr_name="${pair%%:*}"
    src_name="${pair##*:}"
    src="$eth/$src_name"
    dest="$CANON/$bankr_name"
    [[ -f "$src/SKILL.md" ]] || { echo "WARN: missing $src/SKILL.md" >&2; continue; }
    mkdir -p "$dest"
    tmp_keep="$(mktemp -d)"
    for f in catalog.json logo.svg logo.png ethskills.png; do
      [[ -f "$dest/$f" ]] && cp "$dest/$f" "$tmp_keep/" || true
    done
    rsync -a --delete \
      --exclude='catalog.json' --exclude='logo.svg' --exclude='logo.png' --exclude='ethskills.png' \
      "$src/" "$dest/"
    for f in catalog.json logo.svg logo.png ethskills.png; do
      [[ -f "$tmp_keep/$f" ]] && cp "$tmp_keep/$f" "$dest/" || true
    done
    rm -rf "$tmp_keep"
    rewrite_skill_name "$dest/SKILL.md" "$bankr_name"
    echo "expanded $bankr_name"
  done

  # Extra ethskills packages not listed as Bankr stubs
  local extra
  for extra in contracts defi concepts protocol ship noir feedback; do
    src="$eth/$extra"
    [[ -f "$src/SKILL.md" ]] || continue
    dest="$CANON/ethskills-$extra"
    mkdir -p "$dest"
    rsync -a "$src/" "$dest/"
    rewrite_skill_name "$dest/SKILL.md" "ethskills-$extra"
    echo "added ethskills-$extra"
  done

  # --- Base full packages + focused stubs ---
  local pkg bob
  for pkg in base-mcp build-on-base; do
    src="$base/skills/$pkg"
    dest="$CANON/$pkg"
    mkdir -p "$dest"
    rsync -a --delete "$src/" "$dest/"
    echo "installed $pkg"
  done
  bob="$base/skills/build-on-base"

  cat > "$CANON/base-network/SKILL.md" <<'EOF'
---
name: base-network
description: Base Mainnet and Sepolia network configuration — RPC endpoints, chain IDs, explorer URLs, and wallet setup for Base blockchain development. Use when configuring Base chain connectivity, RPC, or testnet setup.
metadata:
  expanded_from: base/base-skills (build-on-base/references/network.md)
---

# Base Network Configuration

EOF
  cat "$bob/references/network.md" >> "$CANON/base-network/SKILL.md"
  mkdir -p "$CANON/base-network/references"
  cp "$bob/references/network.md" "$CANON/base-network/references/"

  cat > "$CANON/base-deploy/SKILL.md" <<'EOF'
---
name: base-deploy
description: Deploy and verify smart contracts on Base with Foundry — testnet faucet access via CDP, encrypted keystore management, BaseScan verification, and common troubleshooting. Use when deploying contracts to Base or Base Sepolia.
metadata:
  expanded_from: base/base-skills (build-on-base/references/deploy-contracts.md)
---

# Deploy Contracts on Base

EOF
  cat "$bob/references/deploy-contracts.md" >> "$CANON/base-deploy/SKILL.md"
  mkdir -p "$CANON/base-deploy/references"
  cp "$bob/references/deploy-contracts.md" "$CANON/base-deploy/references/"

  cat > "$CANON/base-node/SKILL.md" <<'EOF'
---
name: base-node
description: Run a production Base node with Reth client — hardware sizing, port configuration, snapshot bootstrapping, security hardening, and sync monitoring. Use when self-hosting Base RPC or running a Base node.
metadata:
  expanded_from: base/base-skills (build-on-base/references/run-node.md)
---

# Run a Base Node

EOF
  cat "$bob/references/run-node.md" >> "$CANON/base-node/SKILL.md"
  mkdir -p "$CANON/base-node/references"
  cp "$bob/references/run-node.md" "$CANON/base-node/references/"

  rm -rf "$CANON/base-account/references"
  mkdir -p "$CANON/base-account/references"
  cp -R "$bob/references/base-account/." "$CANON/base-account/references/"
  cat > "$CANON/base-account/SKILL.md" <<'EOF'
---
name: base-account
description: ERC-4337 smart wallet integration — Sign in with Base, one-tap USDC payments, gas sponsorship via paymasters, sub accounts, and spend permissions across chains. Use when integrating Base Account, SIWB, Base Pay, or paymasters.
metadata:
  expanded_from: base/base-skills (build-on-base/references/base-account/)
---

# Base Account

Full Base Account documentation is under `references/`. Start with the overview, then load the topic you need.

## Contents

- [overview.md](references/overview.md) — Base Account overview
- [authentication.md](references/authentication.md) — Sign in with Base
- [payments.md](references/payments.md) — Base Pay / USDC payments
- [capabilities.md](references/capabilities.md) — Account capabilities
- [sub-accounts.md](references/sub-accounts.md) — Sub accounts
- [subscriptions.md](references/subscriptions.md) — Subscriptions
- [prolinks.md](references/prolinks.md) — Prolinks
- [troubleshooting.md](references/troubleshooting.md) — Troubleshooting

## Overview

EOF
  cat "$bob/references/base-account/overview.md" >> "$CANON/base-account/SKILL.md"

  rm -rf "$CANON/base-minikit/references"
  mkdir -p "$CANON/base-minikit/references"
  cp -R "$bob/references/migrations/minikit-to-farcaster/." "$CANON/base-minikit/references/"
  if [[ -f "$bob/references/migrations/farcaster-miniapp-to-app.md" ]]; then
    cp "$bob/references/migrations/farcaster-miniapp-to-app.md" "$CANON/base-minikit/references/"
  fi
  cat > "$CANON/base-minikit/SKILL.md" <<'EOF'
---
name: base-minikit
description: Migrate Mini Apps from MiniKit (OnchainKit) to native Farcaster SDK — async context patterns, hook-by-hook mappings, FrameProvider setup, and manifest configuration. Use when migrating MiniKit or Farcaster mini apps.
metadata:
  expanded_from: base/base-skills (build-on-base/references/migrations/minikit-to-farcaster/)
---

# MiniKit → Farcaster SDK Migration

Detailed guides are under `references/`. Start with the overview.

## Contents

- [overview.md](references/overview.md)
- [dependencies.md](references/dependencies.md)
- [mapping.md](references/mapping.md)
- [provider.md](references/provider.md)
- [auth.md](references/auth.md)
- [manifest.md](references/manifest.md)
- [examples.md](references/examples.md)
- [pitfalls.md](references/pitfalls.md)

## Overview

EOF
  cat "$bob/references/migrations/minikit-to-farcaster/overview.md" >> "$CANON/base-minikit/SKILL.md"

  cat > "$CANON/base/SKILL.md" <<'EOF'
---
name: base
description: Base ecosystem skill index — network config, contract deploy, Base Account, MiniKit migration, node ops, and Base MCP. Use when working on Base chain apps, agents, or infrastructure.
metadata:
  expanded_from: base/base-skills
---

# Base Skills Index

This is the Base suite entry point. Prefer the focused skills below (and the full `build-on-base` / `base-mcp` packages).

| Skill | Use for |
|-------|---------|
| `build-on-base` | Complete Base development playbook (all topics) |
| `base-mcp` | Base MCP server — wallet, swap, x402, batched calls |
| `base-network` | RPC, chain IDs, explorers, wallet setup |
| `base-deploy` | Foundry deploy + BaseScan verify + faucet |
| `base-account` | Sign in with Base, payments, paymasters, sub-accounts |
| `base-minikit` | MiniKit → Farcaster SDK migration |
| `base-node` | Self-hosted Base node (Reth) |

Upstream: https://github.com/base/base-skills
EOF
  echo "expanded base suite stubs"

  # --- Uniswap plugin stubs ---
  install_uni_plugin() {
    local plugin="$1"
    local src="$uni/packages/plugins/$plugin"
    local dest="$CANON/$plugin"
    local sub subname top dest_top extra
    [[ -d "$src" ]] || { echo "WARN: missing $src" >&2; return; }
    mkdir -p "$dest"
    tmp_keep="$(mktemp -d)"
    for f in catalog.json logo.svg logo.png uniswap.svg; do
      [[ -f "$dest/$f" ]] && cp "$dest/$f" "$tmp_keep/" || true
    done
    mkdir -p "$dest/skills"
    [[ -d "$src/skills" ]] && rsync -a "$src/skills/" "$dest/skills/"
    for extra in commands agents scripts references; do
      [[ -d "$src/$extra" ]] && rsync -a "$src/$extra/" "$dest/$extra/"
    done
    if [[ -f "$src/.claude-plugin/plugin.json" ]]; then
      mkdir -p "$dest/.claude-plugin"
      cp "$src/.claude-plugin/plugin.json" "$dest/.claude-plugin/"
    fi
    for f in catalog.json logo.svg logo.png uniswap.svg; do
      [[ -f "$tmp_keep/$f" ]] && cp "$tmp_keep/$f" "$dest/" || true
    done
    rm -rf "$tmp_keep"

    python3 - "$plugin" "$src" "$dest" <<'PY'
import sys, re
from pathlib import Path
plugin, src, dest = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
skills_dir = src / "skills"
subs = []
if skills_dir.is_dir():
    for d in sorted(skills_dir.iterdir()):
        skill = d / "SKILL.md"
        if not skill.exists():
            continue
        text = skill.read_text(errors="ignore")
        desc, name = "", d.name
        parts = text.split("---", 2) if text.startswith("---") else None
        if parts and len(parts) >= 3:
            fm, body = parts[1], parts[2]
            m = re.search(r"(?m)^name:\s*(.+)$", fm)
            if m:
                name = m.group(1).strip().strip('"').strip("'")
            m = re.search(r"(?m)^description:\s*(.+)$", fm)
            if m:
                desc = m.group(1).strip().strip('"').strip("'")
            else:
                m = re.search(r"(?ms)^description:\s*[|>]?\s*\n((?:  .+\n)+)", fm)
                if m:
                    desc = " ".join(l.strip() for l in m.group(1).splitlines())
        else:
            body = text
        if not desc:
            for line in body.splitlines():
                line = line.strip()
                if line and not line.startswith("#") and not line.startswith(">"):
                    desc = line
                    break
        subs.append((d.name, name, desc[:240]))
defaults = {
  "uniswap-cca": "Configure and deploy Continuous Clearing Auction (CCA) smart contracts — guided parameter setup, convex supply schedule generation, Q96 price calculations, and multi-chain CREATE2 deployment.",
  "uniswap-driver": "Plan Uniswap swaps and liquidity positions then execute via deep links — verify tokens on-chain, research market conditions, and generate pre-filled Uniswap interface URLs across 12 chains.",
  "uniswap-hooks": "Security-first assistance for building Uniswap v4 hooks — threat modeling, permission flags analysis, NoOp attack prevention, delta accounting, and pre-deployment audit checklists.",
  "uniswap-trading": "Integrate Uniswap swaps into frontends, backends, and smart contracts — V2/V3/V4 support via Trading API, Universal Router, or direct contract calls.",
  "uniswap-viem": "EVM blockchain integration using viem and wagmi — wallet connection, contract reads/writes, real-time event subscriptions, multicall, and multi-chain support.",
  "uniswap-trading-tools": "Uniswap trading tools — DCA bots, copy trade, and index bot skills.",
}
desc = defaults.get(plugin, f"Uniswap AI plugin: {plugin}")
lines = [
  "---", f"name: {plugin}", f"description: {desc}",
  "metadata:", "  expanded_from: Uniswap/uniswap-ai", f"  plugin: {plugin}",
  "---", "", f"# {plugin}", "",
  "Full Uniswap AI plugin content (from `Uniswap/uniswap-ai`). Sub-skills live under `skills/`.",
  "", "Load the relevant sub-skill `skills/<name>/SKILL.md` (and its references) for the task.",
  "", "## Sub-skills", "",
]
if subs:
    lines += ["| Directory | Name | Description |", "|-----------|------|-------------|"]
    for dname, sname, sdesc in subs:
        lines.append(f"| [`skills/{dname}/`](skills/{dname}/SKILL.md) | {sname} | {sdesc.replace('|', '\\|')} |")
else:
    lines.append("_No nested skills found._")
lines += ["", "## How to use", "",
  "1. Identify which sub-skill matches the user request.",
  "2. Read that sub-skill's `SKILL.md` fully before acting.",
  "3. Follow its steps, scripts, and security notes.",
  "", "Upstream: https://github.com/Uniswap/uniswap-ai", ""]
(dest / "SKILL.md").write_text("\n".join(lines))
print(f"expanded {plugin}: {len(subs)} sub-skills")
PY

    if [[ -d "$src/skills" ]]; then
      for sub in "$src/skills"/*/; do
        [[ -f "$sub/SKILL.md" ]] || continue
        subname="$(basename "$sub")"
        top="${plugin}-${subname}"
        dest_top="$CANON/$top"
        mkdir -p "$dest_top"
        rsync -a --delete "$sub/" "$dest_top/"
        rewrite_skill_name "$dest_top/SKILL.md" "$top"
        echo "  + leaf $top"
      done
    fi
  }

  local p
  for p in uniswap-cca uniswap-driver uniswap-hooks uniswap-trading uniswap-viem uniswap-trading-tools; do
    install_uni_plugin "$p"
  done

  cat > "$CANON/zapper/SKILL.md" <<'EOF'
---
name: zapper
description: Placeholder for Zapper skill. No full skill package was published under BankrBot/skills beyond this stub. Prefer Alchemy, Zerion, or protocol-specific portfolio skills for wallet/portfolio data.
---

# Zapper (placeholder)

Bankr lists `zapper` as a placeholder with no external install target. When portfolio data is needed:

- Prefer `alchemy` or `zerion` skills already installed in this repo
- Or use Zapper’s public API docs if the user supplies an API key

Do not invent Zapper API endpoints or keys.
EOF

  rm -rf "$tmp"
  echo "Stub expansion complete. Provenance: $CANON/SOURCE-STUBS.lock"
}

sync_to_dests() {
  if [[ ! -d "$CANON" ]]; then
    echo "Missing vendored skills at $CANON" >&2
    echo "Run: $0 --refresh" >&2
    exit 1
  fi

  local synced=0
  local skill_dirs=()
  local dir name dest
  for dir in "$CANON"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ -f "$dir/SKILL.md" ]] || continue
    skill_dirs+=("$name")
  done

  for dest in "${DESTS[@]}"; do
    mkdir -p "$dest"
    for name in "${skill_dirs[@]}"; do
      rm -rf "$dest/$name"
      cp -R "$CANON/$name" "$dest/$name"
      synced=$((synced + 1))
    done
    echo "synced ${#skill_dirs[@]} skills -> $dest/"
  done

  echo "Done. Source: $CANON (${#skill_dirs[@]} skills, $synced package-writes)"
  if [[ -f "$CANON/SOURCE.lock" ]]; then
    echo "Provenance:"
    sed 's/^/  /' "$CANON/SOURCE.lock"
  fi
  if [[ -f "$CANON/SOURCE-STUBS.lock" ]]; then
    echo "Stub expansion:"
    sed 's/^/  /' "$CANON/SOURCE-STUBS.lock"
  fi
}

main() {
  local do_refresh=0 do_expand=0
  local arg
  for arg in "$@"; do
    case "$arg" in
      --refresh) do_refresh=1; do_expand=1 ;;
      --expand-stubs) do_expand=1 ;;
      -h|--help)
        sed -n '2,16p' "$0"
        exit 0
        ;;
      *)
        echo "Unknown option: $arg" >&2
        exit 1
        ;;
    esac
  done
  if [[ "$do_refresh" -eq 1 ]]; then
    refresh_vendor
  fi
  if [[ "$do_expand" -eq 1 ]]; then
    expand_stubs
  fi
  sync_to_dests
}

main "$@"
