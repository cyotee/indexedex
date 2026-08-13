# Security Audit — A-se-amm-v2

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · **pilot** · `A-se-amm-v2` |
| Status | **COMPLETE** |
| Production paths | `contracts/protocols/dexes/aerodrome/v1/**`, `contracts/protocols/dexes/camelot/v2/**`, `contracts/protocols/dexes/uniswap/v2/**`. Commons (`BasicVaultCommon.sol`, `ERC4626Service.sol`) cited as **blast only** — not re-owned. |
| Test paths | Co-located `TestBase_*`; `test/foundry/spec/protocol/dexes/{aerodrome/v1,camelot/v2,uniswap/v2}/**`; `test/foundry/spec/vaults/standard-exchange/adversarial/**`; Aerodrome Base fork `test/foundry/fork/base_main/aerodrome/**` |
| Skills cited | `SECURITY_AUDIT_PRD.md` §2, §2.4, §5–8, §19; `crane-adversarial-testing`; `indexedex-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `defi-incident-patterns`; `00_SCOPE_PARTITION.md`; `01_METHODOLOGY_NOTES.md`; coverage-audit `T-se-aerodrome-camelot-univ2.md` + `WORK_PACKAGE_BACKLOG.md` |
| Residual-risk scores | Aerodrome V1 SE → **3**; Camelot V2 SE → **2**; Uniswap V2 SE → **2** |

---

## 1. Executive summary

Re-verified at `1e0d7c48`. Coverage-audit (2026-08-09) PAT-I-ABS on `BasicVaultCommon` + Aerodrome override is **closed in production**: commons now uses durable reserve-delta (`U = B − R`); Aerodrome Common **no longer overrides** `_secureTokenTransfer`. Vault-level `DeadlineExceeded` is present on Aerodrome In/Out. Aero + Camelot have catalog-named I1–I3 and J1–J3 on the **proxy**. WP-H-CAM-001 Route4 H + K1 donation tests exist.

**New exploitable classes this program owns** (not covered by `WP-I-*` CODE):

1. **PAT-E6-REFUND** — `exchangeOut` refunds `maxAmountIn − used` after crediting only `used` (`_secureTokenTransfer(tokenIn, amountIn, …)`). Inflated `maxAmountIn` + `pretransferred=true` + transfer of only `used` skims booked `pairToken` / `rateAsset` inventory. Commons `_refundExcess` is blast; **SE call-sites** pass the slippage cap as if it were this-call overpay.
2. **Camelot `exchangeOut` pass-through swap** — `_swap` sends `tokenOut` to the vault (`address(this)`); branch never `safeTransfer`s to `recipient`; then **overwrites** `amountIn` with `amountOut` before `_refundExcess`. Honest users lose `tokenOut`; refund math is unbounded vs leftover `tokenIn`.
3. **Route4 post-deposit convert** (Camelot + Uni V2) — `convertToShares` uses **post-deposit** LP reserve. Systematic under-mint; existing holders extract seigniorage. Camelot preview still uses **pre-deposit** (N2 + theater 2% bound). Aero Route4 is correct (snapshot `vs.vaultLpReserve`).
4. **A0 / K residual LP** — zap-in vault-deposit loads `lastTotalAssets` *before* mint, then `_setLastTotalAssets(live LP balance)` (includes unbooked donated LP). First minter on empty / stale-book vault then redeem can absorb donated `vaultShare` reserve LP. Aerodrome `decimalOffset = 0` (peers use `9`).

| Product | Residual risk | Worst open |
|---------|--------------:|------------|
| Aerodrome V1 SE | **3** | E6 refund + A0 offset-0; I/J/E5 landed |
| Camelot V2 SE | **2** | Out-swap drop + E6 + Route4 convert |
| Uniswap V2 SE | **2** | E6 + Route4 convert; **no** I/J/adversarial instance |

| Severity | Count | Notes |
|----------|------:|-------|
| **Critical** | **0** | No Critical shipped (L-SEC-3: no forge this run; static High max) |
| **High** | **7** | 5 new CODE (`SEC-SE-AC-001`, `SEC-SE-CAM-001`, `SEC-SE-CAM-002`, `SEC-SE-U2-001`, `SEC-SE-AC-002`); 2 **OWNED_ELSEWHERE** TEST (`SEC-SE-AC-003`, `SEC-SE-AC-004`) |
| **Medium** (clustered) | **6** | Aero offset; I2/E6 theater; disable gap; J ERC4626; fork; exact-selector leftover |
| **OWNED_ELSEWHERE** | **6** | TCA/WP links below (includes closed I-ABS root + UniV2 I/J/ADV + self-burn blast + ADV theater) |

**Top recommended WPs (this program, `sec_fix_*`):**

| Pri | WP-ID | Title |
|----:|-------|-------|
| 1 | **WP-SEC-CAM-OUT-001** | Pay `recipient` on Camelot `exchangeOut` swap; stop overwriting `amountIn` |
| 2 | **WP-SEC-E6-SE-001** | Credit/check `maxAmountIn` (or cap refund to this-call unbooked surplus) on all three Out Targets |
| 3 | **WP-SEC-R4-SE-001** | Camelot + Uni V2 Route4 convert against **pre-deposit** reserve; exact preview |
| 4 | **WP-SEC-A0-SE-001** | Zap-in / empty-supply residual LP cannot mint-then-redeem donation; Aero offset parity |
| — | *(do not schedule)* | `WP-I-SE-AC-001` / `WP-J-SE-AC-001` / `WP-ADV-SE-AC-001` still own Uni V2 I/J/ADV tests |

**OWNED_ELSEWHERE count:** **6** findings linked to `TCA-SE-AC-*` / `WP-I-SE-AC-001` / `WP-J-SE-AC-001` / `WP-ADV-SE-AC-001` / `WP-I-COMMON-001` / commons `_secureSelfBurn`.

---

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|--------------:|
| **Aerodrome V1 SE** | `AerodromeStandardExchangeDFPkg`; In Target+Facet (`heldExcessTokens`); Out **split** Execute Facet + Query Facet; `AerodromeStandardExchangeCommon` (inherits BVC, **no** `_secureTokenTransfer` override); Repo; FactoryService | `TestBase_AerodromeStandardExchange`, `_MultiPool`; fork `TestBase_AerodromeFork` | **Gold:** CREATE3 facets + `vm.prank(owner); indexedexManager.deployAerodromeStandardExchangeDFPkg` | **3** |
| **Camelot V2 SE** | `CamelotV2StandardExchangeDFPkg`; In/Out Target+Facet; Common extends BVC (no override); FactoryService | `TestBase_CamelotV2StandardExchange` (co-located) | **Gold:** CREATE3 + `deployCamelotV2StandardExchangeDFPkg` | **2** |
| **Uniswap V2 SE** | `UniswapV2StandardExchangeDFPkg`; In/Out Target+Facet; Common extends BVC + `_requireNotDisabled`; FactoryService | `TestBase_UniswapV2StandardExchange`, `_MultiPool` | **Gold:** CREATE3 + `deployUniswapV2StandardExchangeDFPkg` | **2** |
| Shared SE adversarial | n/a | `TestBase_StandardExchange_Adversarial` still **empty abstract**; instances inherit **protocol** TestBases | Aero + Camelot instances exist; **no** `UniswapV2SE_Adversarial.t.sol` | — |

**Init / books:** all three `MultiAssetBasicVaultRepo._initialize([reserveLP, token0, token1])`. End-of-route `_syncAllExpectedHoldReserves()` is present on the money branches reviewed. ERC4626 `decimalOffset`: Aero **0**, Camelot **9**, Uni V2 **9**. Aero DFPkg rejects stable pools (`PoolMustNotBeStable`). Uni V2 honors registry `VaultDisabled`; Aero/Camelot **do not**.

**Trust-flag entrypoints (all three):** `exchangeIn(..., pretransferred, deadline)`, `exchangeOut(..., pretransferred, deadline)`, `_secureSelfBurn(..., preTransferred)`. Route4 LP deposit uses `ERC4626Service._secureReserveDeposit` (no `pretransferred` flag; implicit “already there if `balance − lastTotal == claimed`”).

---

## 3. Threat models

### 3.1 Aerodrome V1 SE

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn` Route1 swap / zap | `pairToken` / `rateAsset` / pool LP | `pretransferred` | fee oracle on compound routes | After sync, I1 booked free-credit **blocked**. Unbooked donate harvest (K) |
| EXT / CAP | `exchangeOut` swap / zapIn / zapOut | `pairToken` / `rateAsset` / LP | `pretransferred` + `maxAmountIn` | none | **E6** skim booked pair inventory via inflated max |
| EXT | Route4–7 + ERC4626 `deposit`/`redeem` | LP / `vaultShare` | `_secureReserveDeposit` exact-delta; offset **0** | fee shares to `feeTo` | **A0** first mint after residual LP; inflation cheaper than peers |
| HOS | `transferFrom` reentry on In/Out | same | `nonReentrant` / `IsLocked` | — | Nested reentry blocked (C suite exists) |
| CFG | `deployVault(pool)` no seed; `decimalOffset=0` | residual LP | — | — | Empty instance + donate + zap-in |
| ADM | `diamondCut` on instance | — | — | none observed on instance | F1 blocked in adversarial |
| INT | router `pretransferred=true` + `maxAmountIn` | pair tokens | refund to `msg.sender` | — | Same E6; refund not to `recipient` (by design) |

