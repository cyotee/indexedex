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

5. IndexedEx **launch scripts / Anvil** (when adding Foundry Stages, Anvil wrappers, or a gas/funding quote):
   - `.claude/skills/indexedex-launch-scripts/`: Phase/Stage layout; 4663 EIP-1559 quote vs 46630 lab. Gold: `anvil_robinhood_main` `simulate`, `anvil_robinhood_testnet` Phase/Stage.
   - Do **not** start Anvil with a bare `--fork-url`. Do **not** copy `--disable-code-size-limit` onto a 4663 estimate.

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
| Funded staking token | `rebasingClaimToken` / `IStakedDETF` | Nine-decimal sDETF, redeemable 1:1 from held DETF |

**Anti-patterns (do not reintroduce):** `RICH`, `RICHIR`, `richToken`, `wethRichVault`, `mintWithWeth`, `wethAsEth` on generic DETF surfaces.

**WETH rule:** Use `weth` / `WETH` only in code that is *actually* WETH-specific (e.g. `WETHAwareRepo`). DETF packages that accept a configurable rate asset must not name roles after WETH.

**Type names:** Prefer full words in contract/file/type names (e.g. `StandardExchange`, `MultiVaultWeightedDetf`). Short locals (`seVault_`, `share_`) are fine for stack pressure.

See `docs/superpowers/plans/2026-07-14-detf-rich-naming-generalization.md`.

## Token policy (LOCKED — project law, all products)

Universal. Applies to every SE, DETF, hook, router, and DFPkg that takes an IERC20 in `PkgArgs` or as `rateAsset` / `pairToken` / underlying. **Do not re-ask. Do not treat `WP-SEC-TOKEN-001` / `SEC-SPEC-010` as NEEDS_OWNER.**

| Class | Rule |
|-------|------|
| **Fee-on-transfer** | **Forbidden** as `rateAsset`, `pairToken`, or any configured underlying. Never a product claim. Never ship `test_L2_FoT_credits_actualIn`. Pull helpers may still credit **observed inbound delta** (I1 / L-CLAIM-3) — that is accounting robustness, **not** FoT support. |
| **Rebasing underlyings** | **Forbidden** as `rateAsset`, `pairToken`, or any configured underlying (no raw `stETH`-style `balanceOf` rebase). Official wrap faces (`wstETH`, `weETH`, `rETH`, Aave Stata / static aToken) are the required LST / lending faces. **`rebasingClaimToken` is a protocol-issued claim product**, not an underlying — it remains allowed. |
| **Non-18 decimals** | **Allowed.** Normalize where the price adapter requires WAD; retain native units at token boundaries. DETF, sDETF and their SY wrappers use 9 decimals; unrelated SE shares retain their decimals. Do not reject USDC / USDT / WBTC-class decimals and do not invent a decimals allowlist. |
| **Pause / blacklist** | **Accepted risk.** Issuer freeze is out of protocol scope. Do not add pause / blacklist detection or `PkgArgs` rejection. |
| **Enforcement** | **Docs + tests only.** No DFPkg `processArgs` allowlist. Proof: `test_L2_FoT_forbidden` with a **real FoT token as the configured token**, not a mock SUT. Official LST / Stata faces are out of that test’s scope. |

Agents must not invent FoT economics, a token allowlist, or a “this family supports FoT” exception.

## DETF families — common expectations (mandatory for agents)

Apply these to **any** DETF work under `contracts/vaults/detf/**`. The owner-approved [`DETF_ALIGNMENT_PRD.md`](../../contracts/vaults/detf/DETF_ALIGNMENT_PRD.md) **D32–D66 / §24** and [`funded staking implementation and test plan`](../../contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md) supersede conflicting earlier decisions, family PRDs, NatSpec and shared programs under `docs/detf/`. D60 excludes further Balancer-hosted DETF functionality from this release; compilation maintenance remains allowed. D66 defers unfinished Slipstream work and its release gates while preserving completed functionality, tests and evidence. Unrelated Balancer SE and shared V4 work remain in scope. The following describes that target design; it is not evidence that implementation or deployment is complete.

