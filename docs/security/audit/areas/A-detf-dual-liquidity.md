# Security Audit — A-detf-dual-liquidity

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · MODE=full · `A-detf-dual-liquidity` |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**` |
| Test paths | `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**` (incl. `adversarial/`); hermetic: `*MathLib.t.sol` only; outer `test/**/standardExchange/single/*DualLiquidity*` is **REFERENCE only** (owned by `A-detf-single-se`) |
| Skills cited | `SECURITY_AUDIT_PRD` §2, §2.4, §3.8, §5–8, §19 **L-SEC-5**; `crane-adversarial-testing`; `indexedex-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `defi-incident-patterns`; family PRD `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/DualLiquidityLinkedCrossVersionUniswapVault_PRD.md`; seed `docs/testing/coverage-audit/areas/T-detf-dual-liquidity.md`; blast `areas/A-commons-pull.md` §2.2.B |
| Residual-risk scores | DualLiquidityLinkedCrossVersionUniswapVault → **2** |
| Forge | **Not run** (fork-first; L-SEC-3 / orchestrator owns runtime). Static re-verify of production + fork tests only. Coverage-audit `repro/TCA-DETF-DL-001/notes.md` is **stale** (quotes the pre-fix no-op `_receive`). |

---

## 1. Executive summary

- **Residual-risk:** DualLiquidityLinkedCrossVersionUniswapVault **2** — money path reviewed; historical PAT-I-ABS **steal is closed** at this SHA; leftover High CODE is **A0** (1:1 genesis captures idle `reserveBpt`) plus **same-tx pretransfer vs documented two-tx / Permit2** (funds can stick; not free-mint of booked inventory). Fork I/K tests exist by name but assume a durable `R` hold-set this package never writes.
- **Critical / High counts:** **Critical 0**. **High 3** — `SEC-DETF-DL-003` (CODE, same-tx vs documented two-tx/Permit2), `SEC-DETF-DL-004` (CODE, A0), `SEC-DETF-DL-005` (TEST, I/K honesty / PAT-THEATER-PRE). No leftover `diamondCut` / `owner()` on the live instance (L-SEC-11 statically clean).
- **PAT-I-ABS re-verify (must classify honestly):** Pilot `A-commons-pull` §2.2.B is **correct**. `_receive` / `_receiveOut` are **same-tx inbound-delta** (`before = balanceOf`; `pretransferred=true` requires `claimed <= observedDelta`; else `TransferDeltaInsufficient`). **I1-safe if there is no in-call push. Two-tx pretransfer fails.** This is **not** the 2026-08-09 no-op / absolute-held body. ShareInflation remains **A3-class only** — do not count as I/K.
- **Top recommended WPs (this program):**
  1. `WP-SEC-DETF-DL-A0-001` — gate 1:1 genesis so idle `reserveBpt` cannot be first-minter drained; add `test_A0_*` (High CODE+TEST).
  2. `WP-SEC-DETF-DL-DELTA-001` — product-owner pick: durable `U = B − R` (L-CLAIM-3) **or** keep same-tx and rewrite Permit2 / NestedPush / ExactOut surplus tests (High CODE or NEEDS_OWNER).
  3. `WP-SEC-DETF-DL-I-HONESTY-001` — rewrite fork I1–I3/K1 so they do not require `commonToken ∈ vaultTokens()` / end-sync `R==B` (High TEST; L-SEC-5).
- **OWNED_ELSEWHERE count:** **6** linked TCA/WP touch-sets (`SEC-DETF-DL-001`, `002`, `007`, `008`, `009`, `010`). **Do not** schedule competing `sec_fix_*` for the closed steal on `_receive` / `_receiveOut` (`WP-I-DETF-DL-001`) or for J (`WP-J-DETF-DL-001`).
- **Bond/claim:** **N/A** (verified). Family PRD: “No bonding/underwriting machinery of any kind.” No NFT / `sellNFT` / `redeemClaim` in the package. **D2–D6 and F2–F3 bond NFT = N/A.**
- **L-SEC-5:** Fork-first product. Missing/untrustworthy fork P0 (A0, honest I/K) stays **High**, not Medium.

---

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|---------------|
| **DualLiquidityLinkedCrossVersionUniswapVault** | `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol`; Targets: ExchangeIn, ExchangeInQuery, ExchangeOut, ExchangeOutQuery; Common + Repo + MathLib; Facets: ExchangeIn / InQuery / Out / OutQuery + ERC20 / ERC2612 / ERC5267 / MultiAsset Basic + Standard (9 cuts) | `TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol` — Base-fork gold (`TestBase_BaseFork` + IndexedexTest) | **Gold fork path.** CREATE3 Facet/Pkg factories + `indexedexManager.deployVault` / registry. Live Uni V4 + Uni V2 + Balancer V3 on Base. **Never** mock SUT. Hermetic full product **absent** (intentional). | **2** |

Product class (P0 subset): **Standard Exchange vault** (implements `IStandardExchangeIn` / `Out`). Pro-rata `reserveBpt` share diamond. Family PRD: **not** a true DETF — layout co-location only. No mint/burn thresholds, no bond NFT, no rebasing claim.

### 2.1 Production file inventory

| Path | Role |
|------|------|
| `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol` | Registry-gated `processArgs`; 9 `facetCuts`; deploys 3 SE legs + weighted `reservePool`; `MultiAssetBasicVaultRepo._initialize([self, vaultA, vaultB, pairVault, reservePool])` |
| `…ExchangeInTarget.sol` | `exchangeIn` deposit / redeem / swap; **`_receive` same-tx delta** |
| `…ExchangeInFacet.sol` | `facetFuncs` → `exchangeIn` only |
| `…ExchangeInQueryTarget/Facet.sol` | `previewExchangeIn` |
| `…ExchangeOutTarget.sol` | `exchangeOut`; **`_receiveOut` same-tx delta; no surplus refund** |
| `…ExchangeOutFacet.sol` | `facetFuncs` → `exchangeOut` only |
| `…ExchangeOutQueryTarget/Facet.sol` | `previewExchangeOut` |
| `…Common.sol` | share mint/burn vs `reserveBpt`; join/exit; residual sweep to `feeTo` |
| `…Repo.sol` | slot `keccak256("vault.protocol.uniswap.crossVersion.dual-liquidity-linked.repo")` |
| `…MathLib.sol` | pro-rata share math; **1:1 when `totalShares==0 \|\| totalBpt==0`** |
| `*_FactoryService.sol` | CREATE3 helpers |

### 2.2 Trust-flag entrypoints (I-applicable)

| Entrypoint | Flag | Behavior at this SHA |
|------------|------|----------------------|
| `exchangeIn` deposit (non-BPT) | `pretransferred_` | `_receive`: snapshot `balanceOf`; pull only if `false`; if `true` require `amountIn <= observedDelta` else `TransferDeltaInsufficient(amountIn, observedDelta)` |
| `exchangeIn` swap | `pretransferred_` | same `_receive` |
| `exchangeIn` redeem (`kindIn=Shares`) | ignored | `_burnSharesForBpt` from `msg.sender` (no pretransfer credit) |
| `exchangeIn` **reserveBpt** deposit | `pretransferred_=true` | **reverts** `UnsupportedRoute` (intentional; mint uses pre-transfer `totalReserveBpt`) |
| `exchangeOut` deposit/swap (non-BPT) | `pretransferred` | `_receiveOut`: same same-tx delta; **credits claimed `amountIn` only; does not refund `held − amountIn`** |
| `exchangeOut` reserveBpt | `pretransferred=true` | **reverts** `UnsupportedRoute` |
| Nested `_legExchange` | `true` on **leg** | DualLiquidity `safeTransfer`s into the leg then calls leg `exchangeIn/Out(..., true)`. Legs are durable-`U` peers (commons blast). This is **not** DualLiquidity’s own pull. |
| `previewExchangeIn/Out` | N/A | views |

**Honest pull classification (vs commons §2.2.B):**

| Law | DualLiquidity |
|-----|---------------|
| L-CLAIM-3 durable `U = B − R` | **Not implemented.** Package never calls `MultiAssetBasicVaultRepo._updateReserve`. Hold-set is `[self, vaultA, vaultB, pairVault, reservePool]` — **not** `commonToken` / `tokenA` / `tokenB`. |
| Same-tx inbound-delta | **Live.** I1 (no in-call push) reverts `TransferDeltaInsufficient(claimed, 0)`. Two-tx push-then-call also reverts. |
| Historical PAT-I-ABS (`if (pretransferred) return`) | **Gone.** |

### 2.3 Facet surface (J)

| Facet | `facetFuncs` |
|-------|----------------|
| ExchangeIn | `IStandardExchangeIn.exchangeIn` |
| ExchangeInQuery | `IStandardExchangeIn.previewExchangeIn` |
| ExchangeOut | `IStandardExchangeOut.exchangeOut` |
| ExchangeOutQuery | `IStandardExchangeOut.previewExchangeOut` |
| + MultiAsset / ERC20 stack | vault views, ERC20 / 2612 / 5267 |

No PAT-J-OMIT on the money API (static). Fork `test_J1_*` / `test_J2_*` / `test_J3_*` exist on the **proxy**.

### 2.4 Test roots (fork-first)

| Root | Role | Notes |
|------|------|-------|
| `TestBase_DualLiquidity…Vault.sol` | Gold fork TestBase | Permit2 helpers; bootstrap; production DFPkg |
| `*_Deposits/Redemptions/Swaps/ExactOut*.t.sol` | H + preview≡execute | Strong H/P; `test_depositPretransferred_pushThenTrue_succeeds` assumes **durable U** |
| `*_Guards.t.sol` | N (minOut, deadline, recipient) | Some exact selectors |
| `*_ShareInflation.t.sol` | **A3-class** BPT donation | **Not I/K**; no `test_A0_*` |
| `*_Reentrancy*.t.sol` | C `IsLocked` | Exact selector; hostile `tokenB` fixture (not mock SUT) |
| `*_Residual.t.sol` | E residual → `feeTo` | |
| `*_Immutability.t.sol` / `*DFPkg_Registry.t.sol` | F1 / no `diamondCut` | |
| `*_RateExtremes.t.sol` / `*_BestRoute.t.sol` | B-ish | |
| `*_Invariants.t.sol` / `*_InvariantHandler.t.sol` | L2 sequences | L3 Foundry runner deferred (RPC) |
| `*_Permit2*.t.sol` | Prefund then `pretransferred=true` | **Would revert** under same-tx `_receive` |
| `*_NestedPush.t.sol` | T-NEST + T-LOCAL-PUSH | Mix of I1-negative and durable-U-positive |
| `adversarial/Adversarial_DualLiquidity_Catalog.t.sol` | I1–I3, K1, J1–J3, weak H3/F1 | I/K setup requires `commonToken` on hold-set |
| `adversarial/DualLiquidity_ADVERSARIAL_CATALOG.md` | ID map | Still claims **IMPLEMENTED (P0)**; does not mention I/J |
| `*MathLib.t.sol` | Hermetic pure + `testFuzz_roundTrip_neverProfits` | Only hermetic product-adjacent suite |
| Outer `SingleStandardExchangeDETF_DualLiquidityMatrix.t.sol` | DualLiquidity as `underlyingVault` | **Out of area** (`A-detf-single-se`) |

---

## 3. Threat models

**Product:** DualLiquidityLinkedCrossVersionUniswapVault (unowned SE-style diamond). Role names: `commonToken`, `tokenA` / `tokenB` (`pairToken` legs), `vaultAShare` / `vaultBShare` / `pairVaultShare`, `reserveBpt`, `detfToken` = `address(this)`.

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn(..., pretransferred=true)` no transfer | `commonToken` / `tokenA` / `tokenB` / leg `vaultShare` → `detfToken` or swap out | `pretransferred` | none | **Blocked** — `TransferDeltaInsufficient(claimed, 0)`. Historical free mint **closed**. |
| EXT / CFG | Tx1 transfer-to-diamond; Tx2 `pretransferred=true` | same | `pretransferred` | none | Tx2 reverts. Tx1 inventory **sticks** on the diamond (sweep treats it as resting). Permit2 TestBase / NestedPush / ExactOut surplus paths document this as the happy path. **High grief / stuck funds.** |
| CAP | Donate `reserveBpt` while `totalSupply==0`, then 1-wei BPT `exchangeIn` | idle `reserveBpt` | `pretransferred=false` (BPT true is forbidden) | none | First minter 1:1 (`MathLib` short-circuit on `totalShares==0`) owns 100% and redeems donated + own BPT. **A0.** |
| CAP | Donate `reserveBpt` after live | `reserveBpt` | n/a | none | A3: inflation; victim not zeroed (ShareInflation). Donation enriches remaining holders. |
| CAP | Donate `commonToken` then `pretransferred=true` | donated face | `pretransferred` | none | **No free credit** (same-tx delta 0). Donation sits; later `_sweepResidual` does **not** pay it to the caller (snapshot includes it). |
| EXT | `exchangeOut` surplus refund | leftover `tokenIn` | `pretransferred` + `maxIn > used` | none | CODE does **not** refund `held − amountIn` (that theft class is closed). In-call leftover above snapshot → `feeTo`. Tests that assert caller refund are stale. |
| HOS | Hostile `tokenB` `transferFrom` reenters `exchangeIn`/`exchangeOut` | route tokens | pull path | none | **Blocked** — `IsLocked` (shared lock). |
| INT | Permit2 prefund then `true` | face tokens | Permit2 + flag | Permit2 | Same as two-tx: revert; if prefund was a prior tx, inventory sticks. No local ecrecover on DualLiquidity money API. |
| INT | Nested `_legExchange` | face → leg | `true` on leg | leg durable U | Works when DualLiquidity pushes in-call then claims on the **leg**. Not a DualLiquidity I1 hole. |
| ADM | Registry `setVaultAddressDisabled` / package disable | all mutating routes incl. redeem | n/a | manager/registry | Exit freeze. Check uses `StandardVaultRepo._feeOracle()` as `IVaultRegistryDisableQuery` — valid because `PkgInit.feeOracle` is the manager diamond. **CROPS-C; manager-owned.** |
| ADM | Fee oracle `usageFeeOfVault` / `feeTo` | new mint fee slice | n/a | fee oracle | Economic; cannot seize existing `reserveBpt` directly. Exact-out `_grossUpShares` DoS if `feeWad >= 1e18`. |
| CFG | `PkgArgs.useRateProviders` / weights | mark / join math | deploy-time | none | Wrong choice → abandon instance (immutable). |
| CFG | `recipient=address(0)` | minted `detfToken` | n/a | none | Self-grief burn to zero. |
| EXT | `diamondCut` / `owner()` | upgrade / custody | n/a | none | Selectors **absent**. |

---

## 4. Catalog matrix (A–O, E6, F5)

| ID | Product | F/P/G/N/A/VULN | Evidence |
|----|---------|----------------|----------|
| **A0** | DualLiquidity | **VULN** | `MathLib._sharesForBpt` returns `bptIn` when `totalShares==0` even if `totalBpt>0`. No dead shares. No `test_A0_*`. `SEC-DETF-DL-004`. |
| **A1** | DualLiquidity | **P** | Idle non-BPT inventory is not credited (same-tx). No dedicated multi-asset donate suite. |
| **A3** | DualLiquidity | **F** | `test_bptDonation_cannotStealVictimDeposit`, `test_frontRunDonation_doesNotZeroVictim`. **Not I/K.** |
| A2 / A4–A5 | DualLiquidity | **N/A** / **DEFER** | No claim token; P2 dust. |
| **B** | DualLiquidity | **P** | `*_RateExtremes`, `*_BestRoute`. No synthetic mint/burn gates (N/A). Spot-routed hops are aggregator, not a TWAP oracle. |
| **C1–C3** | DualLiquidity | **F** | `test_reentrancy_exchangeIn_deposit_revertsIsLocked`, cross-function `exchangeOut`, redeem reentry — exact `IsLocked`. |
| **D2–D6** | DualLiquidity | **N/A** | No bond/claim NFT (PRD + package inventory). |
| **E1** | DualLiquidity | **P** / **F** | Invariants deposit→BPT redeem never profits; residual suites; fee non-dilution. |
| **E5** | DualLiquidity | **F** / **P** | Zero / deadline / minOut; some bare `expectRevert`. |
| **E6** | `_sweepResidual` | **F** (not attacker extract) | Sweeps `current − snapshot` to **`feeTo`**, not caller. Protects pre-call inventory. |
| **E6** | `_receiveOut` surplus | **F** (theft closed) | No `held − amountIn` refund. Documented unused-input refund to caller is **absent**. |
| **F1** | DualLiquidity | **F** / **P** | Immutability + registry: no `diamondCut` / `owner()`. Catalog `test_F1_diamondCut_notCallable` is a low-level call. |
| F2–F3 | DualLiquidity | **N/A** | No onlyOwner inventory NFT. |
| **F5** | DualLiquidity | **N/A** | No permissionless migrate/resize/reclaim. |
| **G** | DualLiquidity | **P** | Product **is** a 3-leg composition. Outer Single-SE-over-DualLiquidity owned by `A-detf-single-se`. |
| **H2** | DualLiquidity | **N/A** | No claim redeem. |
| **H3** | DualLiquidity | **S** / **P** | Catalog H3 is zero-amount + `tokenIn=address(0)` + bare revert. Stronger residual after success in `*_Residual.t.sol`. |
| **I1** | DualLiquidity CODE | **F** (same-tx) | No in-call push ⇒ `observedDelta=0` ⇒ revert. Steal closed. |
| **I1** | DualLiquidity TEST | **P** / **S** | Named `test_I1_*` exist but `_requireCommonInHoldSet` / `_bookCommonResidual` assume `commonToken ∈ vaultTokens()` and `R==B` end-sync — **false** on this package. Happy `pushThenTrue` is PAT-THEATER-PRE vs same-tx. |
| **I2** | DualLiquidity | **P** | Same-tx: I2 collapses to I1 (`delta=0`). Named tests share the broken hold-set setup. |
| **I3** | DualLiquidity | **P** | Residual cannot fund a second free pretransfer (same-tx). Setup still assumes booked `R`. |
| I4 | DualLiquidity | **G** / **DEFER** | FoT on Base legs uncommon; `!pretransferred` credits claimed `amountIn` after `transferFrom`, not pull-delta. |
| I5 | DualLiquidity | **P** / **N/A** | No DualLiquidity signature verify. Permit2 is a test prefund helper. Router/Permit2 area owns I5. |
| **J1** | DualLiquidity | **F** | `test_J1_facetFuncs_coversTargetApi` from `IStandardExchangeIn/Out`. Facet splits match Targets. |
| **J2** | DualLiquidity | **F** / **P** | `test_J2_proxyLoupe_allProductSelectors` on production proxy. Not a full loupe map of MultiAsset/ERC20. |
| **J3** | DualLiquidity | **P** | Proxy smoke of previews + money path (bare revert on zero amount). H already exercises live money selectors. |
| **K1** | DualLiquidity CODE | **F** (steal) | Donation + `pretransferred=true` does not free-credit (same-tx). |
| **K1** | DualLiquidity TEST | **P** / **S** | `test_K1_*` uses hold-set bookkeeping this SUT does not perform. ShareInflation ≠ K1. |
| **L1** | DualLiquidity | **P** | MathLib fuzz + residual sweep. No public skim of `reserveBpt`. |
| **L2** | DualLiquidity | **G** / **DEFER** | FoT not a product claim. |
| **L3** | DualLiquidity | **P** | Rate/route stress; L2 sequences; no Foundry L3 runner (fork defer). |
| **M1–M3** | DualLiquidity | **N/A** | Legs / router from storage. No user `target+calldata`. |
| **N1** | DualLiquidity | **N/A** | No untrusted hook between quote and settle on this diamond. |
| **N2** | DualLiquidity | **P** | Strong preview≡execute on many routes; multi-hop documented sub-bps drift (`assertApproxEqAbs`). |
| **O1–O3** | DualLiquidity | **P** | ERC-2612 on `detfToken` (Crane permit); suite exists. No DualLiquidity ecrecover on money in. |
| **PAT-I-ABS** | DualLiquidity | **F** (closed) | Same-tx body. `SEC-DETF-DL-001/002` OWNED_ELSEWHERE. |
| **PAT-THEATER-PRE** | DualLiquidity | **VULN** (tests) | Happy prefund + `true` still presented as success. `SEC-DETF-DL-005`. |
| **PAT-E6-REFUND** | DualLiquidity | **F** (caller theft closed) | Sweep to `feeTo`; `_receiveOut` does not pay `balance − floor` to caller. |
| **PAT-A0-EMPTY** | DualLiquidity | **VULN** | `SEC-DETF-DL-004`. |
| **PAT-CROPS-ADMIN** | DualLiquidity | **F** (instance) | Unowned; no cut. Registry disable is manager-owned. |
| **PAT-SPEC-DRIFT** | DualLiquidity | **VULN** | Tests + some NatSpec claim durable `U` / unused-input refund; CODE is same-tx + feeTo dust. |
| **PAT-SHARP-FLAG** | DualLiquidity | **P** | Flag is caller-supplied (not default-true). Integrators following TestBase two-tx will revert / stick funds. |
| **PAT-SLOT** | DualLiquidity | **F** (static) | Unique family slot; MultiAsset uses `indexedex.vaults.basic`; ERC20 / EIP712 / Balancer aware repos are Crane-standard. |
| **PAT-MOCK** | DualLiquidity | **F** | Fork real packages. `ReentrantMockERC20` is a hostile fixture, not a mock SUT. |

**P0 SE subset:** C / E5 / F1 / H / P / J strong-partial; **I1 CODE F**, **I TEST P/S**; **K1 CODE F**, **K TEST P/S**; **A0 VULN**; H3 theater.

---

## 5. Domain notes

Walked as hunt lists (not a second ID space):

| Domain / skill | Walked on | Notable hits |
|----------------|-----------|--------------|
| **general / erc20** | `_receive`, `_receiveOut`, `_sweepResidual`, SafeERC20 vs raw `transferFrom` on BPT | Same-tx I1-safe. BPT path uses raw `transferFrom` (Balancer BPT returns bool). |
| **precision-math** | `MathLib` 1:1 short-circuit; `_ceilDiv`; `_sharesForBptUp` +1 | A0 1:1 ignores idle `reserveBpt`. Exact-out over-burns 1 share unit. |
| **erc4626** | Share/asset ratio vs `reserveBpt` | Not ERC-4626; same inflation class (A0/A3). No virtual offset. |
| **defi-amm** | Best-of routes; `_swapThrough` `minOut=0`; join `minBpt=0` | Intermediate hops rely on outer `minAmountOut`. Sandwich of nested hops is user-slippage, not free mint. |
| **proxies / PAT-SLOT** | 9 cuts; unique repo slot; MultiAsset init set | J1–J3 present. Hold-set ≠ face tokens. |
| **access-control / CROPS** | Unowned; registry disable; fee oracle | Disable bricks redeem (`_requireActive` → `_requireNotDisabled`). Manager-owned. |
| **dos** | `ReservePoolNotInitialized` until bootstrap; feeWad=1e18 exact-out div-by-zero | Inert deploy is intentional. |
| **flashloans** | CAP donate + first mint; CAP route skew | A0 does not need a flash loan if 1 wei `reserveBpt` is obtainable. |
| **signatures** | ERC-2612 share permit; Permit2 only in tests | O on share permit; I5 not on this SUT. |
| **sharp-edges** | `pretransferred`; Permit2 helper; `PkgArgs.useRateProviders` default false | Two-tx presented as canonical nested/router path in Deposits/NestedPush NatSpec. |
| **spec-compliance** | Family PRD vs CODE | PRD: unused-input refund, residual not stranded, 1:1 first deposit, no dust lock, no bond/claim. CODE: unused input not refunded to caller; dust to `feeTo`; 1:1 genesis enables A0; no NFT. |
| **incident themes** | `defi-incident-patterns` | Empty-vault first deposit → A0. Trust-flag free mint → I1 (closed on CODE). Surplus-refund `balance−floor` → E6 (caller theft closed). Donation inflation → A3 (tested). |
| **ethskills-security** | Reentrancy, inflation, SafeERC20, MEV minOut, no upgrade admin | C + F1 clean. A0 matches “vault inflation / first depositor”. `_swapThrough` minOut=0 is the MEV checklist hit. |

---

## 6. Findings

### 6.1 [SEC-DETF-DL-001] Historical PAT-I-ABS on `_receive` — closed at this SHA

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-DL-001` |
| **Title** | Historical no-op `_receive` free mint is closed (same-tx delta) |
| **Severity** | **Info** (historical Blocker; not live) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3, K1 |
| **Pattern IDs** | PAT-I-ABS (historical) |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | Trust-flag free mint |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Blast radius** | Single package |
| **Impact** | None at `1e0d7c48` for booked-inventory free mint. Pre-fix: credit claimed `amountIn` from sitting `commonToken` / `tokenA` / `tokenB` / leg `vaultShare`. |
| **Evidence** | `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget.sol` L464–485: snapshot `before_`; `!pretransferred` `transferFrom`; `observedDelta = balanceOf − before_`; `pretransferred && amountIn > observedDelta` → `ISecurePullErrors.TransferDeltaInsufficient`. Coverage repro `docs/testing/coverage-audit/repro/TCA-DETF-DL-001/notes.md` still quotes the **old** no-op body — **stale**. Gap-closure `WP-I-DETF-DL-001` / commit `29e3598` (`STAGE3_PROGRESS.md`). |
| **Runtime** | Not re-run. Static body is sufficient to refuse a new Critical steal. Label historical runtime **stale**. |
| **Recommended CODE** | none for PAT-I-ABS steal |
| **Recommended TEST** | Keep an I1 that does **not** transfer in-call; do not require MultiAsset `R` (see `SEC-DETF-DL-005`) |
| **Anti-theater** | I1 must not transfer; must not treat ShareInflation as I |
| **Suggested WP-ID** | none (`sec_fix_*` skip) |
| **Link TCA / prior** | `TCA-DETF-DL-001`; `WP-I-DETF-DL-001` |
| **Depends / parallel** | n/a |

### 6.2 [SEC-DETF-DL-002] Historical `_receiveOut` donation refund theft — closed

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-DL-002` |
| **Title** | Historical `_receiveOut` `held − amountIn` refund theft is closed |
| **Severity** | **Info** (historical Blocker; not live) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | I1, E6, K1 |
| **Pattern IDs** | PAT-I-ABS, PAT-E6-REFUND (historical) |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | Surplus-refund / public reclaim |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Blast radius** | Single package |
| **Impact** | None at this SHA for “treat entire `balanceOf` as caller prefund and refund the rest.” |
| **Evidence** | `…ExchangeOutTarget.sol` L359–378: same-tx delta; NatSpec explicitly forbids `held − amountIn`. `_sweepResidual` (`…Common.sol` L580–597) sends **in-call growth above snapshot** to `feeTo`, not `msg.sender`. |
| **Runtime** | Not run. Static. |
| **Recommended CODE** | none for the theft class |
| **Recommended TEST** | I1 exact-out no-transfer (honest setup; see 005) |
| **Anti-theater** | Do not count `test_exactOutMatrix_swap_pretransferredRefundsSurplus` as I1 |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | `TCA-DETF-DL-002`; `WP-I-DETF-DL-001` |
| **Depends / parallel** | n/a |

### 6.3 [SEC-DETF-DL-003] Same-tx delta vs documented two-tx / Permit2 / durable U

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-DL-003` |
| **Title** | Decide DualLiquidity delta law; same-tx breaks documented two-tx prefund and can stick inventory |
| **Severity** | **High** |
| **Class** | **CODE** (or **NEEDS_OWNER** if product keeps same-tx as the family split) |
| **Confidence** | static-high · **RUNTIME_UNPROVEN** |
| **Catalog IDs** | I1–I3, E6, N2 |
| **Pattern IDs** | PAT-SPEC-DRIFT, PAT-SHARP-FLAG, PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | P (exit of mistakenly prefunded inventory) |
| **Incident theme** | Trust-flag / stuck inventory (not free mint) |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Blast radius** | Single package + any router / Permit2 integrator that prefills then calls `true` |
| **Attacker** | **CFG** / **INT** (follows TestBase / PRD / Permit2 helper); not EXT free-mint |
| **Attack scenario** | 1. Integrator or user transfers `commonToken` / `tokenA` / `tokenB` to the diamond (Permit2 AllowanceTransfer or ERC20 `transfer`) in **tx1**, matching `TestBase._permit2PrefundVault` and `test_depositPretransferred_pushThenTrue_succeeds`. 2. Tx2: `exchangeIn` / `exchangeOut(..., pretransferred=true)`. 3. `_receive` / `_receiveOut` snapshots `balanceOf` **after** the tokens already sit; `observedDelta=0`; reverts `TransferDeltaInsufficient(amountIn, 0)`. 4. Tx1 tokens remain. Later honest routes snapshot them as resting; `_sweepResidual` will not return them to the original sender. 5. Same-tx multicall `transfer` then `exchangeIn(true)` also reverts (snapshot is inside `_receive`, after the transfer). Only `pretransferred=false` + `transferFrom` works. |
| **Preconditions** | User/integrator uses the documented two-tx or Permit2-prefund path. Atomic `!pretransferred` pull is safe. |
| **Impact** | Significant loss of the user’s own prefunded face tokens (stuck on an unowned diamond). **Not** unbounded extract of other holders’ `reserveBpt`. Permit2 / NestedPush surplus-refund / ExactOut matrix tests describe a refund that CODE does not implement (`_receiveOut` never pays `maxIn − used` to `msg.sender`). |
| **Evidence** | `_receive` L471–485; `_receiveOut` L364–378. Contrast Deposits L110–122 (`pushThenTrue` “durable U”); NestedPush `test_T_LOCAL_PUSH_transferToDetf_true_whenClaimedLeU` L188–198; NestedPush T-NEST-5/8 L105–184 (`_permit2PrefundVault` then `true`, assert unused refunded to user); Permit2 suite prefund + `true`; ExactOutMatrix `test_exactOutMatrix_swap_pretransferredRefundsSurplus`. Commons §2.2.B already listed this package as same-tx. L-CLAIM-3 / MultiVault / BasicVaultCommon are durable `U = B − R`. DualLiquidity **never** `_updateReserve`. `IBasicVault.vaultTokens()` = `[self, vaultA, vaultB, pairVault, reservePool]` (`DFPkg.sol` L425–434). |
| **Runtime** | Not run. Proof-first: one fork test that transfer-then-`true` **reverts** and one that `!pretransferred` still mints. |
| **Recommended CODE** | **Owner pick (do not implement both):** (A) Align with L-CLAIM-3: credit `min(claimed, U)` where `U = B − R` for face tokens, add those tokens to the hold-set, end-sync `R := B` on money routes; refund exact-out unused **this-call** credit only. (B) Keep same-tx: delete/rewrite Permit2-prefund + `true` as success; NatSpec that `pretransferred=true` is only valid if tokens arrive **during** the snapshot window (practically: never for standard ERC20); provide a recovery story for already-stuck inventory (or accept stranded donations). Do **not** restore PAT-I-ABS. |
| **Recommended TEST** | `test_I1_sameTx_noPush_revertsDelta0` (no hold-set); `test_twoTx_pushThenTrue_revertsOrSucceeds_perChosenLaw`; `test_E6_exactOut_doesNotRefundPriorInventory`. `FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**/crossVersion/v2/**' --match-test 'test_I1_\|test_twoTx_\|test_E6_' --fork-url base_mainnet_alchemy` |
| **Anti-theater** | Do not transfer in I1. Do not assert surplus refund of donated inventory. J3 on proxy if smoke. Exact `TransferDeltaInsufficient` selector. |
| **Suggested WP-ID** | `WP-SEC-DETF-DL-DELTA-001` |
| **Link TCA / prior** | Residual of closed `WP-I-DETF-DL-001` (steal fixed; “do not break Permit2 happy prefund” **not** met). Same files, **new problem**. |
| **Depends / parallel** | Serial with any edit of `…ExchangeInTarget.sol` / `…ExchangeOutTarget.sol`. Parallel with A0 WP if A0 only touches MathLib/Common mint. |

### 6.4 [SEC-DETF-DL-004] A0 — 1:1 genesis captures idle `reserveBpt`

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-DL-004` |
| **Title** | First BPT deposit mints 1:1 even when the diamond already holds `reserveBpt` |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high · **RUNTIME_UNPROVEN** |
| **Catalog IDs** | A0, A3 |
| **Pattern IDs** | PAT-A0-EMPTY |
| **EVM-audit domain** | erc4626 / precision-math |
| **CROPS pillar** | n/a |
| **Incident theme** | Empty vault / first-deposit drain |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Blast radius** | Single package; only **pre-live** residual `reserveBpt` (after live, A3 tests show donation does not zero a victim) |
| **Attacker** | **EXT** / **CAP** |
| **Attack scenario** | 1. Instance is inert: `totalSupply()==0`. Weighted pool exists; someone transfers `reserveBpt` to the diamond (mis-sent bootstrap, donation, or leftover). 2. Attacker `exchangeIn(reserveBpt, 1 wei, detfToken, …, pretransferred=false)` (BPT `true` is `UnsupportedRoute`). 3. `_mintSharesForBpt` → `MathLib._sharesForBpt(1, 0, donatedBpt)` hits `totalShares==0` and returns **1 wei shares**, ignoring `totalBpt>0`. 4. `transferFrom` pulls 1 wei BPT. 5. Attacker holds 100% of supply and `exchangeIn(detfToken → reserveBpt)` takes `donated + 1`. |
| **Preconditions** | `totalSupply==0` and `reserveBpt.balanceOf(diamond) > 0` before the first successful share mint. After `_bootstrapReserve` (atomic first BPT pull) the window is closed. No hostile share required. |
| **Impact** | Drain of all idle `reserveBpt` sitting on an un-bootstrapped diamond. Not a drain of live LP books. Product PRD chose “no dust lock / 1:1 first deposit”; it did **not** document “any pre-live BPT is the first minter’s” as an invariant. |
| **Evidence** | `…MathLib.sol` L11–18: `if (totalShares_ == 0 \|\| totalBpt_ == 0) return bptIn_`. `…ExchangeInTarget.sol` L108–116: `_depositBpt` mints **then** `transferFrom`. `_isBootstrapDeposit` allows BPT→shares when supply is 0 (`…Common.sol` L552–554). ShareInflation only covers **post-bootstrap** A3. Zero `test_A0_*` under the fork tree. |
| **Runtime** | Not run. L-SEC-3: max **High** without forge. Proof-first in WP. |
| **Recommended CODE** | For 1:1 genesis require `totalBpt==0` **and** `totalShares==0`; if `totalShares==0 && totalBpt>0` either revert (`ReservePoolNotInitialized` / dedicated error) or mint against existing BPT so the first minter cannot claim unaccounted inventory (dead-share / virtual offset). Keep BPT `pretransferred=true` forbidden. |
| **Recommended TEST** | `test_A0_idleReserveBpt_firstWeiDeposit_cannotClaimDonation`. Setup: `_create` / deploy inert vault; transfer `reserveBpt` to diamond; attacker deposits 1 wei BPT; assert attacker’s redeemable BPT ≤ attacker’s deposit (+ dust), **or** exact revert. `FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**/crossVersion/v2/**' --match-test 'test_A0_' --fork-url base_mainnet_alchemy` |
| **Anti-theater** | Must start from `totalSupply==0` with **positive** idle `reserveBpt`. Do not count ShareInflation A3. Call **proxy**. No mock SUT. |
| **Suggested WP-ID** | `WP-SEC-DETF-DL-A0-001` |
| **Link TCA / prior** | none (coverage A0 was implicit / not a DualLiquidity WP) |
| **Depends / parallel** | Parallel with I-honesty TEST. Serial with MathLib/Common mint edits. |

### 6.5 [SEC-DETF-DL-005] Fork I/K tests assume durable hold-set; happy pretransfer is theater

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-DL-005` |
| **Title** | Rewrite fork I1–I3/K1 for same-tx CODE; stop counting happy prefund as I |
| **Severity** | **High** (L-SEC-5: fork P0 I/K not honestly green) |
| **Class** | **TEST** + **THEATER** |
| **Confidence** | static-high |
| **Catalog IDs** | I1–I3, K1 |
| **Pattern IDs** | PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | Trust-flag free mint (tests) |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Blast radius** | Test tree only |
| **Attacker** | n/a (false confidence) |
| **Attack scenario** | Reviewer greps `test_I1_` / `test_K1_` and treats ship-gate I/K as F. Setup calls `_requireCommonInHoldSet` / `_bookCommonResidual` / `_endSyncHoldSet`, which require `commonToken ∈ IBasicVault.vaultTokens()` and `reserveOfToken(commonToken)==balanceOf`. Production hold-set never includes `commonToken` and never `_updateReserve`. Those tests fail at setup **or** pass only by accident if someone later adds tokens. Meanwhile Deposits / Permit2 / NestedPush / ExactOut still assert two-tx `true` **succeeds** and surplus is refunded — the opposite of current `_receive` / `_receiveOut`. Catalog md still says **IMPLEMENTED (P0)** and does not list I/J. |
| **Preconditions** | Reading the suite without re-reading `_receive` + `vaultTokens()`. |
| **Impact** | Ship-gate lie. Does not create a new on-chain steal (I1 CODE is safe). Under L-SEC-5 this remains High. |
| **Evidence** | `adversarial/Adversarial_DualLiquidity_Catalog.t.sol` L78–88, L91–108, L112–139, L143–226, L279–363. `DFPkg.sol` L425–434 hold-set. Grep: DualLiquidity production never `_updateReserve`. `DualLiquidity_ADVERSARIAL_CATALOG.md` L5. ShareInflation NatSpec correctly says A3-only. |
| **Runtime** | Not run. Static contradiction is enough for TEST/THEATER. |
| **Recommended CODE** | none (unless 003 chooses durable U — then these tests become the right shape) |
| **Recommended TEST** | Drop hold-set asserts. I1: bootstrap; optional donate `commonToken`; attacker `true` without transfer; exact `TransferDeltaInsufficient(claimed, 0)`; attacker shares/out unchanged. I2: short in-call push if durable U is chosen; else document I2≡I1. I3: second `true` after a successful `!pretransferred`. K1: donate then `true`. Delete or invert `pushThenTrue_succeeds` / Permit2-`true` / surplus-refund-to-caller if same-tx is kept. Replace catalog “P0 complete”. Rewrite H3 to fund a live route + impossible `minOut` + residual asserts. |
| **Anti-theater** | Never `assertTrue(linkedVault != 0)` as catalog coverage. Never transfer for I1. Never count ShareInflation. |
| **Suggested WP-ID** | `WP-SEC-DETF-DL-I-HONESTY-001` |
| **Link TCA / prior** | `TCA-DETF-DL-003`, `TCA-DETF-DL-005`, `TCA-DETF-DL-006`; residual of closed `WP-I-DETF-DL-002` (names landed, setup wrong) |
| **Depends / parallel** | Depends on 003 owner pick (same-tx vs durable). Parallel with A0 TEST. |

### 6.6 [SEC-DETF-DL-007] J1–J3 suite landed on proxy

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-DETF-DL-007` |
| **Title** | J1–J3 fork surface tests exist; no PAT-J-OMIT on money API |
| **Severity** | **Info** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | none live |
| **EVM-audit domain** | proxies |
| **CROPS pillar** | n/a |
| **Incident theme** | Missing diamond selectors |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Blast radius** | n/a |
| **Impact** | Coverage High `TCA-DETF-DL-004` is **closed as TEST**. J3 money path still uses bare `expectRevert` (weak N, not omit). |
| **Evidence** | Facets expose exactly the Target money/query selectors. `test_J1_facetFuncs_coversTargetApi`, `test_J2_proxyLoupe_allProductSelectors`, `test_J3_proxyCallable_smoke_eachSelector`. `WP-J-DETF-DL-001` / STAGE3 11/11 fork. |
| **Recommended TEST** | Optional: exact selector on J3 zero-amount; expand J2 to MultiAsset/ERC20 if diamond specialist wants a full map. |
| **Anti-theater** | Keep J2/J3 on **proxy**, not facet address. |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | `TCA-DETF-DL-004`; `WP-J-DETF-DL-001` |
| **Depends / parallel** | n/a |

### 6.7 Clustered Medium / Info (not full §7.3)

| ID | Sev | Class | Summary |
|----|-----|-------|---------|
| **SEC-DETF-DL-008** | Medium | THEATER · **OWNED_ELSEWHERE** | Catalog `test_H3_failedMint_minOut_leavesNoInventoryOnVault` (zero amount + `address(0)` + bare revert) and `test_catalog_existingSecurityFiles_present` (`linkedVault != 0`). `TCA-DETF-DL-006`; `WP-CAT-DETF-DL-001`. |
| **SEC-DETF-DL-009** | Medium | TEST · **OWNED_ELSEWHERE** | Bare `expectRevert` leftovers (Deposits minOut, catalog H3, J3 zero-amount). `TCA-DETF-DL-008`; `WP-N-DETF-DL-001`. Guards swap minOut **does** use exact `MinAmountNotMet`. |
| **SEC-DETF-DL-010** | Medium | CROPS · **OWNED_ELSEWHERE** | `_requireNotDisabled` wraps **all** mutating routes including redeem (`…Common.sol` L527–538). Registry kill-switch freezes exit. Tests only show deposit blocked. Owner: `A-manager-fee-registry` / `S-crops-trust`. DualLiquidity wiring (`feeOracle == manager`) is consistent. |
| **SEC-DETF-DL-011** | Medium | ACCEPTED_RISK / Info | `_swapThrough` ignores quoted `minOut` (sets 0) so nested Uni V4/V2 hops do not revert on preview undershoot (`…ExchangeInTarget.sol` L487–503). Outer `minAmountOut` still binds. Join `minBpt=0` on `_joinReserve`. Documented; MEV on intermediate hops. |
| **SEC-DETF-DL-012** | Info | ACCEPTED_RISK | Residual dust → `feeTo` (family PRD Known Issue #1). Not PAT-E6 caller extract. |
| **SEC-DETF-DL-013** | Info | ACCEPTED_RISK | Convenience redeem pays one leg and redeposits the rest (large implicit exit cost). Preview returns actual payout. Canonical full-value exit is shares→`reserveBpt`. |
| **SEC-DETF-DL-014** | Low | DEFER | No hermetic full-product suite (`TCA-DETF-DL-010`). Invest in fork P0, not a fake hermetic DualLiquidity. |
| **SEC-DETF-DL-015** | Low | Info | `recipient==address(0)` not rejected (self-grief). Raw BPT `transfer`/`transferFrom` not SafeERC20. |

---

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|----------------------------|-----|
| `test_depositPretransferred_pushThenTrue_succeeds` | Asserts two-tx durable U success; CODE is same-tx | Invert or gate on owner pick (003) |
| Permit2 `pretransferred=true` suite + `_depositCommonViaPermit2` | Prefund is a **prior** transfer; same-tx `_receive` reverts | Treat as H only if durable U lands; else expect revert |
| `test_exactOutMatrix_swap_pretransferredRefundsSurplus` | Caller-funded surplus + refund-to-user | CODE does not refund; rewrite |
| NestedPush T-NEST-5 / T-NEST-8 | Same refund-to-user + Permit2 prefund | Same |
| NestedPush `test_T_LOCAL_PUSH_*` | Durable U positive | Same |
| NestedPush `_assertHoldSetREqualsB` | `R` is never synced; `reserveBpt` B grows | Do not use MultiAsset `R` as DualLiquidity invariant unless CODE writes it |
| `test_I1_*` / `test_I2_*` / `test_I3_*` / `test_K1_*` setup | Requires `commonToken` on hold-set + `R==B` | Same-tx I1 does not need `R` |
| `test_catalog_existingSecurityFiles_present` | `linkedVault != 0` | Delete |
| `test_H3_failedMint_minOut_leavesNoInventoryOnVault` | Zero amount + `tokenIn=0` + bare revert | Fund live route; impossible minOut; residual |
| Catalog md “IMPLEMENTED (P0)” | Omits I/J; overstates A–H | Rewrite matrix |
| ShareInflation as I/K | A3 BPT pull-path only | Keep; do not expand |
| Coverage `repro/TCA-DETF-DL-001` | Quotes no-op `_receive` | Mark stale |
| `test_immutability_packageFacetCountMatchesDeploy` `selectors > 20` | Weak J2 substitute | Real J2 exists now — keep J2 as SoT |

**Not theater:** ShareInflation A3; reentrancy `IsLocked`; residual cleanliness after `!pretransferred` ops; preview≡execute matrix; production proxy H paths; BPT pretransfer reject; J1–J3 (aside from bare J3 revert); I1 **property** if setup is fixed.

**No PAT-MOCK SUT** on DualLiquidity money paths.

---

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| `TCA-DETF-DL-001` / `WP-I-DETF-DL-001` (`_receive` steal) | Yes — CODE steal | **OWNED_ELSEWHERE** — steal **closed**. Do not re-queue `sec_fix_*` for PAT-I-ABS. |
| `TCA-DETF-DL-002` / `WP-I-DETF-DL-001` (`_receiveOut` theft) | Yes | **OWNED_ELSEWHERE** — theft **closed**. |
| `TCA-DETF-DL-003` / `WP-I-DETF-DL-002` (I tests) | Partial — names landed, setup wrong | **New** `SEC-DETF-DL-005` / `WP-SEC-DETF-DL-I-HONESTY-001` (TEST only; do not re-own the closed CODE WP). |
| `TCA-DETF-DL-004` / `WP-J-DETF-DL-001` | Yes — J tests landed | **OWNED_ELSEWHERE** (`SEC-DETF-DL-007`). |
| `TCA-DETF-DL-005` / K1 | CODE half closed with 001; TEST half = 005 | Link; no second CODE WP for K steal. |
| `TCA-DETF-DL-006` / `WP-CAT-DETF-DL-001` | Yes | **OWNED_ELSEWHERE** (`SEC-DETF-DL-008`). May fold honesty edits into I-HONESTY. |
| `TCA-DETF-DL-007` / `WP-L-DETF-DL-001` | Yes | Leave coverage Wave-3; not a new High. |
| `TCA-DETF-DL-008` / `WP-N-DETF-DL-001` | Yes | **OWNED_ELSEWHERE** (`SEC-DETF-DL-009`). |
| `TCA-DETF-DL-009` ShareInflation A3 | Info | Keep; still true. |
| `TCA-DETF-DL-010` hermetic | DEFER | Still DEFER. |
| New A0 | No prior DualLiquidity A0 WP | **This program owns** `WP-SEC-DETF-DL-A0-001`. |
| New same-tx vs Permit2/durable U | Same files as `WP-I-DETF-DL-001`, **different residual** after that WP closed | **This program owns** `WP-SEC-DETF-DL-DELTA-001`. Stage 2 must serialize with any leftover `gap_cover_i-detf-dl` (claimed closed). |
| Outer DualLiquidity matrix | `A-detf-single-se` | Cite only. |
| Commons token pull | `A-commons-pull` | Blast only. DualLiquidity does **not** inherit `BasicVaultCommon`. |
| Registry disable | `A-manager-fee-registry` | **OWNED_ELSEWHERE** (`SEC-DETF-DL-010`). |

---

## 9. Work package stubs

### WP-SEC-DETF-DL-A0-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-DL-A0-001` |
| **Title** | Gate DualLiquidity 1:1 genesis against idle `reserveBpt` |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Finding IDs** | `SEC-DETF-DL-004` |
| **Problem** | `totalShares==0` short-circuit mints `bptIn` shares even when the diamond already holds `reserveBpt`. First 1-wei BPT deposit takes all idle reserve. |
| **Production files (touch set)** | `…MathLib.sol`; possibly `…Common.sol` / `…ExchangeInTarget.sol` `_depositBpt` |
| **Test files (touch set)** | new `adversarial/Adversarial_A0.t.sol` or ShareInflation addendum |
| **Out of scope files** | `_receive` / `_receiveOut`; BasicVaultCommon; outer Single SE matrix |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-DETF-DL-I-HONESTY-001`; J already closed |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-dl-a0` · branch `sec_fix/detf-dl-a0` |
| **Implementation notes** | Crane A0; family PRD bootstrap; keep BPT `pretransferred` forbidden; no `via_ir`; fork TestBase |
| **Acceptance** | `FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**/crossVersion/v2/**' --match-test 'test_A0_' --fork-url base_mainnet_alchemy` green; first minter cannot redeem more `reserveBpt` than deposited when idle BPT sat on the diamond |
| **Anti-theater checks** | `totalSupply==0` + positive idle BPT; proxy call; pass = exploit blocked |
| **Proof-first?** | **yes** (High CODE was RUNTIME_UNPROVEN) |
| **Estimate** | S–M |

### WP-SEC-DETF-DL-DELTA-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-DL-DELTA-001` |
| **Title** | Resolve DualLiquidity same-tx vs L-CLAIM-3 / Permit2 two-tx |
| **Severity** | High |
| **Class** | BOTH (or DOCS if owner accepts same-tx and tests are inverted) |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Finding IDs** | `SEC-DETF-DL-003` |
| **Problem** | Same-tx `_receive` is I1-safe but breaks documented two-tx / Permit2 prefund and can stick inventory. Tests still claim durable U and exact-out surplus refund to caller. |
| **Production files (touch set)** | `…ExchangeInTarget.sol` (`_receive`); `…ExchangeOutTarget.sol` (`_receiveOut`); if durable U: Common + DFPkg hold-set / `_updateReserve` |
| **Test files (touch set)** | Deposits, Permit2*, NestedPush, ExactOutMatrix, adversarial I/K |
| **Out of scope files** | BasicVaultCommon body; Uni V3 clones; A0 MathLib unless needed |
| **Depends on** | Product-owner pick (NEEDS_OWNER) before CODE |
| **Parallelizable with** | `WP-SEC-DETF-DL-A0-001` if files stay disjoint |
| **Conflicts with coverage-audit WP** | Same files as closed `WP-I-DETF-DL-001` — **do not** re-open the steal; this WP is the residual. Confirm `gap_cover_i-detf-dl` is merged/abandoned before `sec_fix_*`. |
| **Suggested worktree** | `sec_fix_detf-dl-delta` · branch `sec_fix/detf-dl-delta` |
| **Implementation notes** | L-CLAIM-3 vs commons §2.2.B family split. If durable U: add face tokens to hold-set; end-sync; refund only this-call unused. If same-tx: rewrite tests; NatSpec. Never restore no-op / `held−amountIn`. |
| **Acceptance** | Fork suite matching the chosen law: I1 no free mint; two-tx either succeeds under `U` **or** reverts with exact selector and no silent success tests left |
| **Anti-theater checks** | I1 no attacker transfer; surplus refund never pays donated inventory |
| **Proof-first?** | **yes** if CODE changes pull math |
| **Estimate** | M |

### WP-SEC-DETF-DL-I-HONESTY-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-DL-I-HONESTY-001` |
| **Title** | Honest DualLiquidity fork I1–I3/K1 + catalog rewrite |
| **Severity** | High |
| **Class** | TEST |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Finding IDs** | `SEC-DETF-DL-005`, `SEC-DETF-DL-008` (fold) |
| **Problem** | Named I/K tests require a hold-set/`R` this SUT does not maintain; catalog claims P0; happy pretransfer theater. |
| **Production files (touch set)** | none |
| **Test files (touch set)** | `adversarial/Adversarial_DualLiquidity_Catalog.t.sol`; `DualLiquidity_ADVERSARIAL_CATALOG.md`; invert stale H pretransfer tests after 003 |
| **Out of scope files** | ShareInflation A3 keep; J suite keep |
| **Depends on** | `WP-SEC-DETF-DL-DELTA-001` owner pick (same-tx vs durable) |
| **Parallelizable with** | A0 TEST; `WP-N-DETF-DL-001` (coverage) |
| **Conflicts with coverage-audit WP** | Residual of closed `WP-I-DETF-DL-002` / `WP-CAT-DETF-DL-001` — TEST-only, no competing CODE |
| **Suggested worktree** | `sec_fix_detf-dl-i-honesty` · branch `sec_fix/detf-dl-i-honesty` (or same tree as DELTA) |
| **Implementation notes** | L-SEC-5; crane I1–I3; exact `TransferDeltaInsufficient`; proxy |
| **Acceptance** | `FOUNDRY_PROFILE=fork forge test --match-path '…/crossVersion/v2/adversarial/**' --match-test 'test_I\|test_K1\|test_J' --fork-url base_mainnet_alchemy` green; catalog md matches scores; no “P0 complete” while A0 G |
| **Anti-theater checks** | No `vault!=0` map test; no ShareInflation as I; I1 no transfer |
| **Proof-first?** | no |
| **Estimate** | S–M |

---

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Reason |
|------|-------|--------|
| Bond/claim D2–D6, F2–F3 | **N/A** | SE-style dual-liquidity vault; family PRD: no NFT / underwriting. Verified: no `bond` / `sellNFT` / `redeemClaim` in package. |
| Same-tx vs durable U as product law | **NEEDS_OWNER** | Commons / L-CLAIM-3 = durable `U`. This package = same-tx (commons §2.2.B). Tests/PRD refund language disagree. `SEC-DETF-DL-003`. |
| A0 “pre-live BPT is first minter’s” | **NEEDS_OWNER** only if product wants ACCEPTED_RISK instead of CODE. Default this report: **High CODE**. |
| Dust / unused intermediate → `feeTo` | **ACCEPTED_RISK** | Family PRD Known Issue #1; not caller extract. |
| Convenience redeem implicit exit cost | **ACCEPTED_RISK** | Documented; preview shows actual payout; canonical exit is `reserveBpt`. |
| `_swapThrough` minOut=0 | **ACCEPTED_RISK** | Nested hop rounding; outer slippage binds. |
| Full Foundry L3 on fork | **DEFER** | RPC cost; L2 sequences exist. |
| Full hermetic DualLiquidity product | **DEFER** | Live Uni V4/V2 + Balancer (`TCA-DETF-DL-010`). |
| Full MEV sandwich reconstruction | **DEFER** | P2. |
| I4 FoT / I5 Permit2 adversarial | **DEFER** / other area | FoT not claimed; I5 → `A-routers-permit2`. |
| Outer Single SE × DualLiquidity matrix | Out of area | `A-detf-single-se`. |
| Registry disable / fee oracle powers | Out of area | `A-manager-fee-registry` / `S-crops-trust`. |
| `via_ir` | Forbidden | Never. |

---

## 11. Commands run

```bash
# Inventory (read-only)
rg -n --type sol 'function _receive|function _receiveOut|pretransferred|facetFuncs|diamondCut|onlyOwner|bond|redeemClaim|_updateReserve|reserveOfToken' \
  contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2

rg -n --type sol 'test_I[0-9]|test_A[0-9]|test_J[0-9]|test_K[0-9]|test_A0_|ShareInflation|pretransferred|expectRevert|testFuzz_' \
  test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2

rg -n 'WP-I-DETF-DL|WP-J-DETF-DL|TCA-DETF-DL' docs/testing/coverage-audit

# Trees listed
# contracts/.../crossVersion/v2/  (15 production files)
# test/foundry/fork/.../crossVersion/v2/ (+ adversarial/)

# Runtime forge: NOT executed this run (fork-first; L-SEC-3).
# Coverage repro TCA-DETF-DL-001 is STALE (old no-op body).
```

**Files read (representative):** ExchangeIn/Out Targets (`_receive`, `_receiveOut`, deposit/redeem/swap, `_depositBpt`, `_legExchange`, `_swapThrough`); all four product Facets; InQuery Target header; Common mint/burn/join/exit/redeposit/sweep/liveness; Repo; MathLib; DFPkg (`facetCuts`, `processArgs`, hold-set init); family PRD; TestBase Permit2 helpers; Deposits pretransfer; NestedPush; ShareInflation; Immutability; Disable; Reentrancy; Residual; Guards header; Invariants test list; adversarial catalog + md; coverage T-detf-dual-liquidity + STAGE3 + WP backlog + stale repro; `A-commons-pull` §2.2.B; MultiAssetBasicVaultRepo; SECURITY_AUDIT_PRD §2.4 / §3.8 / §7.2 / L-SEC-5.

**Not a remaining inventory hole:** FactoryService helpers and every H-matrix `*_Swaps/Fees/RatesOn/*.t.sol` were grepped and sampled; no additional money API or `pretransferred` body exists outside the two Targets.

---

## Return summary (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Critical** | **0** |
| **High** | **3** — `SEC-DETF-DL-003` (CODE same-tx vs two-tx/Permit2), `SEC-DETF-DL-004` (CODE A0), `SEC-DETF-DL-005` (TEST I/K honesty) |
| **OWNED_ELSEWHERE** | **6** — `SEC-DETF-DL-001`, `002`, `007`, `008`, `009`, `010` |
| **Top WP-IDs** | `WP-SEC-DETF-DL-A0-001` · `WP-SEC-DETF-DL-DELTA-001` · `WP-SEC-DETF-DL-I-HONESTY-001` |
| **OUT_FILE** | `docs/security/audit/areas/A-detf-dual-liquidity.md` |
| **PAT-I-ABS** | **Closed** (same-tx). Commons §2.2.B confirmed. ShareInflation ≠ I/K. D2–D6 **N/A**. |
