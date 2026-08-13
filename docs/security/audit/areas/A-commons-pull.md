# Security Audit — A-commons-pull

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · MODE=pilot · `A-commons-pull` |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/basic/**`; `contracts/interfaces/ISecurePullErrors.sol`; DETF `_pullToken` / SE `_securePull` / `_secureTokenTransfer` clones as **reference blast only** |
| Test paths | `test/foundry/spec/vaults/basic/**`; `test/foundry/fork/{base_main,eth_main}/vaults/basic/**`; seed `docs/testing/coverage-audit/areas/T-basic-protocol-commons.md` |
| Skills cited | `docs/security/SECURITY_AUDIT_PRD.md` §2, §2.4, §3.8, §5, §6, §7.2–7.3, §8, §19; `crane-adversarial-testing`; `indexedex-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `defi-incident-patterns` |
| Residual-risk scores | BasicVaultCommon token pull **4**; BasicVaultCommon `_secureSelfBurn` **2**; BasicVault / MultiAsset view facets **4**; ISecurePullErrors **4**; Uni V3 local clones (blast) **1** |

## 1. Executive summary

- **Residual-risk scores:** token-side `_secureTokenTransfer` is **4** (durable reserve-delta `U = B − R` matches L-CLAIM-3 / L-GAPS-9; I1–I3 hermetic tests exist). Shared `_secureSelfBurn` is **2** (High CODE leftover-share sweep, no catalog tests). View-only BasicVault facets are **4**. Uni V3 local clones remain **1** (live PAT-I-ABS, not owned here).
- **Critical / High counts:** **Critical 0**. **High 2** — `SEC-COMMON-002` (new CODE on `_secureSelfBurn`) and `SEC-COMMON-003` (Uni V3 clone residual, **OWNED_ELSEWHERE**).
- **PAT-I-ABS on `BasicVaultCommon._secureTokenTransfer` is not a live CODE vuln at this SHA.** The 2026-08-09 absolute-balance body (`require(balanceOf >= amount); return amount`) is gone. Current helper credits `claimed` iff `claimed <= U` where `U = balanceOf − reserveOfToken`, else `TransferDeltaInsufficient(claimed, U)`. Aerodrome **no longer overrides** the helper (inherits commons). Classify the historical Blocker as **OWNED_ELSEWHERE** (`TCA-COMMON-001` / `WP-I-COMMON-001` / `WP-I-COMMON-002`, gap-closure `bbe501e` + `STAGE3_PROGRESS.md` 44/44). **Do not open a competing Wave-0 `sec_fix_*` WP for token-side PAT-I-ABS.**
- **Top recommended WPs:** **`WP-SEC-E6-COMMON-001`** (new Wave-0 CODE+TEST on `_secureSelfBurn` leftover refund / missing share-delta). No new `sec_fix_*` for token PAT-I-ABS. Uni V3 residual stays on coverage `WP-I-CLONE-001` / area `A-se-v3-v4-lending` (stale “closed” claim).
- **OWNED_ELSEWHERE count:** **5** linked TCA/WP touch-sets (`SEC-COMMON-001`, `SEC-COMMON-003`, plus TEST/THEATER leftovers `TCA-COMMON-002/003/008` already closed by `WP-I-COMMON-002` at helper unit layer).

Headline: **commons token pull is reserve-delta and I1-blocked when `R == B`**. The remaining commons money defect is **`_secureSelfBurn`**: `pretransferred=true` burns vault self-shares with **no inbound-delta / unbooked-share check**, then refunds **all** leftover self-balance to `owner` (PAT-E6 + I1 on vault shares). That is the single new Wave-0 CODE WP from this area.

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|---------------|
| **BasicVaultCommon** | Shared internal lib (not a DFPkg). Inherited by Aero / Camelot / Uni V2 / Aave Stata SE commons. | Harness-only (`new BasicVaultCommonHarness`) — acceptable for helper; **not** product A–K | N/A (internal). Production consumers: CREATE3 facets + `indexedexManager.deploy*DFPkg` | **3** overall (token pull **4**; self-burn **2**) |
| **ISecurePullErrors** | Shared error interface | Used by hermetic I1–I3 | Import-only | **4** (NatSpec still says “this call”; impls use durable `U` or same-tx delta) |
| **BasicVaultFacet / Target** | View-only `IBasicVault` (3 selectors) | No dedicated money TestBase | CREATE3 / FactoryService when packaged | **4** (no money entry) |
| **MultiAssetBasicVaultFacet / Target / Repo** | Durable `R` book used by commons pull | Exercised via helper harness | Same slot as `BasicVaultRepo` (`keccak256(abi.encode("indexedex.vaults.basic"))`) | **4** (layout-compatible twin lib; hygiene) |
| **BasicVaultRepo** | Twin storage lib, same slot/layout as MultiAsset | Views via `BasicVaultTarget` | CREATE3 facet | **4** (duplicate lib, not a collision) |
| **ERC4626BasedBasicVaultFacet** | `IBasicVault` views from `ERC4626Repo._lastTotalAssets` | Product SE packages | CREATE3 | **4** (view book ≠ MultiAsset `R`; not a pull bug) |
| **BasicVaultErrors.sol** | Empty file (license only) | n/a | n/a | **Info** |
| **RebasingClaimToken / DETF / SE clones** | Reference blast only — see §2.1 | Product areas own TestBases | Registry DFPkg | See blast table |

### 2.1 Direct inheritors of `BasicVaultCommon`

| Contract | Path | Override of `_secureTokenTransfer`? |
|----------|------|-------------------------------------|
| `AerodromeStandardExchangeCommon` | `contracts/protocols/dexes/aerodrome/v1/` | **No** — comment: inherit reserve-delta law; `_excessToken*` is compound dust only |
| `CamelotV2StandardExchangeCommon` | `contracts/protocols/dexes/camelot/v2/` | No |
| `UniswapV2StandardExchangeCommon` | `contracts/protocols/dexes/uniswap/v2/` | No |
| `AaveV3StataStandardExchangeCommon` | `contracts/protocols/lending/aave/v3.6/` | No; In uses `_secureTokenTransfer`; Out uses `_secureSelfBurn` |

### 2.2 Blast radius — clone / peer pull helpers (not owned)

#### A. Reserve-delta peers (`U = B − R`, `TransferDeltaInsufficient`) — aligned with commons

| Surface | Path |
|---------|------|
| MultiVault `_pullToken` | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol` ~470–481 |
| Single SE DETF `_pullToken` | `.../standardExchange/single/SingleStandardExchangeDETFCommon.sol` ~521–531 |
| MixedBuffer `_pullToken` | `.../mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol` ~540–551 |
| ComposedStable `_secureTokenTransfer` | `.../stable/common/ComposedStableCommonDetfCommon.sol` ~305–316 |
| Uni V4 CP Single SE DETF `_pullToken` | `.../uniswap/v4/.../constantProduct/single/UniswapV4SingleStandardExchangeDETFCommon.sol` ~484–495 |
| Uni V4 Orbital DETF `_pullToken` | `.../orbital/UniswapV4StandardExchangeOrbitalDETFCommon.sol` ~743–754 |
| Uni V4 Weighted DETF `_pullToken` | `.../weighted/UniswapV4StandardExchangeWeightedDETFCommon.sol` ~811–822 |
| Uni V4 Curve Quad DETF `_pullToken` | `.../stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFCommon.sol` ~815–826 |
| ERC4626 SE `_securePull` | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol` ~164–194 |
| Uni V4 SE Common `_secureTokenTransfer` | `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` ~1083–1101 (face-booked `U`) |
| Hook `_securePull` (CP / Dual / Orbital / Weighted / Bal Quad / Curve Quad) | `contracts/hooks/uniswap/v4/standardExchange/**` |

#### B. Same-tx inbound-delta peers (I1-safe if no in-call push; two-tx pretransfer **fails**)

| Surface | Path |
|---------|------|
| Slipstream `_secureTokenTransfer` | `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol` ~441–459 |
| RebasingClaimToken `_secureTokenTransfer` | `contracts/vaults/detf/common/claimToken/RebasingClaimTokenTarget.sol` ~559–581 |
| RebasingDETFToken `_secureTokenTransfer` | `.../stable/common/RebasingDETFTokenTarget.sol` ~433–454 |
| DualLiquidity `_receive` / `_receiveOut` | `.../crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVaultExchange{In,Out}Target.sol` |
| Lido / Rocket / EtherFi `_securePull` | `contracts/protocols/staking/{lido,rocket-pool,etherfi}/**` (`InsufficientDeposit`, same-tx delta) |

#### C. **Still PAT-I-ABS** (absolute `balanceOf >= amount` → `return amount`)

| Surface | Path | Notes |
|---------|------|-------|
| Uni V3 SE In | `contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInTarget.sol` ~195–205 | Live absolute credit |
| Uni V3 SE Out | `.../UniswapV3StandardExchangeOutTarget.sol` ~258–268 | Same |
| Uni V3 `_refundRemainder` | InTarget ~212–217 | **PAT-E6**: transfers **entire** `balanceOf` to `msg.sender` |

No remaining `if (pretransferred) return amount` blind-return bodies were found under `contracts/` (excluding Uni V3 absolute-balance require).

#### D. `_secureSelfBurn` call sites (commons body; product areas own e2e)

| Consumer | Files |
|----------|-------|
| Aerodrome SE | `AerodromeStandardExchangeInTarget.sol`; `AerodromeStandardExchangeOutExecuteTarget.sol` |
| Camelot V2 SE | `CamelotV2StandardExchange{In,Out}Target.sol` |
| Uniswap V2 SE | `UniswapV2StandardExchange{In,Out}Target.sol` |
| Aave V3 Stata Out | `AaveV3StataStandardExchangeOutTarget.sol` (`_secureSelfBurn(msg.sender, maxAmountIn, pretransferred)`) |

### 2.3 Test inventory (this area)

| Suite | Path | I1–I3? |
|-------|------|--------|
| TokenTransfer unit | `test/foundry/spec/vaults/basic/BasicVaultCommon_TokenTransfer.t.sol` | **Yes** — `test_I1_bookedInventory_*`, `test_I2_*`; I3 absorb in `test_push_underClaim_absorbsSurplus_noRefund`; theater-named `test_secureTokenTransfer_pretransferred_returnsAmount` now **expects revert** |
| TrustFlags unit | `.../BasicVaultCommon_TrustFlags.t.sol` | **Yes** — `test_I1_*`, `test_I2_*`, `test_I3_*` |
| Permit2 unit | `.../BasicVaultCommon_Permit2.t.sol` | Partial — booked I1 revert; no `test_I*` names; Permit2 happy + FoT |
| Permit2 Base/Eth fork | `test/foundry/fork/{base_main,eth_main}/vaults/basic/**` | **No** — harness never inits/syncs MultiAsset `R`; pretransfer tests are push-then-claim happy paths (`R=0` bootstrap) |
| `_secureSelfBurn` | none under `test/**` | **Gap** |

## 3. Threat models

### 3.1 BasicVaultCommon — `_secureTokenTransfer` / `_refundExcess` / reserve sync

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `_secureTokenTransfer(..., pretransferred=true)` via SE `exchangeIn` / `exchangeOut` | `rateAsset` / `pairToken` / vault inventory | `pretransferred` | none on helper | **Blocked** when `R == B` (`TransferDeltaInsufficient(claimed, 0)`). Free credit of **booked** inventory is the closed PAT-I-ABS class. |
| EXT / CAP | Same, after donation (no sync yet) | Unbooked surplus `U` | `pretransferred=true` | none | Next pretransfer caller **credits `min(claimed, U)`**. Documented absorb law (not exact-delta grief). **ACCEPTED_RISK** — donation benefits next pusher, not booked LPs. |
| CFG | Bootstrap `R = 0` | Full live `B` | `pretransferred=true` | unsynced new diamond | First claimer can credit entire unsynced balance. Documented (`test_bootstrap_R0_*`). Product go-live / first sync is the gate. |
| HOS | `_secureTokenTransfer(..., false)` | FoT token | allowance / Permit2 | none | Credits **pull delta only** (does not add prior `U`). I4 partial. |
| INT | Permit2 branch when ERC20 allowance `< claimed` | same | Permit2 `transferFrom` `uint160(claimed)` | Permit2 | Credits observed pull delta. No local ecrecover. I5 signed≠delivered is Permit2/router-owned. |
| EXT | `_refundExcess` | unused **claimed** credit | `pretransferred && max > used` | none | Refund = `maxAmount − usedAmount` (this-call unused). **Not** `balance − floor`. E6-safe. |
| EXT | `_unbookedSurplus` / pretransfer `B − R` | n/a | n/a | desynced `R > B` | Solidity underflow revert (DoS on pretransfer) until a route syncs `R := B`. |

### 3.2 BasicVaultCommon — `_secureSelfBurn`

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | SE `exchangeOut` / share-in routes with `pretransferred=true` → `_secureSelfBurn` | vault shares (`address(this)`) + underlying `rateAsset` / LP | `pretransferred` | none | If vault already holds its own shares (`D ≥ burnAmount`): attacker burns **without delivering shares**, receives exit assets, **and** is sent **all remaining self-shares** (`leftoverShares = balanceOf(this)`). Two-tx victim push of shares is stealable. **High.** |
| CAP / HOS | Donate vault shares to diamond, then `pretransferred=true` exit | donated shares + pro-rata assets | `pretransferred` | none | Skim donation that should have stayed idle / accrued to remaining holders. |
| CFG | Two-tx “push shares then redeem” | victim shares | `pretransferred=true` | none | Frontrun `exchangeOut`; leftover refund sweeps victim inventory. |

### 3.3 BasicVault / MultiAsset view facets

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `vaultTokens` / `reserveOfToken` / `reserves` | none | none | none | Views only. `ERC4626BasedBasicVaultFacet.reserveOfToken` reports `lastTotalAssets`, not MultiAsset `R` — integrator confusion, not extract. |
| ADM | n/a on these facets | n/a | n/a | no `diamondCut` here | CROPS leftover admin is manager/DETF-owned (`S-crops-trust`). |

## 4. Catalog matrix (A–O, E6, F5)

| ID | Product | F/P/G/N/A/VULN | Evidence |
|----|---------|----------------|----------|
| **A1** | BasicVaultCommon token | **P** | Donation becomes unbooked `U`; next `pretransferred` may credit it. Law: absorb into `R` at end-of-op if unclaimed. No `test_K1_*` name. |
| **A0** | BasicVaultCommon | **P** | Bootstrap `R=0` → `U=B` (`test_bootstrap_R0_pushTrue_claimsFullLiveBalance`). First-minter drain of **booked** inventory blocked after sync. Product go-live owned by SE/DETF areas. |
| **B** | commons | **N/A** | No pricing in helper. |
| **C** | commons | **N/A** | No external call in token pull; share refund uses `safeTransfer`. Product `IsLocked` owned by SE/DETF. |
| **D** | commons | **N/A** | No claim/NFT. |
| **E1 / E5** | token pull | **P** | FoT pull delta; zero-amount not unit-tested on helper. |
| **E6** | `_refundExcess` | **F** | Cap to `max − used` claimed unused. |
| **E6** | `_secureSelfBurn` leftover | **VULN** | Refunds **all** self-share balance after burn. `SEC-COMMON-002`. |
| **F / F5** | commons | **N/A** | Internal helpers; no public migrate/reclaim. |
| **G** | commons | **N/A** | Nested DETF owned by product areas. |
| **H** | commons | **N/A** | Atomicity on product routes. |
| **I1** | token pull | **F** | `test_I1_*` booked `R==B`, no in-call transfer → `TransferDeltaInsufficient(claimed, 0)`. |
| **I1** | `_secureSelfBurn` | **VULN** | No delta / unbooked-share gate. |
| **I2** | token pull | **F** | `test_I2_*` `claimed > U` exact selector+args; pull short-delivery returns observed delta. |
| **I3** | token pull | **F** | After `moneyIn` sync, second free pretransfer reverts (`test_I3_*`, `test_push_underClaim_*`). |
| **I4** | token pull | **P** | FoT `pretransferred=false` unit + Permit2 FoT. |
| **I5** | Permit2 branch | **P** | Production Permit2 fork pull; no signed-amount ≠ delivered adversarial on this helper. |
| **J1–J3** | BasicVaultFacet | **F** (views) | `facetFuncs` = 3 `IBasicVault` selectors. No money API. Product J owned elsewhere. |
| **J** | BasicVaultCommon | **N/A** | Not a facet. |
| **K1** | token pull | **P** | I3 absorb is the K×I regression; **no** `test_K1_*`. Donation-then-pretransfer **before** sync is accepted `U` credit. |
| **L1–L3** | commons | **N/A** | No AMM books in helper. Uni V3 `_refundRemainder` is product L1/E6 blast. |
| **M1–M3** | commons | **N/A** | No `target+calldata`. |
| **N1–N2** | commons | **N/A** | No quote–settle in helper. |
| **O1–O3** | commons | **N/A** | No ecrecover; Permit2 is `transferFrom` only. |
| **PAT-I-ABS** token | BasicVaultCommon | **F** (closed) | Reserve-delta body L75–100. Historical CODE = `SEC-COMMON-001` OWNED_ELSEWHERE. |
| **PAT-I-ABS** clones | Uni V3 In/Out | **VULN** (blast) | `SEC-COMMON-003` OWNED_ELSEWHERE. |

## 5. Domain notes

Walked as hunt lists (not a second ID space):

| Domain / skill | Walked on | Notable hits |
|----------------|-----------|--------------|
| **general / erc20** | `_secureTokenTransfer`, `_refundExcess`, `_secureSelfBurn`, SafeERC20 | Token pull FoT-safe on `false`; self-burn ignores share delivery. |
| **precision-math** | `U = B − R` checked sub | Underflow if `R > B` (SEC-COMMON-008). Pull path does not add `U` (good). |
| **erc4626** | Twin view facet `lastTotalAssets` vs MultiAsset `R` | View desync for integrators (SEC-COMMON-010 Info). |
| **proxies / PAT-SLOT** | `BasicVaultRepo` vs `MultiAssetBasicVaultRepo` | **Same slot**, same two-field layout (`AddressSet` + mapping). Not a collision. Duplicate libraries are hygiene. |
| **access-control / CROPS** | commons internals | No owner/operator on helper. DETF unowned / leftover `diamondCut` → `S-crops-trust` / `A-detf-*`. |
| **dos** | `R > B` underflow; full-set sync loop | Bounded by `_vaultTokens` length. Underflow is pretransfer DoS until sync. |
| **signatures** | Permit2 `transferFrom` | No local permit verify. `uint160` truncation if `claimed > type(uint160).max` — credit follows actual delta. |
| **sharp-edges** | `pretransferred` bool; fork harness `R=0` | Flag is caller-supplied (not default-true in helper). Two-tx share pretransfer is the dangerous default UX (`S-sharp-edges`). |
| **spec-compliance** | L-CLAIM-3 / L-GAPS-9 vs durable `U` | Durable last-sync delta **is** the production reading of “observed inbound delta” for two-tx push. Same-tx snapshot (claim/Slipstream/Lido) is a **family split**, not commons drift. `ISecurePullErrors` NatSpec still says “this call”. |
| **incident themes** | `defi-incident-patterns` | Trust-flag free mint → I1–I3 (closed on token helper). Surplus-refund `balance − floor` → E6 (`_secureSelfBurn`, Uni V3 `_refundRemainder`). Donation/inflation → A/K (accepted `U` absorb). |
| **ethskills-security** | SafeERC20, CEI, FoT, inflation | Pull uses SafeERC20 + delta. Self-burn transfers leftover **after** burn (CEI OK) but refund math is wrong. |

## 6. Findings

### 6.1 [SEC-COMMON-001] PAT-I-ABS on `_secureTokenTransfer` — closed at this SHA

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-COMMON-001` |
| **Title** | Historical absolute-balance pretransfer on BasicVaultCommon token pull is closed |
| **Severity** | **Info** (historical High/Blocker; not live) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high (current source); historical runtime confirmed on 2026-08-09 tree only |
| **Catalog IDs** | I1–I3, K1 |
| **Pattern IDs** | PAT-I-ABS, PAT-THEATER-PRE (historical) |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | Trust-flag free mint |
| **Products** | BasicVaultCommon; inheritors Aero / Camelot / Uni V2 / Aave Stata |
| **Blast radius** | Shared commons — all inheritors consume the fixed helper |
| **Impact** | None at `1e0d7c48` on this helper. Pre-fix: free credit of booked inventory. |
| **Evidence** | `contracts/vaults/basic/BasicVaultCommon.sol` L15–19, L53–100: `U = B0 − R`; `claimed > U` → `TransferDeltaInsufficient`; else credit `claimed`. Pull branch returns `B1 − B0` only. AerodromeCommon L47–49: inherit, no override. Tests: `BasicVaultCommon_TrustFlags.t.sol` `test_I1_*` / `test_I2_*` / `test_I3_*`; TokenTransfer `test_I1_bookedInventory_pretransferred_revertsDelta0`; migrated `test_secureTokenTransfer_pretransferred_returnsAmount` now expects revert. |
| **Runtime** | Historical `docs/testing/coverage-audit/repro/TCA-COMMON-001/` is **stale** (theater PASS). Re-check notes: `docs/security/audit/repro/SEC-COMMON-001/`. This agent did **not** run forge (orchestrator owns runtime). Static body + inverted unit tests are sufficient to refuse a new Critical CODE. |
| **Recommended CODE** | none on this helper for PAT-I-ABS |
| **Recommended TEST** | Keep I1–I3 green; do not treat fork happy-push as I1 |
| **Anti-theater** | I1 must not transfer in-call; must sync `R==B` first |
| **Suggested WP-ID** | none (`sec_fix_*` skip) |
| **Link TCA / prior** | `TCA-COMMON-001`, `TCA-COMMON-002`, `TCA-COMMON-003`, `TCA-SE-AC-001`; `WP-I-COMMON-001`, `WP-I-COMMON-002`; gap-closure `bbe501e` |
| **Depends / parallel** | n/a |

### 6.2 [SEC-COMMON-002] `_secureSelfBurn` leftover sweep + no share-delta

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-COMMON-002` |
| **Title** | Cap `_secureSelfBurn` leftover refund to this-call unused shares and require inbound share delta |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high · **RUNTIME_UNPROVEN** (no forge this run; no existing test hits the helper) |
| **Catalog IDs** | I1, E6, K1 |
| **Pattern IDs** | PAT-I-ABS (share path), PAT-E6-REFUND, PAT-THEATER-PRE (no tests) |
| **EVM-audit domain** | erc20 / erc4626 |
| **CROPS pillar** | n/a |
| **Incident theme** | Surplus-refund / public reclaim (`balance − floor`) |
| **Products** | BasicVaultCommon; Aero / Camelot / Uni V2 / Aave Stata SE share-burn routes |
| **Blast radius** | Shared commons — every `_secureSelfBurn` call site (In/Out Targets listed in §2.2.D) |
| **Attacker** | **EXT** (public `exchangeOut`/`exchangeIn` `pretransferred=true`); **CFG** two-tx share push; **CAP** donate shares |
| **Attack scenario** | 1. Vault self-share balance is normally ~0. Victim (or donor) transfers `S` vault shares to the diamond (two-tx pretransfer or donation). 2. Attacker calls production `exchangeOut`/`exchangeIn` with `pretransferred=true` and `burnAmount ≤ S` (Aave Out uses `maxAmountIn`). 3. `_secureSelfBurn` burns `burnAmount` from `address(this)` with **no** check that the attacker delivered shares this call / against an unbooked share book. 4. `leftoverShares = IERC20(this).balanceOf(this)` — **entire** remainder, not `S_this_call − burnAmount` — is `safeTransfer`’d to `owner` (attacker). 5. Route pays exit assets for the burned shares. Victim’s subsequent redeem finds no shares. |
| **Preconditions** | Vault already holds its own shares (`balanceOf(this) ≥ burnAmount`). Atomic router `transfer + exchangeOut` in **one tx** starting from 0 self-balance is safe. Two-tx push, donation, or leftover from a prior incomplete user is enough. No hostile share / admin required. |
| **Impact** | Steal of sitting vault shares + corresponding underlying (`rateAsset` / LP / Stata). Not an unbounded drain of **booked** token reserves unless those shares already sit on the vault. Realistic High, not Critical without runtime e2e share-balance proof. |
| **Evidence** | `BasicVaultCommon.sol` L128–141: `if (preTransferred) { ERC20Repo._burn(address(this), burnAmount); leftoverShares = IERC20(this).balanceOf(this); if (leftoverShares > 0) safeTransfer(owner, leftoverShares); }`. Contrast `_refundExcess` L122–125 (`max − used` only). Contrast token pull L95–100 (requires `claimed ≤ U`). `rg test_secureSelfBurn\|_secureSelfBurn` under `test/**` → **no matches**. Callers: Aave Out L105; Camelot Out L658–664; Aero OutExecute L311, L443; Uni V2 Out analogous. |
| **Runtime** | Not run. Label **RUNTIME_UNPROVEN**. Proof-first task in WP. Max severity High per L-SEC-3. |
| **Recommended CODE** | In `BasicVaultCommon._secureSelfBurn`: snapshot `b0 = IERC20(this).balanceOf(this)` (or a booked self-share reserve). If `preTransferred`: require `burnAmount ≤ unbooked` (or same-tx delivered); burn `burnAmount`; refund **only** `min(leftover, delivered − burnAmount)` — never `balanceOf(this)` after burn. If `!preTransferred`: keep burn-from-owner. Align NatSpec with token-side I/E6 law. Do not use raw `balance − 0` as refund. |
| **Recommended TEST** | `test_I1_secureSelfBurn_pretransferred_noShareDelivery_existingSelfBalance_revertsOrNoExtract`; `test_E6_secureSelfBurn_doesNotSweepOtherUsersShares`; `test_I3_secureSelfBurn_residualSelfShares_notRefundedToSecondCaller`. Setup: mint/transfer vault shares to harness (or production SE via registry); attacker `pretransferred=true` without transferring; assert attacker share+asset deltas = 0 or exact revert. `forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_I1_secureSelfBurn\|test_E6_secureSelfBurn' -vv` plus one SE proxy smoke after CODE (`A-se-amm-v2` / Aave). |
| **Anti-theater** | I1 must **not** transfer shares in-call. Must not assert leftover==all self-balance as success. No `vm.mockCall` on vault. J3 if product smoke: call **proxy**, not facet. Exact selector on revert. |
| **Suggested WP-ID** | `WP-SEC-E6-COMMON-001` |
| **Link TCA / prior** | none (TCA-COMMON / WP-I-COMMON-001 did not own `_secureSelfBurn`) |
| **Depends / parallel** | Depends on closed `WP-I-COMMON-001` only as same-file serial history. Parallel with product I suites that do **not** edit `BasicVaultCommon.sol`. |

### 6.3 [SEC-COMMON-003] Uni V3 local `_secureTokenTransfer` still PAT-I-ABS

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-COMMON-003` |
| **Title** | Uni V3 In/Out still credit claimed amount against absolute `balanceOf` |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS, PAT-E6-REFUND (`_refundRemainder`) |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | Trust-flag free mint; surplus-refund |
| **Products** | Uniswap V3 Standard Exchange (not BasicVaultCommon) |
| **Blast radius** | Single package + `_refundRemainder` pays **entire** token balance to `msg.sender` |
| **Attacker** | EXT / CAP (pretransferred against inventory; leftover skim) |
| **Attack scenario** | 1. Vault holds ≥ `amountIn` of `tokenIn`. 2. Attacker `pretransferred=true` with no transfer. 3. `require(balanceOf >= amountIn); return amountIn` credits inventory. 4. Optional `_refundRemainder` sends **all** remaining `token` to caller. |
| **Preconditions** | Deployable Uni V3 SE; inventory on diamond. |
| **Impact** | Free credit / extract of vault inventory on Uni V3 routes. |
| **Evidence** | `UniswapV3StandardExchangeInTarget.sol` L195–205, L212–217; `UniswapV3StandardExchangeOutTarget.sol` L258–268. Monorepo `balanceOf(address(this)) >=` on pull helpers is **only** these two production files. |
| **Recommended CODE** | Product area: replace with commons reserve-delta or same-tx delta + `TransferDeltaInsufficient`; delete whole-balance refund. |
| **Recommended TEST** | Product `test_I1_*` / `test_E6_*` on Uni V3 proxy after registry deploy. |
| **Anti-theater** | Proxy I1; no happy-only pretransfer. |
| **Suggested WP-ID** | none new — `WP-I-CLONE-001` / `A-se-v3-v4-lending` |
| **Link TCA / prior** | `TCA-COMMON-004`, `WP-I-CLONE-001` (STAGE3 claimed **closed** — **stale**; residual still in tree) |
| **Depends / parallel** | Do **not** schedule `sec_fix_*` from this area. Full-pass `A-se-v3-v4-lending` owns. |

### 6.4 [SEC-COMMON-004] Fork pretransfer suites still happy-only (R never booked)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-COMMON-004` |
| **Title** | Fork Permit2 harness never syncs MultiAsset `R`; pretransfer tests are bootstrap happy paths |
| **Severity** | Medium |
| **Class** | **TEST** / **THEATER** |
| **Confidence** | confirmed (source) |
| **Catalog IDs** | I1 |
| **Pattern IDs** | PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 |
| **Products** | BasicVaultCommon fork harness |
| **Blast radius** | False confidence only (does not change production) |
| **Impact** | Fork `test_fork_secureTokenTransfer_pretransferred_*` cannot fail if booked-inventory I1 is broken (`R` stays 0 so `U=B`). |
| **Evidence** | `test/foundry/fork/base_main/vaults/basic/BasicVaultCommon_TokenTransfer_Permit2_BaseFork.t.sol` L66–73, L139–151; Eth fork L113–121, L186–198. Constructor inits Permit2 only. Comment still says “returns amount_ directly”. |
| **Recommended TEST** | Init hold-set + `syncAllExpectedHoldReserves` after seed; add fork I1 booked revert. Or delete pretransfer fork cases and point at hermetic I1. |
| **Suggested WP-ID** | cluster with `WP-SEC-E6-COMMON-001` TEST slice or leftover `WP-I-COMMON-002` hygiene |
| **Link TCA / prior** | `TCA-COMMON-002` (partially closed hermetic; fork leftover) |

### 6.5 [SEC-COMMON-005] `ISecurePullErrors` NatSpec vs durable `U`

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-COMMON-005` |
| **Title** | Shared error NatSpec says same-tx delta; commons uses last-sync `U` |
| **Severity** | Low |
| **Class** | **CODE** (comment only) / **PAT-SPEC-DRIFT** |
| **Confidence** | confirmed |
| **Catalog IDs** | I1 |
| **Pattern IDs** | PAT-SPEC-DRIFT |
| **EVM-audit domain** | general |
| **Products** | `ISecurePullErrors` + all importers |
| **Impact** | Integrators / clone authors may implement same-tx snapshot (breaks two-tx push) or re-introduce absolute credit. |
| **Evidence** | `ISecurePullErrors.sol` L8–11 “balance increase **in this call**” vs `BasicVaultCommon` L63–67 durable `U`. Claim/Slipstream/DualLiquidity follow the interface comment (same-tx). |
| **Recommended CODE** | Rewrite NatSpec: two lawful algorithms (durable `U=B−R` vs same-tx `observedDelta`) both revert `TransferDeltaInsufficient(claimed, observed)`. |
| **Suggested WP-ID** | fold into `WP-SEC-E6-COMMON-001` or Wave-4 docs |

### 6.6 [SEC-COMMON-006] Donation / bootstrap `U` credit (product law)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-COMMON-006` |
| **Title** | Unbooked surplus (donation or `R=0`) is claimable by the next pretransfer |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** |
| **Confidence** | confirmed |
| **Catalog IDs** | A1, A0, K1 |
| **Pattern IDs** | PAT-K-DONATE, PAT-A0-EMPTY |
| **EVM-audit domain** | erc4626 |
| **Products** | BasicVaultCommon + all durable-`U` clones |
| **Impact** | No steal of **booked** (`R`) inventory. Unbooked push/donation is intentionally claimable (`claimed ≤ U`) and unclaimed remainder is absorbed at `_syncAllExpectedHoldReserves` (I3). |
| **Evidence** | NatSpec L15–18, L66–67; `test_bootstrap_R0_*`; `test_push_underClaim_absorbsSurplus_noRefund`. L-GAPS-9: do not require exact-delta equality (donation grief). |
| **Invariants** | After successful money route + sync: `R == B` for every `_vaultTokens` entry (`INV-R1`). Booked inventory cannot fund I1. Victim **booked** balances unchanged by a stranger’s pretransfer. |
| **Suggested WP-ID** | none; optional `test_K1_donationThenPretransfer_creditsUOnly` documentation test |

### 6.7 [SEC-COMMON-007] No catalog `test_K1_*` on commons

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-COMMON-007` |
| **Title** | Missing named K1 donation→pretransfer unit |
| **Severity** | Low |
| **Class** | **TEST** |
| **Confidence** | confirmed |
| **Catalog IDs** | K1 |
| **Pattern IDs** | none |
| **Evidence** | `rg test_K1_` under `test/foundry/spec/vaults/basic` → none. I3 absorb is the closest. |
| **Suggested WP-ID** | cluster TEST with `WP-SEC-E6-COMMON-001` |
| **Link TCA / prior** | `TCA-COMMON-006` / `WP-K-COMMON-001` (coverage Medium; not a competing High CODE) |

### 6.8 [SEC-COMMON-008] `U = B − R` underflow when `R > B`

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-COMMON-008` |
| **Title** | Pretransfer reverts via underflow if booked reserve exceeds live balance |
| **Severity** | Low |
| **Class** | **CODE** |
| **Confidence** | static-medium |
| **Catalog IDs** | K, H |
| **Pattern IDs** | PAT-K-DONATE (desync) |
| **EVM-audit domain** | precision-math / dos |
| **Products** | BasicVaultCommon; durable-`U` clones that copy `B0 - R` unchecked |
| **Impact** | DoS on `pretransferred=true` until a route runs `_syncAllExpectedHoldReserves`. Possible if `_refundExcess` (or outbound) lowers `B` and another pull reads `U` before sync, or rebasing-down token. Hook CP uses `B0 >= R ? B0 - R : B0` (safer). |
| **Evidence** | `BasicVaultCommon.sol` L34–35, L96. |
| **Recommended CODE** | `U = B0 >= R ? B0 - R : 0` then `TransferDeltaInsufficient`. |
| **Suggested WP-ID** | fold into `WP-SEC-E6-COMMON-001` |

### 6.9 [SEC-COMMON-009] Duplicate reserve libraries / ERC4626 view book

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-COMMON-009` |
| **Title** | Twin repos share a slot; ERC4626 view facet reports a different reserve book |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** / hygiene |
| **Confidence** | static-high |
| **Catalog IDs** | J (views), K |
| **Pattern IDs** | PAT-SLOT |
| **Evidence** | `BasicVaultRepo` and `MultiAssetBasicVaultRepo` both `STORAGE_SLOT = keccak256(abi.encode("indexedex.vaults.basic"))` with isomorphic `AddressSet + mapping`. `ERC4626BasedBasicVaultFacet.reserveOfToken` returns `ERC4626Repo._lastTotalAssets`, not MultiAsset `R`. |
| **Impact** | No slot smash. Integrators reading ERC4626 facet `reserveOfToken` cannot reconstruct pull `U`. |
| **Suggested WP-ID** | none (Wave-4 optional unify) |

### 6.10 [SEC-COMMON-010] Empty `BasicVaultErrors.sol` / harness `new`

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-COMMON-010` |
| **Title** | Empty errors file; helper tests use `new` harness |
| **Severity** | Info |
| **Class** | **DEFER** / **PAT-MOCK** note |
| **Confidence** | confirmed |
| **Catalog IDs** | none |
| **Pattern IDs** | PAT-MOCK |
| **Evidence** | `BasicVaultErrors.sol` is license-only. Unit/fork tests `new BasicVaultCommonHarness` — allowed for internal helper; must not count as SE/DETF adversarial. |
| **Suggested WP-ID** | none |

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| 2026-08-09 `test_secureTokenTransfer_pretransferred_returnsAmount` (historical) | Asserted free credit of seeded inventory | **Inverted** in current hermetic suite (expects `TransferDeltaInsufficient`). Keep inverted. |
| Fork `test_fork_secureTokenTransfer_pretransferred_*` | Push then claim with `R` never booked; comment “returns amount_ directly” | Book `R` + I1, or drop as I coverage (`SEC-COMMON-004`) |
| Permit2 unit `test_pretransferred_returnsAmount` | Name is theater; body now expects booked revert | Rename to `test_I1_*` |
| SE happy `pretransferred=true` with a real prior transfer | Not I1 (skill anti-pattern) | Product areas must keep separate `test_I1_*` |
| Coverage `STAGE3_PROGRESS.md` “44/44 closed” incl. `WP-I-CLONE-001` | Uni V3 absolute pull still in tree | Treat clone WP close as **stale** for Uni V3 (`SEC-COMMON-003`) |
| Coverage `repro/TCA-COMMON-001/forge.log` | Pre-fix theater PASS | Do not cite as current-SHA proof |
| Helper harness `new` as “SE adversarially tested” | Not a registry diamond | Never count as product I/J |
| No `_secureSelfBurn` tests | Cannot fail if leftover sweep is live | `SEC-COMMON-002` tests |

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| `TCA-COMMON-001` / `WP-I-COMMON-001` | **Yes** — `BasicVaultCommon._secureTokenTransfer` (+ historical Aero override) | **OWNED_ELSEWHERE**. CODE **closed** at `1e0d7c48` (reserve-delta). No `sec_fix_*`. |
| `TCA-COMMON-002` / `TCA-COMMON-003` / `TCA-COMMON-008` / `WP-I-COMMON-002` | **Yes** — I1–I3 unit + theater kill | **OWNED_ELSEWHERE**. Hermetic I1–I3 **present**. Fork leftover = `SEC-COMMON-004` (Medium TEST, not a new High WP). |
| `TCA-COMMON-004` / `WP-I-CLONE-001` | Clone inventory (this area blast-only) | **OWNED_ELSEWHERE**. Most clones now reserve-delta or same-tx delta. **Residual live PAT-I-ABS: Uni V3 In/Out** — stale close. Full-pass `A-se-v3-v4-lending`. |
| `TCA-COMMON-005` / `WP-I-CLAIM-001` | Claim foreign-token (blast) | **OWNED_ELSEWHERE**. Current claim helper is same-tx delta (`RebasingClaimTokenTarget` L559–581). Product area confirms e2e. |
| `TCA-COMMON-006` / `WP-K-COMMON-001` | K after I fix | **OWNED_ELSEWHERE** (Medium TEST). Commons I3 covers absorb; named `test_K1_*` still missing (`SEC-COMMON-007`). |
| `TCA-COMMON-007` Aero override | Historical override PAT-I-ABS | **Closed** — override removed; Aero inherits commons. |
| `TCA-SE-AC-001` | Inheritor root CODE | **OWNED_ELSEWHERE** → closed commons + `WP-I-SE-AC-001` (SE area). |
| `_secureSelfBurn` / leftover E6 | **No** prior TCA High/Blocker | **New** `SEC-COMMON-002` / `WP-SEC-E6-COMMON-001`. |

## 9. Work package stubs

**No new Wave-0 `sec_fix_*` for token-side PAT-I-ABS** (OWNED_ELSEWHERE / closed).

### WP-SEC-E6-COMMON-001 — Fix `_secureSelfBurn` share-delta + leftover cap

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-COMMON-001` |
| **Title** | Require inbound/unbooked share proof in `_secureSelfBurn` and cap leftover refund to this-call unused |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | BasicVaultCommon; Aero / Camelot / Uni V2 / Aave Stata share-burn routes |
| **Finding IDs** | `SEC-COMMON-002` (primary); fold `SEC-COMMON-005` NatSpec, `SEC-COMMON-008` `U` underflow, `SEC-COMMON-004`/`007` TEST hygiene if same tree |
| **Problem** | Token pull is reserve-delta; share burn is still “burn from `this` + refund **all** leftover self-shares.” An unprivileged caller with `pretransferred=true` can consume sitting vault shares (donation or victim two-tx push) and receive both exit assets and the remainder. No unit or catalog test exists. Attack one-liner: donate or wait for sitting shares → `exchangeOut(pretransferred=true)` → steal leftover shares + assets. |
| **Production files (touch set)** | `contracts/vaults/basic/BasicVaultCommon.sol`; optional comment-only `contracts/interfaces/ISecurePullErrors.sol` |
| **Test files (touch set)** | `test/foundry/spec/vaults/basic/BasicVaultCommon_TrustFlags.t.sol` (extend) or new `BasicVaultCommon_SelfBurn.t.sol`; optional fork harness init of MultiAsset `R` |
| **Out of scope files** | Uni V3 clone bodies (`SEC-COMMON-003`); DETF `_pullToken` clones; SE route rewrite except compile fixes if signature unchanged |
| **Depends on** | none (token PAT-I-ABS already landed). Same file as closed `WP-I-COMMON-001` — **serial** vs any other editor of `BasicVaultCommon.sol` |
| **Parallelizable with** | Product I/J WPs that do not edit `BasicVaultCommon.sol`; `A-detf-multi-vault` / `A-se-amm-v2` **after** this merges if they assert self-burn behavior |
| **Conflicts with coverage-audit WP** | `none` for this defect. Do **not** reopen `WP-I-COMMON-001` token-delta. Same-file caution only. |
| **Suggested worktree** | `sec_fix_e6-common-selfburn` / branch `sec_fix/e6-common-selfburn` |
| **Implementation notes** | Skills: `crane-adversarial-testing` I + E6; `indexedex-adversarial-testing`; L-CLAIM-3 / L-GAPS-9 for “credit/consume only observed unused.” Gold: token-side `_refundExcess` + `_secureTokenTransfer` reserve-delta. Prefer snapshot `b0` / unbooked self-shares; refund `delivered − burned` only. SafeERC20 already in file. Never `via_ir`. Facets still CREATE3; no `new` production facet. DETF role names in any SE smoke (`vaultShare`, not brand). |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/basic/**' -vv` green; new `test_I1_secureSelfBurn_*` and `test_E6_secureSelfBurn_*` **fail on pre-fix** / pass post-fix. Optional: one Aero or Aave registry-deployed proxy smoke `test_I1_secureSelfBurn_*`. Existing token `test_I1_*` / `test_I2_*` / `test_I3_*` stay green. |
| **Anti-theater checks** | I1: no in-call share transfer; vault already holds self-shares; attacker product/share/asset balances do not increase. E6: second user’s sitting shares must not be transferred to the first `pretransferred` caller. Exact selector, not bare `expectRevert()`. No `vm.mockCall` on SUT. Pass = exploit blocked. |
| **Proof-first?** | **yes** (High CODE was RUNTIME_UNPROVEN) |
| **Estimate** | M |

No other Critical/High WP stubs. `SEC-COMMON-003` is OWNED_ELSEWHERE (no `sec_fix_*`).

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Notes |
|------|-------|-------|
| Token-side PAT-I-ABS Wave-0 CODE | OWNED_ELSEWHERE / closed | Do not re-queue `sec_fix_*` |
| Uni V3 PAT-I-ABS + `_refundRemainder` E6 | OWNED_ELSEWHERE / DEFER to `A-se-v3-v4-lending` | Blast listed; stale `WP-I-CLONE-001` close |
| Same-tx vs durable-`U` family split | **ACCEPTED_RISK** / **NEEDS_OWNER** only if product wants one algorithm monorepo-wide | Commons + DETF locals = durable; claim / Slipstream / Dual / Lido = same-tx |
| Donation `U` claimable by next pretransfer | **ACCEPTED_RISK** | Invariants in `SEC-COMMON-006` |
| Bootstrap `R=0` full-balance claim | **ACCEPTED_RISK** | First money-route sync is the gate; product A0 still required on SE/DETF |
| BasicVaultFacet A–H adversarial | **DEFER** | View-only; 2026-07 Wave 3C still valid |
| ProtocolDETFCommon / SeigniorageDETFCommon | **N/A** | Not in tree |
| L1–L3 / M / N / O / F5 on helper | **N/A** | No AMM / router / sig / structural settle in commons |
| e2e free **share** mint via token PAT-I-ABS | **N/A** at this SHA on inheritors of the fixed helper | Product areas still prove proxy I1 |
| `_secureSelfBurn` e2e share steal | **RUNTIME_UNPROVEN** | `SEC-COMMON-002`; WP is proof-first |
| `via_ir` | Forbidden | Never recommend |
| BUILD_BLOCKED | n/a | Static review complete; forge not required of this agent |

## 11. Commands run

```bash
# Inventory (rg --glob '*.sol'; rg --type sol unavailable)
rg -n 'function _secureTokenTransfer|function _securePull|function _pullToken|function _secureSelfBurn' --glob '*.sol'
rg -n 'is BasicVaultCommon|TransferDeltaInsufficient|_syncAllExpectedHoldReserves|_secureSelfBurn' --glob '*.sol'
rg -n 'balanceOf\(address\(this\)\) >=' --glob '*.sol'
rg -n 'if \(pretransferred' --glob '*.sol' --multiline
rg -n 'function test_I1_|function test_I2_|function test_I3_|function test_K1_' test/foundry/spec/vaults/basic
rg -n 'test_secureSelfBurn|_secureSelfBurn|leftoverShares' test --glob '*.sol'
rg -n 'WP-I-COMMON-001|TCA-COMMON-001' docs --glob '*.md'

# Files read (production allowlist + blast + tests + law)
# contracts/vaults/basic/{BasicVaultCommon,BasicVaultErrors,BasicVaultFacet,BasicVaultRepo,BasicVaultTarget,IBasicVault,MultiAssetBasicVault*,ERC4626BasedBasicVaultFacet}.sol
# contracts/interfaces/{ISecurePullErrors,IBasicVault}.sol
# Aerodrome/Camelot/UniV2/Aave commons + Out/In Targets (self-burn / inherit)
# Clone/peer pulls: MultiVault, Single SE, MixedBuffer, ComposedStable, UniV4 DETF commons,
#   ERC4626 SE, UniV4 SE, Slipstream, Claim, RebasingDETF, DualLiquidity, Lido/Rocket,
#   Uni V3 In/Out, hook _securePull sample
# test/foundry/spec/vaults/basic/{BasicVaultCommon_TokenTransfer,TrustFlags,Permit2}.t.sol
# test/foundry/fork/{base_main,eth_main}/vaults/basic/*Permit2*.t.sol
# docs/security/SECURITY_AUDIT_PRD.md; audit/00_SCOPE_PARTITION.md; 01_METHODOLOGY_NOTES.md
# docs/testing/coverage-audit/{WORK_PACKAGE_BACKLOG,STAGE3_PROGRESS,areas/T-basic-protocol-commons}.md
# docs/security/audit/repro/SEC-COMMON-001/{notes,COMMANDS}.md
# skills: crane-adversarial-testing; indexedex-adversarial-testing; indexedex-testing;
#         ethskills-security; defi-incident-patterns
```

**Forge:** not run by this agent (PRD: orchestrator owns runtime proof; static review sufficient). Target command for orchestrator / WP proof-first:

```bash
# Hermetic I1–I3 regression (token pull closed)
forge test --match-path 'test/foundry/spec/vaults/basic/**' \
  --match-test 'test_I1_|test_I2_|test_I3_|test_secureTokenTransfer_pretransferred' -vv
# via_ir: not used. Profile: default hermetic. ALCHEMY_KEY: not required.
```

---

**Area status: COMPLETE**  
**Critical: 0 · High: 2** (`SEC-COMMON-002` CODE; `SEC-COMMON-003` OWNED_ELSEWHERE)  
**OWNED_ELSEWHERE: 5** TCA/WP links (`WP-I-COMMON-001/002`, `WP-I-CLONE-001`, `WP-I-CLAIM-001`, `WP-K-COMMON-001`)  
**Top WP-IDs: `WP-SEC-E6-COMMON-001` (new Wave-0); do not open `sec_fix_*` for token PAT-I-ABS**