### Product docs vs public docs (LOCKED)

| Location | Role |
|----------|------|
| **Next to package code** (`contracts/…/<family>/…_PRD.md`, `…_IMPLEMENTATION_AND_TEST_PLAN.md`) | **Internal product law and implementation plans** for that package/family. Agents treat co-located family PRDs as normative for that family. Prefer this for new family product law. |
| **`docs/detf/`** | **Shared / cross-family** product programs (compound + expansion, thresholds) and **public-facing** or process docs (handoffs, dual-liquidity process, etc.). Not a requirement that every family PRD live here. |
| **Do not** treat co-located PRDs as “public documentation” that must be mirrored under `docs/`. Do **not** reorg existing `docs/detf/` trees solely to match package paths. |

Family-specific compound/expansion **stage plans** for Balancer families currently live under `docs/detf/balancer/v3/<family-path>/` (historical). New Uni V4 family plans may sit next to the package or under a mirrored docs path when public; product PRD stays co-located.

### What a DETF is

- A **true DETF**: the diamond **is** the share ERC-20; seigniorage mint/burn is against a **reserve that includes a DETF self-leg** (Balancer V3 weighted/stable pool + BPT, or Uni V4 Single SE Buffer CP hook + fungible LP, or family-equivalent).
- Raw DETF issuance retains the reserve-host quote and fee formulas. Primary redemption maps burnt DETF proportionally to actual protocol-owned LP and outstanding DETF supply; sDETF unstaking instead pays held DETF directly.
- **Opacity:** production DETF code talks only to `IStandardExchange*` / share ERC-20 / reserve host ABI (Balancer vault/router or Uni V4 CP buffer hook). Do **not** import concrete Uni/Aero/Camelot/Aave **vault** types into DETF production sources beyond host plumbing. Nested SE vaults (including DETF-as-vault) are allowed and must stay opaque.

### Families (when to use which)

| Family | Path | Use when |
|--------|------|----------|
| Single Standard Exchange (Balancer) | `detf/protocols/dexes/balancer/v3/standardExchange/single/` | Exactly **one** SE vault + DETF **Balancer weighted** reserve (protocol-owned BPT) |
| Composed stable multi | `detf/protocols/dexes/balancer/v3/stable/common/` | Multiple SE vaults with **like-kind** rate targets (stable-style composition) |
| Mixed-buffer multi-vault stable | `detf/protocols/dexes/balancer/v3/mixedBuffer/` | Multiple SE vaults sharing one **bufferToken** (rateAsset) in a **MixedBuffer MultiVault Stable** reserve; mint buffer or vaultShare → DETF; burn DETF → supported buffer or vault-share routes; live via permissionless `bootstrapFirstBond` |
| Multi-vault weighted | `detf/protocols/dexes/balancer/v3/multi-vault-weighted/` | Multiple SE vaults that must keep **distinct** valuations in a **weighted** reserve |
| **Uni V4 DETF (unified)** | `detf/protocols/dexes/uniswap/v4/detf/` | One DFPkg (`UniswapV4DetfDFPkg` / `IUniswapV4Detf`) bound to **one** of four buffer **hooks** (CP, Orbital, Weighted, Curve Quad). `PkgArgs.hook` + route tables. Bond NFT under `…/uniswap/v4/bondNft/`. Law: [`DETF_INSTANCE_IO_ROUTING_PRD.md`](../../contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md) §16 + [`UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md`](../../contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md). Family Uni V4 DETF diamonds are deleted |

**Layout law:** shared true-DETF infrastructure → `detf/common/`; host-family packages → `detf/protocols/dexes/<host>/…`. See `contracts/vaults/detf/DETF_DIRECTORY_REORGANIZATION_PRD.md`.

