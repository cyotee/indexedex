# CI and local Foundry test gates

How GitHub Actions and local Foundry profiles line up for IndexedEx.

## Profile law (mandatory)

IndexedEx uses **exactly two** Foundry product profiles:

| Profile | Role | `test=` | RPC |
|---------|------|---------|-----|
| **`default`** | Hermetic / local | `test/foundry/spec` | none |
| **`fork`** | Network forks | `test/foundry/fork` | `ALCHEMY_KEY` (or full RPC URLs) |

**Rules for agents and humans:**

1. Do **not** add new `[profile.*]` entries for package isolation.
2. Focus a suite with `forge test --match-path '…/**'` or `--match-contract`, not a custom profile.
3. Hermetic tests **must** live under `test/foundry/spec/**`.
4. Fork tests **must** live under `test/foundry/fork/**`.
5. **`via_ir = false` always.** Fix stack-too-deep with structs / helper frames (see Crane code-style skill). Never re-enable IR.
6. Contract size output: `forge build --sizes` when needed (`sizes = false` on both profiles for quiet logs).

## What runs on GitHub

| Workflow | File | When | Secret |
|----------|------|------|--------|
| **Foundry CI — hermetic** | `.github/workflows/foundry-ci.yml` | push `main`, PRs, manual | none |

- **Hermetic only:** `forge build` + `forge test` under the **default** profile (`test/foundry/spec`).
- **Fork profile is never run on Actions** (`FOUNDRY_PROFILE=fork` / `test/foundry/fork/**`). Run those **locally** with your own RPC key when needed.
- CI also **excludes** misplaced `**/fork/**` and `*Fork*` contracts under `spec` that call `createSelectFork`, and forces empty `ALCHEMY_KEY` / `*_RPC_URL` so Actions cannot hit Alchemy rate limits.
- **Vercel is independent of this workflow.** Frontend deploys from the Git integration on push; they are **not** gated on Foundry CI success.

## Local commands

```bash
# Hermetic (default suite under test/foundry/spec) — same as CI
forge build
forge test -vv

# Focus a package without a custom profile
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/**' -vv
forge test --match-path 'test/foundry/spec/routers/**' -vv

# Fork suite (local only; test/foundry/fork) — needs ALCHEMY_KEY in env or .env
export ALCHEMY_KEY=your_raw_key
FOUNDRY_PROFILE=fork forge test -vv
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/**' -vv
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

`foundry.toml` `[rpc_endpoints]` uses aliases such as:

```text
base_mainnet_alchemy = "https://base-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}"
ethereum_mainnet_alchemy = "https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}"
```

Fork TestBases pass the **alias** (e.g. `base_mainnet_alchemy`) into `vm.createSelectFork`.

## Submodules

CI checks out with `submodules: recursive` (`lib/crane` + nested forge-std / OZ / etc.). Locally:

```bash
git submodule update --init --recursive
```

## Adding a new test suite

1. Put hermetic tests under `test/foundry/spec/…` or fork tests under `test/foundry/fork/…`.
2. Run under **default** or **`FOUNDRY_PROFILE=fork`** only.
3. CI only runs hermetic (`default`). Do not re-add a fork job to Actions without an explicit decision.
4. Never set `via_ir = true`.
