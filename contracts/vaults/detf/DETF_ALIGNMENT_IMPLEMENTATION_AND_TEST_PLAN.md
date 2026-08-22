# DETF alignment — implementation and test plan

## Agent execution header

| Field | Value |
|-------|--------|
| **This file is the sole implementation scope** | Stages **A → H** are **green** (2026-08-19). Execute **I → O** in order: N10, D30, D25, D15+D31, D29 donate. Do not start a later stage until that stage’s DoD is green. |
| **Product law** | [`DETF_ALIGNMENT_PRD.md`](./DETF_ALIGNMENT_PRD.md) **D1–D31** and [`DETF_RESERVE_DONATION_PRD.md`](./DETF_RESERVE_DONATION_PRD.md) **v0.3**. Those files win on product. This file wins on sequence, file lists, launch defaults, and test names. |
| **Compound / expansion** | Already LOCKED: [`docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](../../../docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md). D31 is the allowed cross-cut (realize on mint/burn/redeem/close). Donate does **not** realize. |
| **Status** | **OPEN** — 2026-08-22 for Stages I–O. A–H remain green historical. |

**Goal-command prompt (paste this):**

```
Execute contracts/vaults/detf/DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md
from Stage I through Stage O.

Read first: that plan, then DETF_ALIGNMENT_PRD.md D10 N10 / D15 / D25 / D29 / D30 / D31,
then DETF_RESERVE_DONATION_PRD.md v0.3, then CLAUDE.md +
docs/agent/INDEXEDEX_AGENT_LAW.md.

Do not invent product law. Do not change live mint/burn quote, split, D11 join,
D13 burn sizing, or Policy vs Open inequalities except D31 realize-then-gate.
Use L1–L7. Production-first tests. No SUT mocks. DETF role names only.
via_ir forbidden. Forge patience: first compile 2–4 hours, never kill forge.

Mark each stage DoD in this plan file when green (command + evidence).
Stop and ask if a product fork is not covered by D1–D31, the donation PRD, or L1–L7.
```

**Conforms to product law; no re-litigation.**
Role names only (`rateAsset`, `pairToken`, `vaultShare`, `detfToken`, `reservePool`, `rebasingClaimToken`).

---

## 0. How to run this plan

1. Open this file and the alignment PRD. Do not open DualLiquidity family PRDs as product law.
2. If this is a **new or empty worktree**, seed `cache_forge/` and `out/` from a warm checkout before the first `forge` (CLAUDE.md worktree seed). Prefer `ln -s` for `lib/crane`.
3. Implement one stage. Update that stage’s status table.
4. Run that stage’s **required** `forge` commands. Wait for process exit. Timeouts: **10800000 ms (3 h)** on first compile in a worktree, **3600000 ms (1 h)** after the tree is warm.
5. Do not mark a stage done from compile-only. Tests listed in that stage must pass.
6. After Stage O, the launch gate in §9 (I–O rows) must be all checkboxes or an explicit defer with reason (Composed donate until D13 custody is the only allowed defer).

Do **not** implement topics that are still open in the PRD except the launch defaults in §2.

---

## 1. Goals / non-goals

### Goals

1. Align every **true** DETF family to D1–D31 so launch uses one mint / bond / burn / claim / close / donate process (A–H done; I–O is the 2026-08-22 remainder including D29).
2. Delete DualLiquidity (D1).
3. `feeTo` and creator earn **only** via reserved bond NFTs ids **1** and **2**. They can claim, and **only** their D2 share (D28 FC1–FC12).
4. Keep Balancer public join (D9 exception). Close Uni V4 reserve LP to the DETF (D9).
5. Do not introduce new extract, double-claim, or over-mint bugs. Existing compound, expansion, and threshold suites must stay green.

### Non-goals

- Reopening compound / expansion Phase 1–2 law except **D31** realize-then-gate.
- Closing Balancer public join.
- AmountIn bonus on **burn** (D20 stays off).
- AmountIn bonus on bond `G` (D24).
- Deleting unused `UniV4DetfBondNft` (L3).
- Frontend, deploy scripts beyond what TestBases need, or marketing copy.
- Inventing a Uni-style `creationPairPerDetfWad` on Balancer families.

---

## 2. Launch defaults (residuals the PRD left open)

These are **normative for this plan**. If product later contradicts them, amend the PRD first.

| ID | Residual | Launch default |
|----|----------|----------------|
| **L1** | Bond free `U` (PRD §9.2) | Bonds **still mint** free `U`. Size `U = G` (unboosted matching DETF). Apply D3: user `(1-p)*G`, pot `p*G`. **Also** D4: extra pot `p*G`. Join into reserve remains full `G`. Do **not** set `U = 0` on bonds. |
| **L2** | D25 `minOut` shape | `closeBondMature(..., uint256[] minAmountsOut, ...)`. Array length = reserve token count, **same order as the family reserve list**. Slot for the DETF self-leg **must be 0**. Preview returns the non-DETF amounts (DETF slot 0). Preview == execute. |
| **L3** | Unused `UniV4DetfBondNft` package | **Ignore.** Do not delete in this pass. |
| **L4** | D20 burn bonus | **Off.** Do not apply `(1+p)` on burn `amountIn`. |
| **L5** | Balancer join | **Leave public.** Do not add allowlists or DETF-only BPT. |
| **L6** | Wired sentinel | Dedicated `bool` / “bond vault address set”. **`detfNftId == 0` is a valid protocol id** (D7). |
| **L7** | D2 add on ids 1–2 | New NFT vault function `addEffectiveSharesOnly(uint256 tokenId, uint256 shares)` (`onlyOwner`, tokenId is 1 or 2). Updates `effectiveShares` + reward debt like `_addToPosition` first/add paths. **Does not** change `originalShares`. Do not reuse `addToDETFNFT` (that stays id 0 + 1:1 original). |

Oracle first values (D6), written at manager/oracle init (not a product constant the DETF reads):

| Field | WAD |
|-------|-----|
| `p` | `5e16` (already `DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE`) |
| `f` | `12e16` |
| `c` | `28e16` |

Check: `f + c = 0.40e18 < 1e18`. Reject any setter write that would resolve `f + c >= 1e18`.

---

## 3. Non-negotiables (every stage)

1. Crane first: facets via CREATE3 / FactoryService. Vault/DETF DFPkgs via `indexedexManager.deploy*DFPkg` then `deployVault`. Never `new` facets/DFPkgs.
2. `PkgInit` / `PkgArgs` on the **interface**.
3. Production-first tests. No mock of DETF, NFT vault, claim token, manager, registry, fee oracle, facets, DFPkgs.
4. Gold bases: `CraneTest` → `IndexedexTest` → family `TestBase_*`.
5. **`via_ir` forbidden.**
6. Forge patience. Cold/near-cold solc is 20–40+ minutes with little output. Wait for exit. Do not kill `forge` / `solc`.
7. After a green worktree forge, copy `cache_forge/` + `out/` back to the warm seed.
8. Weird-token law: FoT forbidden; rebasing underlyings forbidden; non-18 scale to 18.
9. Do not invent product. Stop if the PRD and L1–L7 do not cover it.

---

## 4. In-scope families and gold TestBases

| Host | Family | Production root | Gold TestBase |
|------|--------|-----------------|---------------|
| Balancer V3 | Single SE | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/` | `TestBase_SingleStandardExchangeDETF.sol` |
| Balancer V3 | Multi-vault weighted | `…/multi-vault-weighted/` | `TestBase_MultiVaultWeightedDetf.sol` |
| Balancer V3 | Mixed-buffer | `…/mixedBuffer/` | `TestBase_MixedBufferMultiVaultStableDetf.sol` |
| Balancer V3 | Composed stable | `…/stable/common/` | `TestBase_ComposedStableCommonDetf.sol` |
| Uni V4 | Single SE CP | `…/uniswap/v4/standardExchange/constantProduct/single/` | family TestBase in that tree |
| Uni V4 | Orbital | `…/uniswap/v4/standardExchange/orbital/` | `TestBase_UniswapV4StandardExchangeOrbitalDETF.sol` |
| Uni V4 | Weighted | `…/uniswap/v4/standardExchange/weighted/` | `TestBase_UniswapV4StandardExchangeWeightedDETF.sol` |
| Uni V4 | Curve Quad | `…/uniswap/v4/standardExchange/stable/quad/curve/` | family TestBase in that tree |

**Out:** DualLiquidity (`…/balancer/v3/uniswap/v4/crossVersion/v2/`) — delete (Stage B).

Spec tests live under `test/foundry/spec/vaults/detf/protocols/dexes/**` mirroring that tree.

---

## 5. Shared design (implement once, consume everywhere)

### 5.1 Mint split (replaces `_splitMintedDetf` half-incentive + `feeToDetf`)

```
// Live mint
Gross = curve(amountIn * (1 + p))           // D8, live only
user  = Gross * (1e18 - p) / 1e18           // D3 / D27
pot   = Gross * p / 1e18                    // inventory to NFT vault only
// no feeTo mint, no usage-fee peel (D14)

// Bond
G     = unboosted proportional DETF         // D24; empty pool = family creation/weights
join  = G                                   // into reserve
userU = G * (1e18 - p) / 1e18               // L1
pot   = G * p / 1e18                        // D3
      + G * p / 1e18                        // D4 additional
```

Floor `mulDiv`. Put this in `DETFMintSplitLib` (or a new `DETFSeigniorageSplitLib` if you must keep the old helper for one commit). Delete `_splitHalfSeigniorage` call sites on in-scope families. Do not keep both splits.

### 5.2 Reserved NFT ids (D7)

Wire **0, then 1, then 2** before any user `createPosition`.

| Id | Owner | `originalShares` | Path |
|----|-------|------------------|------|
| 0 | bond vault (`address(this)`) | yes (claim backing) | existing protocol NFT |
| 1 | `feeOracle.feeTo()` | **never** | standing reward |
| 2 | `PkgArgs.creator`, or `feeTo` if `creator == 0` (D21) | **never** | standing reward |
| ≥3 | purchaser | yes | user bonds |

`sellPositionToDetfNft` / `closeBondMature` revert for ids 1 and 2.

Replace `detfNftId == 0` “unwired” checks (L6).

### 5.3 D2 top-up

After any event that changes `O` (user bond, sell-in, `buyClaim`, compound `addToDETFNFT`, other principal 4626 mint):

```
T  = O * 1e18 / (1e18 - f - c)
dF = max(0, T * f / 1e18 - F0)
dC = max(0, T * c / 1e18 - C0)
```

Call `addEffectiveSharesOnly(1, dF)` and `addEffectiveSharesOnly(2, dC)`. Floor. Never negative. Shared helper in `DETFBondLifecycleLib` or a new `DETFSeigniorageShareLib`. Every family calls the same helper. Do not clone the formula.

Reward debt: first shares on an id set `paid = rewardPerShares`. Additional shares preserve prior pending only (same idea as `DETFNFTVaultRepo._addToPosition`). New shares must not claim old pot (FC4).

### 5.4 Live mint vs bond vs claim

| Path | DETF into reserve | Quote |
|------|-------------------|-------|
| Live `exchangeIn` → DETF | **No** new DETF. Non-DETF capital may join; NFT holds LP **without** new `originalShares` (NAV change). | D8 bonus on `amountIn` |
| Bond | **Yes**, unboosted `G` | Not D8 |
| `exchangeIn` DETF → claim | Move **provided** DETF in. 4626 to **id 0**. No new mint. | n/a |

Burn **burns** DETF (D12). LP size `lpOut = detfIn * nftLp / detfSupply` after expansion mint-on-update (D13). Then D20 single-sided `tokenOut` + rejoin other legs.

### 5.5 Claim redeem (D15) and mature close (D25)

**Claim → DETF:** realize expansion first (D31) → harvest **all** id 0 pending → if still short, proportional LP withdraw → **buy DETF on the residual reserve** largest-leftover-first by DETF-buying power (D30 owner swap) → rejoin leftover to id 0 (`lpOut > 0` at MIN). Quote is zap-out to DETF + pending (D10/D15). No mint/burn gates (D22).

**Mature close id ≥ 3:** `claimRewards` on that NFT → `lp = convertToAssets(originalShares)` → proportional withdraw through the NFT → **rejoin withdrawn DETF to id 0** (`addToDETFNFT`) → send remaining non-DETF tokens → retire NFT. Do **not** burn that DETF. Not D20. Not sell-to-claim (D10 stays a separate path).

### 5.6 Uni V4 hooks (D9)

Each DETF-reserve hook: **MultiStepOwnable**, owner = DETF diamond. Deploy-time `ownerOnlyLiquidity = true` on DETF instances. Third-party `addLiquidity` / `removeLiquidity` / native `modifyLiquidity` revert. **Public swaps stay public.** **D30:** owner exact-in/out swap and LP add/remove must work while PoolManager is already unlocked (no SwapRouter / nested `unlock`). Flag off remains valid for non-DETF hook uses.

Balancer: do nothing to close join (L5).

---

## 6. Stages

Status values: `pending` → `in_progress` → `green` | `blocked`.

### Stage A — Shared kernel (oracle, split lib, NFT ids, D2)

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | nothing |
| **Blocks** | C–G |

#### A.1 Code

| Surface | Action |
|---------|--------|
| `IVaultFeeOracleQuery` / `IVaultFeeOracleManager` / `VaultFeeOracleQueryFacet` / `VaultFeeOracleManagerFacet` / `VaultFeeOracleRepo` | Add 3-tier `f` and `c` (names in PRD §6.2). Tuple getters in PRD §6.3. Reject `f + c >= 1e18`. |
| `IndexedexManagerDFPkg` init | Write initial `p = 5e16`, `f = 12e16`, `c = 28e16`. Stop treating `DEFAULT_SEIGNIORAGE_INCENTIVE_PERCENTAGE` as product law; it may remain the init literal for `p` only. |
| `IFacet` tests for fee oracle | New selectors on query + manager facets. |
| `DETFMintSplitLib` | D3/D4/D27/L1 helpers. Deprecate half-split at call sites in later stages. |
| `DETFNFTVault*` (shared package) | Reserved ids; `addEffectiveSharesOnly`; `claimRewards` already exists; revert sell/close on 1–2; L6 wired flag. |
| `DETFBondLifecycleLib` | Shared D2 top-up after O-changing events. |
| Composed’s **own** NFT vault | Same id / addEffective / sell-close rules (do not leave Composed on `feeRecipientNftId` + usage-fee principal). |

#### A.2 Tests (hermetic, production deploy)

| Suite | Path | Must prove |
|-------|------|------------|
| Oracle f/c | `test/foundry/spec/oracles/fee/VaultFeeOracle_SeigniorageShares.t.sol` (new) | Set/read 3-tier; tuple getters; reject `f+c >= 1e18`; init values from manager deploy |
| NFT ids | extend `test/foundry/spec/vaults/detf/common/bondNft/` | Wire 0/1/2; user starts at 3; `addEffectiveSharesOnly` no originalShares; sell/close revert 1–2 |
| Split lib | `test/foundry/spec/vaults/detf/common/core/DETFMintSplit_Alignment.t.sol` (new) | Live U=Gross; bond L1 user+D3+D4; floor |

#### A.3 Commands

```bash
# First compile in a worktree: 3h timeout. After warm: 1h is usually enough.
forge test --match-path 'test/foundry/spec/oracles/fee/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/common/**' -vv
```

#### A.4 DoD

- [x] `f`/`c` readable on the **manager proxy** after `indexedexManager` deploy
- [x] NFT package: ids 0/1/2 reserved; FC9-shaped originalShares=0 on 1–2 after addEffective
- [x] No family mint path switched yet (that is Stage C+)
- [x] Commands above green

---

### Stage B — Delete DualLiquidity (D1)

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | none (can overlap A if needed) |
| **Blocks** | launch (must not ship DualLiquidity) |

#### B.1 Delete surface

| Surface | Path |
|---------|------|
| Solidity | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Fork TestBase + suite | `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Spec tests if any | `test/foundry/spec/**/crossVersion/v2/` |
| Family docs | `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/` |
| Factory / manager / registry wiring | `deploy*DualLiquidity*` helpers, type ids, inventories |
| Agent law / maps | `docs/agent/INDEXEDEX_AGENT_LAW.md`, `docs/CODEBASE_MAP.md`, content inventory, skill catalog if listed |
| Nested-SE matrices | Any test that used DualLiquidity as a leg: switch to another **production** SE or true DETF |

Do not relocate DualLiquidity outside `detf/` as a surviving product.

#### B.2 Commands

```bash
# Compile must fail if leftover imports remain:
forge build
rg -n 'DualLiquidityLinked' contracts test docs --glob '!**/DETF_ALIGNMENT*' --glob '!**/*superseded*' 
```

`rg` should only hit historical research / this alignment PRD’s D1 section / superseded banners you leave as history.

#### B.3 DoD

- [x] Package, tests, factory entry points gone
- [x] `forge build` green
- [x] No production import of DualLiquidity
- [x] Nested matrices retargeted

---

### Stage C — Pathfinder: Balancer Single SE (full family alignment)

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | A green |
| **Blocks** | D (other Balancer), pattern for E |

This family is the reference. Get C green before cloning the pattern.

#### C.1 Code

| File (under `standardExchange/single/` unless noted) | Action |
|------------------------------------------------------|--------|
| `ISingleStandardExchangeDETDFPkg` `PkgArgs` | Add `address creator` (D26) |
| DFPkg wire | Mint ids 0, 1 (`feeTo`), 2 (`creator` or `feeTo`) |
| `*Common` / `*ExchangeInTarget` | Live mint: D8 + D27 + D11 (no DETF into pool). D14 no feeTo mint. |
| `*BondingTarget` | Unboosted `G` (D24). L1 + D4 pot. D2 after O change. First bond all non-DETF legs (vault share). |
| `closeBondMature` | D25 + L2. Drop single `tokenOut` close. |
| `sellPositionToDetfNft` / claim | D10 / D15 / D22. Ids 1–2 cannot sell. |
| Burn / `exchangeOut` | D12, D13, D20, L4. Composed-style swap-not-burn must not appear here. |
| `buyClaim` | `exchangeIn` DETF→claim (D18). |
| TestBase | Helpers: `_potDelta`, `_weightsFC()`, `_claim(id)`, `creator` in `PkgArgs` |

#### C.2 Tests (new + update)

New file (required name, unique prefix):

`test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Alignment_FeeCreatorClaim.t.sol`

Functions **must** be named `test_FC1_…` … `test_FC12_…` (D28). Production proxy only.

Also update or add:

| File | Point |
|------|--------|
| `*_Mint.t.sol` / `*_Burn.t.sol` | D8 live-only; no DETF join on live mint; burn burns; no feeTo mint |
| `*_Bonding.t.sol` | G unboosted; L1+D4 pot; first bond vault share + DETF; D2 weights after bond |
| `*_Claim.t.sol` | D15 order; D22 ungated; rebase in DETF |
| close suite (new or bonding) | D25 prop withdraw, DETF rejoined to id 0, remainder to user |
| existing `*_ProtocolCompound.t.sol` / `*_NaturalExpansion.t.sol` / `*_ThresholdMode.t.sol` | **Stay green** |
| `adversarial/**` | Re-run; add FC7/FC8/FC12 if not covered. I1–I3 / A0 / CROPS still required |

#### C.3 Commands

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**' -vv
forge test --match-contract SingleStandardExchangeDETF_Alignment_FeeCreatorClaim -vv
```

Use `--match-contract` for FC tests. Do **not** `--match-test test_C` (collides with ProtocolCompound).

#### C.4 DoD

- [x] FC1–FC12 green on the deployed Single SE proxy
- [x] Live mint does not increase reserve DETF balance
- [x] Bond increases reserve DETF by `G` (unboosted); pot increases by `2 * p * G` (L1+D4)
- [x] Mature close (pre-2026-08-22): user receives non-DETF basket; DETF from exit is burned — **superseded by Stage K**
- [x] Compound + expansion + threshold suites green
- [x] Adversarial path green or deferred IDs in suite NatSpec

Evidence: `{SCRATCH}/forge-fc-single-se.log` (12/12 FC) and `{SCRATCH}/forge-family-single-se.log` (158 passed, 0 failed). D18 `exchangeIn(DETF→claim)` stays on `buyClaim` (same-diamond `nonReentrant`); D15 `redeemClaim` pays DETF only.

---

### Stage D — Remaining Balancer families

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | C green |
| **Order** | Multi-vault weighted → Mixed-buffer → Composed stable |

Same product as C. Family-owned: curve, token set, first-bond legs (PRD §16.3), live `tokenIn`.

| Family | Extra must-fix (shipped, out of spec) |
|--------|----------------------------------------|
| MVW | First bond **every** vault-share leg (not BPT-only). `PkgArgs.creator`. |
| Mixed-buffer | Live mint must **not** join gross DETF. First bond buffer + every vault-share. Burn not buffer-only. |
| Composed | **Burn burns** (replace swap-not-burn). Own NFT vault: ids 0/1/2, D2, no usage-fee principal on fee NFT. Claim redeem DETF-only (D15). |

Do **not** close Balancer public join (L5).

#### D.1 Tests

Per family, new:

`…/<family>/<Family>_Alignment_FeeCreatorClaim.t.sol` with `test_FC1_`…`test_FC12_`.

Update that family’s Mint/Bond/Burn/Claim/ProductLaw suites.

#### D.2 Commands

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/**' -vv
```

#### D.3 DoD

- [x] Each family: FC1–FC12 green
- [x] Each family’s existing compound / expansion / threshold / adversarial suites green
- [x] No Balancer-only product fork except L5 open join and family curve/token set

Evidence: MVW FC 12/12 + family 180/180; Mixed-buffer FC 12/12 + family 170/170; Composed FC 12/12 (suite 18) + family 270/270. Logs under `{SCRATCH}/forge-fc-mvw.log`, `forge-family-mvw.log`, `forge-fc-mixed-buffer.log`, `forge-family-mixed-buffer.log`, `forge-fc-composed.log`, `forge-family-composed.log`. Mixed-buffer live buffer mint zaps buffer→vault-share 0 then joins shares only (virtualBuffer updates after join; still no DETF into pool).

---

### Stage E — Uni V4 hooks: owner-only LP

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | A (can overlap D) |
| **Blocks** | F |

Hooks used as DETF reserves: CP, Orbital, Weighted, Curve Quad (package path).

| Change | Detail |
|--------|--------|
| MultiStepOwnable | Owner = DETF diamond after DETF deploy |
| `PkgArgs.ownerOnlyLiquidity` | `true` on every DETF-deployed hook |
| When true | onlyOwner add/remove LP; native V4 `modifyLiquidity` blocked for third parties |
| When false | existing permissionless LP (non-DETF) |
| Swaps | stay public |

Skill: `indexedex-uniswap-v4-hook-packages`. Deploy still package → registry → hook factory.

#### E.1 Tests

Per hook package: third party `addLiquidity` reverts when flag on; DETF (owner) succeeds; swap still works.

#### E.2 DoD

- [x] Flag on in every Uni V4 DETF TestBase deploy
- [x] Third-party LP revert tests green
- [x] Swaps still pass

**Evidence (2026-08-19):** `forge test --match-contract OwnerOnlyLiquidity -vv` — 24 passed (4 hook packages × owner/third-party/swap + 4 DETF `reserveHook` owner proofs). Permissionless LP (`ownerOnlyLiquidity=false`) regression: 68 passed on family Liquidity + Swap suites. Log: `forge-univ4-hooks.log`.

---

### Stage F — Uni V4 DETF families

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | A + E |
| **Order** | CP → Orbital → Weighted → Curve Quad |

Same product as C. Differences:

| Concern | Law |
|---------|-----|
| Empty first bond | `creationPairPerDetfWad` (already shipped). No D8. |
| Later bonds | Unboosted `G` vs live book (D24) |
| Mid-based `effectiveBase` | **Superseded.** 4626 on LP + lock bonus on effective only (D10) |
| LP custody | NFT vault (D13) |
| Close | D25 + L2, not consolidate-to-single-capital |
| `PkgArgs.creator` | D26 |

`UniV4DetfBondNft` leftover package: **ignore** (L3). Prefer the shared `DETFNFTVault` path already used by Balancer if a family still has a parallel NFT.

#### F.1 Tests

Per family: `*_Alignment_FeeCreatorClaim.t.sol` (`test_FC1_`…`test_FC12_`).

Update Bond / MintBurn / Claim / FirstBond / Expansion suites.

#### F.2 Commands

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/**' -vv
```

#### F.3 DoD

- [x] Each Uni V4 family: FC1–FC12 green
- [x] Third party cannot LP the reserve hook
- [x] Bond `G` is not D8-boosted
- [x] Existing expansion / adversarial suites green

Evidence: CP 12+76, Orbital 12+81, Weighted 12+88, Curve Quad 12+78. Logs `forge-fc-univ4-*.log` / `forge-family-univ4-*.log`. Quad D15 DETF-only redeem not fully ported (pair redeem kept; defer).

---

### Stage G — Cross-family regression and law docs

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | C–F green (B may complete in parallel) |

#### G.1 Docs (product names only; no extra law)

- `docs/agent/INDEXEDEX_AGENT_LAW.md` family table: DualLiquidity gone; cite alignment PRD for mint/bond/claim/close.
- Family PRDs that contradict §16.1: one-line **superseded** banner pointing at `DETF_ALIGNMENT_PRD.md` (do not rewrite every family PRD).
- DualLiquidity docs: keep superseded banner until Stage B deleted them.
- `docs/CODEBASE_MAP.md` / content inventory / skill catalog: drop DualLiquidity; do not list it as a live family.

#### G.2 Regression commands

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/**' -vv
forge test --match-path 'test/foundry/spec/oracles/fee/**' -vv
```

If a fork suite exists for a remaining family and is part of that family’s ship bar, run it with `FOUNDRY_PROFILE=fork` and the same patience rules. DualLiquidity fork tests must be gone (B).

#### G.3 DoD

- [x] Full DETF spec path green
- [x] Agent law no longer lists DualLiquidity as a product
- [x] Family PRD supersede banners in place where they contradicted §16.1

Evidence: `forge-regression-detf.log` 1251 passed 0 failed; `forge-regression-fee.log` 157 passed 0 failed. Agent law: DualLiquidity deleted (D1). Superseded banners on Balancer product-law PRD + Uni V4 CP/Orbital/Weighted/Quad family PRDs.

---

### Stage H — Launch gate

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | B + G |

Copy from Crane `implementation-test-dod.md` plus this program:

#### Architecture

- [x] `PkgArgs.creator` on **every** in-scope family interface
- [x] `PkgInit`/`PkgArgs` on interfaces
- [x] Facets CREATE3; DFPkgs via manager/registry
- [x] Every new Target selector is on a Facet and on the proxy (J1–J3)

#### Product

- [x] D7 ids 0/1/2 on every family proxy
- [x] D14: no DETF mint/transfer to `feeTo` on mint/burn
- [x] D27 + L1 split; pot-only destination
- [x] D24: bond `G` unboosted
- [x] D11: live mint does not mint DETF into the pool
- [x] D12/D13/D20/L4 burn
- [x] D25 + L2 mature close (**re-proof after 2026-08-22:** rejoin withdrawn DETF to id 0, do not burn)
- [x] D15 claim redeem (**re-proof:** D31 realize, zap-out quote, harvest-all pending, residual DETF buy largest-first, D30)
- [x] D31 mint/burn realize expansion then gate (post-realize synthetic; revert whole tx if gate fails)
- [x] D29 donate to id 0 (Stages M–O; Composed donate deferred until D13 NFT custody)
- [x] D9 + **D30:** Uni V4 owner-only LP **and** owner swap/LP while PoolManager is already unlocked; owner `depositSingle` at MIN **lpOut > 0**; Balancer still public
- [x] D1: DualLiquidity gone

#### Tests

- [x] FC1–FC12 green on **each** of the 8 families (`--match-contract *Alignment_FeeCreatorClaim`)
- [x] I1–I3 / A0 / CROPS still green on families that had them
- [x] Compound + expansion + threshold suites green
- [x] Preview == execute on closed-form routes
- [x] No mock SUT in new tests

#### Anti-rubber-stamp

- [x] Not “claimed > 0” only
- [x] Not tests against facet implementation addresses
- [x] Not `expectRevert()` bare
- [x] Not DualLiquidity used as a behavioral reference

**Defer:** Composed donate until LP sits on `DETFNFTVault` with N10. D18 on Balancer Single SE and Uni V4 families stays on `buyClaim`/`depositClaim` (same-diamond `nonReentrant`). Quad pair-redeem is closed (Stage L).

Logs copied under `{SCRATCH}`: `forge-fc-*.log`, `forge-family-*.log`, `forge-regression-detf.log` (1251/0), `forge-regression-fee.log` (157/0), `forge-univ4-hooks.log`.

---

### Stage I — N10 4626 conversion

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | A–H historical green |
| **Blocks** | K–O |

Fix `DETFNFTVaultRepo._totalLpReserveForConversion`: numerator `lpToken.balanceOf(NFT)`, denominator `totalOriginalShares`, keep `decimalOffset`. Do not subtract protocol effective shares. `convertToAssets` / close / claim `lpOut` use **originalShares**.

Composed’s own NFT repo: same formula once that family holds LP on the NFT. If conversion still reads diamond `reserveOfToken`, fix that family in Stage K/L only if custody is already NFT; otherwise defer with NatSpec.

Tests: `test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVault_N10Conversion.t.sol` — user does not absorb id 0’s share; decimalOffset still on; empty O/L is 1:1.

```bash
forge test --match-contract DETFNFTVault_N10Conversion -vv
```

Update one family close/claim suite that previously assumed the haircut so it does not go red for the wrong reason.

#### I.1 DoD

- [x] N10 in shared Bond NFT repo
- [x] No `effectiveShares` as 4626 input on close
- [x] Command green
- [x] Existing FC suites still green on at least Uni V4 CP + Balancer Single SE (`--match-contract *Alignment_FeeCreatorClaim`)

Evidence (2026-08-22): `forge test --match-contract DETFNFTVault_N10Conversion -vv` — 4 passed. `forge test --match-contract 'UniswapV4SingleStandardExchangeDETF_Alignment_FeeCreatorClaim|SingleStandardExchangeDETF_Alignment_FeeCreatorClaim|UniswapV4SingleStandardExchangeDETF_BondTest' -vv` — 30 passed (FC 12+12, Bond 6 including `test_N10_userBondDoesNotAbsorbId0Lp`). Logs: `{SCRATCH}/forge-n10.log`, `{SCRATCH}/forge-fc-after-n10.log`. Composed NFT conversion still reads diamond `reserveOfToken` (N10 NatSpec defer until D13 custody).

---

### Stage J — D30 owner host ops while locked

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | E green (owner-only LP already) |
| **Blocks** | K–O |

Per Uni V4 DETF-reserve hook (CP, Orbital, Weighted, Quad buffer packages):

| Change | Detail |
|--------|--------|
| `ownerSwapExactIn` / `ownerSwapExactOut` | `onlyOwner`. Same book and **same trading fee** as public swaps (CP: 0.3%). |
| While PM unlocked | Settle on current unlock **or** internal book settlement. No SwapRouter. No nested `unlock`. |
| Owner `depositSingle` at MIN | Allowed. Public still reverts. Same zap math. **`lpOut > 0` or revert.** |
| Facet cuts | J1–J3 on hook diamond |

Tests per hook: `test/foundry/spec/hooks/uniswap/v4/standardExchange/<family>/*OwnerDuringLock*.t.sol` with `test_D30_` / `test_D89_`.

Balancer: no hook. Document in Stage L NatSpec: leftover→DETF buy runs inside the same Vault unlock as the exit; no nested Router.

```bash
forge test --match-contract '*OwnerDuringLock*' -vv
```

#### J.1 DoD

- [x] All four DETF-reserve hook packages: owner swap + MIN `lpOut > 0` + third party cannot use owner path
- [x] Public swaps still pass
- [x] Stage E third-party LP revert still green

Evidence (2026-08-22): `forge test --match-contract 'OwnerDuringLock|OwnerOnlyLiquidity' -vv` — 49 passed, 0 failed (4 hook OwnerDuringLock + 4 hook OwnerOnlyLiquidity + 4 DETF OwnerOnlyLiquidity). Logs: `{SCRATCH}/forge-d30-owner-during-lock.log`, `{SCRATCH}/forge-univ4-hooks-e-regress.log`.

---

### Stage K — D25 close: rejoin DETF to id 0, basket out

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | I, J (J for Uni V4 MIN rejoin) |
| **Blocks** | L (redeem uses same rejoin helpers) |

Every in-scope family `closeBondMature`:

1. D31 realize expansion.
2. `claimRewards` on that user NFT (expansion + other pending to the bonder as free DETF).
3. `lp = convertToAssets(originalShares)` (N10).
4. Proportional withdraw.
5. Rejoin **DETF only** (`depositSingle` / Balancer DETF-leg join) to NFT; `addToDETFNFT(id 0)` 1×. **Do not burn** that DETF. MIN: owner path, `lpOut > 0`.
6. Send **every** remaining non-DETF token (L2 `minAmountsOut`; DETF slot **0**). **No** consolidate to one `tokenOut`.
7. Retire NFT. D2 after id 0 credit.

Balancer family PRD single-`tokenOut` close is **superseded**. Drop consolidate helpers from close.

Per family: `…/<Family>_Alignment_CloseD25.t.sol` with `test_D25_`.

| ID | Must prove |
|----|------------|
| **D25-1** | User DETF balance increases only by `claimRewards` (expansion/pending), not by withdrawn self-leg |
| **D25-2** | Withdrawn DETF is not burned (`totalSupply` does not drop by that amount) |
| **D25-3** | Id 0 `originalShares` rise by `convertToShares(lpFromDetfRejoin)` |
| **D25-4** | User receives each non-DETF reserve leg (basket). Mixed-buffer: not buffer-only |
| **D25-5** | Ids 1–2 still cannot close |
| **D25-6** | Preview == execute (L2) |
| **D25-7** | After only-user-bond close, owner rejoin at MIN has `lpOut > 0` (Uni V4) |

```bash
forge test --match-contract '*Alignment_CloseD25*' -vv
```

#### K.1 DoD

- [x] All 8 families except any NatSpec defer: D25-1…D25-6 green on the proxy
- [x] Uni V4: D25-7 green
- [x] FC8 still green (ids 1–2 cannot close)
- [x] No DETF burned on close

Evidence (2026-08-22): `forge test --match-contract Alignment_CloseD25 -vv` — **66 passed, 0 failed** after Bond-NFT physical BPT + leftover loop-join (8 family suites including `test_D25_lastClose_feeCreatorPendingDoesNotJump`). Uni V4 MIN rejoin caps single-sided DETF join to 25% of live book and **loop-joins until the zap fails**; leftover DETF stays on the diamond (not NFT rewards). Balancer last-exit of the sole remaining user can hit `TokenBalanceBelowMin` (1e6); those families assert leftover-join extract on a later-bond close. Logs: `{SCRATCH}/forge-d25-close.log`. FC: `{SCRATCH}/forge-d15-donate-fc-smoke.log`.

---

### Stage L — D15 redeem zap-out + D31 mint/burn realize-then-gate

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | I, J, K |
| **Blocks** | M–O (donate DN14 needs K; DN12 needs L D31 contrast) |

#### L.1 D31 mint/burn

On every family live mint and live burn **before** the Policy gate:

1. `_realizeExpansionIfNeeded` (Open: no-op).
2. Synthetic from **minted** `totalSupply`.
3. Gate. Fail → full revert (expansion does not stick).

Views `isMintingAllowed` / `isBurningAllowed` count pending expansion in the denominator (match post-realize).

Do **not** change D8 quote, D27/D3 split, D11 join, D13 `lpOut`, or Open always-pass.

Tests: `…/<Family>_Alignment_D31_ExpansionGate.t.sol` with `test_D31_`.

| ID | Must prove |
|----|------------|
| **D31-1** | Policy, synthetic just above mintThreshold, pending expansion would pull it to ≤ mintThreshold: `exchangeIn` → DETF **reverts**; `totalSupply` and `lastExpansionTimestamp` unchanged |
| **D31-2** | Policy, mint still allowed after realize: mint succeeds; expansion DETF is on the Bond NFT; `lastExpansionTimestamp` advanced |
| **D31-3** | Same pair for burn vs `burnThreshold` |
| **D31-4** | Open: mint/burn do not mint expansion |
| **D31-5** | Skip until Stage M; then donate still does not realize (DN12) |

#### L.2 D15 redeem

Replace DETF-leg-only `owed`. Sequence is alignment §15.5 (realize, harvest **all** id 0 pending, skip withdraw if pending ≥ owed, else prop withdraw, buy DETF largest-first by DETF-buying power, exact-in dump too-small legs, rejoin leftover with `lpOut > 0`).

Tests: `…/<Family>_Alignment_RedeemD15.t.sol` with `test_D15_`. Quad: this stage **closes** the old pair-redeem defer — redeem is DETF only.

| ID | Must prove |
|----|------------|
| **D15-1** | `previewRedeemClaim` == execute (zap-out identity, residual book, public swap fee in the buy) |
| **D15-2** | Harvest all id 0 pending: one small redeem can consume all pending up to owed |
| **D15-3** | Pending ≥ owed: no LP withdrawn; id 0 originalShares unchanged except compound leftover pending |
| **D15-4** | Shortfall: leftover→DETF buy on residual; other bonders’ `originalShares` unchanged |
| **D15-5** | Multi-leg: snapshot DETF-buying power once; largest first; exact-in dump then next |
| **D15-6** | Last exit: no buy; leftover pair rejoined to id 0 with `lpOut > 0`; no pair to redeemer |
| **D15-7** | Realize expansion first; claim holder can be paid from id 0’s expansion slice (in harvested pending) |
| **D15-8** | `tokenOut != DETF` reverts `InvalidRoute` |
| **D15-9** | Ungated vs Policy mint/burn (D22) |

#### L.3 Commands

```bash
forge test --match-contract '*Alignment_D31_ExpansionGate*' -vv
forge test --match-contract '*Alignment_RedeemD15*' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/**' -vv
```

#### L.4 DoD

- [x] D31-1…D31-4 green on Uni V4 CP; D31-4 Open on all 8 families
- [x] D15-1…D15-9 pathfinder on Uni V4 CP (D15-5 N/A); D15-8 InvalidRoute on all 8; Quad redeem pays DETF only
- [x] Quad no longer redeems claim to pair
- [x] CP expansion + mint/burn + claim suites green after realize-then-gate
- [x] Mint/burn quote/split/D11/D13/Open inequalities unchanged except realize-then-gate

Evidence (2026-08-22): `forge test --match-contract Alignment_RedeemD15 -vv` in `{SCRATCH}/forge-d15-donate-fc-smoke.log` — CP 8/8 including D15-3 harvest-skip, D15-4 residual buy / other originalShares, honest last-exit D15-6, D15-7 realize-first; Single SE 3/3 after NFT-BPT physical avail; D15-8 on all 8; Quad redeem pays DETF only. Claim redeem after D13 custody reads Bond NFT BPT, not diamond BPT. Logs: `{SCRATCH}/forge-d31-d15.log`, `{SCRATCH}/forge-d15-donate-fc-smoke.log`.

---

### Stage M — D29 donate: NFT ABI + Uni V4 CP

| Field | Value |
|-------|--------|
| **Status** | green (2026-08-22) |
| **Depends on** | I, J, K, L |
| **Blocks** | N, O |
| **Product** | Donation PRD v0.3 |

#### M.1 NFT donate surface

| Surface | Action |
|---------|--------|
| `IDetfNftReserveDonation` (production Bond NFT; not `IDETFNFTVault`, so Composed NFT is not forced to ship donate) / DETF `IDetfReserveDonation` | `donate`, `previewDonate`, Permit2 allowance + signature, `ReserveDonated(donor, token, amountIn, lpOut)` |
| `DETFNFTVaultTarget` + Facet + DFPkg | Public donate. `nonReentrant`. Live via DETF `isReserveLive`. Deadline. `minLpOut`. Funding: `transferFrom`, Permit2, `pretransferred` unbooked surplus (non-LP). **No native ETH.** `lpToken` = this-call inbound LP delta only, then `addToDETFNFT(id 0, lpOut)` 1×. Else push exact amount to DETF, `joinDonatedCapital`, then `addToDETFNFT(id 0, lpOut)`. Reset allowance. Do **not** realize expansion. |
| Donor | Overload callable **only** by the DETF passes `donor = IDetf.msg.sender`. Direct NFT callers: `donor = msg.sender`. EOAs cannot spoof. No `tx.origin`. |
| `IDetf.notifyReserveDonated()` | `msg.sender == bondNftVault`. Runs `_topUpFeeCreatorShares` only. NFT calls it after id 0 credit. |
| `UniV4DetfBondNft` | Do not add donate. |

#### M.2 Uni V4 CP join + forwarder

| Surface | Action |
|---------|--------|
| Family interface + Facet | `joinDonatedCapital` / `previewJoinDonatedCapital`. `onlyBondNft`. Else `NotAuthorized`. |
| Common | `_settleToPair` + `_depositSinglePair(..., _bondLpHolder())` for non-DETF; `_depositSingleDetf` for DETF. No mint split. No expansion. Sync holds. Inbound disable: revert. D30: join while PM already unlocked. MIN rejoin `lpOut > 0`. |
| `IDetf.donate` | `bondNft.donate(..., minLpOut=0, pretransferred, block.timestamp+1)` with donor = `msg.sender`. Void. NatSpec = donation PRD. |

#### M.3 Tests

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_ReserveDonation.t.sol`

Functions `test_N1_…` … `test_N18_…` as donation PRD §10, plus:

| ID | Must prove |
|----|------------|
| **DN19** | Permit2 allowance donate of `pairToken` same id 0 credit as `transferFrom` |
| **DN20** | Permit2 signature donate |
| **DN21** | After donate, ids 1 and 2 `effectiveShares` are `f` and `c` of the new total |
| **DN22** | Donate/join while owner op holds PoolManager lock still succeeds |

Adversarial: I1/DN9, K1 (idle pair sweep intended; lpToken no double credit), A0/DN16, CROPS/DN18, J1–J3. Happy-path `pretransferred=true` does not cover DN9.

```bash
forge test --match-contract UniswapV4SingleStandardExchangeDETF_ReserveDonation -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**' -vv
```

#### M.4 DoD

- [x] DN1–DN22 green on the **production CP DETF proxy**
- [x] Donate does not realize expansion (DN12 vs D31-2)
- [x] Existing CP mint/bond/burn/FC/expansion suites still green
- [x] No mock SUT

Evidence (2026-08-22): `forge test --match-contract UniswapV4SingleStandardExchangeDETF_ReserveDonation -vv` — 22 passed, 0 failed (DN1–DN22). `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**' -vv` — 122 passed, 0 failed (includes mint/bond/burn/FC/expansion/D15/D25/D31 + donate). `DETFNFTVault_Surface` J1–J3 3/3 after donate selectors. Donate ABI is on `IDetfNftReserveDonation` (production `DETFNFTVault*`), not `IDETFNFTVault`, so Composed’s NFT is not forced to implement donate. CP zap `previewDonate` vs execute is `assertApproxEqRel` 0.01e18 (single-sided zap, not few-wei closed-form). Logs: `{SCRATCH}/forge-donate-cp.log`, `{SCRATCH}/forge-donate-cp-path.log`.

---

### Stage N — D29 donate: other Uni V4 families

| Field | Value |
|-------|--------|
| **Status** | green (2026-08-22) |
| **Depends on** | M |
| **Order** | Orbital → Weighted → Curve Quad |

Same donate process. Family settle → single-sided that pair or DETF self-leg. D30 already on those hooks from J.

Per family: `…/<Family>_ReserveDonation.t.sol` with `test_N1_…`–`test_N18_…` plus DN19–DN21. DN1 uses the family’s first mint token. DN4 donate(DETF) required. DN11: third-party hook LP reverts; donate succeeds.

```bash
forge test --match-contract '*ReserveDonation*' --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/**' -vv
```

#### N.1 DoD

- [x] Orbital, Weighted, Quad: DN1–DN13, DN15–DN21 green on the proxy
- [x] Family mint/bond/burn/FC suites still green

Evidence (2026-08-22): `forge test --match-contract 'ReserveDonation' --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/**' -vv` — 82 passed, 0 failed (CP 22 + Orbital/Weighted/Quad 20 each). FC 12/12 on Orbital, Weighted, and Quad. Orbital MintBurn 6/6 and Bond 7/7. Weighted and Quad J1 donate/join on bonding facetFuncs. Orbital N16 last-exit donate uses DETF self-leg then dual-pair next bond: pair0 single-sided join at MIN reverts `ZeroAmount` on the orbital book. Preview vs execute is `assertApproxEqRel` 0.02e18. Logs: `{SCRATCH}/forge-donate-univ4.log`, `{SCRATCH}/forge-donate-univ4-path.log`.

---

### Stage O — D29 donate: Balancer families

| Field | Value |
|-------|--------|
| **Status** | green |
| **Depends on** | M (can overlap N) |
| **Order** | Single SE → MVW → Mixed-buffer. **Composed: defer.** |

Single-sided Balancer add of that leg, BPT to NFT, `addToDETFNFT(id 0)`. Public join stays (L5). Join/swap inside an already-open Vault unlock if donate sits in one unlock. DN3: mint BPT via public join, then `donate(lpToken)` with `transferFrom`. DN11 N/A (NatSpec).

Composed: **do not** ship donate until LP is on `DETFNFTVault` and N10 applies.

```bash
forge test --match-contract SingleStandardExchangeDETF_ReserveDonation -vv
forge test --match-contract MultiVaultWeightedDetf_ReserveDonation -vv
forge test --match-contract MixedBufferMultiVaultStableDetf_ReserveDonation -vv
```

#### O.1 DoD

- [x] Single SE, MVW, Mixed-buffer: DN1–DN21 green
- [x] Composed donate **not** shipped
- [x] Existing family suites green
- [x] Balancer public join unchanged

Evidence (2026-08-22): `forge test --match-contract ReserveDonation -vv` in `{SCRATCH}/forge-d15-donate-fc-smoke.log` — CP 23/0 (includes DN9 booked-DETF pretransferred revert), Orbital/Weighted/Quad 20 each, Single SE/MVW/Mixed 20 each. Composed has no `joinDonatedCapital` / `donate`. Pretransferred DETF credits only `balance - lastRewardTokenBalance`. Last-exit leftover DETF is loop-joined to id 0 LP, not transferred onto the NFT as rewards. DN3 live-mints then transfers diamond D11 BPT. DN10 Balancer unbalanced join is not closed-form (`assertGt` both sides). DN11 N/A (L5 public join stays). Logs: `{SCRATCH}/forge-donate-balancer.log`, `{SCRATCH}/forge-donate-univ4.log`, `{SCRATCH}/forge-d15-donate-fc-smoke.log`.

---

## 7. Test naming and helpers

- FC tests: `test_FC1_<familyShort>_…` so `--match-test test_FC` is safe.
- Close: `test_D25_`. Redeem: `test_D15_`. Expansion gate: `test_D31_`. Donate: `test_N1_…`. Hook owner: `test_D30_` / `test_D89_`.
- Prefer `--match-contract <File>` for FC, donate, and adversarial.
- Shared assertions: put small helpers on each family TestBase (`_due(id, delta, T)`, `_claim(id, to)`). A shared library under `test/foundry/spec/vaults/detf/common/` is allowed if it does not mock the SUT.
- Dust: **one wei per position** on floor splits (FC3/FC12). Document if a family needs more; do not silently widen.

---

## 8. Risk notes (do not “fix” by changing product)

| Risk | Required handling |
|------|-------------------|
| D2 top-up without reward-debt rebase | FC4 fails. Use L7 addEffective path. |
| `addToDETFNFT` on ids 1–2 | Would give redeemable LP. Forbidden. Use `addEffectiveSharesOnly`. |
| Live mint still joins DETF (MixedBuffer) | Out of spec. Remove that join. |
| Composed swap-not-burn | Out of spec. Burn supply. |
| Bond sized from D8 Gross | Out of spec (D24). |
| Closing Balancer join “to be safe” | Forbidden (L5). |
| Close still burns DETF | Forbidden (Stage K). |
| Redeem quotes DETF-leg only | Forbidden (Stage L). |
| Mint/burn skip D31 realize | Forbidden. |
| Owner `depositSingle` at MIN with lpOut 0 | Forbidden. |
| `detfNftId == 0` as unwired | Breaks D7. Use L6. |
| Usage fee re-enabled on mint | D14 off. Do not turn it on to fund feeTo. |
| Killing forge mid-compile | Forbidden. Loses the compile cache. |
| Donate(DETF) as `buyClaim` or burn | Forbidden. |
| Realize expansion on donate | Forbidden (DN12). |
| Live mint retargeted to id 0 | Forbidden (D11). |

---

## 9. Launch gate checklist

Stage H (D1–D28 historical) is **green**. I–O remainder:

- [x] I N10
- [x] J D30 owner-during-lock + MIN `lpOut > 0`
- [x] K D25 rejoin DETF to id 0, basket
- [x] L D15 zap-out redeem + D31 realize-then-gate
- [x] M D29 donate NFT + Uni V4 CP (DN1–DN22)
- [x] N D29 other Uni V4
- [x] O D29 Balancer (Composed deferred)

Do not declare this remainder launch-ready until I–O are green (Composed donate defer allowed).

---

## 10. Out of scope until a new PRD lock

- Bond `U = 0` (would override L1).
- Burn amountIn bonus.
- Balancer owner-only join.
- Deleting `UniV4DetfBondNft`.
- Changing `p`/`f`/`c` initial numbers.
- Transferring id 1 on `feeTo()` change.

---

## 11. Evidence log

The executing agent appends one row per green stage.

| Stage | Date | Command | Result |
|-------|------|---------|--------|
| A | 2026-08-19 | fee oracle + common NFT/split | green |
| B | 2026-08-19 | DualLiquidity deleted | green |
| C–H | 2026-08-19 | family FC + regression | green |
| I | 2026-08-22 | N10 conversion | green: DETFNFTVault_N10Conversion 4/4; FC Single SE 12/12 + Uni V4 CP 12/12; Bond N10 6/6 |
| J | 2026-08-22 | D30 owner-during-lock | green: OwnerDuringLock+OwnerOnlyLiquidity 49/0 |
| K | 2026-08-22 | D25 rejoin + basket | green: Alignment_CloseD25 58/0 |
| L | 2026-08-22 | D15 + D31 | green: D31+D15 38/0; CP expansion/mint/claim 15/0 |
| M | 2026-08-22 | D29 donate CP | green: ReserveDonation 22/0; CP spec path 122/0; NFT surface J1–J3 3/3 |
| N | 2026-08-22 | D29 other Uni V4 | green: ReserveDonation 82/0 (CP+Orbital+Weighted+Quad); FC 36/0; Orbital mint/bond 13/0 |
| O | 2026-08-22 | D29 Balancer | green: ReserveDonation Single SE 20/0, MVW 20/0, Mixed 20/0; Composed donate not shipped |
| post-O | 2026-08-22 | CloseD25 after NFT BPT + leftover loop-join | green: Alignment_CloseD25 **66/0** (`{SCRATCH}/forge-d25-close.log`); last-close fee/creator pending does not jump |
| post-O | 2026-08-22 | D15 + donate + FC smoke | green: Alignment_RedeemD15 + ReserveDonation + Alignment_FeeCreatorClaim **269/0** (`{SCRATCH}/forge-d15-donate-fc-smoke.log`); CP D15-3/4/6/7; DN9 booked DETF |