**Fresh codepath rule:** new DETF families are **behavioral references only** relative to peers — do **not** subclass concrete contracts from another family. Reuse `detf/common/core/*` and `detf/common/factory/*` libs/factories.

### Governance and immutability

- DETF instances are immutable and unowned after deploy: no normal-operation owner, diamondCut or admin pause. Flawed configuration requires a new instance.
- Wire the reserve, funded staking token, bond NFT and separate raw/staking SY wrappers during registered package deployment.
- Preserve the fee oracle as the source of usage fees, duration terms and issuance/standing reward fractions. Thresholds and the retained expansion closure rate are deployment parameters.
- Every DETF uses strict price gating with reserve-swap fallback. Remove Open mode and its configuration. Epoch length is fixed at eight hours; remove configurable supply, rebase, catch-up and mint caps.

### Liveness and first bond

- Deploy inert. The first successful family bond/bootstrap supplies actual payment and a separately minted proportional DETF self-leg to the reserve, establishes liveness and anchors the epoch clock.
- The same purchase additionally mints the purchased DETF principal and stakes it for the bond. User bond positions have no claim on held LP. All LP acquired by DETF operations belongs to the DETF as a whole, including authorized NFT custody; external LP stays external property.
- Retain family bootstrap routes: Single SE first bond; V4 configured first-bond joins; Multi-vault `initializeReserve` with non-DETF legs; Mixed Buffer `bootstrapFirstBond`; Composed Stable initialization with its inner BPT legs.
- Use the existing initial-price parameter on a linear first-bond curve, including V4's existing opening override/creation fallback. A family lacking that parameter requires an explicit requirement resolution; do not invent a seed valuation.

### Pricing and primary/swap selection

- The reserve host and existing rate providers remain the pricing engine. Preserve ordinary issuance, fee and reserve-withdrawal equations. Do not invent an off-pool FX ledger.
- Synthetic prices and percentages remain WAD; raw DETF, sDETF and their SY tokens use 9 decimals. Hook and pool adapters convert once at their documented boundary.
- Zero threshold arguments resolve through `DETFThresholdPolicy` to the existing defaults (`1.05e18` mint, `0.95e18` burn). Require mint threshold greater than burn threshold; no post-deploy setter.
- After settling due expansion, primary mint requires synthetic strictly above its threshold; primary burn requires synthetic strictly below its threshold. Equality uses the reserve swap. `isMintingAllowed` and `isBurningAllowed` describe primary issuance/redemption eligibility, not availability of the standard exchange route.
- A failed price condition explicitly selects the existing reserve-pool swap. It does not revert solely for price, mint/burn DETF supply, create an issuance reward pot or add a fallback surcharge. Genuine route, liquidity, authorization, deadline and slippage failures still revert.
- Previews project the same due expansion and choose the same branch. A first bond, direct DETF/sDETF stake/unstake and NFT claims are not price gated.
- Primary burn uses `floor(DETF in * actual protocol-owned LP / actual outstanding DETF supply)`, after expansion and before burning. Supply includes DETF in pools and staking custody. Do not subtract fictitious bond-owner LP liabilities or count external LP.

### Immediate rewards and epoch expansion

