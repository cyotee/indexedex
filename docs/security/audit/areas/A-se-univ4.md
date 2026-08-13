# Security Audit — A-se-univ4

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · **MODE=full** · `A-se-univ4` |
| Status | **COMPLETE** |
| Production paths | `contracts/protocols/dexes/uniswap/v4/**` (**SE vault only** — not DETF families, not hooks) |
| Test paths | `test/foundry/spec/protocol/dexes/uniswap/v4/**`; co-located `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange.sol`. DETF/hook trees cited as **reference only**. |
| Skills cited | `docs/security/SECURITY_AUDIT_PRD.md` §2, §2.4, §3.8, §5–8, §19; `00_SCOPE_PARTITION.md`; `crane-adversarial-testing`; `indexedex-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `defi-incident-patterns`; seed `docs/testing/coverage-audit/areas/T-se-univ4-aave-balancer.md` (Uni V4 rows only); pilot `A-commons-pull` §2.2.A |
| Residual-risk scores | Uniswap V4 SE vault → **2**; LiquidReserve surface → **3**; token-side `_secureTokenTransfer` → **4** |

## 1. Executive summary

Re-read at `1e0d7c48`. Coverage-audit **T-se-univ4-aave-balancer** (2026-08-09) claimed Uni V4 `_secureTokenTransfer` was a **live PAT-I-ABS local clone** (`pretransferred` → `balanceOf >= amount` → `return amountIn`). **That CODE claim is stale.** Gap-closure `fec9fbb` / `WP-I-CLONE-UAB-001` landed a **face-booked reserve-delta** peer: `U = B_face − (R − deployed)`; `claimed > U` → `TransferDeltaInsufficient`. Pilot `A-commons-pull` §2.2.A already listed this helper as a reserve-delta peer. **Do not open a competing `sec_fix_*` for token-side PAT-I-ABS.**

**I1 is proven on the proxy** for booked `rateAsset` / `pairToken` after an honest mint (`test_I1_pretransferred_*` in `Adversarial_UniswapV4SE_SecurePull.t.sol`). **I2 / I3 named tests are still absent** (CODE looks correct; STAGE3 “closed I1–I3” is **stale TEST**). LiquidReserve is **cut into the diamond** (`facetCuts_[10]`); dedicated `*_IFacet_Test` is still missing (J residual TEST).

**New exploitable classes this program owns** (not in coverage CODE WPs):

1. **PAT-E6 + I1 on `vaultShare`** — Out zap-out burns `address(this)` when `pretransferred=true` with **no inbound-share delta**, then refunds `maxSharesToBurn − sharesBurned` from the vault’s self-balance. In zap-out always `_burn(address(this))` after `_secureTokenTransfer` on `address(this)`, where MultiAsset `R(vaultShare) == 0` so `U = balanceOf(this)`. Peer of `SEC-COMMON-002` but **local files** (Uni V4 does not inherit `BasicVaultCommon`).
2. **`importPosition` trusts caller `positionManager` + `owner`** — no allowlist; `transferFrom(owner, vault, tokenId)` does not require `owner == msg.sender`. Fake PM inflates `_deployedAmounts` / first-mint shares; subsequent honest zap-in is diluted; empty-vault + donation is drainable.
3. **PAT-A0-EMPTY** — first mint is `amount0Added + amount1Added` with **no virtual offset / dead shares**. Empty or 1-wei supply + donation → first minter / inflator captures residual `rateAsset` / `pairToken` (classic ERC-4626 inflation; `minSharesOut=0` mints **zero** shares and keeps the victim deposit).

| Product | Residual risk | Worst open |
|---------|--------------:|------------|
| Uniswap V4 SE (overall) | **2** | Share-burn leftover + untrusted import + A0 |
| Token pull (`_secureTokenTransfer` on pool currencies) | **4** | I1 green; I2/I3 TEST leftover |
| LiquidReserve + public rebalance | **3** | F5-safe (no surplus to caller); J/IFacet TEST leftover |
| Position import | **2** | Untrusted PM / owner |

| Severity | Count | Notes |
|----------|------:|-------|
| **Critical** | **0** | L-SEC-3: no forge this run; static High max |
| **High** | **3** | All **new CODE**: `SEC-SE-U4-002`, `SEC-SE-U4-003`, `SEC-SE-U4-004` |
| **Medium** (clustered) | **6** | I2/I3 TEST; LiquidReserve J; N2 preview buffer; uncollected fees; hostile `PkgArgs.hooks`; disable/CROPS cite |
| **OWNED_ELSEWHERE** | **6** | Collision WPs + closed token PAT-I-ABS + fork + ADV residual |

**Top recommended WPs (this program, `sec_fix_*`):**

| Pri | WP-ID | Title |
|----:|-------|-------|
| 1 | **WP-SEC-E6-U4-001** | Share-delta + leftover cap on In/Out zap-out (`vaultShare`) |
| 2 | **WP-SEC-IMP-U4-001** | Allowlist PositionManager; `owner == msg.sender` (or explicit operator) |
| 3 | **WP-SEC-A0-U4-001** | Dead shares / virtual offset; first mint cannot absorb residual inventory |
| — | *(do not schedule)* | `WP-I-CLONE-UAB-001`, `WP-I-SE-UAB-001`, `WP-ADV-SE-UAB-001`, `WP-J-SE-UAB-001`, `WP-I-CLONE-001` |

**OWNED_ELSEWHERE count:** **6** linked TCA/WP touch-sets (`SEC-SE-U4-001`, `005`, `006`, `010`, plus clustered fork/ADV).

Headline: **token-side PAT-I-ABS is closed and I1-blocked when face is booked.** The remaining Uni V4 SE money defects are **share-burn leftover**, **untrusted position import**, and **empty-supply inflation**.

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|--------------:|
| **Uniswap V4 Standard Exchange** | `UniswapV4StandardExchangeDFPkg`; In Target+Facet (+ InExecutionDelegate); InQuery; Out Execute Target+Facet (+ OutExecutionDelegate); OutQuery; PositionImport; LiquidReserve Target+Facet; Common (local `_secureTokenTransfer`, **does not** inherit `BasicVaultCommon`); FactoryService; repos (PoolManager / PoolKey / Position) | Co-located `TestBase_UniswapV4StandardExchange` (extends `TestBase_Permit2` + `TestBase_VaultComponents`) | **Gold:** CREATE3 facets + `vm.prank(owner); indexedexManager.deployUniswapV4StandardExchangeDFPkg(...)` then `pkg.deployVault(poolKey, widthMultiplier)` via registry | **2** |
| **IUniswapV4StandardExchangeLiquidReserve** | Views + permissionless `rebalanceLiquidReserve` | Exercised in `UniswapV4StandardExchange_LocalLiquidBuffer*.t.sol` | Cut as facet 10 | **3** (F5-safe; J TEST gap) |
| **ISecurePullErrors** | Imported by Common | Adversarial I1 uses exact selector | Import-only | **4** (token path) |

**Init / books:** `MultiAssetBasicVaultRepo._initialize([token0, token1])` only — **`vaultShare` is not a booked vault token**. `_syncVaultReserves` writes `R = free + deployed` for pool currencies. ERC20 init `UV4X` / 18 decimals, **no dead shares**. USAGE fee type id = `type(IUniswapV4StandardExchangeLiquidReserve).interfaceId` (oracle liquid-% cascade). Init grants **max** ERC20 + Permit2 allowances to Permit2 / PoolManager.

**Trust-flag entrypoints:** `exchangeIn(..., pretransferred, deadline)`, `exchangeOut(..., pretransferred, deadline)`. Token pull: face-booked `U`. Share zap-out: **not** delta-safe (see §6.2).

**Out of area (reference only):** Uni V4 DETF families (`A-detf-single-se`, `A-detf-univ4-extra`); SE buffer / swap hooks (`A-hooks-v4-*`); coordinator router (`A-routers-permit2`); `BasicVaultCommon` / `SEC-COMMON-002` (blast peer, different files).

### 2.1 Test inventory (this area)

| Suite | Path | Catalog? |
|-------|------|----------|
| Secure-pull + residual A–H / J money | `test/foundry/spec/protocol/dexes/uniswap/v4/adversarial/Adversarial_UniswapV4SE_SecurePull.t.sol` | **I1** (2 tests) + A1–A3, E1/E4/E5, F1, H2/H3, J1–J3 **In/Out only**. **No I2/I3/A0/K1/E6/L** names |
| Routes H/P | `UniswapV4StandardExchangeRoutes_Test.t.sol` | Happy pretransfer **push-then-true** (not I1) |
| Local liquid buffer | `UniswapV4StandardExchange_LocalLiquidBuffer.t.sol` | T4d donation dilutes; public rebalance; C reenter (T13); H mid-session sleeve |
| H2 hook mid-swap | `UniswapV4StandardExchange_LocalLiquidBuffer_H2.t.sol` | Product H2 vs Single SE Buffer hook |
| Deploy | `UniswapV4StandardExchangeDFPkg_Deploy.t.sol` | Facet address list |
| IFacet declaration | In / InQuery / Out / PositionImport `*_IFacet_Test.t.sol` | **No** `LiquidReserveFacet_IFacet_Test` |
| SE-native fork | none under `test/foundry/fork/**/uniswap/v4` SE | Hooks/DETF forks ≠ this SUT |

## 3. Threat models

### 3.1 Uniswap V4 SE — `exchangeIn` / `exchangeOut` (pool currencies)

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn` direct swap / zap-in | `rateAsset` / `pairToken` / `vaultShare` | `pretransferred` | fee-oracle liquid % | **Blocked** when face booked (`U==0`). Closed PAT-I-ABS. |
| EXT / CAP | Same after donation, no sync | Unbooked face `U` | `pretransferred=true` | none | Next pusher credits `min(claimed, U)`. **ACCEPTED_RISK** (L-CLAIM-3 / L-RSRV-DUST). |
| EXT | `exchangeOut` direct swap | `rateAsset` ↔ `pairToken` | `pretransferred` + `maxAmountIn` | none | Credits **max** then refunds `provided − used` (this-call unused). **E6-safe** on pool tokens (unlike A-se-amm-v2 used-then-refund-max). |
| HOS | `transferFrom` reentry | same | `nonReentrant` on In/Out/LiquidReserve | — | Nested reentry blocked (T13 + nonReentrant). |
| CFG | `PkgArgs.poolKey.hooks` hostile | swap/liquidity callbacks | — | — | N1/B sandwich inside unlock; CFG at deploy. |
| ADM | fee-oracle `liquidReservePercentageOfVault` | free↔deployed only | — | fee oracle | Cannot extract; can force sleeve/deploy. Manager-owned. |
| ADM | registry `isDisabled` | exit | — | registry | Freeze In/Out/rebalance. `A-manager-fee-registry`. |

