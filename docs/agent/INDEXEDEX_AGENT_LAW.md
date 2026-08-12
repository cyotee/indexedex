# IndexedEx agent law (full)

> **Progressive disclosure.** Always-on agent instructions live in root [`CLAUDE.md`](../../CLAUDE.md) (router).
> Open **this file** when implementing DETFs, vault packages, deploy paths, or tests that need the full product law.
>
> Formerly the root `AGENTS.md` / `Agents.md` (removed so only `CLAUDE.md` is auto-loaded).

This file provides guidance to AI Agents when working with code in this repository.
If PROGRESS.md exists in the project root, read it for cross-session context before starting work.
**Frontend product / redesign roadmap:** start at [`frontend/ROADMAP.md`](frontend/ROADMAP.md) (not root `PROGRESS.md`, which may only hold historical notes + a pointer).

## Discovery (maps, inventory, skills)

Cold-start findability — open these before grepping the monorepo:

| Need | Open |
|------|------|
| Primary codebase map | [`docs/CODEBASE_MAP.md`](../CODEBASE_MAP.md) |
| Task → skill / law / path | [`docs/agent/AGENT_NAVIGATION_INDEX.md`](./AGENT_NAVIGATION_INDEX.md) |
| Package content inventory | [`docs/agent/INDEXEDEX_CONTENT_INVENTORY.md`](./INDEXEDEX_CONTENT_INVENTORY.md) |
| Skill catalog | [`docs/agent/SKILL_CATALOG.md`](./SKILL_CATALOG.md) |
| Crane capabilities | [`lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md`](../../lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md) |
| Cartographer on PATH | [`scripts/install-cartographer.sh`](../../scripts/install-cartographer.sh) |

Always-on routers stay lean; this Discovery block is the deep entry into inventories.

## Required Reading

**You MUST read in this order:**

1. Crane materials (Crane lives at `lib/crane/`):
   - `lib/crane/AGENTS.md`
   - **Canonical Crane skills** in `lib/crane/.claude/skills/` (source of truth; do not rely on stale copies elsewhere):
     - `crane-deployment` — CREATE3, DFPkgs, FactoryService, proxy creation.
     - `crane-architecture` — core patterns, DFPkg.
     - `crane-testing` — `CraneTest`, factory bootstrap, TestBases, **production-first testing**.
     - `crane-adversarial-testing` — abuse/attack catalogs, hostile harnesses, P0/P1 adversarial suites for diamonds/vaults.
   - Crane docs under `lib/crane/docs/` (especially `docs/deployment/` and `docs/development/testing.md`).

2. This file — explains how IndexedEx layers on Crane (opened on demand from root CLAUDE.md).

3. IndexedEx testing skills (after Crane testing):
   - `.claude/skills/indexedex-testing/` — `IndexedexTest`, vault registry deploy path, gold TestBases, when mocks are forbidden.
   - `.claude/skills/indexedex-adversarial-testing/` — DETF / SE / multi-vault adversarial suites (bond/claim, seigniorage, nested).

4. IndexedEx Uniswap V4 **hook diamond packages** (when implementing hook DFPkgs / deployHookVault / flag mining):
   - `.claude/skills/indexedex-uniswap-v4-hook-packages/` — package → registry → hook factory; salt/flags; gold stub.
   - Mirrored for Grok/OpenCode: `.grok/skills/indexedex-uniswap-v4-hook-packages/`, `.opencode/skills/indexedex-uniswap-v4-hook-packages/`.
   - **Not** monomorph CREATE3 hooks (weighted/orbital/quad) unless migrating to this path.

**Skill source of truth:** Crane skills are authored under `lib/crane/.claude/skills/`. After editing them in Crane, run `./scripts/sync-crane-skills.sh` to refresh IndexedEx `.claude/skills/`, `.opencode/skills/`, and `.grok/skills/` copies. Prefer reading the Crane path when in doubt.

**IndexedEx-local skills** (this repo, not Crane): author under `.claude/skills/<name>/` and **mirror** to `.grok/skills/` and `.opencode/skills/` (e.g. `rsync -a .claude/skills/<name>/ .grok/skills/<name>/`).

**Bankr skills:** Vendored at `lib/bankr-skills/` but synced to the **parent** workspace (`projects-defi/.claude|/.grok|/.opencode/skills`), not IndexedEx trees. Refresh: `./scripts/sync-bankr-skills.sh` (see script header).

Always-on router: root `CLAUDE.md`.

## Project Overview

IndexedEx is modular DeFi vault infrastructure using the Diamond Pattern (EIP-2535). It provides upgradeable vault strategies with integrated cross-protocol orchestration across Uniswap V2, Camelot V2, Aerodrome, and Balancer V3.

## DETF / vault role naming (mandatory)

Use **role names**, never product token brands, in contracts, interfaces, storage fields, NatSpec, and tests:

| Role | Name | Meaning |
|------|------|---------|
| Rate Provider target / mint-bond-redeem settlement | `rateAsset` | “New money”; must be in underlying vault `tokens()` |
| Other vault-declared token(s) | `pairToken` | Not the rateAsset |
| Underlying SE vault | `underlyingVault` / `standardExchangeVault` | Any `IStandardExchange` |
| Vault share of that SE vault | `vaultShare` / `standardExchangeVaultShare` | Often the vault address itself |
| DETF diamond share | `detfToken` / `address(this)` | This proxy is the ERC-20 |
| Reserve pool / BPT | `reservePool` / `reserveBpt` | Balancer V3 pool + BPT |
| Rebasing claim token | `rebasingClaimToken` / `IRebasingClaimToken` | Claim on protocol-owned reserve BPT |