- Preserve the ordinary issuance split. Every DETF issuance allocates its seigniorage reward immediately to funded staking; reward minting/distribution does not recursively charge itself.
- Bonds preserve the unboosted proportional liquidity quote `G`. Apply the full existing duration multiplier once to actual payment to quote purchased `U`; do not stack an ordinary issuance uplift. Purchased principal is `floor((1-p)*U)` and the reward pot is `floor(p*U) + floor(p*G)`. Join only actual payment plus the separately minted `G`.
- Only automatic expansion uses epochs: first-bond anchor, fixed eight-hour boundaries, all completed intervals in one aggregate mint/distribution, no historical compounding and no catch-up cap. Preserve each reserve family's premium-closure math and eligibility conditions; advance completed boundaries even when expansion is zero.
- V4 automatic expansion uses the highest non-DETF synthetic price, with each leg normalized by its own creation price against the same current supply and reserve LP. Any leg strictly above the configured mint threshold qualifies (positive premium above peg is still required). Use that maximum in one expansion calculation; do not sum per-leg expansions. Preview, settlement and the expansion event agree on the maximum. Primary mint/burn gates remain specific to the input/output route. Owner clarification: `DETF_ALIGNMENT_PRD.md` §24.3.2, 2026-09-11.
- Settle due rewards before changing participation through exchange, staking, transfers, SY, bonding or claims. Stake present at the due boundary participates, including a deposit just before it. The transaction's new stake after settlement does not participate retroactively. Count only actually minted and funded DETF.
- Fund and stake a bond's purchased principal before its own immediate reward allocation. For an ordinary composed mint-and-stake route, distribute its issuance reward before staking the user's new principal.
- Rebase eligible ordinary stake first, then issue fully funded, freely transferable and unstakable sDETF to fee/creator recipients. New receipts do not earn their own distribution; previously held receipts are ordinary stake for later distributions.
- Fee/creator standing weights persist after all their sDETF is unstaked. Preserve top-up-only weight algebra. Reserved role NFTs hold distribution rights, not redeemable principal; transferring receipt tokens does not transfer those rights.

### Standard user routes and donations

- Consolidate fungible routes under `IStandardExchangeIn`, `IStandardExchangeOut` and Pendle `IStandardizedYield`. Retain specialized NFT operations that require a duration or position ID. Remove parallel aliases such as `mintClaim`.
- Raw DETF SY is separately backed 1:1 by raw DETF and does not automatically stake. Staking SY has static shares backed by attributed sDETF gons. Both use 9 decimals and expose only supported directional routes.
- Each SE native SY preserves its actual asset/share model, decimals, fees and existing external reward handling. Use proportional accounting value per share, not a trade-sized quote. A position vault with no single whole-book liquidity unit needs an explicit valuation policy; `yieldToken() == address(0)` alone does not define its rate.
- Direct staking mints sDETF only against actual DETF received and unstaking pays the same native number of DETF units from custody. Reserve LP is not involved.
- Reserve donations remain permissionless where specified, acquire protocol-owned LP and do not mint user DETF or create bond principal. Remove per-bond LP shares and donation allocation to such shares.
- Keep family route discovery directional and truthful. Cross-vault-share trading uses the reserve/SE router unless explicitly supported. Preserve closed-form preview/execution parity and reject unsupported exact-output routes.

### Funded staking and linear bonds

- The staking reserve holds actual DETF sufficient for every aggregate liability. Its gons conversion can stay flat or increase balances only when funded. Pool-price changes cannot reduce sDETF units. Track principal, allocation dust, ordinary rebase dust and unsolicited balances separately.
- Preserve minimum lock validation and maximum duration clamp from the existing duration formula. Each purchased NFT records funded principal, claimed principal, attributed staking gons, start and duration; it records no LP entitlement.
- Principal vests linearly. Principal-only, rewards-only and combined claims pay sDETF. Rewards are claimable while principal is still vesting. A final claim retires only that position's residual fraction and burns the fully paid NFT.
- An NFT's benefits are its discounted DETF purchase and staking while vesting. Do not retain a separate LP reward or bonus-share distribution ledger.
- Reserved NFT IDs 0/1/2 represent protocol/fee/creator roles, not purchased bonds. Fee and creator payments are ordinary sDETF that recipients may immediately unstake for DETF, even after previously redeeming all their receipts.
- Full account unstaking pays every displayed unit and retires only its own fraction. It never resets the staking index, clears another holder's gons or grants unsolicited custody to the next depositor.
- SVG/JSON must describe purchased principal, linear vesting, claimable sDETF rewards and standing role rights. Remove LP-backed redemption, cliff-only claim and invented APY language.