### 3.2 Camelot V2 SE

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeOut` Route1 swap | `pairToken`/`rateAsset` | `pretransferred`, `maxAmountIn` | referrer = `feeTo` | **`tokenOut` trapped in vault**; E6 refund uses **amountOut** as `used` |
| EXT | `exchangeIn` Route4 | LP → `vaultShare` | `_secureReserveDeposit` | fee mint | **Post-deposit convert** under-mints; existing holders gain |
| EXT | Other In routes 1–3,5–7 | pair / LP / shares | `pretransferred` | — | I1 booked blocked after sync; E6 N/A on In |
| EXT | `exchangeOut` ZapIn / ZapIn-deposit | — | — | — | `InvalidRoute` (intentional negatives) |
| CAP | A0 zap-in deposit | donated LP | stale `lastTotalAssets` | offset 9 | First minter redeem absorbs unbooked LP |
| CFG / ADM | no `VaultDisabled` check | all | — | registry disable **ineffective** | Cannot freeze via registry |

### 3.3 Uniswap V2 SE

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeOut` swap / zap | pair / LP | `pretransferred` + `maxAmountIn` | `_requireNotDisabled` | **E6** same call-site pattern; recipient **is** paid (`_swapTokensForExactTokens`) |
| EXT | `exchangeIn` Route4 | LP → `vaultShare` | post-deposit convert (preview **mirrors** wrong formula) | fee mint | Systematic under-mint |
| EXT | I1/I2/I3 / J | — | — | — | **Unproven** on this SUT (no adversarial / IFacet suite) |
| ADM | registry disable | all exchange | — | owner disable | Kill-switch **works** (suite exists) |

---

## 4. Catalog matrix (A–O, E6, F5)

Legend: **F** found/covered · **P** partial · **G** gap · **N/A** · **VULN** production appears exploitable.

| ID | Aerodrome | Camelot | Uni V2 | Evidence |
|----|-----------|---------|--------|----------|
| **A1** | F | F | G | `test_A1_donateToken_cannotMintFreeShares` Aero/Camelot. Uni V2: no instance |
| **A2** | F | F | G | donate `vaultShare` idle; no free mint |
| **A3** | P | P | G | donate LP no free shares; does **not** cover zap-in absorb (**A0**) |
| **A0** | **VULN** | **VULN** | **VULN** | Zap-in deposit + stale `lastTotalAssets`; Aero offset=0. No `test_A0_*` |
| **B1/B3** | N/A | N/A | N/A | No synthetic mint/burn thresholds on SE |
| **B / L3** | P | P | P | Pass-through quotes use pool spot; slippage `minOut`/`maxIn` = ACCEPTED_RISK. Not used as share oracle |
| **C1–C3** | P | P | G | ReentrancyGuard suites Aero/Camelot (`IsLocked`). Uni V2: no dedicated C |
| **D\*** | N/A | N/A | N/A | No claim/NFT |
| **E1** | P | P | P | Round-trip Aero/Camelot adversarial; Uni V2 InOut invariant |
| **E5** | F | F | P | Aero `Deadline.t.sol` + adversarial exact `DeadlineExceeded`. Camelot same. Uni V2 vault-level check present; no E5 adversarial |
| **E6** | **VULN** | **VULN** | **VULN** | `_refundExcess(maxAmountIn, used)` after credit of `used` only. Camelot Out swap also uses **amountOut** as used. No `test_E6_*` false-max |
| **F1** | P | P | P | diamondCut blocked Aero/Camelot; Uni V2 disable suite |
| **F5** | N/A | N/A | N/A | No public migrate/reclaim; compound is internal `_claimAndCompoundFees` |
| **G** | N/A | N/A | N/A | SE is not a nested DETF |
| **H2/H3** | P | P | P | Aero exact `MaxAmountExceeded` + residual 0. Camelot H2 still bare `expectRevert`. Uni V2 slippage only |
| **I1** | F | F | **G** | Aero/Camelot `test_I1_*` on proxy after sync. Uni V2: **none** |
| **I2** | P | P | G | Named `test_I2_*` is **push-success**, not short-delivery. Short `claimed > U` only via I1 selector |
| **I3** | F | F | G | Residual after honest pull cannot second-credit |
| **I4** | G | G | G | FoT: pull returns `B1−B0`; not product P0 |
| **I5** | N/A | N/A | N/A | Permit2 only as pull fallback; no SE witness |
| **J1** | P | P | **G** | Aero/Camelot Target ⊆ facetFuncs for In/Out money. Aero `heldExcessTokens` not in J1 controls. Uni V2: none |
| **J2** | P | P | **G** | Loupe on proxy for 4 SE selectors. ERC4626/MultiAsset not enumerated |
| **J3** | P | P | **G** | Proxy smoke + I1 revert. Not full product API |
| **K1** | P | P | P | Route4 donation → `ERC4626TransferNotReceived` (Aero/UniV2 historical + Camelot WP-H-CAM). Swap-path unbooked U is claimable (policy) |
| **L1** | P | P | P | Pass-through checks `pool.balance == lastTotalAssets` after swap/zap. E6 pair-token skim bypasses LP check |
| **L2** | N/A | P | N/A | Camelot router FoT-supporting swap; credit via quote not measured `balance` delta on Out. Defer FoT as product policy |
| **L3** | P | P | P | See B |
| **M1–M3** | N/A | N/A | N/A | No user `target+calldata`. Approvals are exact-in to allowlisted router |
| **N1** | N/A | N/A | N/A | `pool.swap(..., "")` empty callback on Aero exact-out |
| **N2** | P | **VULN** | P | Camelot Route4 preview ≠ exec (known, 2% theater). Uni V2 preview **mirrors** post-deposit. Aero snapshot-consistent |
| **O1–O3** | N/A | N/A | N/A | No SE permit path (ERC2612 on share token only) |