**Anti-patterns (do not reintroduce):** `RICH`, `RICHIR`, `richToken`, `wethRichVault`, `mintWithWeth`, `wethAsEth` on generic DETF surfaces.

**WETH rule:** Use `weth` / `WETH` only in code that is *actually* WETH-specific (e.g. `WETHAwareRepo`). DETF packages that accept a configurable rate asset must not name roles after WETH.

**Type names:** Prefer full words in contract/file/type names (e.g. `StandardExchange`, `MultiVaultWeightedDetf`). Short locals (`seVault_`, `share_`) are fine for stack pressure.

See `docs/superpowers/plans/2026-07-14-detf-rich-naming-generalization.md`.

## DETF families — common expectations (mandatory for agents)

Apply these to **any** DETF work under `contracts/vaults/detf/**`. Normative product law is this section, code NatSpec, **family PRDs co-located with package code**, and shared cross-family law under `docs/detf/` (compound/expansion PRD + PROGRAM + threshold plans).

### Product docs vs public docs (LOCKED)

| Location | Role |
|----------|------|
| **Next to package code** (`contracts/…/<family>/…_PRD.md`, `…_IMPLEMENTATION_AND_TEST_PLAN.md`) | **Internal product law and implementation plans** for that package/family. Agents treat co-located family PRDs as normative for that family. Prefer this for new family product law. |
| **`docs/detf/`** | **Shared / cross-family** product programs (compound + expansion, thresholds) and **public-facing** or process docs (handoffs, dual-liquidity process, etc.). Not a requirement that every family PRD live here. |
| **Do not** treat co-located PRDs as “public documentation” that must be mirrored under `docs/`. Do **not** reorg existing `docs/detf/` trees solely to match package paths. |

Family-specific compound/expansion **stage plans** for Balancer families currently live under `docs/detf/balancer/v3/<family-path>/` (historical). New Uni V4 family plans may sit next to the package or under a mirrored docs path when public; product PRD stays co-located.

### What a DETF is

- A **true DETF**: the diamond **is** the share ERC-20; seigniorage mint/burn is against a **reserve that includes a DETF self-leg** (Balancer V3 weighted/stable pool + BPT, or Uni V4 Single SE Buffer CP hook + fungible LP, or family-equivalent).
- **Not** a pure pro-rata “shares ∝ BPT/LP” vault unless a specific route explicitly uses proportional principal accounting (bond/claim unwind helpers).
- **Opacity:** production DETF code talks only to `IStandardExchange*` / share ERC-20 / reserve host ABI (Balancer vault/router or Uni V4 CP buffer hook). Do **not** import concrete Uni/Aero/Camelot/Aave **vault** types into DETF production sources beyond host plumbing. Nested SE vaults (including DETF-as-vault) are allowed and must stay opaque.

### Families (when to use which)

| Family | Path | Use when |
|--------|------|----------|
| Single Standard Exchange (Balancer) | `detf/protocols/dexes/balancer/v3/standardExchange/single/` | Exactly **one** SE vault + DETF **Balancer weighted** reserve (BPT principal) |
| Composed stable multi | `detf/protocols/dexes/balancer/v3/stable/common/` | Multiple SE vaults with **like-kind** rate targets (stable-style composition) |
| Mixed-buffer multi-vault stable | `detf/protocols/dexes/balancer/v3/mixedBuffer/` | Multiple SE vaults sharing one **bufferToken** (rateAsset) in a **MixedBuffer MultiVault Stable** reserve; mint buffer or vaultShare → DETF; burn DETF → buffer only; live via permissionless `bootstrapFirstBond` |
| Multi-vault weighted | `detf/protocols/dexes/balancer/v3/multi-vault-weighted/` | Multiple SE vaults that must keep **distinct** valuations in a **weighted** reserve |
| **Uni V4 Single SE CP buffer** | `detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/` | Exactly **one** SE + **Uni V4 Single SE Buffer Constant Product** reserve (DETF raw leg ↔ pairToken; fungible hook LP principal); see co-located `UniswapV4SingleStandardExchangeDETF_PRD.md` |
| Dual-liquidity / protocol | elsewhere under `contracts/vaults/` | Protocol-specific DETF-like products; do not subclass for new generic DETFs |

**Layout law:** shared true-DETF infrastructure → `detf/common/`; host-family packages → `detf/protocols/dexes/<host>/…`. See `contracts/vaults/detf/DETF_DIRECTORY_REORGANIZATION_PRD.md`.

**Fresh codepath rule:** new DETF families are **behavioral references only** relative to peers — do **not** subclass concrete contracts from another family. Reuse `detf/common/core/*` and `detf/common/factory/*` libs/factories.

### Governance and immutability

- DETF **instances are immutable and unowned** after deploy: no instance owner, no diamondCut, no admin pause surface on the diamond for normal operation.
- Flawed config → abandon instance; ship a new package/args. Prefer deploy-time wiring only (bond NFT, claim token, rate providers, reserve pool) inside DFPkg `postDeploy`.
- **Fees / bond terms / seigniorage incentive:** **Vault Fee Oracle** (`feeOracle` on manager) where peer DETFs already do.
- **Mint/burn thresholds + mode:** deploy-time only via **`PkgArgs` → resolve → instance storage** — **not** the fee oracle. See **Pricing and mint/burn gates** below.
- **Protocol compound rules + natural expansion rate/caps:** deploy-time only via **`PkgArgs` → resolve → instance storage** — **not** the fee oracle. See **Protocol seigniorage compound + natural supply expansion** below.

### Liveness (inert → live)