### 3.2 Uniswap V4 SE — zap-out `vaultShare` burn

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn(vaultShare → tokenOut, pretransferred=true)` | `vaultShare` + `rateAsset`/`pairToken` | `pretransferred` | none | `_secureTokenTransfer(address(this))` sees `R=0` → `U=self-balance`. Burns self, pays pro-rata assets. **High.** |
| EXT | `exchangeOut(vaultShare → tokenOut, pretransferred=true)` | same | `pretransferred` | none | No pull. `_burn(this, sharesBurned)` then `_transfer(this, msg.sender, max − burned)`. Steals **all** sitting self-shares + exit assets. **High.** |
| CFG | Two-tx push of shares then redeem | victim `vaultShare` | `pretransferred=true` | none | Frontrun redeem; leftover refund sweeps victim inventory. |
| CAP | Donate `vaultShare` to diamond | donated shares + NAV | `pretransferred` | none | Skim donation that should stay idle / accrue to remaining holders. |

### 3.3 Position import + LiquidReserve

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT / HOS | `importPosition(positionManager, tokenId, …, owner, recipient)` | NFT + minted `vaultShare` | caller-supplied PM | none | Fake PM + empty supply → inflated deployed NAV; later depositor diluted; sleeve drain on redeem. **High.** |
| INT | Same, `owner ≠ msg.sender` | victim NFT | vault approved as ERC-721 operator | none | Front-run import; mint shares to attacker `recipient`. |
| EXT | `rebalanceLiquidReserve` | free↔deployed | permissionless | oracle target % | **F5-safe**: no tokens to `msg.sender`. Grief = gas / band chase. After donation, rebalance **syncs R** and closes U. |
| EXT | `unlockCallback` | PM settle | `msg.sender == poolManager` | — | Arbitrary caller blocked. |

## 4. Catalog matrix (A–O, E6, F5)

| ID | Product | F/P/G/N/A/VULN | Evidence |
|----|---------|----------------|----------|
| **A1** | Uni V4 SE | **P** | `test_A1_donateToken_cannotMintFreeShares` — no immediate mint. Donation becomes `U` until sync. |
| **A0** | Uni V4 SE | **VULN** | First mint `amount0+amount1`; no offset. `SEC-SE-U4-004`. |
| **A2** | Uni V4 SE | **P / VULN** | `test_A2_*` idle `vaultShare` on diamond; redeem path **does** extract (`SEC-SE-U4-002`). |
| **A3** | Uni V4 SE | **P** | Donate `pairToken` idle; no free mint. |
| **B / L3** | Uni V4 SE | **P** | Direct swap is spot; `minOut` / deadline. Zap-in mint is reserve-based (not spot oracle). No seigniorage thresholds. **ACCEPTED_RISK** MEV with slippage. |
| **C1–C3** | Uni V4 SE | **F** | `nonReentrant` on In/Out/LiquidReserve; T13 hostile ERC20; unlock gate. |
| **D** | Uni V4 SE | **N/A** | No claim NFT (import is ERC-721 PM, not DETF bond). |
| **E1** | Uni V4 SE | **P** | `test_E1_swapRoundTrip_bounded`; routes conservation. |
| **E5** | Uni V4 SE | **F** | Deadline + invalid route exact selectors. Zero-amount uses bare `expectRevert` in one A/H test. |
| **E6** | Out `_refundExcess` (pool tokens) | **F** | `provided − used` after crediting **max**. |
| **E6** | Out zap leftover `vaultShare` | **VULN** | `SEC-SE-U4-002`. |
| **F / F1** | Uni V4 SE | **F** | `test_F1_diamondCut_blocked` loupe `facetAddress==0`. No `onlyOwner` in package. |
| **F5** | `rebalanceLiquidReserve` | **F** | Permissionless structural move; **does not** settle surplus to caller. Syncs books if moved. |
| **G** | Uni V4 SE | **N/A** | Nested DETF/hooks owned by those areas. H2 sleeve path exists for in-session hosts. |
| **H2** | Uni V4 SE | **F** | Atomic fail tests + dedicated H2 hook file. |
| **H3** | Uni V4 SE | **P** | minOut / maxIn fail; residual self-shares asserted 0. |
| **I1** | pool currencies | **F** | Adversarial I1 after honest mint; exact `TransferDeltaInsufficient(claimed, 0)`. |
| **I1** | `vaultShare` | **VULN** | `R(vaultShare)=0`; Out burn-from-self. |
| **I2** | pool currencies | **P** | CODE: `claimed > U` reverts. **No** `test_I2_*`. |
| **I3** | pool currencies | **P** | Zap-in `_syncVaultReserves` books leftover; direct swap leaves stale R conservative (`U=0` on consumed token). **No** `test_I3_*`. |
| **I4** | pull path | **P** | `!pretransferred` returns `B1−B0` only. No FoT named test. |
| **I5** | Uni V4 SE | **N/A** | No local Permit2 witness on vault money API (init allowances only). Router-owned. |
| **J1** | In/Out/Query/Import | **P** | IFacet tests exist; controls copied from Facet (PAT-J-CTRL hygiene). Target APIs match listed selectors. |
| **J1** | LiquidReserve | **G** | `facetFuncs` has 6 selectors including `rebalanceLiquidReserve`; **no** IFacet_Test. |
| **J2–J3** | money In/Out | **P** | Adversarial loupe + proxy smoke for 4 SE selectors. Import / LiquidReserve not in `_controlSelectors()`. |
| **J4** | DFPkg | **F** | `facetCuts` includes all 11 facets (static). |
| **K1** | live donation | **P** | T4d documents dilution if unused. Pretransfer harvest of `U` is absorb law. No `test_K1_*`. |
| **L1** | Uni V4 SE | **P** | Books = free+principal-liq; uncollected position fees not in `_positionAmounts`. No public skim of fees to caller. |
| **L2** | Uni V4 SE | **P** | Pull path FoT-safe; product does not claim FoT support. |
| **L3** | Uni V4 SE | **P** | See B. |
| **M1–M3** | import | **VULN** | User-supplied `positionManager` + `owner`. `SEC-SE-U4-003`. Unlock callback not user target. Delegates not cut as facets. |
| **N1** | unlock / hook | **P** | Hostile pool hook is CFG. In-session paths sleeve (no nested unlock). |
| **N2** | preview vs exec | **P** | Out zap-out preview adds 1% share buffer (`OutBase` L88–95). Routes compare loosely. |
| **O1–O3** | ERC2612 on `vaultShare` | **N/A** | Crane facet; no local ecrecover. |
| **PAT-I-ABS** token | Common | **F** (closed) | Face-booked body L1083–1101. `SEC-SE-U4-001`. |
| **PAT-CROPS-ADMIN** | instance | **F** | No leftover owner/operator/`diamondCut`. |
| **PAT-SLOT** | repos | **F** | Distinct keccak slots: position / pool key / pool manager / `indexedex.vaults.basic`. |

## 5. Domain notes

Walked as hunt lists (not a second ID space):

| Domain / skill | Walked on | Notable hits |
|----------------|-----------|--------------|
| **general / erc20** | `_secureTokenTransfer`, `_refundExcess`, zap-out burns, SafeERC20 | Token pull FoT-safe on `false`. Share path ignores delivery. |
| **precision-math** | `_sharesOutForDeposit`, face-booked `U`, rebalance frac | First mint ignores residual. Subsequent single-sided `amount * S / R` rounds down (inflation). |
| **erc4626** | share mint/burn; no ERC4626 deposit facet on this diamond | `MultiAssetStandardVaultFacet` is **views only** (fee type / contents / types / config). |
| **defi-amm** | unlock swap/add/remove; `_positionAmounts` | Principal-liq NAV; fees realized on remove. Spot swap not used as mint oracle. |
| **proxies / J** | DFPkg cuts; IFacet ×4; adversarial J | LiquidReserve cut but undeclared in tests. `unlockCallback` on InFacet only (one diamond callback — OK). |
| **access-control / CROPS** | no `onlyOwner`; disable via registry; fee-oracle liquid % | Instance unowned after deploy. Disable freeze → manager area. |
| **dos** | in-session hard-revert on paths that need unlock; sleeve cover | Direct swap requires free PM (`_requireCanOpenPoolManagerUnlock`). |
| **flashloans** | CAP can donate then import/mint | Combined with A0 / fake PM. |
| **signatures** | ERC2612 facet present | No local permit verify on money routes. |
| **sharp-edges** | `pretransferred` bool; `minSharesOut=0`; `importPosition` args; max Permit2 | Two-tx share push is the dangerous UX. Infinite PM allowances = Uni V4 norm. |
| **spec-compliance** | Local-liquid-buffer PRD D1–D29 vs code | Sleeve + `R = free+deployed` matches D9/D29. First-mint formula vs “share SoT = all controlled assets” **drifts** on residual (`SEC-SE-U4-004`). Vault plan: PM not for core ops — import still trusts caller PM. |
| **incident themes** | `defi-incident-patterns` | Trust-flag free mint (closed on tokens; live on shares). Surplus-refund leftover. Empty-vault inflation. Arbitrary helper (fake PM). |
| **ethskills-security** | SafeERC20, CEI, inflation offset, infinite approve, delegatecall | Delegates are CREATE3 immutables via `functionDelegateCall` (not user target). No virtual offset. Max approve on init. |

## 6. Findings

### 6.1 [SEC-SE-U4-001] Historical PAT-I-ABS on token `_secureTokenTransfer` — closed at this SHA

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U4-001` |
| **Title** | Historical absolute-balance pretransfer on Uni V4 SE token pull is closed |
| **Severity** | **Info** (historical Blocker; not live) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high (current source) |
| **Catalog IDs** | I1–I3, K1 |
| **Pattern IDs** | PAT-I-ABS (closed) |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | Trust-flag free mint (closed) |
| **Products** | Uniswap V4 Standard Exchange |
| **Blast radius** | Local Common helper (not `BasicVaultCommon` inherit) |
| **Impact** | None at `1e0d7c48` on **pool currencies**. Pre-fix: free credit of face inventory. |
| **Evidence** | `UniswapV4StandardExchangeCommon.sol` L1073–1101: `R` from MultiAsset; `!pretransferred` returns pull delta only; `faceBooked = R − deployed`; `U = B0 − faceBooked`; `amountIn > U` → `TransferDeltaInsufficient`. Contrast 2026-08-09 quote in `T-se-univ4-aave-balancer.md` §5.1 (`if (pretransferred) { if (balanceOf < amountIn) revert; return amountIn; }`) — **gone**. I1: `Adversarial_UniswapV4SE_SecurePull.t.sol` L161–208. Pilot `A-commons-pull` §2.2.A lists this helper as reserve-delta peer. STAGE3: `WP-I-CLONE-UAB-001` closed `fec9fbb`. |
| **Runtime** | Not re-run. Existing I1 expects exact revert — sufficient to refuse a new Critical CODE. |
| **Recommended CODE** | none for token PAT-I-ABS |
| **Recommended TEST** | Keep I1 green; add I2/I3 (see `SEC-SE-U4-005`) |
| **Anti-theater** | I1 must not transfer in-call; must book face first |
| **Suggested WP-ID** | none (`sec_fix_*` skip) |
| **Link TCA / prior** | `TCA-SE-UAB-001`; `WP-I-CLONE-UAB-001`; `WP-I-CLONE-001`; `A-commons-pull` §2.2.A |
| **Depends / parallel** | n/a |