---

## 5. Domain notes

Walked (evm-audit hunt lists, not a second ID space):

| Domain | What was walked | Notable hits |
|--------|-----------------|--------------|
| **general / access-control** | `nonReentrant` on In/Out; instance `diamondCut`; Uni V2 `VaultDisabled`; Aero/Camelot **no** disable | SEC-SE-AC-018 (Medium) |
| **precision-math** | `BetterMath._convertToShares*(assets, reserve, supply, offset)`; Route4 reserve ordering | SEC-SE-CAM-002, SEC-SE-U2-001 |
| **erc20 / erc4626** | `_secureTokenTransfer` reserve-delta; `_secureReserveDeposit` exact `balance−lastTotal`; `decimalOffset` 0 vs 9 | A0; I1 closed on booked inventory |
| **defi-amm** | Pass-through swap/zap via router or `pool.swap`; Camelot `_executeSwap` `to = address(this)` | SEC-SE-CAM-001; L3 spot quote + slippage ACCEPTED |
| **proxies / J** | DFPkg `facetCuts` 9 (Aero includes Out query); J tests Aero/Camelot only | SEC-SE-AC-004 Uni V2 |
| **flashloans** | No flash-loan callback surface; Aero exact-out `bytes(0)` | clean |
| **dos** | Route negatives `InvalidRoute`; Camelot Out ZapIn/ZapIn-deposit hard-revert | product-intentional |
| **CROPS** | SE instance unowned after deploy (F1). Registry disable **does not** freeze Aero/Camelot. Fee oracle `feeTo` gets usage-fee shares — cannot steal principal via fee path reviewed | disable gap Medium |
| **sharp-edges** | `pretransferred` default is caller-supplied (not default-true on iface). `maxAmountIn` treated as “amount prepaid” is the E6 footgun. `minAmountOut=0` on `deployVault` seed deposit | PAT-SHARP-FLAG / E6 |
| **incidents** | A0 empty-vault; L1 skim; E6 `balance−floor` / surplus-refund; I1 trust-flag (closed on booked R) | mapped |

**PAT hunt (§2.4):**

| Pattern | Hit | Notes |
|---------|-----|-------|
| **PAT-I-ABS** | **Closed** at this SHA on these three SEs | Commons reserve-delta; Aero override **removed**. Blast: `BasicVaultCommon` owned by `A-commons-pull` / `WP-I-COMMON-001` |
| **PAT-E6-REFUND** | **YES** | SE Out call-sites. Commons helper is blast |
| **PAT-A0-EMPTY** | **YES** | Zap-in + offset-0 Aero |
| **PAT-K-DONATE** | Partial / policy | Route4 mismatch reverts; inter-op unbooked U claimable; zap-in absorbs LP donation into NAV after mint |
| **PAT-L-SKIM** | **YES** via E6 on pair tokens | LP skim blocked by `poolBalance == lastTotalAssets` on zap/swap |
| **PAT-J-OMIT / J-CTRL** | Unproven Uni V2; Aero `heldExcessTokens` declared | Static In/Out money selectors look complete |
| **PAT-THEATER-PRE** | Partial residual | Happy `*_pretransferred_true` still exist; Aero/Camelot I1 now real. Uni V2 refund tests are E6 theater |
| **PAT-THEATER-FACET** | Uni V2 | No IFacet/J suite |
| **PAT-F5-RESIZE** | No | |
| **PAT-M-CALL** | No | |
| **PAT-N-TOCTOU** | Camelot Route4 N2 | |
| **PAT-SHARP-FLAG** | `maxAmountIn` as prepaid | |
| **PAT-MOCK** | No SUT mocks in these trees | |

---

## 6. Findings