- Deploy **inert**. Mint/burn of user DETF against vault shares is blocked until live (`isReserveLive` / equivalent).
- Live is established by a **first successful bond** that creates protocol reserve (family-specific):
  - **Single SE DETF (Balancer):** first bond with SE vault shares (mints DETF self-leg into pool + joins shares; BPT principal on bond NFT).
  - **Uni V4 Single SE CP buffer DETF:** **permissionless** first bond that joins **hook LP** at deploy-time **creation rate** (pair capital + minted DETF self-leg; LP principal on bond NFT). See family PRD.
  - **Multi-vault weighted:** first bond of **reserve BPT** (user may obtain BPT via `initializeReserve` / join that mints DETF **only into the pool**, not open seigniorage mint).
  - **Mixed-buffer multi-vault stable:** permissionless `bootstrapFirstBond` (multi-asset non-DETF legs + rate-scaled peg DETF self-seed + reserve init; BPT principal on bond NFT).
- Do not invent a second product “bootstrap mode.” Speak **inert / pre-live** vs **live**.

### Pricing and mint/burn gates

**Normative source:** this section + core lib [`contracts/vaults/detf/common/core/DETFThresholdPolicy.sol`](contracts/vaults/detf/common/core/DETFThresholdPolicy.sol) (and threshold plan under [`docs/detf/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md`](docs/detf/DETFThresholdPolicy_Threshold_Modes_IMPLEMENTATION_AND_TEST_PLAN.md)). Threshold mode product law is **LOCKED** in code and AGENTS; do not invent a separate off-tree Threshold Modes PRD path.

- **Pricing engine = reserve host** (Balancer pool balances/weights/fees/rate providers, or Uni V4 CP buffer hook effective reserves / LP). Do **not** introduce an off-pool multi-asset FX “numeraire” ledger.
- **Synthetic price:** fully diluted backing from owned reserve principal (BPT or hook LP) claim on reserve inventory (rate-scaled / zap-out-to-numeraire as family defines), ÷ DETF `totalSupply`, abstract **1e18 peg** (Policy narrative). Include principal held by bond NFT vault when peers do. **All mint/burn threshold gates use synthetic** — never spot alone.
- **Deploy-time `ThresholdMode`:** explicit field on `PkgArgs` / instance storage — **`Policy` (default)** vs **`Open`**. **Never** infer Open from `0` thresholds. Omitted / zero mode → Policy.
- **Defaults:** `mintThreshold = 0` and `burnThreshold = 0` resolve to **`1.05e18` / `0.95e18`** via `DETFThresholdPolicy` (both modes). Resolved values are **stored** for getters under Open as well; Open gates **ignore** them.
- **Source of truth:** mode + thresholds from **`PkgArgs` → resolve → instance storage only**. Fee oracle does **not** set, override, or mutate mode or thresholds.
- **Validation (after resolve, both modes):** `mintThreshold > burnThreshold`; invalid mode reverts at deploy/init. No post-deploy setter.
- **Policy gates (when live):** mint iff `synthetic > mintThreshold`; burn iff `synthetic < burnThreshold`; **equality = deadband** (neither). First bond / bootstrap remains **synthetically ungated** (both modes).
- **Open gates (when live):** threshold gates **always pass**. Open does **not** change the route set (e.g. MixedBuffer still burns **buffer only**), fees, seigniorage split, or inert→live rules. Do not advertise a peg for Open instances.
- **Info surface:** `thresholdMode()`, live-coupled `isMintingAllowed()` / `isBurningAllowed()` (and stored threshold getters).
- **Shipped:** F1–F5 implement Policy/Open; F6 `IDetf` documents the shared DETF surface (formerly `IProtocolDETF`). **Legacy dual-token SeigniorageDETF** product under `contracts/vaults/seigniorage/` is **REMOVED** (not a true DETF family). DualLiquidity / pure SE vaults remain out of this PRD.
- Seigniorage mint shape (live): quote DETF from weighted-pool math for vault-share (or family-defined) input; apply usage fee + seigniorage split (`DETFUsageFeeLib` / peer mint split); join reserve; leave free DETF with user / feeTo / protocol as peers do.

### Protocol seigniorage compound + natural supply expansion