### Deploy path (same as vault packages)

- Facets: CREATE3 + `*FactoryService` / `DetfFacetFactoryService` / family `*_Facet_FactoryService`.
- DETF DFPkg: **Vault Registry / manager** (`indexedexManager.deployPkg` / typed `deploy*DFPkg`). **Never** `new` DFPkg/facets; never bypass registry for registered vault packages.
- `PkgInit` / `PkgArgs` **on the interface**, not the contract (Crane rule).
- **Uni V4 SE DETF peg vs opening:** `creationPairPerDetfWad` is the synthetic 1.0 (mandatory primary gates and expansion). `openingPairPerDetfWad` is pair per DETF on empty-book first bond (`0` → creation). After `isReserveLive`, mint/bond quotes use the live curve. Do not impersonate the DETF or hook `depositSingle` as the diamond to fake launch-rich. Law: `UNISWAP_V4_SE_DETF_PEG_AND_OPENING_PRICE_PRD.md`.
- Shared helpers: `contracts/vaults/detf/common/core/*`, `detf/common/factory/*`, bond NFT packages, `StandardExchangeRateProviderDFPkg`, Balancer `WeightedPoolFactory`.

### Testing expectations (DETF-specific)

Production-first rules and `indexedex-testing` apply. The funded implementation plan §11 and PRD A1–A42 are the acceptance matrix, subject to D60 and D66.

1. Use real registered diamonds, facets, DFPkgs, manager, registry, fee oracle and attached SEs. Inherit the existing Crane → Indexedex → protocol TestBase hierarchy. Protocol ports and funding tokens are acceptable; mock SUTs are not.
2. Cover all four in-scope V4 DETF bindings and every in-scope SE share issuer: metadata, installed/retired selectors, runtime size, first bond, actual liquidity plus separately funded principal, standard/SY routes and exact-output limits. Balancer-hosted DETFs have no functional completion gate under D60; unfinished Slipstream tests, forks and integration checks are deferred under D66.
3. Exercise strict threshold equality/deadband and both primary/swap regimes with real pool trades. Verify fallback preserves supply and adds no issuance pot, while genuine failures remain atomic.
4. Prove actual custody backs gons liabilities; 1:1 full/partial unstaking; funded upward/flat rebases; unsolicited balance separation; linear principal and early reward claims; multiple-NFT fraction isolation and owner/operator transfers.
5. Exercise immediate reward ordering, rebase-before-fee-receipts, persistent standing recipients after complete unstaking, just-before-boundary stake, post-boundary new stake, fixed 25-hour/seven-day catch-up and zero expansion. No Open mode, configurable caps or hypothetical unfunded accrual.
6. Keep decimal, reentrancy, allowance, pretransfer, callback, slippage, deadline and unsupported-route regressions. Never impersonate a production SUT to create a convenient market state.
7. Consolidate identical arithmetic and duplicate deployment suites, mapping every retired assertion to preserved coverage or a superseding decision. Keep distinct family and security integrations; do not reduce fuzz/depth or substitute mocks for speed.
8. Build before tests because FactoryServices load artifact creation code. Run focused checks during work and the full hermetic/relevant integration release checks. Report comparable build/test timing and test-contract counts; fewer files alone do not prove a speedup.

### Key reference paths