### 6.1 [SEC-SE-AC-001] — `exchangeOut` refunds `maxAmountIn − used` without crediting `max`

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-AC-001` |
| **Title** | Cap or credit `maxAmountIn` before `_refundExcess` on SE exact-out |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high / **RUNTIME_UNPROVEN** (forge not run; L-SEC-3) |
| **Catalog IDs** | E6, L1, I |
| **Pattern IDs** | PAT-E6-REFUND, PAT-L-SKIM, PAT-SHARP-FLAG |
| **EVM-audit domain** | erc20, defi-amm |
| **CROPS pillar** | n/a |
| **Incident theme** | surplus-refund / `balance − floor` (defi-incident-patterns E6/L1) |
| **Products** | Aerodrome V1 SE, Camelot V2 SE, Uniswap V2 SE |
| **Blast radius** | All three Out Targets; helper `_refundExcess` in `BasicVaultCommon` (**do not re-own** — cite `A-commons-pull`) |
| **Attacker** | EXT (single tx); INT (router passing fat `maxAmountIn`) |
| **Attack scenario** | 1) Vault holds booked `pairToken`/`rateAsset` (`R == B` after prior `_syncAllExpectedHoldReserves`). 2) Attacker transfers **only** quoted `amountIn` (or uses existing `U ≥ amountIn`). 3) Calls `exchangeOut(tokenIn, maxAmountIn=amountIn+EXTRA, tokenOut, amountOut, attacker, pretransferred=true, deadline)`. 4) `_secureTokenTransfer(tokenIn, amountIn, true)` succeeds (`claimed ≤ U`). 5) Swap consumes `amountIn`. 6) `_refundExcess(tokenIn, maxAmountIn, amountIn, true, msg.sender)` transfers `EXTRA` from remaining vault inventory. 7) LP `lastTotalAssets` check does **not** see pair-token drain. 8) `_syncAllExpectedHoldReserves` books the theft. |
| **Preconditions** | Live SE with pair-token inventory (compound dust, synced donation, leftover). `exchangeOut` swap or zap-in (tokenIn ≠ vault LP). Pretransfer path. |
| **Impact** | Drain of booked `pairToken`/`rateAsset` up to `min(EXTRA, vault tokenIn balance after swap)`. Not LP principal on routes that assert `poolBalance == lastTotalAssets` **after** refund of **LP** (those revert). Pair-token / Aero `_excessToken*` inventory is unprotected. |
| **Evidence** | Commons refund is `maxAmount_ - usedAmount_` with **no** unbooked-surplus cap: `contracts/vaults/basic/BasicVaultCommon.sol:115-126`. SE credits **used** only, then refunds **max**: Aero `AerodromeStandardExchangeOutExecuteTarget.sol:138-170` (swap), `:387-407` (zap-in), `:493-563` (zap-in deposit), `:673-701` (zap-out). Camelot `CamelotV2StandardExchangeOutTarget.sol:413-431`. Uni V2 `UniswapV2StandardExchangeOutTarget.sol:472-478`, `:521-544`. Happy refund tests transfer the **full** max (`AerodromeStandardExchangeOut_Swap.t.sol:148-174`; `UniswapV2Vault_RouterRefund.t.sol:150-170`) — cannot fail this class. |
| **Runtime** | Not executed. Stage 2 proof-first: hermetic `exchangeOut` swap, `pretransferred=true`, transfer `used` only, `maxAmountIn = used + vaultTokenInBal`. |
| **Recommended CODE** | In each Out Target: either (a) `_secureTokenTransfer(tokenIn, maxAmountIn, pretransferred)` then consume `used` and refund `max−used`, **or** (b) refund `min(max−used, _unbookedSurplus(tokenIn))` after the swap (SE-local; do not edit `BasicVaultCommon` in this WP). Prefer (a) so routers that truly prepaid max keep UX. |
| **Recommended TEST** | `test_E6_exchangeOut_swap_inflatedMax_pretransferred_noExtraTransfer_noInventorySkim` on **proxy** for all three. Setup: seed booked pair inventory via honest pull+sync; attacker transfers **only** preview `amountIn`; `maxAmountIn = amountIn + inventory`. Pass: revert **or** refund ≤ 0 extra; vault pair-token booked inventory unchanged; attacker `tokenOut` not funded from inventory. `forge test --match-test 'test_E6_' --match-path 'test/foundry/spec/vaults/standard-exchange/adversarial/**'` |
| **Anti-theater** | Must **not** transfer `maxAmountIn` in I/E6 case. Must not only assert “refund happens” on honest 2× prepay. |
| **Suggested WP-ID** | `WP-SEC-E6-SE-001` |
| **Link TCA / prior** | none for E6 CODE. Related theater: TCA-SE-AC-012 (Out refund H, not I1) |
| **Depends / parallel** | Parallel with CAM-OUT / R4 / A0 (disjoint files except if one agent takes all Aero Out). Serial with any commons E6 WP if `A-commons-pull` also edits `_refundExcess`. |

### 6.2 [SEC-SE-CAM-001] — Camelot `exchangeOut` swap never pays `recipient` and corrupts refund `used`

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-CAM-001` |
| **Title** | Deliver `tokenOut` to `recipient` and keep `amountIn` as tokenIn used |
| **Severity** | **High** (static; would be Critical “silent money API” if runtime-confirmed — L-SEC-3 cap) |
| **Class** | **CODE** |
| **Confidence** | static-high / **RUNTIME_UNPROVEN** |
| **Catalog IDs** | E6, H, L1, N2 |
| **Pattern IDs** | PAT-E6-REFUND, PAT-L-SKIM |
| **EVM-audit domain** | defi-amm, erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | surplus-refund; missing payout |
| **Products** | Camelot V2 SE |
| **Blast radius** | Single package Out swap branch (+ Crane `CamelotV2Service._executeSwap` as reference: `to = address(this)`) |
| **Attacker** | EXT (grief honest user + harvest leftover); EXT E6 as in 6.1 amplified |
| **Attack scenario** | 1) Victim or attacker calls `exchangeOut(tokenA, maxAmountIn, tokenB, amountOut, recipient, pretransferred, deadline)` on the swap route. 2) Vault pulls `tokenA`, `CamelotV2Service._swap` → router `swapExactTokensForTokensSupportingFeeOnTransferTokens(..., to=address(this))`. 3) `tokenB` sits on the vault. 4) `amountIn = _swap(...)` **overwrites** tokenIn-used with **amountOut**. 5) `_refundExcess(tokenIn, maxAmountIn, amountOut, …)` refunds `max − amountOut` of **tokenA**. 6) `_syncAllExpectedHoldReserves` books trapped `tokenB`. Recipient balance of `tokenB` is unchanged. 7) Later E6/I/K path can target booked `tokenB`. |
| **Preconditions** | Any successful Camelot Out swap. Compare In swap, which **does** `tokenOut.safeTransfer(recipient, amountOut)` (`CamelotV2StandardExchangeInTarget.sol:367`). |
| **Impact** | User `tokenOut` not delivered (honest-path loss). Refund can exceed leftover `tokenIn` (revert) or skim booked `tokenIn` (E6). |
| **Evidence** | `CamelotV2StandardExchangeOutTarget.sol:413-434` — pull, `_swap`, refund, sync; **no** recipient transfer. `lib/crane/contracts/protocols/dexes/camelot/v2/services/CamelotV2Service.sol:160-169` `to = address(this)`. Uni V2 Out swap **does** pass `recipient` (`UniswapV2StandardExchangeOutTarget.sol:475`). No Camelot Out happy-path swap test (adversarial Out only deadline/maxIn **reverts**). Stale comment `:504-506` still claims `_secureTokenTransfer returns balanceOf(this)`. |
| **Runtime** | Not executed. Hermetic: `previewExchangeOut` + `exchangeOut` swap; assert `tokenB.balanceOf(recipient) == 0` today. |
| **Recommended CODE** | After `_swap`, `tokenOut.safeTransfer(recipient, amountOut)` using a **separate** `out` variable. Do not assign `_swap` return onto `amountIn`. Then apply SEC-SE-AC-001 refund rule. |
| **Recommended TEST** | `test_exchangeOut_swap_recipientReceivesTokenOut`; `test_E6_exchangeOut_swap_doesNotUseAmountOutAsUsed`. `forge test --match-path 'test/foundry/spec/protocol/dexes/camelot/v2/**' --match-test 'test_exchangeOut_swap'` |
| **Anti-theater** | Assert recipient **delta** of `tokenOut`; do not only assert `amountIn` return. Call **proxy**. |
| **Suggested WP-ID** | `WP-SEC-CAM-OUT-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Implement **before or with** E6 on Camelot Out. Parallel with Uni V2 / Aero E6. |

### 6.3 [SEC-SE-CAM-002] — Camelot Route4 converts shares against post-deposit LP reserve (preview uses pre)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-CAM-002` |
| **Title** | Convert Route4 shares against pre-deposit `lastTotalAssets`; make preview match |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high (test file **admits** the drift) |
| **Catalog IDs** | E, N2, K, A |
| **Pattern IDs** | PAT-K-DONATE (ordering), PAT-N-TOCTOU (preview/exec) |
| **EVM-audit domain** | erc4626, precision-math |
| **CROPS pillar** | n/a |
| **Incident theme** | donation / inflation (first holder extracts from later depositor) |
| **Products** | Camelot V2 SE |
| **Blast radius** | Camelot In Target Route4 only (Out deposit uses `_convertToAssetsUp` then `_secureReserveDeposit` — separate) |
| **Attacker** | EXT (existing `vaultShare` holder) |
| **Attack scenario** | 1) Attacker holds most `vaultShare` (first depositor / seed recipient). 2) Victim `exchangeIn(poolLP, D, vault, …)` Route4. 3) `_secureReserveDeposit` pulls D; code sets `vault.vaultLpReserve = pool.balanceOf(this)` (**includes D**). 4) `convertToSharesDown(D, reserveAfter, S, offset)` under-mints vs `convert(D, reserveBefore, S, offset)`. 5) Victim’s claim on LP is too small; attacker’s redeemable fraction of `(oldLP+D)` rises. Large `D ≈` vault TVL → ~50% under-mint (virtual offset 9 mitigates dust, not equal-size deposits). |
| **Preconditions** | Live vault with existing shares + LP. Victim uses Route4 (LP → shares), not only swap. |
| **Impact** | Systematic depositor loss / existing-holder seigniorage. Preview **overstates** shares (`CamelotV2StandardExchangeInTarget.sol:157-159` uses **pre**-deposit reserve). |
| **Evidence** | Exec: `CamelotV2StandardExchangeInTarget.sol:529-572` — deposit, **then** `vaultLpReserve = balanceOf`, **then** convert. Preview: `:157-159` pre-deposit. Test theater: `CamelotV2StandardExchangeIn_VaultDeposit.t.sol:91-96` “exec slightly below preview… `assertApproxEqRel(..., 0.02e18)`”. Aero gold: `AerodromeStandardExchangeInTarget.sol:355-362` converts against snapshot `vs.vaultLpReserve` **before** deposit. |
| **Runtime** | Static + existing test comment. Optional: deposit `D == vaultLp` and measure share under-mint ≫ 2%. |
| **Recommended CODE** | Snapshot `reserveBefore = lastTotalAssets` (already in `vault.vaultLpReserve` pre-deposit). Convert against `reserveBefore`. Update `lastTotalAssets` after mint. Align preview. |
| **Recommended TEST** | `test_Route4_largeDeposit_sharesEqPreview_preDepositReserve`; `test_N2_previewEqualsExecute_route4`. Fail if exec < preview beyond 1 wei / fee-share. `forge test --match-path 'test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchangeIn_VaultDeposit.t.sol'` |
| **Anti-theater** | Include **D ≈ existing LP** case; do not keep 2% relative slack as pass. |
| **Suggested WP-ID** | `WP-SEC-R4-SE-001` (same tree as Uni V2 Route4) |
| **Link TCA / prior** | TCA-SE-AC-007 / WP-H-CAM-001 landed H/K1 tests but **greenwashed** N2 |
| **Depends / parallel** | Parallel with E6/CAM-OUT. Same WP as SEC-SE-U2-001. |