**Normative PRD:** [`docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md) (**LOCKED**). Program index / stages: [`DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md`](docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PROGRAM.md). Shared libs: [`DETFProtocolCompoundLib.sol`](contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol), [`DETFNaturalExpansionLib.sol`](contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol).

Apply to **true DETFs** in scope (Balancer Single SE, multi-vault weighted, mixed-buffer, composed stable common, **Uni V4 Single SE CP buffer**). **Out:** removed single-vault DETF residue, `contracts/vaults/seigniorage/`, dual DETF stubs (deleted) unless re-supported.

**Protocol compound (detf-owned bond NFT only):**

- Capital-backed seigniorage inventory accrues on the bond NFT reward ledger. **User** and **fee-recipient** positions: **claimable free DETF** while locked (`claimRewards` / pending) — do **not** auto-compound them in v1.
- **Detf-owned NFT** pending reward DETF is **auto-compounded** into the reserve via **single-sided DETF join** (self-leg only); credit BPT to detf-owned principal. Weight skew accepted in v1.
- **Lazy** on DETF touch points that already update rewards (mint inventory, bond, etc.) **plus** required public **`compoundProtocolRewards()`** (or family-equivalent). No keeper.
- Join failure is **best-effort**: do not fail the whole user touch solely because join reverts; leave pending for next touch / public compound; reward debt must stay consistent.
- When rebasing claim is wired: protocol compound **must** increase detf-owned BPT so claim redemption rate **can rise**.

**Natural supply expansion (Policy only):**

- While **live + `thresholdMode == Policy` + synthetic mint-allowed** (`synthetic > mintThreshold`), mint free DETF **without** external capital into the bond reward vault (**mint-on-update** → same `rewardPerShares` ledger as seigniorage). **Open = never expands.**
- Formula shape: **premium-closure** via `DETFNaturalExpansionLib` (deploy-time rate / catch-up caps from **`PkgArgs` → resolve → storage only** — not fee oracle; no post-deploy setter).
- Distribution: **same effective-share weights** as seigniorage inventory rewards. Free unlocked DETF holders get none unless they hold a bond.
- Protocol’s expansion share compounds via the Phase 1 path. Users claim expansion while locked like other rewards. Preview pending consistent with claim after update.
- No keeper. Idle catch-up respects deploy-time caps.

**Do not** invent balanced multi-leg protocol compound, user auto-compound, or expansion under Open without a PRD revision.

### User routes (defaults)

- Prefer **configured vault shares ↔ DETF** on the DETF surface (exact-in closed form).
- **RateAsset as mint `tokenIn` on the DETF** is usually **out of scope** unless a family package explicitly documents a zap: user deposits into the SE vault first, then uses shares.
- **vaultShareᵢ ↔ vaultShareⱼ on the DETF** is out of scope: use Balancer / Standard Exchange Router on the reserve pool.
- Routes that need **binary search / gas-heavy exact-out solvers** should **revert** with **`InvalidRoute`** on new families (do not introduce `UnsupportedRoute` on new surfaces; Balancer Single SE may still emit legacy `UnsupportedRoute` until a cleanup). Do not ship approximate solvers “for convenience.”
- **Preview/execution:** closed-form routes must share one quote path; tests assert **exact** preview == execution when possible (document ≤ few-wei only if Balancer multi-leg proportional exit forces it).

### Bonding and rebasing claim

- **Full bond NFT vault** is the default v1 shape: user bond positions + protocol NFT + fee-recipient NFT wiring as peer families.
- Bond lock terms from oracle: **revert if lock < min**; **clamp to max** if longer (bonus at max). Use `DETFBondNFTMathLib` / `DETFBondLifecycleLib`.
- `acceptedBondTokens()` must list what the family accepts (at least reserve BPT and/or vault shares per PRD).
- **Sell NFT → protocol (rebasing claim) — DETF-wide standard (LOCKED):** bond holders **must not** sell their bond for rebasing claim until the bond is **mature** (`block.timestamp >= unlockTime`). Pre-maturity sell **reverts**. At maturity the holder may **close** (principal out in family settlement assets) **or** **sell → rebasing claim** (migrate principal LP/BPT to protocol + mint claim). While locked, rewards remain claimable free DETF via `claimRewards` (not a principal exit). **First family adopter:** Uni V4 Standard Exchange Orbital DETF (`…/uniswap/v4/standardExchange/orbital/`). **Balancer V3 true DETFs** (Weighted, Mixed-buffer, Composed, Single SE): follow [`BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md`](../../contracts/vaults/detf/protocols/dexes/balancer/v3/BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_PRD.md) + [impl plan](../../contracts/vaults/detf/protocols/dexes/balancer/v3/BALANCER_V3_DETF_PRODUCT_LAW_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md) (mature-only sell/close, ERC-4626 claim, `buyClaim`). DualLiquidity under `uniswap/v4/crossVersion/v2/` is **not** a true DETF.
- **Claim redeem:** DETF-orchestrated unwind of protocol reserve BPT → vault share path → payout in configured `rateAsset`(s). Never treat raw claim amounts as free BPT authority without burning claim shares (`burnShares` / peer path). Require claim token configured when redeem is exposed.
- Wire claim package in DFPkg `postDeploy` when the family requires claim (role-named `IRebasingClaimToken` / `RebasingClaimTokenDFPkg`).

### Deploy path (same as vault packages)

- Facets: CREATE3 + `*FactoryService` / `DetfFacetFactoryService` / family `*_Facet_FactoryService`.
- DETF DFPkg: **Vault Registry / manager** (`indexedexManager.deployPkg` / typed `deploy*DFPkg`). **Never** `new` DFPkg/facets; never bypass registry for registered vault packages.
- `PkgInit` / `PkgArgs` **on the interface**, not the contract (Crane rule).
- Shared helpers: `contracts/vaults/detf/common/core/*`, `detf/common/factory/*`, bond NFT packages, `StandardExchangeRateProviderDFPkg`, Balancer `WeightedPoolFactory`.

### Testing expectations (DETF-specific)

Production-first rules in this file and `indexedex-testing` apply. Additionally for DETFs:

1. **No mocks of SUT:** DETF diamond, facets, DFPkg, manager, registry, fee oracle, attached SE vaults under test.
2. **Gold TestBases:** inherit `CraneTest` → `IndexedexTest` → vault components / Balancer SE router or protocol SE TestBases; mirror `TestBase_SingleStandardExchangeDETF` / family `TestBase_*` patterns.
3. **Real SE legs:** deploy production SE vaults (Aerodrome/Camelot hermetic ports, fork Uni V4, nested DETF/DualLiquidity as matrix rows). Crane `*/stubs/` protocol ports are **not** “mocks.”
4. **Allowed non-SUT harnesses:** mintable ERC20 for funding; **reentrancy hostile ERC20** as configured vault share only for attack tests (see Single SE + MultiVault reentrancy suites); never a fake Standard Exchange for lifecycle.
5. **Cover at least:** inert deploy; first-bond → live; pre-live mint blocked; mint/burn with **preview == execution**; threshold gates; route rejects (`InvalidRoute` / family equivalent); bond lock clamp; **pre-maturity sell→claim reverts**; **post-maturity** sell → claim and/or maturity close (when in scope); residual free inventory zero on success (BPT on diamond may remain); nested reentrancy hits `IsLocked`.
6. **Price movement:** for threshold tests under **default** mint/burn thresholds, drive synthetic via **real underlying pool trades** (and seigniorage dilution where needed) so both mint-allowed and burn-allowed regimes are exercised — do not only use open-threshold deploys as the sole proof.
7. **Matrix:** when attaching many SE types, equal-priority production providers (not one preferred mock).
8. **Protocol compound:** lazy + public `compoundProtocolRewards`; detf-owned BPT ↑; user claim free DETF while locked; join-failure best-effort + retry; claim rate path when claim is wired.
9. **Natural expansion (Policy):** expands only when live + mint-allowed synthetic; Open never expands; pending == claim after update; protocol expansion share compounds; catch-up caps.

### Key reference paths

```text
contracts/vaults/detf/common/core/                    # shared math/lifecycle libs (incl. compound + expansion)
contracts/vaults/detf/common/factory/                 # facet/pkg factory helpers, NFT interfaces
contracts/vaults/detf/common/bondNft/                 # DETFNFTVault (shared bond NFT package)
contracts/vaults/detf/common/claimToken/              # RebasingClaimToken package
contracts/vaults/detf/common/inventory/               # NFT inventory policy interfaces
contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/  # Single SE DETF + TestBase
contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/     # multi-leg weighted DETF
contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/            # multi-vault stable + claim packages
contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/              # mixed-buffer multi-vault stable
contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/  # Uni V4 Single SE CP buffer DETF (+ co-located PRD)
contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/  # DualLiquidity linked cross-version (pro-rata BPT vault; NOT a true DETF)
docs/detf/                                            # shared compound + expansion + threshold programs (public/process)
docs/detf/balancer/v3/<family-path>/                  # historical family compound/expansion stage plans
docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/     # DualLiquidity process docs
```

When implementing a new DETF family: place package code under the correct host tree (`protocols/dexes/<host>/…`), keep shared libs in `common/`, and keep **family product PRDs / impl plans co-located with the package** (internal law). Shared cross-family programs stay under `docs/detf/`. Do not re-open locked shared product law without an explicit PRD revision.

## Codebase Overview

IndexedEx is modular DeFi vault infrastructure using the Diamond Pattern (EIP-2535) with CREATE3 deterministic deployments. It provides upgradeable vault strategies with integrated cross-protocol orchestration.

**Stack**: Solidity (see `foundry.toml` `solc`; currently 0.8.35), Foundry, Next.js 14, Wagmi/Viem, Balancer V3 (incl. Standard Exchange Buffer Pool), Aerodrome V1 + Slipstream, Uniswap V2 + V4, Camelot V2, Aave V3 Stata (ERC-4626).

**Structure**:
- `contracts/` - Smart contracts (manager, registries, oracles/fee, vaults, protocols/dexes + protocols/lending) + TestBases next to features
- `frontend/` - Next.js React app (list-driven, chain-keyed; swap auto-routes through Standard Exchange Vaults)
- `scripts/foundry/<env>/` - Staged deploy scripts (`Script_00..Script_99`); `scripts/node/` - Token List aggregator
- `test/foundry/spec/` - Hermetic / unit / integration / invariant / comparative specs
- `test/foundry/fork/` - Fork tests against live networks (e.g. Base mainnet)
- `lib/crane/` - Crane framework (Diamond + Factory infrastructure)
- `lib/bankr-skills/` - Vendored [BankrBot/skills](https://github.com/BankrBot/skills) packages (synced to agent skill dirs)
- `.cartographer/` - Code-graph artifacts (`graph.sqlite`); query with `cartographer brief`/`slice`/`impact`

For detailed architecture, see [docs/CODEBASE_MAP.md](docs/CODEBASE_MAP.md) (refreshed 2026-06-21 from the Cartographer graph).

## Build & Test Commands

**Foundry profiles (only two):** see [`docs/ci.md`](docs/ci.md) Profile law.

| Profile | Use for | Command |
|---------|---------|---------|
| **default** | Hermetic / local (`test/foundry/spec`) | `forge test` |
| **fork** | Fork suite (`test/foundry/fork`) | `FOUNDRY_PROFILE=fork forge test` |

Do **not** add package-specific Foundry profiles. Focus with `--match-path` / `--match-contract`. **`via_ir` is forbidden.**

```bash
# Build
forge build
forge build --sizes         # with contract size output

# Hermetic (default profile → test/foundry/spec)
forge test
forge test -vvv             # verbose output
forge test -vvvv            # full stack trace

# Run specific tests (no custom FOUNDRY_PROFILE)
forge test --match-path 'test/foundry/spec/protocol/**'
forge test --match-path 'test/foundry/spec/routers/**'
forge test --match-test testFunctionName
forge test --match-contract ContractNameTest

# Fork (needs ALCHEMY_KEY)
export ALCHEMY_KEY=...
FOUNDRY_PROFILE=fork forge test -vv
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/**' -vv

# Format Solidity
forge fmt

# Local development with Anvil fork
anvil --fork-url <RPC_URL>
forge script scripts/foundry/UI_Dev_Anvil.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## Architecture: 3-Tier Diamond Deployment

**Facets -> Packages -> Proxies**

1. **Facets**: Individual logic components (e.g., `FeeCollectorManagerFacet`, `VaultRegistryDeploymentFacet`)
2. **Packages (DFPkg)**: Bundle related facets together (e.g., `FeeCollectorDFPkg`, `IndexedexManagerDFPkg`)
3. **Proxies**: Diamond proxy instances that users interact with (e.g., `IFeeCollectorProxy`, `IIndexedexManagerProxy`)

## Critical: CREATE3 Factory Deployment (Crane Foundation)

**NEVER use `new` to deploy contracts.** All deployments go through Crane's CREATE3 factory system. See the `crane-deployment` skill (in the Crane submodule) for the full detailed patterns, code examples, anti-patterns, and test setup.

High-level reminder:
```solidity
// WRONG
MyContract c = new MyContract();

// CORRECT (via FactoryService or directly on create3Factory)
myFacet = create3Factory.deployFacet(
    type(MyFacet).creationCode,
    abi.encode(type(MyFacet).name)._hash()
);
```

FactoryService libraries (Crane + IndexedEx):
- Crane core: `AccessFacetFactoryService`, `IntrospectionFacetFactoryService` (in Crane).
- IndexedEx core: `IndexedexManagerFactoryService`, `FeeCollectorFactoryService`, `VaultComponentFactoryService`.
- Protocol: `*_Component_FactoryService.sol` (e.g. `CamelotV2_Component_FactoryService`).

**Always start with the Crane `crane-deployment` skill + `CraneTest` / `InitDevService`.**

## Key Import Remappings

```
@crane/          -> lib/crane/
forge-std/       -> lib/crane/lib/forge-std/src/
```

Other libs are remapped under `lib/crane/` as well. Prefer the live `remappings.txt` / `foundry.toml` over this summary. Update both when adding new libraries.

## Testing Philosophy: Production-First

**Prefer production code and production deploy paths in tests. Do not invent mocks for the subject under test.**

Ladder (use the highest step that fits):

1. **Real production contracts**, deployed the same way as production (CREATE3 + FactoryService + DFPkg + IndexedEx vault registry where applicable).
2. **Existing TestBase chains** (`CraneTest` → `IndexedexTest` → `TestBase_VaultComponents` → protocol TestBase). Search for a TestBase before writing setup from scratch.
3. **External protocols**: Crane **protocol ports** under `lib/crane/contracts/protocols/.../stubs/` (real protocol implementations for hermetic deploy) **or** fork bases under `test/foundry/fork/` with live addresses. Do not invent interface mocks when a TestBase already deploys the protocol.
4. **Test-only doubles outside the SUT** are OK when they implement real interfaces and only add controllability (e.g. mintable ERC20, reentrancy ERC20).
5. **`vm.mockCall` / fake contracts** only for: isolating a pure unit with no deploy path, a failure mode production cannot express cheaply, or a documented third-party oracle/VRF harness — **and the SUT remains real production code**.

**Never mock**: facets, DFPkgs, vaults, IndexedexManager, fee oracle, vault registry, or Standard Exchange packages under test. Prefer real SE vaults over `MockStandardExchange` for new work.

Generic Foundry skills that demo `MockOracle` / `new MyContract()` are **subordinate** to `crane-testing` + `indexedex-testing`.

### Terminology (do not conflate)

| Term | Meaning in this monorepo |
|------|---------------------------|
| **Protocol port (`*/stubs/`)** | Real/protocol-faithful implementation used for hermetic local deploy (e.g. Camelot factory/router under Crane) — **not** a fake |
| **Mintable / harness stub** | ERC20 (or similar) with mint or reentrancy hooks for test control |
| **Mock / test double** | Canned behavior replacing a dependency; last resort for non-SUT only |
| **Handler** | Fuzz/invariant harness wrapping a real SUT; not a substitute for production deploy |

## Test Patterns

**See `crane-testing` (under `lib/crane/`) + `indexedex-testing` + `crane-deployment` first.** For abuse/attack suites use `crane-adversarial-testing` + `indexedex-adversarial-testing`. Ship gate checklist: `lib/crane/.claude/skills/crane-adversarial-testing/references/implementation-test-dod.md`.

- Inherit `CraneTest` (provides `create3Factory` + `diamondPackageFactory` via `InitDevService`).
- Then `IndexedexTest` (builds the core manager, fee collector, etc. using Crane factories + registers the manager as operator).
- Then `TestBase_VaultComponents` (deploys shared vault facets via Crane factories + `VaultComponentFactoryService`).
- Then protocol TestBases (e.g. `TestBase_CamelotV2StandardExchange`).

Protocol / vault gold TestBases (follow these exactly):
- `contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol`
- `contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol`
- `contracts/protocols/dexes/aerodrome/v1/TestBase_AerodromeStandardExchange.sol`
- `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol` (fork + full factory/registry path)

**Key rule in IndexedEx**: Facets use the Crane path (`create3Factory`). Vault/StandardExchange *DFPkgs* use the manager/registry path. See the section below.

IFacet / behavior tests implement the usual virtuals (`facetTestInstance()`, etc.).

### Non-negotiable test gaps agents must not repeat

| Failure class | Required bar |
|---------------|--------------|
| **Trust-flag free mint** (`pretransferred=true` / claimed `amountIn` while vault already holds inventory) | Negative tests I1–I3; BasicVault family uses reserve-delta (`U = balanceOf − reserveOfToken`), not absolute inventory — see `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` |
| **Incomplete `facetFuncs`** | Controls from **Target/product API**; after DFPkg deploy, loupe + smoke call every product selector on the **proxy** (J1–J3) |
| **Happy-path-only security** | Adversarial catalog A–K P0 (or explicit NatSpec defer); happy path is not a security bar |

Catalog I/J/K details live in `crane-adversarial-testing` (synced from Crane).

## Project Structure

```
contracts/
├── constants/          # Deployment constants
├── fee/collector/      # Fee collection system
├── interfaces/         # Contract interfaces & proxies
├── manager/            # IndexedexManager (main orchestrator)
├── oracles/fee/        # Fee oracle system
├── protocols/dexes/    # DEX integrations
│   ├── aerodrome/v1/
│   ├── balancer/v3/
│   ├── camelot/v2/
│   └── uniswap/v2/
├── registries/vault/   # Vault registry system
├── script/             # Foundry scripts
├── test/               # Test bases and helpers
└── vaults/             # Vault implementations
```

## Solidity Version & Compiler Settings

- Solidity: follow `foundry.toml` (`solc`; currently `0.8.35`)
- Optimizer: enabled, max runs (`4294967295`)
- FFI: enabled (required for some tests)

## Protocol Integration Pattern

Each DEX/lending integration follows this structure (see `crane-deployment` for Crane base + the Component_FactoryService for the IndexedEx manager path):
- `*StandardExchangeInFacet.sol` / `...OutFacet.sol` / Marker — deployed via `create3Factory` (Crane).
- `*_Component_FactoryService.sol` — provides the typed `deploy*Facet` (on create3Factory) and `deploy*DFPkg` (on indexedexManager) helpers.
- `TestBase_*StandardExchange.sol` — correct test setup (follow these).
- The DFPkg itself and instance creation go through the VaultRegistry path on the manager (see Deployment section above).

## Permit2 Witness Canonical Source (Balancer Router)

For Permit2 signed swap flows, treat the router as the source of truth for witness schema values.

- The router proxy already includes `BalancerV3StandardExchangeRouterPermit2WitnessFacet` in its package wiring.
- Read canonical values from the router via:
  - `WITNESS_TYPE_STRING()`
  - `WITNESS_TYPEHASH()`

Current canonical witness values (from router constants):

```text
WITNESS_TYPE_STRING = "Witness witness)TokenPermissions(address token,uint256 amount)Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)"
WITNESS_TYPEHASH   = keccak256("Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)")
```

Practical rules:
- Do not hardcode alternate witness strings in clients if router getters are available.
- Use EIP-712 typed-data signatures (`signTypedData`), not `signMessage`.
- In signed mode, if quote-time signature is missing/expired, re-sign at swap click and execute `*WithPermit` paths.

## Deployment in IndexedEx (Crane + Registry Layer)

**Foundational mechanics come from Crane.** Read the Crane `crane-deployment` skill first for facets, DFPkgs, FactoryService, and `CraneTest` bootstrap.

IndexedEx adds a registry layer **only** for vault-style packages (StandardExchangeDFPkgs, DETF pkgs, etc.). Core foundation packages (IndexedexManagerDFPkg, FeeCollectorDFPkg) use the direct Crane path.

### Two Paths

**1. Pure Crane path (facets + generic packages)**
- Facets: `create3Factory.deployXXXFacet()` (or via `*FactoryService`).
- Generic DFPkgs: `create3Factory.deployPackageWithArgs(...)`.
- Instances: `diamondPackageFactory.deploy(pkg, args)` or package helper.

See `IndexedexTest` for how the core manager + feeCollector are created this way.

**2. IndexedEx vault package path (the one that trips people up)**
- Facets (In/Out/Marker, vault components): still pure Crane via `create3Factory` + `VaultComponentFactoryService` / `XXX_Component_FactoryService`.
- DFPkg for the vault package: **must** go through the manager:
  ```solidity
  vm.prank(owner);
  myVaultDFPkg = indexedexManager.deployCamelotV2StandardExchangeDFPkg(pkgInit);
  // (or deployAaveV3Stata..., deployAerodrome..., etc.)
  ```
  This calls `IVaultRegistryDeployment.deployPkg(...)`, which does CREATE3 + registers in `VaultRegistryVaultPackageRepo`.
- Instance: `myVaultDFPkg.deployVault(asset)`.
  The DFPkg calls the registry's `deployVault`, which does the actual `diamondPackageFactory` step + registers the resulting vault.

See concrete examples:
- `contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol`
- `contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol`

### Why the registry path for vault packages?

- Discovery via `indexedexManager.vaultsOfToken(...)` / `vaultsOfType(...)`.
- Authorization (`_onlyOwnerOrOperatorOrPkg` in `VaultRegistryDeploymentTarget`).
- Consistent fee oracle + manager wiring.

### Anti-Patterns

```solidity
// WRONG — bypass CREATE3 / factories
SomeFacet f = new SomeFacet();
SomeDFPkg p = new SomeDFPkg(init);

// WRONG — deploy registered vault DFPkg outside the manager registry path
address v = diamondPackageFactory.deploy(IDiamondFactoryPackage(myVaultPkg), args);
create3Factory.deployPackageWithArgs(...); // for a registered vault DFPkg

// WRONG — mock the subject under test (vault, SE, manager, registry, facets)
MockStandardExchange se = new MockStandardExchange(...);
vm.mockCall(address(vault), abi.encodeWithSelector(...), abi.encode(...));
```

**Always**:
- Use the factories from `CraneTest` / `IndexedexTest`.
- For vault DFPkgs, use the typed `indexedexManager.deploy*DFPkg(...)` (requires `vm.prank(owner)`).
- Let the DFPkg's `deployVault(...)` (or manager) create instances.
- Prefer real Standard Exchange vaults and protocol TestBases over mocks for new tests.

### Vault DFPkg Requirements

Every vault DFPkg must implement `IStandardVaultPkg`.

**Additionally (Crane rule)**: `PkgInit` and `PkgArgs` structs **must** be defined inside the package's interface (`interface IMyVaultDFPkg { struct PkgInit ... }`), never inside the contract.

This is a very common error. Full explanation and correct vs. incorrect examples are in the Crane `crane-architecture` skill → `references/dfpkg-pattern.md`.

### Key Files

See the table in the original "Vault Deployment Pattern" area and the files listed in `contracts/registries/vault/` and protocol `*_Component_FactoryService.sol` files.

Consult the Crane `crane-deployment` skill for the underlying mechanics, then follow the patterns in IndexedEx's good TestBases.

## Submodules / Crane dependency

Crane is vendored at **`lib/crane/`** (see `@crane/` remapping). Initialize nested deps with:
```bash
git submodule update --init --recursive
```

## Git Worktree Workflow (git-wt)

This project uses `git-wt` to simplify working with multiple branches simultaneously via git worktrees. Each worktree is an independent working directory with its own branch.

### Commands

```bash
# List all worktrees
git wt

# Create new worktree for a branch (or switch to existing)
git wt <branch-name>

# Delete worktree and branch (with safety checks)
git wt -d <branch-name>

# Force delete worktree and branch
git wt -D <branch-name>
```

### Configuration

Configure via `git config`:

```bash
# Set custom worktree base directory (default: ../{repo}-wt)
git config wt.basedir /path/to/worktrees

# Copy .gitignore-excluded files to new worktrees
git config wt.copyignored true

# Copy untracked files to new worktrees
git config wt.copyuntracked true

# Copy uncommitted changes to new worktrees
git config wt.copymodified true

# Run hook after creating worktree (e.g., install deps)
git config wt.hook "forge build"
```

### Recommended Workflow

When working on a feature or fix that requires isolation:

```bash
# Create worktree for feature branch
git wt feature/new-vault-strategy

# Work in the new worktree directory
# Changes are isolated from main worktree

# When done, delete the worktree
git wt -d feature/new-vault-strategy
```

This is useful for:
- Running long tests in one worktree while developing in another
- Comparing behavior between branches side-by-side
- Isolating experimental changes without stashing

### Submodule-Aware Worktree Scripts

Due to nested submodules under `lib/crane/`, standard `git worktree` commands can fail. Use these scripts instead:

```bash
# Create worktree with proper submodule initialization
./scripts/wt-create.sh feature/my-feature

# Remove worktree (handles submodules, cleans locks)
./scripts/wt-remove.sh feature/my-feature

# Manually init submodules in existing worktree
./scripts/wt-post-create.sh /path/to/worktree
```

**Why scripts instead of `git wt`?**

1. **Submodule pointer corruption** - Worktrees can reference commits that no longer exist
2. **Lock file contention** - Multiple worktrees share `.git/modules/` and can deadlock
3. **Force removal required** - `git worktree remove` fails on submodule worktrees
4. **Fallback copying** - Scripts copy submodules from main repo when git init fails

The `wt.hook` is configured to run `./scripts/wt-post-create.sh` automatically when using `git wt`.

**Troubleshooting:**

```bash
# Clear stale lock files
find .git/modules -name "*.lock" -delete

# Prune stale worktree references
git worktree prune

# Manual submodule copy (if all else fails)
cp -R /path/to/main/lib/crane /path/to/worktree/lib/crane
```

## Librarian (Documentation Search)

Librarian is a local CLI tool that fetches and searches up-to-date developer documentation. Use it to get real context from official docs instead of relying on potentially outdated training data.

### Core Commands

```bash
# Search documentation (hybrid keyword + semantic search)
librarian search --library vercel/next.js "middleware"
librarian search --library openzeppelin/contracts "ERC20"
librarian search --library balancer/docs "swap"

# Search modes
librarian search --library <lib> --mode word "query"    # keyword only
librarian search --library <lib> --mode vector "query"  # semantic only
librarian search --library <lib> --version 5.x "query"  # specific version

# Get full document content
librarian get --library <lib> docs/path/to/file.md
librarian get --library <lib> --doc 69 --slice 19:73    # specific lines

# Find library and list available versions
librarian library "solidity"
librarian library "foundry"
```

### Managing Documentation Sources

```bash
# Add GitHub repo as source
librarian add https://github.com/owner/repo --docs docs --ref main
librarian add https://github.com/foundry-rs/foundry --version 1.x

# Add website documentation
librarian add https://docs.soliditylang.org
librarian add https://docs.balancer.fi --depth 3 --pages 500

# Ingest/update documentation
librarian ingest                    # process all sources
librarian ingest --force            # re-process existing
librarian ingest --embed            # generate semantic embeddings

# Manage sources
librarian source list               # view configured sources
librarian source remove 1           # delete a source
librarian seed                      # add built-in seed libraries
```

### Utility Commands

```bash
librarian detect      # identify project versions in current directory
librarian status      # show document counts and statistics
librarian cleanup     # remove inactive documentation
librarian mcp         # run as MCP server for AI agent integration
```

### Recommended Sources for This Project

```bash
# Solidity & Foundry
librarian add https://github.com/foundry-rs/foundry --docs docs
librarian add https://docs.soliditylang.org

# OpenZeppelin
librarian add https://github.com/OpenZeppelin/openzeppelin-contracts --docs docs

# Balancer V3
librarian add https://github.com/balancer/docs --docs docs

# Uniswap
librarian add https://github.com/Uniswap/docs --docs docs
```

### Configuration

Config file: `~/.config/librarian/config.yml`

```yaml
github:
  token: ghp_xxx              # for private repos

crawl:
  concurrency: 5

ingest:
  maxMajorVersions: 3
```
