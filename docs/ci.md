# CI and local Foundry test gates

How GitHub Actions and local Foundry profiles line up for IndexedEx.

## What runs on GitHub

| Workflow | File | When | Secret |
|----------|------|------|--------|
| **Foundry CI — hermetic** | `.github/workflows/foundry-ci.yml` | push `main`, PRs, manual | none |
| **Foundry CI — fork** | same | same | **Repository secret** `ALCHEMY_KEY` |

GitHub Pages for the research teaser site has been **dropped** (no Pages workflow). Static assets under `marketing/research-site/` may remain for other hosts; they are not deployed from this repo’s Actions.

### Required vs soft

- **Hermetic** (`FOUNDRY_PROFILE=ci`): intended **required** check for merge confidence. No RPC key.
- **Fork** (`FOUNDRY_PROFILE=ci_fork`): uses Alchemy; currently **`continue-on-error: true`** until the suite is reliably green. Then remove soft-gate and require the check in branch protection.

External PRs from forks **do not** receive repository secrets. Hermetic still runs; fork job fails the “require key” step (soft) without leaking secrets.

## Repository secret

| Field | Value |
|-------|--------|
| **Name** | `ALCHEMY_KEY` |
| **Secret** | Raw Alchemy API key only (not the full URL, not `ALCHEMY_KEY=...`) |

`foundry.toml` builds URLs:

```text
https://base-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}
https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}
```

Use a dedicated Alchemy app for CI when possible (rate limits / rotation).

## Local commands

```bash
# Hermetic (default suite under test/foundry/spec)
forge build
forge test
# same knobs as CI:
FOUNDRY_PROFILE=ci forge test -vv

# Fork suite (test/foundry/fork) — needs ALCHEMY_KEY in env or .env
export ALCHEMY_KEY=your_raw_key
FOUNDRY_PROFILE=fork forge test -vv
# or CI overlay:
FOUNDRY_PROFILE=ci_fork forge test -vv

# Optional package isolation (not all run in default CI)
FOUNDRY_PROFILE=hook_factory forge test -vv
FOUNDRY_PROFILE=coordinator forge test -vv
# see foundry.toml for the full list
```

Foundry loads a root `.env` if present (do not commit it). Example vars:

```bash
ALCHEMY_KEY=
# optional fork pins (supported by several TestBases)
BASE_FORK_BLOCK=
ETH_FORK_BLOCK=
# optional full RPC fallbacks used by some TestBases
BASE_RPC_URL=
ETH_RPC_URL=
```

## Profiles (foundry.toml)

| Profile | Role |
|---------|------|
| `default` | Hermetic; `test/foundry/spec` |
| `fork` | Fork; `test/foundry/fork` |
| `ci` | Inherits `default`, `sizes = false` (CI logs) |
| `ci_fork` | Same as `fork` (`test/foundry/fork`) with `sizes = false` (explicit; non-default `inherits` is unreliable on some Foundry versions) |
| package profiles | Isolated `via_ir` / narrow trees (`orbital`, `coordinator`, hooks, DETFs, …) — run via `FOUNDRY_PROFILE=…` |

Do not merge all package profiles into default; CI should add them as an explicit matrix later if needed.

## Submodules

CI checks out with `submodules: recursive` (`lib/crane` + nested forge-std / OZ / etc.). Locally:

```bash
git submodule update --init --recursive
```

## Adding a new package suite to CI

1. Keep a dedicated `[profile.<name>]` in `foundry.toml` if isolation is required.
2. Add a matrix job (or new job) in `foundry-ci.yml` that runs `FOUNDRY_PROFILE=<name> forge test -vv`.
3. Do not fold `via_ir` packages into `profile.default` “for convenience.”