### 6.4 [SEC-SE-U2-001] — Uni V2 Route4 converts against post-deposit reserve (preview mirrors the bug)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U2-001` |
| **Title** | Uni V2 Route4: convert against pre-deposit reserve (stop mirroring wrong math in preview) |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | E, K, A |
| **Pattern IDs** | PAT-K-DONATE (ordering) |
| **EVM-audit domain** | erc4626, precision-math |
| **CROPS pillar** | n/a |
| **Incident theme** | inflation / first-holder extract |
| **Products** | Uniswap V2 SE |
| **Blast radius** | Uni V2 In Target Route4 (+ preview) |
| **Attacker** | EXT (existing holder) |
| **Attack scenario** | Same as SEC-SE-CAM-002. Preview **intentionally** uses `reserveAfter = vaultLpReserve + amountIn` (`UniswapV2StandardExchangeInTarget.sol:202-208`) so N2 is green while the ERC4626 invariant is wrong. |
| **Preconditions** | Same as Camelot Route4 |
| **Impact** | Same systematic under-mint; preview will not save integrators |
| **Evidence** | Exec `UniswapV2StandardExchangeInTarget.sol:581-623`. Preview comment `:202-204` “computes shares against the post-deposit reserve. Mirror that here so preview matches execution.” |
| **Runtime** | RUNTIME_UNPROVEN |
| **Recommended CODE** | Same snapshot-before-deposit as Aero. Preview uses the same pre-deposit reserve. |
| **Recommended TEST** | `test_Route4_convertUsesPreDepositReserve` on `TestBase_UniswapV2StandardExchange_MultiPool`. |
| **Anti-theater** | Large-vs-TVL deposit; exact `assertEq` vs preview after fix. |
| **Suggested WP-ID** | `WP-SEC-R4-SE-001` |
| **Link TCA / prior** | none for this CODE (Route4 K1 donation tests are a different touch) |
| **Depends / parallel** | Same WP as SEC-SE-CAM-002 (two files, one agent OK per L-SEC-13? **No** — L-SEC-13 one worktree per package. Split: `WP-SEC-R4-CAM-001` + `WP-SEC-R4-U2-001` if Stage 2 wants package isolation. This report clusters math-identical fix as one stub with two suggested trees.) |

### 6.5 [SEC-SE-AC-002] — Unbooked LP + zap-in deposit lets first minter absorb residual (A0)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-AC-002` |
| **Title** | Revert or dead-share unbooked LP before zap-in / empty mint |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high / RUNTIME_UNPROVEN |
| **Catalog IDs** | A0, K1, A3 |
| **Pattern IDs** | PAT-A0-EMPTY, PAT-K-DONATE |
| **EVM-audit domain** | erc4626 |
| **CROPS pillar** | n/a |
| **Incident theme** | empty vault / first deposit drain |
| **Products** | Aerodrome V1 SE (worse: `decimalOffset = 0`); Camelot V2; Uni V2 |
| **Blast radius** | In Target zap-in vault-deposit (+ ERC4626 `deposit` exact-match donation harvest — Crane `ERC4626Service` blast, not re-owned) |
| **Attacker** | EXT (after accidental/mis-routed LP donation); CFG `deployVault(pool)` unsown |
| **Attack scenario** | 1) Vault `totalSupply==0` or tiny, `lastTotalAssets` does not include donated LP D. 2) Attacker zap-in deposit: snapshot `vs.vaultLpReserve = lastTotalAssets` (excludes D); `_secureTokenTransfer` pair tokens; `_swapDepositVolatile` mints L LP to vault; `_setLastTotalAssets(balance)` **includes D+L**; mint shares for **L only**. 3) Attacker redeems all shares against inflated lastTotal → absorbs D. Route4 `deposit` of **exactly** D also harvests via `_secureReserveDeposit` implicit pretransfer. |
| **Preconditions** | Unseeded `deployVault(pool)` or post-exit residual + LP donation. Seeded `deployVault(tokenA,amt,…)` is the common happy path (not A0-safe for later empty). |
| **Impact** | Loss of donated / leftover reserve LP to first minter. Aero offset=0 makes empty-supply inflation cheaper (`shares = assets * (S+1) / (R+1)`). |
| **Evidence** | Aero zap-in deposit `AerodromeStandardExchangeInTarget.sol:395-425`. Aero init `AerodromeStandardExchangeDFPkg.sol:599-604` `decimalOffset = 0`. Camelot/Uni V2 DFPkg offset **9**. No `test_A0_*` under SE trees. A3 tests only assert donate-LP does not mint shares **immediately**. |
| **Runtime** | Not executed. Hermetic: `deployVault(pool)` no seed; donate LP; attacker zap-in; redeem; `assert attacker LP profit ≤ fees`. |
| **Recommended CODE** | Before zap-in mint: `require(pool.balanceOf(this) == lastTotalAssets)` (same invariant as pass-through zap). Optionally raise Aero offset to 9. Empty-supply: dead shares or reject `totalSupply==0 && balance>0`. |
| **Recommended TEST** | `test_A0_donateLp_thenZapInDeposit_cannotRedeemDonation`; `test_A0_emptyVault_residualLp_firstMinter_noDrain`. |
| **Anti-theater** | Attacker must not be the donator in the “no steal” assert only — also run donator≠attacker. Redeem path required. |
| **Suggested WP-ID** | `WP-SEC-A0-SE-001` |
| **Link TCA / prior** | none (coverage A3/A1 did not include A0 redeem) |
| **Depends / parallel** | Parallel per package after shared invariant sketch. |