### 6.2 [SEC-SE-U4-002] Zap-out burns self-held `vaultShare` without inbound delta and refunds leftover

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U4-002` |
| **Title** | Require inbound `vaultShare` delta (or booked unbooked-share `U`) and cap leftover refund to this-call unused |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high · **RUNTIME_UNPROVEN** (no forge this run) |
| **Catalog IDs** | I1, E6, A2, K1 |
| **Pattern IDs** | PAT-I-ABS (share path), PAT-E6-REFUND, PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 / erc4626 |
| **CROPS pillar** | n/a |
| **Incident theme** | Surplus-refund / public reclaim; trust-flag free redeem |
| **Products** | Uniswap V4 Standard Exchange |
| **Blast radius** | Single package In zap-out + Out zap-out. **Peer of `SEC-COMMON-002`** (`_secureSelfBurn`) but Uni V4 does **not** inherit commons — different touch-set. |
| **Attacker** | **EXT** (public `pretransferred=true`); **CFG** two-tx share push; **CAP** donate `vaultShare` |
| **Attack scenario** | 1. Vault self-share balance is normally 0. Victim (or donor) transfers `S` `vaultShare` to the diamond (two-tx pretransfer or A2 donation). 2. **Out path:** attacker `exchangeOut(vaultShare, maxSharesToBurn=S, tokenOut, amountOut, attacker, pretransferred=true, deadline)`. `OutExecuteTarget` does **not** call `_secureTokenTransfer` for zap-out; delegates to `executeZapOutWithdrawal`. 3. Preview burns `sharesBurned ≤ S`. `ERC20Repo._burn(address(this), sharesBurned)` with **no** delivery check. 4. If `max > burned`, `_transfer(address(this), msg.sender, max − burned)` sends **remaining self-shares** to the attacker. 5. Route pays `tokenOut` for the burned shares. 6. **In path:** `exchangeIn(vaultShare, amountIn, tokenOut, …, true)` → `_secureTokenTransfer(IERC20(address(this)), amountIn, true)`: `R=0`, `deployed=0`, `U=balanceOf(this)=S`; credits `amountIn` if `≤ S`; `_executeZapOutExactIn` **always** `_burn(address(this), sharesBurned)`. |
| **Preconditions** | Diamond already holds its own shares (`balanceOf(this) ≥ burn`). Atomic router `transfer + exchange` in **one tx** from 0 self-balance is safe on In (pull) and on Out `pretransferred=false` (burns `msg.sender`). Two-tx push, donation, or leftover is enough. No admin required. |
| **Impact** | Steal of sitting `vaultShare` + corresponding `rateAsset` / `pairToken`. Not an unbounded drain of **booked** pool reserves unless those shares already sit on the vault. Realistic High (L-SEC-3: not Critical without runtime). |
| **Evidence** | Out delegate `UniswapV4StandardExchangeOutExecutionDelegate.sol` L34–41 and L55–59 (burn self + leftover transfer). Out execute `UniswapV4StandardExchangeOutExecuteTarget.sol` L63–68 (zap-out **skips** `_secureTokenTransfer`). In target L68–71 + InBase L178 / L229 always `_burn(address(this))`. Common L1087–1101 + `_deployedFaceOf` L1105–1109: unknown token (incl. `address(this)`) `deployed=0`. DFPkg L233–237 inits only `[currency0, currency1]`. MultiAsset `_reserveOfToken` default 0. Happy theater: `Routes_Test` `test_exchangeOut_zap_pretransferred_true` L435–458 **transfers** shares first. `test_A2_*` asserts idle shares stay — does not redeem. |
| **Runtime** | Not run. Label **RUNTIME_UNPROVEN**. Proof-first in WP. |
| **Recommended CODE** | Treat `vaultShare` like a booked asset: snapshot `b0 = balanceOf(this)` (or add self-share to MultiAsset and sync). `pretransferred`: require `burn ≤ unbooked`; burn `burn`; refund **only** `delivered − burned` (never raw remainder if that exceeds this-call credit). Prefer reuse of a share-delta helper aligned with `SEC-COMMON-002` sketch **copied locally** (do not edit `BasicVaultCommon` in this WP). Out zap-out must pull/credit **before** burn (same as In). |
| **Recommended TEST** | `test_I1_exchangeOut_zap_pretransferred_noShareDelivery_existingSelfBalance_revertsOrNoExtract`; `test_E6_exchangeOut_zap_doesNotSweepOtherUsersShares`; `test_I1_exchangeIn_zapOut_pretransferred_noShareDelivery_reverts`; `test_I3_residualSelfShares_notRedeemableBySecondCaller`. Setup: honest mint; victim transfers shares to proxy; attacker `pretransferred=true` with zero transfer. Pass: attacker `vaultShare` + `tokenOut` deltas = 0 or exact `TransferDeltaInsufficient`. `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v4/adversarial/**' --match-test 'test_I1_exchangeOut_zap\|test_E6_exchangeOut_zap'` |
| **Anti-theater** | I1 must **not** transfer shares in-call. Must not treat leftover==all self-balance as success. Call **proxy**. Exact selector. No `vm.mockCall` on vault. |
| **Suggested WP-ID** | `WP-SEC-E6-U4-001` |
| **Link TCA / prior** | none (coverage `WP-I-CLONE-UAB-001` owned **token** pull only). Peer `SEC-COMMON-002` / `WP-SEC-E6-COMMON-001` — **do not** merge files. |
| **Depends / parallel** | Parallel with import / A0 WPs (disjoint primary files if import stays on PositionImportTarget). Serial with any agent editing `OutExecutionDelegate` / `InBase`. |

### 6.3 [SEC-SE-U4-003] `importPosition` trusts caller PositionManager and `owner`

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U4-003` |
| **Title** | Allowlist PositionManager and require `owner == msg.sender` (or explicit operator) |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high · **RUNTIME_UNPROVEN** |
| **Catalog IDs** | M1–M3, A0, K1, F |
| **Pattern IDs** | PAT-M-CALL, PAT-A0-EMPTY, PAT-SHARP-FLAG |
| **EVM-audit domain** | general / access-control / erc721 |
| **CROPS pillar** | n/a |
| **Incident theme** | Arbitrary call / fake oracle; empty-vault drain |
| **Products** | Uniswap V4 Standard Exchange |
| **Blast radius** | Single package import + all later mint/burn that read `_deployedAmounts()` from imported PM |
| **Attacker** | **EXT** / **HOS** (fake PM); **INT** (victim approved vault on real PM) |
| **Attack scenario** | **A — fake PM:** 1) Vault `totalSupply()==0` and no managed position. 2) Attacker deploys a PM stub that returns the vault’s real `PoolKey`, attacker-chosen ticks, and huge `getPositionLiquidity`. ERC-721 `transferFrom` succeeds. 3) `importPosition(fakePM, tokenId, 0, attacker, attacker, deadline)` mints `sharesOut = amount0+amount1` from fake liquidity (`_quoteImportedPositionShares` → `_quoteSharesOut` first-mint). 4) `_initializeImportedPosition` stores **fake PM**. 5) Victim zap-in real `rateAsset`: `_totalVaultReserves` = free + **fake deployed** → victim under-minted. 6) Attacker redeems: decrease via fake PM yields no tokens, but `freeOutShare = (free * sharesBurned) / totalSupply` takes almost all sleeve (victim deposit). **B — stolen NFT:** victim `approve(vault, tokenId)` then waits; attacker `importPosition(realPM, tokenId, 0, victim, attacker, deadline)`. |
| **Preconditions** | Empty instance (import gated by `totalSupply()!=0 \|\| _isPositionCreated()`). Fake-PM drain needs a later honest deposit or pre-seeded sleeve. NFT steal needs vault approval. Permissionless `deployVault` / first-action race on a fresh diamond. |
| **Impact** | Dilution / sleeve extract of subsequent depositors; theft of approved position NFT + minted `vaultShare`. |
| **Evidence** | `UniswapV4StandardExchangePositionImportTarget.sol` L24–58: caller `positionManager` / `owner` / `recipient` unchecked vs `msg.sender`; poolKey hash only. `_positionInfo` imported branch (`Common.sol` L218–226) reads `getPositionLiquidity` from stored PM. Vault plan: “Do not use PositionManager for core vault operations” — import is the exception and is unauthenticated. No import adversarial test (only in-session revert harness). |
| **Runtime** | Not run. Hermetic: deploy empty vault; fake PM; import; victim zap-in; attacker zap-out; assert victim residual. |
| **Recommended CODE** | Bind official PM in `PkgInit` / `PkgArgs` (or allowlist). `require(owner == msg.sender)` or `isApprovedForAll` **and** `msg.sender` is owner/operator **of the NFT**, not merely “vault is approved”. Verify `positionManager` codehash / canonical address. Optionally require empty sleeve or include face residual in first-mint quote. |
| **Recommended TEST** | `test_M1_importPosition_fakePoolManager_cannotInflateDeployedOrMint`; `test_M3_importPosition_ownerNotCaller_reverts`; `test_A0_importThenVictimDeposit_attackerCannotTakeSleeve`. `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v4/**' --match-test 'test_M1_importPosition\|test_M3_importPosition'` |
| **Anti-theater** | Must use a **hostile PM contract**, not `mockCall` on the vault. Victim ≠ attacker. Redeem path required for A0. Call **proxy**. |
| **Suggested WP-ID** | `WP-SEC-IMP-U4-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Parallel with E6-share and A0 offset WPs. |

### 6.4 [SEC-SE-U4-004] Empty / tiny supply first mint absorbs residual inventory (no virtual offset)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U4-004` |
| **Title** | Dead-share or virtual-offset first mint so residual `rateAsset`/`pairToken` cannot be drained |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high · **RUNTIME_UNPROVEN** |
| **Catalog IDs** | A0, K1, A1 |
| **Pattern IDs** | PAT-A0-EMPTY, PAT-K-DONATE |
| **EVM-audit domain** | erc4626 / precision-math |
| **CROPS pillar** | n/a |
| **Incident theme** | Empty vault / first deposit drain; ERC-4626 inflation |
| **Products** | Uniswap V4 Standard Exchange |
| **Blast radius** | `_sharesOutForDeposit` / `_quoteSharesOut` first-mint + zap-in execute |
| **Attacker** | **EXT** (after donation or 1-wei seed); **CFG** unsown `deployVault` |
| **Attack scenario** | **A — empty + donate:** 1) `totalSupply==0`; attacker or third party transfers `D` `rateAsset` to the diamond. 2) Attacker `exchangeIn(rateAsset, 1 wei, vaultShare, minOut=0, …, false)`. 3) `_sharesOutForDeposit` hits `totalSharesBefore==0` → `return amount0Added + amount1Added` (**ignores** `reserve0Before` which includes `D`). 4) Attacker owns 100% of supply and redeems `D + 1`. **B — inflation:** attacker first-mints 1 wei (1 share), donates `D`, victim zap-in `X < D` with `minSharesOut=0` → `sharesOut = X * 1 / (D+1) == 0`; `_mint(0)` still `_syncVaultReserves`; victim tokens stay; attacker redeems all. |
| **Preconditions** | Fresh vault or post-exit empty supply; donation or dust first mint. Live T4d path (donation **after** sole holder) is dilution of that holder — different. |
| **Impact** | Loss of donated / leftover sleeve to first minter; victim zero-share deposit. No dead shares / `decimalOffset`. |
| **Evidence** | `UniswapV4StandardExchangeCommon.sol` L518–529 and L989–995. `InBase._executeZapInDeposit` L305–314 uses live totals but first-mint branch ignores residual; `sharesOut < minSharesOut` only if caller set min. Routes / adversarial honest mints use `minSharesOut=0`. T4d (`LocalLiquidBuffer.t.sol` L128–143) only asserts supply unchanged after donation — no redeem. No `test_A0_*` under Uni V4 SE tests. Local-liquid-buffer PRD: share SoT is **all** controlled assets — first-mint formula **drifts**. |
| **Runtime** | Not run. Hermetic: `deployVault`; donate; 1-wei mint; redeem; attacker profit. Second case: 1-wei mint; donate; victim deposit; victim shares == 0. |
| **Recommended CODE** | Virtual offset (ERC-4626-style `S+offset` / `R+1`) **or** mint dead shares at init **or** revert `totalSupply()==0 && free+deployed > amountIn` (force first minter to match residual / go-live seed). Include residual in first-mint quote so shares are backed 1:1 with **total** inventory. Do not mint 0 shares when `amountIn>0`. |
| **Recommended TEST** | `test_A0_donateThenFirstMint_cannotRedeemDonation`; `test_A0_dustShare_donation_victimDeposit_noZeroShareAbsorb`. Pass: attacker net `rateAsset`/`pairToken` ≤ fees; victim shares > 0 or exact revert. `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v4/adversarial/**' --match-test 'test_A0_'` |
| **Anti-theater** | Donator ≠ attacker on the “no steal” case. Must **redeem**. Do not only assert “donation does not mint immediately” (A1 already does). |
| **Suggested WP-ID** | `WP-SEC-A0-U4-001` |
| **Link TCA / prior** | `TCA-SE-UAB-009` is TEST K1 dilution (T4d) — **not** this A0 redeem. |
| **Depends / parallel** | Parallel with E6/import. Same Common file as token pull — do **not** parallel another agent on `UniswapV4StandardExchangeCommon.sol`. |

### 6.5 [SEC-SE-U4-005] I2 / I3 named proofs missing — OWNED_ELSEWHERE (stale STAGE3 close)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U4-005` |
| **Title** | Add I2/I3 proxy proofs on Uni V4 SE (token path) |
| **Severity** | **Medium** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed (tests absent; CODE present) |
| **Catalog IDs** | I2, I3 |
| **Pattern IDs** | PAT-THEATER-PRE (partial — I1 exists) |
| **EVM-audit domain** | erc20 |
| **Products** | Uniswap V4 SE |
| **Blast radius** | Test-only for **pool tokens** (production face-booked `U` looks correct) |
| **Impact** | STAGE3 listed `WP-I-SE-UAB-001` closed; tree has **I1 only**. Regression risk. |
| **Evidence** | `rg test_I2_\|test_I3_` under `test/foundry/spec/protocol/dexes/uniswap/v4` → empty. Adversarial file documents I1 + A–H residual. |
| **Recommended TEST** | As `WP-I-SE-UAB-001` Uni V4 slice: `test_I2_claimedGtU_revertsExactArgs`; `test_I3_residualAfterSync_secondPretransfer_reverts`. |
| **Anti-theater** | Exact selector; no in-call transfer on I3 second call |
| **Suggested WP-ID** | `WP-I-SE-UAB-001` (**no** `sec_fix_*`) |
| **Link TCA / prior** | `TCA-SE-UAB-004`, `TCA-SE-UAB-005`; `WP-I-SE-UAB-001` |

### 6.6 [SEC-SE-U4-006] LiquidReserve J1–J3 incomplete — OWNED_ELSEWHERE (stale STAGE3 close)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U4-006` |
| **Title** | LiquidReserve IFacet + proxy loupe/smoke for all 6 selectors |
| **Severity** | **Medium** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-J-CTRL, PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **Products** | Uni V4 LiquidReserve facet |
| **Blast radius** | Test-only — selectors **are** in `facetCuts_[10]` and `facetFuncs` (not a silent missing money API) |
| **Impact** | Rebalance/view regression can land without declaration tests. Adversarial `_controlSelectors` omits import + liquid reserve. |
| **Evidence** | No `UniswapV4StandardExchangeLiquidReserveFacet_IFacet_Test.t.sol`. `Adversarial_*` J1–J3 only In/Out preview/execute. Coverage `TCA-SE-UAB-007`; STAGE3 `WP-J-SE-UAB-001` claimed closed. |
| **Recommended TEST** | As `WP-J-SE-UAB-001` Uni V4 slice |
| **Suggested WP-ID** | `WP-J-SE-UAB-001` (**no** `sec_fix_*`) |
| **Link TCA / prior** | `TCA-SE-UAB-007`; `WP-J-SE-UAB-001` |

### 6.7 Clustered Medium / Info / ACCEPTED_RISK

| ID | Sev | Class | Summary |
|----|-----|-------|---------|
| **SEC-SE-U4-007** | Info | **ACCEPTED_RISK** | Unbooked face `U` (donation / pre-sync) is claimable by next `pretransferred` (`L-CLAIM-3` / I1 comments L-RSRV-DUST). Invariant: after money route + `_syncVaultReserves`, face booked; **booked** inventory cannot fund I1. |
| **SEC-SE-U4-008** | Medium | **CODE** (NAV hygiene) | `_positionAmounts` is principal-liquidity only (no uncollected V4 fees). Fees realize into face on remove; preview can drift (N2/L1). Not a public skim. |
| **SEC-SE-U4-009** | Medium | **TEST** / sharp | `PkgArgs.poolKey.hooks` can be hostile (CFG N1). Native `currency==address(0)` would break `IERC20.approve` in `initAccount` (init revert — cannot deploy native pools). Document / reject address(0) + non-zero hooks unless product allows. |
| **SEC-SE-U4-010** | Info | **OWNED_ELSEWHERE** / **ACCEPTED_RISK** | Init `approve(Permit2, max)` + Permit2 `approve(PoolManager, max)`. Uni V4 settlement norm. CROPS if PM/Permit2 compromised — not leftover admin on the diamond. |
| **SEC-SE-U4-011** | Medium | **OWNED_ELSEWHERE** | No SE-native fork P0 (`TCA-SE-UAB-011`). Hermetic-first product — not L-SEC-5 High. |
| **SEC-SE-U4-012** | Low | **THEATER** | Routes `test_exchangeIn_zap_pretransferred_true` is push-then-true (durable U happy). I1 exists separately — keep comment; do not count as I1. |
| **SEC-SE-U4-013** | Info | **ACCEPTED_RISK** | Direct swap MEV / spot (B) bounded by `minOut` + deadline. |
| **SEC-SE-U4-014** | Medium | **OWNED_ELSEWHERE** | `_requireNotDisabled` bricks In/Out/rebalance. Exit freeze → `A-manager-fee-registry` / `S-crops-trust`. |
| **SEC-SE-U4-015** | Low | **TEST** | Out zap-out preview adds 1% share buffer (`OutBase` L88–95) — documented N2 slack; no exact preview≡exec on zap-out. |
| **SEC-SE-U4-016** | Info | clean | No leftover `onlyOwner` / `diamondCut` / operator on instance (`test_F1_*`). USAGE fee type registered; **no** usage fee taken on exchange (Info / `A-manager-fee-registry`). |

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| `test_exchangeIn_zap_pretransferred_true` / Out mirror | Real transfer first; proves durable-U happy path only | Keep as H; I1 already separate; add share-path I1 (`SEC-SE-U4-002`) |
| `test_A2_donateSeShares_noFreeMintOrTheft` | Asserts idle inventory; never calls zap-out `pretransferred=true` | Add redeem extract negative |
| `test_T4d_donationDilutesSharePrice` | Honest economic dilution after live shares; not A0 redeem / inflation | `test_A0_*` with redeem |
| IFacet controls copied from Facet | PAT-J-CTRL if both omit (LiquidReserve omitted entirely) | Target/interface-derived + LiquidReserve file |
| Adversarial J `_controlSelectors` (4) | Import + LiquidReserve + `unlockCallback` not smoked | Expand J2–J3 |
| STAGE3 “44/44 closed” for UAB I/J/ADV | I1 + partial A–H/J landed; I2/I3/A0/E6-share/import not | This report’s new CODE WPs + leftover coverage TEST |
| Coverage 2026-08-09 PAT-I-ABS quote | Stale vs current Common body | `SEC-SE-U4-001` Info |

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| `TCA-SE-UAB-001` / `WP-I-CLONE-UAB-001` | Yes — token `_secureTokenTransfer` | **OWNED_ELSEWHERE** — CODE **closed** at this SHA (`SEC-SE-U4-001`) |
| `WP-I-CLONE-001` | Umbrella clone checklist | **OWNED_ELSEWHERE** — Uni V4 token row closed; share-burn was **not** in that WP |
| `TCA-SE-UAB-004/005` / `WP-I-SE-UAB-001` | I1–I3 tests | **OWNED_ELSEWHERE** — I1 landed; I2/I3 still missing (`SEC-SE-U4-005`). No new `sec_fix_*` |
| `TCA-SE-UAB-007` / `WP-J-SE-UAB-001` | LiquidReserve J + ADV J | **OWNED_ELSEWHERE** — money J partial; LiquidReserve IFacet still missing (`SEC-SE-U4-006`) |
| `TCA-SE-UAB-007/008` / `WP-ADV-SE-UAB-001` | A–H residual | **OWNED_ELSEWHERE** — A1/E/H/F present; A0/E6-share/L not in that WP |
| `TCA-SE-UAB-009` | K1 donation | Partial — T4d exists; not A0 redeem. New A0 is **this** program |
| `TCA-SE-UAB-011` | SE fork | **OWNED_ELSEWHERE** Medium |
| `TCA-SE-UAB-002/003/006/008/010` | Aave / router | **Not this area** (`A-se-aave`, `A-se-balancer-v3`) |
| `SEC-COMMON-002` / `WP-SEC-E6-COMMON-001` | `_secureSelfBurn` commons | **Peer class, different files** — Uni V4 share-burn is **new** `WP-SEC-E6-U4-001` |

## 9. Work package stubs

### WP-SEC-E6-U4-001 — Cap zap-out share burn to inbound delta / unused this-call

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-U4-001` |
| **Title** | Share-delta + leftover cap on Uni V4 zap-out |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V4 SE |
| **Finding IDs** | `SEC-SE-U4-002` |
| **Problem** | Out zap-out burns self-held `vaultShare` without proving delivery and refunds leftover self-balance. In zap-out credits `U=balanceOf(this)` because `R(vaultShare)==0`. Two-tx / donation is stealable. |
| **Production files (touch set)** | `UniswapV4StandardExchangeOutExecutionDelegate.sol`; `UniswapV4StandardExchangeOutExecuteTarget.sol`; `UniswapV4StandardExchangeInBase.sol`; optionally `UniswapV4StandardExchangeCommon.sol` (share `U` helper). **Do not** edit `BasicVaultCommon.sol`. |
| **Test files (touch set)** | `test/foundry/spec/protocol/dexes/uniswap/v4/adversarial/Adversarial_UniswapV4SE_SecurePull.t.sol` (or sibling `Adversarial_UniswapV4SE_ShareBurn.t.sol`) |
| **Out of scope files** | DETF/hooks; Aave; commons `_secureSelfBurn`; token I1 (already green) |
| **Depends on** | none (token PAT-I-ABS already closed) |
| **Parallelizable with** | `WP-SEC-IMP-U4-001` if import files only; **not** with A0 if both edit Common |
| **Conflicts with coverage-audit WP** | none (`WP-I-CLONE-UAB-001` was token pull) |
| **Suggested worktree** | `sec_fix_e6-u4` / branch `sec_fix/e6-u4` |
| **Implementation notes** | Copy law from `SEC-COMMON-002` / L-CLAIM-3; `indexedex-adversarial-testing` I1/E6. Out must credit before burn. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v4/adversarial/**' --match-test 'test_I1_exchangeOut_zap\|test_E6_exchangeOut_zap\|test_I1_exchangeIn_zapOut'` exit 0; exploit blocked on **proxy** |
| **Anti-theater checks** | No in-call share transfer on I1; leftover ≠ all self-balance; exact selector |
| **Proof-first?** | yes (High CODE was RUNTIME_UNPROVEN) |
| **Estimate** | M |

### WP-SEC-IMP-U4-001 — Authenticate position import

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-IMP-U4-001` |
| **Title** | Allowlist PositionManager; bind NFT owner to caller |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V4 SE |
| **Finding IDs** | `SEC-SE-U4-003` |
| **Problem** | `importPosition` takes arbitrary `positionManager` and `owner`. Fake PM inflates deployed NAV; approved NFT can be imported to attacker `recipient`. |
| **Production files (touch set)** | `UniswapV4StandardExchangePositionImportTarget.sol`; `UniswapV4StandardExchangeDFPkg.sol` (`PkgInit`/`PkgArgs` bind); optionally `UniswapV4PositionRepo.sol` |
| **Test files (touch set)** | new adversarial import tests under `test/foundry/spec/protocol/dexes/uniswap/v4/adversarial/` |
| **Out of scope files** | In/Out zap math; hooks |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-E6-U4-001`, `WP-SEC-A0-U4-001` if A0 does not need import files |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_imp-u4` / branch `sec_fix/imp-u4` |
| **Implementation notes** | Crane CREATE3 still for facets; bind canonical PM like `POOL_MANAGER`. Skills: `ethskills-security` (untrusted input), catalog M. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v4/**' --match-test 'test_M1_importPosition\|test_M3_importPosition\|test_A0_importThen'` |
| **Anti-theater checks** | Hostile PM contract, not `mockCall` on SUT; proxy call |
| **Proof-first?** | yes |
| **Estimate** | M |

### WP-SEC-A0-U4-001 — First-mint residual / inflation offset

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-A0-U4-001` |
| **Title** | First mint cannot absorb residual inventory; block zero-share deposits |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V4 SE |
| **Finding IDs** | `SEC-SE-U4-004` |
| **Problem** | `totalShares==0` → shares = `amount0+amount1` ignoring residual; no virtual offset; `minSharesOut=0` mints 0 and keeps victim assets. |
| **Production files (touch set)** | `UniswapV4StandardExchangeCommon.sol` (`_sharesOutForDeposit`, `_quoteSharesOut`); `UniswapV4StandardExchangeInBase.sol` (`_executeZapInDeposit`); optionally DFPkg init dead shares |
| **Test files (touch set)** | adversarial `test_A0_*` |
| **Out of scope files** | Import PM allowlist (unless first-mint quote also used there — coordinate) |
| **Depends on** | none; **serial** with any other Common.sol editor |
| **Parallelizable with** | `WP-SEC-IMP-U4-001` (if import-only files) |
| **Conflicts with coverage-audit WP** | none (TCA-SE-UAB-009 is T4d TEST) |
| **Suggested worktree** | `sec_fix_a0-u4` / branch `sec_fix/a0-u4` |
| **Implementation notes** | ERC-4626 virtual offset or dead shares. Product law: share SoT = free+deployed. Do not require exact-delta grief on token `U` (L-CLAIM-3). |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v4/adversarial/**' --match-test 'test_A0_'` |
| **Anti-theater checks** | Redeem required; donator ≠ attacker; victim shares ≠ 0 or revert |
| **Proof-first?** | yes |
| **Estimate** | M |

Coverage leftovers stay on `gap_cover_*` / existing WP-I/J/ADV IDs — **do not** schedule `sec_fix_*`.

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Note |
|------|-------|------|
| Token-side PAT-I-ABS | closed / OWNED_ELSEWHERE | Face-booked `U`; I1 green |
| Donation `U` absorb (live, booked face) | **ACCEPTED_RISK** | L-CLAIM-3; I1 comments; T4d if unused |
| Direct-swap MEV | **ACCEPTED_RISK** | `minOut` + deadline |
| Public rebalance | **ACCEPTED_RISK** / F5-safe | No surplus to caller |
| Infinite Permit2 / PM allowance | **ACCEPTED_RISK** | Uni V4 settle |
| Instance leftover admin | clean | No owner / `diamondCut` |
| Registry disable / fee-oracle liquid % | **OWNED_ELSEWHERE** | `A-manager-fee-registry` |
| ERC2612 / O | **N/A** | Crane facet |
| I5 Permit2 witness | **N/A** | `A-routers-permit2` |
| DETF / hooks | out of allowlist | Other areas |
| SE-native fork | DEFER / OWNED_ELSEWHERE Medium | Hermetic-first |
| Uncollected V4 fees in NAV | Medium hygiene | Realize on remove |
| USAGE fee unused on exchange | Info / manager | Type id exists for liquid % only |
| `via_ir` | forbidden | none recommended |
| Runtime forge | not executed | L-SEC-3 → High max; proof-first on new CODE WPs |

## 11. Commands run

```text
# Inventory
ls contracts/protocols/dexes/uniswap/v4/
ls test/foundry/spec/protocol/dexes/uniswap/v4/

# Pattern hunt (allowlisted production + tests)
rg -n '_secureTokenTransfer|_securePull|_secureSelfBurn|_refund|pretransferred|onlyOwner|onlyOperator|diamondCut|facetFuncs|importPosition|rebalanceLiquidReserve|_syncVaultReserves|_deployedAmounts|_sharesOutForDeposit' \
  contracts/protocols/dexes/uniswap/v4 test/foundry/spec/protocol/dexes/uniswap/v4

rg -n 'test_I[12345]_|test_K1_|test_A0_|test_E6_|test_F5_|test_L[123]_|LiquidReserveFacet_IFacet' \
  test/foundry/spec/protocol/dexes/uniswap/v4

# Collision WPs
rg -n 'WP-I-CLONE-UAB-001|WP-I-SE-UAB-001|WP-ADV-SE-UAB-001|WP-J-SE-UAB-001|WP-I-CLONE-001|TCA-SE-UAB' \
  docs/testing/coverage-audit

# No forge / via_ir this run (static Stage 1; monorepo compile 20–40+ min).
# I1 existing tests are the static substitute for refusing Critical on token PAT-I-ABS.
```

Skills walked: `crane-adversarial-testing` (A–K + A0/L/M/N/O + E6/F5 + J bar + I delta bar); `indexedex-adversarial-testing` (SE mapping); `ethskills-security` (inflation, approve, delegatecall); `defi-incident-patterns` (theme map). Normative: PRD §2, §2.4, §3.8, §5–8, §19 L-SEC-2/3/4/9/10/11/14.