```text
contracts/vaults/detf/common/core/                    # shared math/lifecycle libs (incl. compound + expansion)
contracts/vaults/detf/common/factory/                 # facet/pkg factory helpers, NFT interfaces
contracts/vaults/detf/common/bondNft/                 # DETFNFTVault (shared bond NFT package)
contracts/vaults/detf/common/claimToken/              # RebasingClaimToken package
contracts/vaults/detf/common/inventory/               # legacy inventory surfaces pending reader audit
contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/  # Single SE DETF + TestBase
contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/     # multi-leg weighted DETF
contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/            # multi-vault stable + claim packages
contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/              # mixed-buffer multi-vault stable
contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/           # unified Uni V4 DETF DFPkg (+ I/O routing §16)
contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/        # Uni V4 funded bond NFT
contracts/hooks/uniswap/v4/standardExchange/                    # CP / Orbital / Weighted / Quad buffer hooks (not DETF diamonds)
docs/detf/                                            # shared compound + expansion + threshold programs (public/process)
docs/detf/balancer/v3/<family-path>/                  # historical family compound/expansion stage plans
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

After **any** production contract edit, run `forge build` **before** `forge test` / `forge script`. See **FactoryService creation bytecode** below. Do not treat `forge test` as a substitute for that build.

```bash
# After production contract edits: build first so FactoryService reads current out/
forge build
forge build --sizes         # with contract size output

# Hermetic (default profile → test/foundry/spec) — only after a current forge build
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

# Local Anvil / launch scripts: load skill `indexedex-launch-scripts`.
# Gas/funding quote (4663, EIP-170 on):  scripts/shell/anvil_robinhood_main.sh simulate --restart-anvil
# Dev lab (46630 Phase/Stage):           scripts/shell/anvil_robinhood_testnet.sh all
# Do not use a bare `anvil --fork-url` for either path.
```

### FactoryService creation bytecode (LOCKED — project law)

IndexedEx FactoryServices load creation bytecode from `out/` via `ArtifactCreationCode.creationCode("File.sol:ContractName")` (`vm.getCode`). They do **not** import Facet/DFPkg implementations solely for `type().creationCode`. That cut is the compile-time win: editing a production implementation no longer invalidates the FactoryService compile unit or the TestBase / script fan-out.

**After any production contract change, run `forge build` then `forge test` (or `forge script`). Do not run `forge test` first and assume Foundry rebuilt the deployed bytecode.**

```bash
# After editing facets / DFPkgs / targets / Crane seed targets:
forge build
forge test --match-path 'test/foundry/spec/...'
```

- `forge build` compiles `src = 'contracts'`, including `contracts/utils/foundry/CraneFactoryArtifactSeed.sol` (the compile root for Crane implementations those services deploy).
- `forge test` does **not** reliably refresh those artifacts when the test graph no longer imports the implementation. Tests then CREATE3-deploy whatever is already in `out/`.
- A `forge build` is also required when artifacts are missing (empty worktree `out/`, deleted cache, or a command that skips compiling `contracts/`).
- Missing artifact: `vm.getCode` reverts (no matching artifact). That is expected. Do not deploy empty bytecode.
- Do not delete `CraneFactoryArtifactSeed.sol`. Do not import it from TestBases or FactoryServices.
- Worktree seed (`cache_forge/` + `out/` from a warm checkout) stays in force; `out/` is load-bearing for FactoryService deploys. Seeded `out/` is **stale** the moment you edit production source: `forge build` again before test.
- Crane FactoryServices (`AccessFacetFactoryService`, `IntrospectionFacetFactoryService`) still embed `type().creationCode` (out of this bytecode path). IndexedEx FactoryServices do not.

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

// CORRECT — IndexedEx FactoryService (creation bytecode from out/)
myFacet = create3Factory.deployFacet(
    ArtifactCreationCode.creationCode("MyFacet.sol:MyFacet"),
    abi.encode("MyFacet")._hash()
);

// CORRECT — Crane FactoryService still uses type().creationCode
// (AccessFacetFactoryService, IntrospectionFacetFactoryService)
```

FactoryService libraries (Crane + IndexedEx):
- Crane core: `AccessFacetFactoryService`, `IntrospectionFacetFactoryService` (in Crane). Those still embed `type().creationCode`.
- IndexedEx core: `IndexedexManagerFactoryService`, `FeeCollectorFactoryService`, `VaultComponentFactoryService` (artifact bytecode via `ArtifactCreationCode`).
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