### 6.6 [SEC-SE-AC-003] — Uni V2 missing I1–I3 proofs — OWNED_ELSEWHERE

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-AC-003` |
| **Title** | Uni V2 SE I1–I3 on production proxy |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed (tests absent at this SHA) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | trust-flag free mint |
| **Products** | Uniswap V2 SE |
| **Blast radius** | Test-only; production pull is commons-fixed |
| **Impact** | No SUT proof Uni V2 I1; residual **test** hole after Wave-0 CODE |
| **Evidence** | `rg test_I` under `test/foundry/spec/protocol/dexes/uniswap/v2` empty; no `UniswapV2SE_Adversarial.t.sol`. Aero/Camelot I1–I3 exist and look non-theater for **booked** inventory. |
| **Recommended TEST** | As `WP-I-SE-AC-001` |
| **Anti-theater** | I1 no in-call transfer |
| **Suggested WP-ID** | `WP-I-SE-AC-001` (coverage-audit; **no** `sec_fix_*`) |
| **Link TCA / prior** | TCA-SE-AC-002, TCA-SE-AC-003 |
| **Depends / parallel** | gap_cover tree |

### 6.7 [SEC-SE-AC-004] — Uni V2 missing J1–J3 and adversarial instance — OWNED_ELSEWHERE

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-AC-004` |
| **Title** | Uni V2 J surface + `UniswapV2SE_Adversarial` |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | J1–J3, A1, E5, F1, H3 |
| **Pattern IDs** | PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **Products** | Uniswap V2 SE |
| **Blast radius** | tests only; static In/Out `facetFuncs` look complete |
| **Impact** | Silent selector omit would not be caught |
| **Evidence** | No `*_IFacet*` / `test_J*` under Uni V2 spec. `WP-J-SE-AC-001` / `WP-ADV-SE-AC-001`. STAGE3 claimed J 26/26 for SE-AC but Uni V2 adversarial file still missing at this SHA — **J for Aero/Camelot landed; Uni V2 J still gap**. |
| **Recommended TEST** | Coverage WPs |
| **Anti-theater** | J3 on **proxy** |
| **Suggested WP-ID** | `WP-J-SE-AC-001`, `WP-ADV-SE-AC-001` |
| **Link TCA / prior** | TCA-SE-AC-004, 005, 006 |
| **Depends / parallel** | gap_cover |

### 6.8 Clustered Medium / Low / Info

| ID | Sev | Class | Title | Notes |
|----|-----|-------|-------|-------|
| **SEC-SE-AERO-001** | Medium | CODE | Aerodrome `decimalOffset = 0` vs Camelot/UniV2 `9` | A0 cheaper; fold into `WP-SEC-A0-SE-001` |
| **SEC-SE-AC-005** | Medium | TEST / THEATER | I2 tests misnamed (push success, not short delivery); E6 happy-refund theater | Add `test_I2_claimedGtU` + E6 negatives |
| **SEC-SE-AC-006** | Info | OWNED_ELSEWHERE | PAT-I-ABS root **closed** at SHA | `WP-I-COMMON-001` / TCA-SE-AC-001 / TCA-COMMON-001. Aero Common L47–49 inherit-only |
| **SEC-SE-AC-007** | Info | OWNED_ELSEWHERE | Aero vault deadline **closed** | `WP-E5-AERO-001` + `AerodromeStandardExchange_Deadline.t.sol` + In/Out `DeadlineExceeded` |
| **SEC-SE-AC-008** | Medium | OWNED_ELSEWHERE | `_secureSelfBurn` refunds **all** leftover `vaultShare` (`balanceOf(this)`) | Commons blast `BasicVaultCommon.sol:128-137`. E6 on donated shares. `A-commons-pull` |
| **SEC-SE-AC-009** | Info | NEEDS_OWNER / ACCEPTED_RISK | Inter-op unbooked `U` is claimable via `pretransferred` | L-CLAIM-3 / commons NatSpec: surplus absorbed at end-of-op; between ops first claimer harvests donations |
| **SEC-SE-AC-010** | Low | TEST | Aero J1 controls omit `heldExcessTokens()` | View only; selector **is** in `facetFuncs` |
| **SEC-SE-AC-011** | Medium | THEATER / OWNED_ELSEWHERE | Bare `expectRevert` leftover (Aero E5 zero; Camelot H2/H3) | `WP-ADV-SE-AC-001` |
| **SEC-SE-AC-012** | Info | ACCEPTED_RISK | Camelot Out ZapIn + ZapIn-deposit `InvalidRoute` | Documented negatives; not a missing-selector (preview/exec both revert) |
| **SEC-SE-AC-013** | Info | DEFER | L2 FoT | Product does not claim FoT support |
| **SEC-SE-AC-014** | Info | ACCEPTED_RISK | AMM spot quotes on pass-through | `minOut`/`maxIn` required; not share pricing |
| **SEC-SE-AC-015** | Medium | TEST / NEEDS_OWNER | Camelot / Uni V2 SE-native fork P0 | Aero has Base fork. Camelot chain = NEEDS_OWNER |
| **SEC-SE-AC-016** | Medium | TEST | ERC4626 `deposit/mint/withdraw/redeem` not in SE J matrix | Shared ERC4626 facet cut is in DFPkg; J smoke is SE In/Out only |
| **SEC-SE-AC-017** | Medium | CODE | Aero + Camelot ignore registry `VaultDisabled` | Uni V2 `_requireNotDisabled`. CROPS freeze gap |
| **SEC-SE-AC-018** | Low | TEST | Empty `TestBase_StandardExchange_Adversarial` | TCA-SE-AC-014 / WP-ADV |
| **SEC-SE-AC-019** | Low | CODE hygiene | Stale comments: `_secureTokenTransfer returns balanceOf(this)` on Camelot/UniV2 Out zap-out | After commons fix, comment is false |
| **SEC-SE-AC-020** | Low | CODE | Router `approve(amount)` not always zeroed (Aero In swap) | Uni V2 `_swapExact*` zeros; residual allowance if router compromised |

---

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| Aero/Uni V2 `exchangeOut_*pretransferredRefund*` / `test_exchangeOut_refundExcess` | Transfers **full** `maxAmountIn` then asserts refund — honest UX only | `test_E6_*` with transfer == used, max ≫ used |
| Aero/Camelot `test_I2_transferBeforeCall_pretransferred_revertsDelta0` | Name says revert; body asserts **success** (push ≤ U). No short-delivery I2 | Rename; add `claimed > U` after push of `U/2` |
| Camelot `test_Route4VaultDeposit_execVsPreview` 2% rel | Documents post- vs pre-deposit convert; hides equal-TVL under-mint | Exact eq after CODE; large-D case |
| `test_A1` / `test_A3` “no free shares” | Does not redeem after zap-in / does not prove A0 drain | `test_A0_*` redeem |
| Happy `*_pretransferred_true` with real transfer (route H) | Cannot fail booked I1 (now separately tested on Aero/Camelot only) | Keep as H; Uni V2 still needs I1 |
| Aero/Camelot J1–J3 4 selectors | Misses ERC4626 + `heldExcessTokens` + MultiAsset | Expand control from full DFPkg product API |
| `TestBase_StandardExchange_Adversarial` | Empty hooks; looks like shared harness | Implement or delete |
| STAGE3 “WP-J-SE-AC-001 26/26” / “WP-ADV-SE-AC-001” | Uni V2 adversarial file **still absent** | Do not treat Uni V2 J/ADV as closed |
| Coverage TCA-SE-AC-001 “Aero reserved-dust override” | **Stale** — override gone; reserve-delta inherited | Treat CODE root closed; do not re-fix |

---

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| **TCA-SE-AC-001** / **WP-I-COMMON-001** | Yes — BVC + former Aero override | **OWNED_ELSEWHERE** (CODE **closed** at SHA). Do not `sec_fix` BVC |
| **TCA-SE-AC-002/003/012** / **WP-I-SE-AC-001** | I1–I3 tests | **OWNED_ELSEWHERE**. Aero/Camelot **landed**; Uni V2 **still open** |
| **TCA-SE-AC-004** / **WP-J-SE-AC-001** | J declaration/proxy | **OWNED_ELSEWHERE**. Aero/Camelot landed; Uni V2 open |
| **TCA-SE-AC-005/006/009/014** / **WP-ADV-SE-AC-001** | Adversarial expand + Uni V2 instance | **OWNED_ELSEWHERE**. Aero/Camelot A–H residual landed; Uni V2 instance missing |
| **TCA-SE-AC-007** / **WP-H-CAM-001** | Camelot H + Route4 K1 | **OWNED_ELSEWHERE** (tests exist). **New** SEC-SE-CAM-002 is **different** (convert math), not a second I/J WP |
| **TCA-SE-AC-008** / **WP-E5-AERO-001** | Aero deadline | **OWNED_ELSEWHERE** — **closed** in CODE+tests |
| **TCA-SE-AC-010** L3 | Medium L2/L3 depth | DEFER / coverage Wave 3 `WP-L3-SE-AC-001` |
| **TCA-SE-AC-011** fork | Fork parity | NEEDS_OWNER / coverage |
| **WP-I-COMMON-001** Aero override file | Touch-set listed Aero Common | Override **removed**; file now inherit-only. Commons area still owns BVC |

**Still new (this program):** SEC-SE-AC-001 (E6), SEC-SE-CAM-001, SEC-SE-CAM-002, SEC-SE-U2-001, SEC-SE-AC-002 (A0), SEC-SE-AERO-001 (offset), SEC-SE-AC-017 (disable).

---

## 9. Work package stubs

### WP-SEC-CAM-OUT-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-CAM-OUT-001` |
| **Title** | Camelot `exchangeOut` swap: pay recipient; do not overwrite `amountIn` |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Camelot V2 SE |
| **Finding IDs** | SEC-SE-CAM-001 |
| **Problem** | Out swap leaves `tokenOut` on the vault and uses `amountOut` as refund `used`. Honest users lose output; E6 refund is wrong. |
| **Production files (touch set)** | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol` |
| **Test files (touch set)** | `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchangeOut_Swap.t.sol` (new); optional adversarial |
| **Out of scope files** | `BasicVaultCommon.sol`; Aero/Uni V2; Crane `CamelotV2Service` unless a follow-up adds a recipient param (prefer SE-local transfer) |
| **Depends on** | none |
| **Parallelizable with** | WP-SEC-E6-SE-001 (Aero/Uni V2 files); WP-SEC-R4-SE-001 |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_cam-out` / branch `sec_fix/cam-out` |
| **Implementation notes** | Mirror Camelot **In** swap `safeTransfer(recipient, amountOut)`. Keep `usedIn` vs `out` locals. Skills: indexedex-testing gold TestBase. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/protocol/dexes/camelot/v2/**' --match-test 'test_exchangeOut_swap'` — recipient `tokenOut` delta ≥ `amountOut`; refund uses tokenIn used |
| **Anti-theater checks** | Proxy call; assert balances, not only return value |
| **Proof-first?** | yes |
| **Estimate** | S |

### WP-SEC-E6-SE-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-SE-001` |
| **Title** | SE `exchangeOut`: refund only this-call prepaid surplus |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Aerodrome, Camelot, Uni V2 SE |
| **Finding IDs** | SEC-SE-AC-001 |
| **Problem** | Call-sites credit `used` then refund `maxAmountIn − used`, skimming booked pair inventory. |
| **Production files (touch set)** | `AerodromeStandardExchangeOutExecuteTarget.sol`; `CamelotV2StandardExchangeOutTarget.sol`; `UniswapV2StandardExchangeOutTarget.sol`. **Not** `BasicVaultCommon.sol` |
| **Test files (touch set)** | `test/foundry/spec/vaults/standard-exchange/adversarial/**` + per-protocol Out swap files |
| **Out of scope files** | Commons pull; DETF; Uni V3/V4 SE |
| **Depends on** | WP-SEC-CAM-OUT-001 first on Camelot Out (same file) — **serial on Camelot Out Target** |
| **Parallelizable with** | Aero Out + Uni V2 Out after Camelot Out merge, or one agent all three |
| **Conflicts with coverage-audit WP** | none (E6 not in TCA CODE). If commons later caps `_refundExcess`, coordinate with `A-commons-pull` |
| **Suggested worktree** | `sec_fix_e6-se` / `sec_fix/e6-se` (or split `sec_fix_e6-aero`, `sec_fix_e6-u2` after Camelot Out) |
| **Implementation notes** | Prefer credit `maxAmountIn` then spend `used`. L-CLAIM-3: do not require exact-U equality. |
| **Acceptance** | `forge test --match-test 'test_E6_'` — inflated max + transfer(used) ⇒ no pair-token inventory loss |
| **Anti-theater checks** | I1-style: no transfer of EXTRA |
| **Proof-first?** | yes |
| **Estimate** | M |

### WP-SEC-R4-SE-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-R4-SE-001` |
| **Title** | Route4 convert against pre-deposit reserve (Camelot + Uni V2) |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Camelot V2 SE, Uniswap V2 SE |
| **Finding IDs** | SEC-SE-CAM-002, SEC-SE-U2-001 |
| **Problem** | Post-deposit reserve in `convertToShares` under-mints later depositors. Camelot preview still pre-deposit (N2 theater 2%). |
| **Production files (touch set)** | `CamelotV2StandardExchangeInTarget.sol`; `UniswapV2StandardExchangeInTarget.sol` (preview+exec) |
| **Test files (touch set)** | `CamelotV2StandardExchangeIn_VaultDeposit.t.sol`; `UniswapV2StandardExchangeIn_VaultDeposit.t.sol` |
| **Out of scope files** | Aero In (already correct); Out Targets |
| **Depends on** | none |
| **Parallelizable with** | E6, CAM-OUT, A0 |
| **Conflicts with coverage-audit WP** | **Soft:** WP-H-CAM-001 tests will need assert update (same Camelot VaultDeposit file). Stage 2: either take over that test file in this `sec_fix` or wait for `gap_cover_h-cam` to be idle. Prefer this program **edits the test file** because the 2% bound is now known theater. |
| **Suggested worktree** | `sec_fix_r4-se` — or `sec_fix_r4-cam` + `sec_fix_r4-u2` (L-SEC-13) |
| **Implementation notes** | Copy Aero snapshot `vs.vaultLpReserve`. Remove Uni V2 preview `reserveAfter` comment/hack. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/protocol/dexes/{camelot/v2,uniswap/v2}/**VaultDeposit*'` — `assertEq(exec, preview)`; large-D case share price does not jump in depositor’s disfavor |
| **Anti-theater checks** | D ≈ existing LP; no 2% slack |
| **Proof-first?** | no (static + existing test already shows drift) |
| **Estimate** | M |

### WP-SEC-A0-SE-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-A0-SE-001` |
| **Title** | Block zap-in/empty mint from unbooked LP; Aero offset parity |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | All three SE |
| **Finding IDs** | SEC-SE-AC-002, SEC-SE-AERO-001 |
| **Problem** | Zap-in deposit snapshots lastTotal then sets lastTotal to live LP (includes donation). First redeem drains D. Aero offset=0. |
| **Production files (touch set)** | Aero/Camelot/UniV2 In Targets (zap-in deposit); Aero `AerodromeStandardExchangeDFPkg.sol` offset only |
| **Test files (touch set)** | SE adversarial `test_A0_*` |
| **Out of scope files** | `ERC4626Service.sol` / `ERC4626Target.sol` (blast; other area if deposit() harvest is in-scope later) |
| **Depends on** | none |
| **Parallelizable with** | E6, R4 (different branches) — **not** same In Target hunks as R4 on Camelot/Uni V2 Route4 (same files!) → **serial with R4 on those two In Targets** |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_a0-se` after R4 merge on shared In files, **or** fold A0 check into R4 worktrees per package |
| **Implementation notes** | `pool.balanceOf == lastTotalAssets` before zap-in mint (pass-through already does after). Offset 9 on Aero DFPkg. |
| **Acceptance** | `forge test --match-test 'test_A0_'` — donator≠attacker; redeem profit ≤ 0 vs donation |
| **Anti-theater checks** | Must redeem; must not only assert no immediate share mint (A3) |
| **Proof-first?** | yes |
| **Estimate** | M |

**Do not schedule `sec_fix_*` for:** WP-I-SE-AC-001, WP-J-SE-AC-001, WP-ADV-SE-AC-001, WP-I-COMMON-001, WP-E5-AERO-001, WP-H-CAM-001 (except R4 test-assert update noted above).

---

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Note |
|------|-------|------|
| DETF B1/B3 synthetic gates | N/A | SE has no mint/burn deadband |
| Claim/NFT D | N/A | |
| F5 public reclaim | N/A | Compound internal only |
| M\*/O\* | N/A | No helper calldata / SE permit |
| Inter-op unbooked U harvest | NEEDS_OWNER / ACCEPTED_RISK | Commons NatSpec + L-CLAIM-3; not booked I1 |
| Donation beneficiary on swap dust | NEEDS_OWNER | Same as coverage §9 |
| Camelot fork chain | NEEDS_OWNER | L-SEC-5 if they declare fork-first |
| FoT I4/L2 | DEFER | P1 unless product claims FoT |
| Full MEV sandwich reconstruction | DEFER | P2 |
| `via_ir` | forbidden | not recommended |
| Runtime proof of High CODE | Stage 2 proof-first | No forge this subagent |
| Slipstream / V3 / V4 / LST | out of area | |
| Commons `_refundExcess` / `_secureSelfBurn` body | OWNED `A-commons-pull` | SE call-sites owned here |

---

## 11. Commands run

Static review only. **No `forge` / `solc`** (hard rule). No production or test `*.sol` edits.

```bash
# Inventory
ls contracts/protocols/dexes/aerodrome/v1/
ls contracts/protocols/dexes/camelot/v2/
ls contracts/protocols/dexes/uniswap/v2/
ls test/foundry/spec/vaults/standard-exchange/adversarial/
ls test/foundry/spec/protocol/dexes/{aerodrome/v1,camelot/v2,uniswap/v2}/

# Pattern / catalog greps (workspace; rg --type sol unavailable → glob)
rg -n --glob '*.sol' '_syncAllExpectedHoldReserves|_refundExcess|_secureTokenTransfer|DeadlineExceeded|function facetFuncs' \
  contracts/protocols/dexes/aerodrome/v1 \
  contracts/protocols/dexes/camelot/v2 \
  contracts/protocols/dexes/uniswap/v2

rg -n --glob '*.sol' 'function test_I[0-9]_|function test_J[0-9]_|function test_A0_|function test_E6_|function test_K1_' \
  test/foundry/spec/vaults/standard-exchange/adversarial \
  test/foundry/spec/protocol/dexes/aerodrome/v1 \
  test/foundry/spec/protocol/dexes/camelot/v2 \
  test/foundry/spec/protocol/dexes/uniswap/v2

rg -n --glob '*.sol' 'decimalOffset|_requireNotDisabled|PoolMustNotBeStable' \
  contracts/protocols/dexes/aerodrome/v1 \
  contracts/protocols/dexes/camelot/v2 \
  contracts/protocols/dexes/uniswap/v2

# Read (non-exhaustive): BasicVaultCommon.sol; Aero/Camelot/UniV2 Common + In/Out Targets + Facets + DFPkg;
# CamelotV2Service._executeSwap; ERC4626Service._secureReserveDeposit; BetterMath._convertToShares;
# Aero/Camelot SE adversarial; Camelot VaultDeposit; UniV2 RouterRefund; coverage T-se-aerodrome-camelot-univ2.md;
# WORK_PACKAGE_BACKLOG.md WP-I/J/ADV/H/E5-SE-AC; STAGE3_PROGRESS.md (re-checked vs tree)
```

**Suggested Stage 2 / Stage 3 acceptance (not run):**

```bash
forge test --match-path 'test/foundry/spec/vaults/standard-exchange/adversarial/**'
forge test --match-path 'test/foundry/spec/protocol/dexes/aerodrome/v1/**'
forge test --match-path 'test/foundry/spec/protocol/dexes/camelot/v2/**'
forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v2/**'
# FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/aerodrome/**' --fork-url base_mainnet_alchemy
```

---

**Area status: COMPLETE** · Report: `docs/security/audit/areas/A-se-amm-v2.md` · Critical: **0** · High: **7** (5 new CODE + 2 OWNED_ELSEWHERE TEST) · OWNED_ELSEWHERE: **6** · Top WPs: `WP-SEC-CAM-OUT-001`, `WP-SEC-E6-SE-001`, `WP-SEC-R4-SE-001`, `WP-SEC-A0-SE-001`.
