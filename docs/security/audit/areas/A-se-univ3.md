# Security Audit — A-se-univ3

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · **full** · `A-se-univ3` |
| Status | **COMPLETE** |
| Production paths | `contracts/protocols/dexes/uniswap/v3/**` only. Commons (`BasicVaultCommon.sol`) cited as **blast / peer law** — not re-owned. Uni V4 SE, Slipstream, DETFs **out of area**. |
| Test paths | Co-located `contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange.sol`; `test/foundry/spec/protocol/dexes/uniswap/v3/**` (routes, previews, import, fee-compound, 3× IFacet, `adversarial/**`); Base fork `test/foundry/fork/base_main/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Fork.t.sol` |
| Skills cited | `SECURITY_AUDIT_PRD.md` §2, §2.4, §3.8, §5–8, §19; `00_SCOPE_PARTITION.md`; `crane-adversarial-testing`; `indexedex-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `defi-incident-patterns`; seeds `A-commons-pull.md` §2.2.C, `WP-I-CLONE-001`, `T-basic-protocol-commons.md` §2.3.B / TCA-COMMON-004 |
| Residual-risk scores | Uniswap V3 SE → **1** |

---

## 1. Executive summary

Re-read at `1e0d7c48`. Pilot `A-commons-pull` §2.2.C / `SEC-COMMON-003` is **still live**: Uni V3 In/Out keep a **local** `_secureTokenTransfer` that `require`s absolute `balanceOf(this) >= amount` and **`return amount`** (PAT-I-ABS). That CODE is the exact clone listed in coverage `TCA-COMMON-004` / **`WP-I-CLONE-001`** (`UniswapV3StandardExchange{In,Out}Target.sol`). **Do not open a competing `sec_fix_*` for the pull helper.** `STAGE3_PROGRESS.md` “WP-I-CLONE-001 closed” is **stale** for this package.

**New exploitable classes this program owns** (not described by `WP-I-CLONE-001`):

1. **PAT-E6-REFUND** — zap-in `_refundRemainder` and import `_refundRemainderTo` `safeTransfer` **the entire** `balanceOf(this)` of `pairToken` / `rateAsset` to `msg.sender` / `recipient`. Not this-call unused. After fee-collect, that is a public skim of unbooked pair inventory (violates family PRD §6.4 “do not enrich the next depositor”).
2. **Zap-out share I1** — `pretransferred=true` burns `vaultShare` from `address(this)` with **no inbound share delta**, then transfers `maxSharesToBurn − sharesBurned` of self-shares to the caller. Local cousin of commons `_secureSelfBurn` (`SEC-COMMON-002`); Uni V3 does **not** inherit `BasicVaultCommon`.
3. **PAT-A0-EMPTY** — `deployVault(pool)` is unsown. First zap-in (`totalShares == 0`) mints `amount0Used + amount1Used` from **all** free inventory (donations included). Import remint uses `balanceOf` of both pair tokens the same way.

| Product | Residual risk | Worst open |
|---------|--------------:|------------|
| Uniswap V3 SE | **1** | Live PAT-I-ABS (clone WP) + E6 whole-balance refund + empty first mint + zap-out share burn |

| Severity | Count | Notes |
|----------|------:|-------|
| **Critical** | **0** | No forge this run (L-SEC-3). Static High max + `RUNTIME_UNPROVEN` |
| **High** | **5** | 3 new CODE (`SEC-SE-U3-002`, `003`, `004`); 2 **OWNED_ELSEWHERE** (`001` I-ABS, `006` I1–I3 tests) |
| **Medium** (clustered) | **6** | J2/J3 declaration-only; F1 theater; A1 token-refund theater; usage-fee spec drift; MultiAsset `R` never synced; import approve-vault sharp edge |
| **OWNED_ELSEWHERE** | **3** | `WP-I-CLONE-001` / `TCA-COMMON-004` / `SEC-COMMON-003` (I-ABS CODE + I tests + stale STAGE3 close) |

**Top recommended WPs:**

| Pri | WP-ID | Title |
|----:|-------|-------|
| — | **`WP-I-CLONE-001`** (reopen Uni V3 slice) | Delta-pretransfer on In/Out `_secureTokenTransfer` — **`gap_cover_*` only**; no `sec_fix_*` |
| 1 | **WP-SEC-E6-U3-001** | Cap `_refundRemainder` / `_refundRemainderTo` to this-call unused |
| 2 | **WP-SEC-I-U3-SHARE-001** | Zap-out: inbound `vaultShare` delta; leftover = this-call unused only |
| 3 | **WP-SEC-A0-U3-001** | Empty-supply / import cannot mint or refund donated pair inventory |
| — | *(collapse)* | After clone-slice merge, one `sec_fix_se-univ3` tree may take E6+share+A0 (same files) |

**OWNED_ELSEWHERE count:** **3** findings linked to `TCA-COMMON-004` / `WP-I-CLONE-001` / `SEC-COMMON-003`.

---

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|--------------:|
| **Uniswap V3 SE** | `UniswapV3StandardExchangeDFPkg` (9 cuts: ERC20, ERC5267, ERC2612, MultiAsset Basic **views**, MultiAsset Standard **views**, In, InQuery, Out, PositionImport); In Target+Facet (mutate + mint/swap callbacks); InQuery Target+Facet (`previewExchangeIn` only); Out Target+Facet; PositionImport Target+Facet; `UniswapV3StandardExchangeCommon` (pool ops, callbacks, ticks/wings, quotes — **does not** inherit `BasicVaultCommon`); `UniswapV3VaultRepo` / PoolAware / FactoryAware; `UniswapV3_Component_FactoryService` | Gold `TestBase_UniswapV3StandardExchange` (CREATE3 facets + `vm.prank(owner); indexedexManager.deployUniswapV3StandardExchangeDFPkg`); adversarial `TestBase_UniswapV3StandardExchange_Adversarial`; fork `UniswapV3StandardExchange_Fork.t.sol` (Base WETH/USDC 500) | **Gold:** CREATE3 + registry DFPkg + `pkg.deployVault(pool, widthMultiplier)` | **1** |

**Init / books:** `MultiAssetBasicVaultRepo._initialize([token0, token1])`; `StandardVaultRepo` + fee-oracle aware + Permit2 + factory/pool + `UniswapV3VaultRepo._initialize(widthMultiplier)` (`centerWidthMultiplier=2`, `activeLiquidityBps=1000`); ERC20 name `UniV3 Vault of (…)` / `UV3X` / 18. **No** `_syncAllExpectedHoldReserves` on routes reviewed — MultiAsset `R` stays bootstrap. Share math is `ConstProdUtils._depositQuote` / first-deposit `amount0Used + amount1Used` (not ERC4626; no `decimalOffset`).

**Trust-flag entrypoints:** `exchangeIn(..., pretransferred, deadline)`, `exchangeOut(..., pretransferred, deadline)`. Import has **no** `pretransferred` (NFT `transferFrom(owner, vault)`).

**Routes:** In swap (`pairToken`↔`rateAsset`); In zap-in (`pair` → `vaultShare`); Out swap exact-out; Out zap-out (`vaultShare` → one pair token); import NPM → center-only (empty NFT left on vault, D15).

**Not a DETF.** Role names on this SE: `rateAsset` / `pairToken` = pool `token0`/`token1`; `vaultShare` = `address(this)`; no `rebasingClaimToken`.

---

## 3. Threat models

### 3.1 Uniswap V3 SE

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn` swap | `pairToken` / `rateAsset` | `pretransferred` | `_requireNotDisabled` | **I-ABS:** credit vault inventory, swap to attacker (`recipient`) |
| EXT | `exchangeIn` zap-in | pair → `vaultShare` + leftover pair | `pretransferred`; then `_refundRemainder` both tokens | fee-first compound (no `feeTo` cut) | **I-ABS** + **E6** whole-balance refund of both pair tokens; **A0** on empty supply |
| EXT / CAP | `exchangeOut` swap | pair in → pair out | `pretransferred`; `_refundExcess(pull, used, **true**)` | quote+1bps buffer then refund | **I-ABS** funds exact-out from inventory; refund `pull−used` of leftover pair |
| EXT | `exchangeOut` zap-out | `vaultShare` → pair | `pretransferred` share burn from `this` | collect-all fees first (stay as free inventory) | Burn sitting self-shares; leftover `max−used` shares sent to caller |
| EXT | `importPosition(owner, recipient)` | NPM NFT + pair remint + `vaultShare` | ERC-721 approve(vault) | empty-only; D16 = NPM auth only | Frontrun if victim approved **vault**; leftover pair `_refundRemainderTo(recipient)` |
| EXT | `uniswapV3{Mint,Swap}Callback` | pair tokens to pool | `msg.sender == bound pool` | none | Spoof **blocked** (`_requireBoundPoolCaller`) |
| CFG | `deployVault(pool)` unsown | residual / donated pair | — | widthMultiplier ≥ 1 | Empty instance + donate + first zap-in / import |
| ADM | instance `diamondCut` | — | — | none in this package’s cuts | No owner/operator on instance in this tree; registry disable **is** wired |
| INT | router `pretransferred=true` + fat `amountIn`/`maxAmountIn` | pair / shares | refund to `msg.sender` (In remainder) / `recipient` (import) | — | Same I/E6; In refund **not** to `recipient` |
| HOS | FoT pair | pull `false` uses `B1−B0` | — | — | Pretransfer `true` still credits claimed (I4/L2) |

---

## 4. Catalog matrix (A–O, E6, F5)

Legend: **F** found/covered · **P** partial · **G** gap · **N/A** · **VULN** production appears exploitable.

| ID | Uni V3 SE | Evidence |
|----|-----------|----------|
| **A1** | **P** / theater | `test_A1_donation_doesNotGrantFreeSharesAsPrincipal` — share-only; **does not** assert pair-token refund. Subsequent honest zap-in runs `_feeFirstCompound` then `_refundRemainder` |
| **A2** | G | No donate-`vaultShare` idle suite |
| **A3** | P | `test_A3_feeTiming_tinyZapAfterFees` share bound only |
| **A0** | **VULN** | Empty `deployVault`; first zap-in `sharesOut = amount0Used + amount1Used` from live free inventory. No `test_A0_*` |
| **B1/B3** | N/A | No synthetic mint/burn thresholds |
| **B / L3** | P | Pass-through Uni V3 spot + `minOut`/`maxIn` = ACCEPTED_RISK. `test_B1_spotManip_noUnboundedFreeLunch` weak (`try/catch`, `1 wei` out) |
| **C1–C3** | F | `Adversarial_Reentrancy.t.sol` C1–C4 `IsLocked` on In/Out/import/callback |
| **D\*** (claim/NFT DETF) | N/A | Not a DETF. Import is SE bootstrap |
| **D import auth** | P / ACCEPTED | D16 locked: NPM/ERC-721 only. `test_D2` no-approval revert. No `owner ≠ msg.sender` + vault approved case |
| **E1** | P | `test_E1_roundTrip_zapInOut_conservation` — recovered `>0` and `≤ deposit` |
| **E5** | P | Deadline/zero on routes + `test_E2`. Bare `expectRevert` in several negatives |
| **E6** | **VULN** | `_refundRemainder` / `_refundRemainderTo` = **entire** `balanceOf`. Out `_refundExcess` = `pull−used` after I-ABS credit |
| **F1** | P / theater | `_requireNotDisabled` present. `test_F1` `try/catch` always `assertTrue(true)` |
| **F5** | N/A | No public migrate/reclaim; compound is internal `_feeFirstCompound*` |
| **G** | N/A | SE is not a nested DETF |
| **H2/H3** | P | Slippage atomic (`test_E3`, routes). Import H2/H3 exist |
| **I1** | **VULN** / **G** | Absolute credit on In/Out token pull; zap-out share burn from `this`. **No** `test_I1_*` |
| **I2** | G | Absolute short string revert only; no `claimed > U` |
| **I3** | G | No residual second-credit |
| **I4** | P | `false` path measures `B1−B0`. Product does not claim FoT |
| **I5** | N/A | Permit2 stored; pull is `safeTransferFrom` only (no SE witness) |
| **J1** | P | Static Target ⊆ `facetFuncs` for In (`exchangeIn`+callbacks), InQuery (`previewExchangeIn`), Out (preview+mutate), Import (preview+mutate). IFacet tests are **facet impl** only |
| **J2** | **G** | No loupe-on-proxy enumeration |
| **J3** | **P** | Routes/adversarial call **proxy** for money. No formal J3 control list. InQuery IFacet test **missing** |
| **K1** | P / policy | `_totalVaultReserves` = positions + `tokensOwed` (**excludes** free inventory). Honest zap-in compounds first. Unbooked free pair is then **refunded** (E6) or I-ABS-swapped |
| **L1** | **VULN** | Via E6 / I-ABS on pair tokens. Position LP not directly skimmed |
| **L2** | N/A | FoT not claimed |
| **L3** | P | See B |
| **M1–M3** | N/A | No user `target+calldata`. Import NPM address is caller-supplied but gated by pool match (D9/D14) |
| **N1** | P | Callbacks pool-auth + empty `bytes("")`. Import `decreaseLiquidity` `amount*Min=0` bounded by `minSharesOut` |
| **N2** | P | Preview suites exist (`UniswapV3StandardExchange_Previews.t.sol`). InQuery extra `vaultShare→pair` view is rate-provider only (mutate is Out) |
| **O1–O3** | N/A | ERC2612 on `vaultShare` only; no SE permit path |

---

## 5. Domain notes

Walked (evm-audit hunt lists, not a second ID space):

| Domain | What was walked | Notable hits |
|--------|-----------------|--------------|
| **general / access-control** | `nonReentrant` on In/Out/import; `_requireNotDisabled`; callbacks `msg.sender == pool`; no `onlyOwner` / `diamondCut` in this tree | F1 wired; F1 test theater. Disable is CROPS freeze that **works** if registry is set |
| **precision-math** | `ConstProdUtils._depositQuote`; first mint `used0+used1`; zap-out binary search + 1% buffer | First-deposit raw sum = A0. Reserves exclude free inventory (K vs PRD §6.4 “include free working inventory”) |
| **erc20 / erc4626** | Local pull clones; no ERC4626 facet. MultiAsset Standard = 4 **views** | PAT-I-ABS; no share-offset inflation defense |
| **defi-amm** | `pool.swap` / `mint` / `burn`+`collect max`; ZapQuoter; wings 10% center / 90% wings | Internal zap swap `minOut=0`; import `amount*Min=0` |
| **proxies / J / PAT-SLOT** | 9 DFPkg cuts; `UniswapV3VaultRepo` slot `keccak256("indexedex.protocols.dexes.uniswap.v3.vault")`; twin MultiAsset layout unused for pull | J1 static complete; J2/J3 gap. Callbacks only on **In** facet (Out/Import swap/mint still hit diamond → In) |
| **flashloans** | No flash callback surface; swap callback data empty | clean |
| **dos** | Unsupported routes revert; second import reverts; `widthMultiplier>=1` | H1 extreme width smoke |
| **CROPS** | Instance unowned in this package (no owner facet). Registry disable present. `updatePkg` is no-op `return true` | Walkaway: users can still `exchangeOut` unless disabled. Usage fee **not** taken on compound |
| **sharp-edges** | `pretransferred` caller-supplied; import `owner` + `approve(vault)`; `minAmountOut=0` common in tests | PAT-SHARP-FLAG; D16 locked |
| **spec-compliance** | Family `UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PRD.md` §6.4 / D16 / import `owner` | E6 refund contradicts “do not enrich next depositor”. Usage fee lock unimplemented. D16 accepts NPM-only import auth |
| **incidents** | Trust-flag free mint (I); surplus-refund `balance−0` (E6); empty-vault first minter (A0); NFT approval confusion | mapped |
| **ethskills-security** | SafeERC20; CEI on zap-out (burn then pay); callback auth | Refund **after** mint (CEI OK) but amount is wrong |

**PAT hunt (§2.4):**

| Pattern | Hit | Notes |
|---------|-----|-------|
| **PAT-I-ABS** | **YES** (live) | In L199–204; Out L262–267. **OWNED_ELSEWHERE** `WP-I-CLONE-001` |
| **PAT-E6-REFUND** | **YES** | In `_refundRemainder`; import `_refundRemainderTo`; Out `_refundExcess` after I-ABS |
| **PAT-A0-EMPTY** | **YES** | Unsown deploy + first zap-in / import remint from `balanceOf` |
| **PAT-K-DONATE** | Partial | Honest subsequent zap compounds first (A1 shares). Leftover / I-ABS still harvests |
| **PAT-L-SKIM** | **YES** | Via E6 / I-ABS on pair tokens |
| **PAT-J-OMIT / J-CTRL** | Unproven | Static selectors look complete; no loupe |
| **PAT-THEATER-PRE** | **YES** | `test_P_PRE_01_pretransferred_exactIn` transfers then claims |
| **PAT-THEATER-FACET** | **YES** | IFacet tests = impl metadata only |
| **PAT-F5-RESIZE** | No | |
| **PAT-M-CALL** | No arbitrary call. Import NPM allowlisted by pool match | |
| **PAT-N-TOCTOU** | Import/zap `min*=0` internals | `minSharesOut` / `minAmountOut` user-supplied |
| **PAT-O-SIG** | No SE ecrecover | |
| **PAT-CROPS-ADMIN** | No leftover owner on this package | Disable works if wired |
| **PAT-SPEC-DRIFT** | Usage fee; free inventory in NAV; “dust” vs whole-balance refund | |
| **PAT-SHARP-FLAG** | `pretransferred`; import `owner`; approve-vault | |
| **PAT-SLOT** | Unique V3 vault slot; MultiAsset unused for credit | |
| **PAT-MOCK** | No SUT mocks in this tree (gold TestBase) | |

---

## 6. Findings

### 6.1 [SEC-SE-U3-001] — Uni V3 `_secureTokenTransfer` still PAT-I-ABS

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U3-001` |
| **Title** | Re-verified live absolute-balance pretransfer on Uni V3 In/Out (do not re-own) |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high (source at this SHA) |
| **Catalog IDs** | I1–I3, L1 |
| **Pattern IDs** | PAT-I-ABS, PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | Trust-flag free mint |
| **Products** | Uniswap V3 SE |
| **Blast radius** | In Target swap + zap-in; Out Target swap (`_secureTokenTransfer` then `_refundExcess`). Commons-pull blast `SEC-COMMON-003` |
| **Attacker** | EXT (single tx); INT (router `pretransferred=true`) |
| **Attack scenario** | 1) Vault holds ≥ `amountIn` / `pullAmount` of `pairToken` or `rateAsset` (donation, uncompounded fees after zap-out collect, leftover). 2) Attacker calls `exchangeIn` or `exchangeOut` with `pretransferred=true` and **no** transfer. 3) `require(balanceOf >= amount); return amount` credits inventory. 4) In swap: `_swap(..., recipient)` pays `tokenOut` from that credit. 5) Out swap: `_swapExactOut` pays `amountOut` to `recipient`; `_refundExcess(pullAmount, used, true)` returns `pull−used` of remaining pair inventory. |
| **Preconditions** | Deployed Uni V3 SE with pair-token inventory ≥ claimed. Empty vault with no inventory reverts the require. |
| **Impact** | Free extract of unbooked **and** (because there is no `R` book) any sitting pair inventory, via swap or via Out refund. |
| **Evidence** | `UniswapV3StandardExchangeInTarget.sol` L195–210; `UniswapV3StandardExchangeOutTarget.sol` L258–273, call-site L91–102. Monorepo production `balanceOf(this) >=` pull helpers remain these two files (commons-pull). `test_P_PRE_01` L181–195 **transfers** then claims. No `test_I1_*` under `test/foundry/spec/protocol/dexes/uniswap/v3`. |
| **Runtime** | Not executed. Label N/A for class OWNED_ELSEWHERE. Stage 2 proof stays on `WP-I-CLONE-001`. |
| **Recommended CODE** | As `WP-I-CLONE-001`: reserve-delta or same-tx delta + `TransferDeltaInsufficient`; prefer inherit / `SecurePullLib`. **This program must not edit these helpers in a `sec_fix_*`.** |
| **Recommended TEST** | `test_I1_*` / `test_I2_*` / `test_I3_*` on **proxy** after clone CODE. `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v3/**' --match-test 'test_I'` |
| **Anti-theater** | I1: **no** in-call transfer; inventory already on vault; must not credit. |
| **Suggested WP-ID** | none new — **`WP-I-CLONE-001`** (`gap_cover_i-clones`). Reopen Uni V3 slice; STAGE3 close is stale. |
| **Link TCA / prior** | `TCA-COMMON-004`; `T-basic-protocol-commons.md` §2.3.B + §5.4; `SEC-COMMON-003`; `A-commons-pull.md` §2.2.C |
| **Depends / parallel** | Serial on In/Out Target files vs any `sec_fix` E6/A0/share WPs below. |

### 6.2 [SEC-SE-U3-002] — `_refundRemainder` transfers entire pair `balanceOf` to caller

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U3-002` |
| **Title** | Cap zap-in / import remainder refund to this-call unused pair tokens |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high / **RUNTIME_UNPROVEN** |
| **Catalog IDs** | E6, L1, K1, A1 |
| **Pattern IDs** | PAT-E6-REFUND, PAT-L-SKIM, PAT-SPEC-DRIFT |
| **EVM-audit domain** | erc20, defi-amm |
| **CROPS pillar** | n/a |
| **Incident theme** | Surplus-refund / `balance − floor` |
| **Products** | Uniswap V3 SE |
| **Blast radius** | `UniswapV3StandardExchangeInTarget._refundRemainder` (both pool tokens after every successful zap-in); `UniswapV3StandardExchangePositionImportTarget._refundRemainderTo` (both tokens after remint). Out `_refundExcess` is `pull−used` (E6-amplified by I-ABS; after clone fix it matches commons `max−used`) |
| **Attacker** | EXT (honest or hostile zap-in); INT |
| **Attack scenario** | 1) Vault holds unbooked `pairToken`/`rateAsset` (donation, zap-out `_collectManagedFees` left as free inventory, compound dust). 2) Attacker `exchangeIn(tokenIn, amountIn, vaultShare, …)` (even `pretransferred=false` with a real pull). 3) Optional `_feeFirstCompound` remints what the range can take. 4) Zap mints managed liquidity from **all** `balanceOf` pair tokens. 5) `_refundRemainder(token0); _refundRemainder(token1)` sends **whatever remains** of **both** tokens to `msg.sender` (not `recipient`). 6) Import path: empty vault + donated pair + tiny NFT → remint then `_refundRemainderTo` both balances to `recipient`. |
| **Preconditions** | Any live vault with leftover pair balances after mint/compound. Does **not** require `pretransferred=true`. Empty + donation is enough for import. |
| **Impact** | Skim of unbooked `rateAsset`/`pairToken`. Family PRD §6.4: do **not** enrich the next depositor with stranded fee/free inventory. “Dust refund matching Slipstream” is **dust**, not `balance − 0`. |
| **Evidence** | InTarget L161–162, L212–217: `balance = IERC20(token).balanceOf(address(this)); if (balance > 0) safeTransfer(msg.sender, balance)`. Import L141–143, L184–189 same to `recipient`. A1 adversarial L21–34 donates 50 ether then zap-ins 1 ether and only checks **shares** — cannot fail this class. |
| **Runtime** | Not executed. Proof-first: seed booked LP via honest zap; donate `rateAsset`; attacker tiny zap-in; assert attacker pair-token profit ≤ this-call unused (≈0 vs donation). |
| **Recommended CODE** | Snapshot `b0` per token after pull / before mint (or this-call unused = post-mint leftover **capped** by delivered unused). Never transfer `balanceOf(this)`. Leave unmintable prior inventory on the vault (or compound-only). Align import remint leftover the same way. |
| **Recommended TEST** | `test_E6_zapIn_doesNotRefundPriorDonation`; `test_E6_zapIn_refundsOnlyThisCallUnused`; `test_E6_import_doesNotSweepDonatedPairTokens`. `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v3/**' --match-test 'test_E6_'` |
| **Anti-theater** | Must donate ≠ attacker principal token/amount; must assert **token** deltas, not only shares (A1 is insufficient). Call **proxy**. |
| **Suggested WP-ID** | `WP-SEC-E6-U3-001` |
| **Link TCA / prior** | none for E6 CODE. Same **files** as `WP-I-CLONE-001` In Target (serial). Commons `_refundExcess` is blast-only. |
| **Depends / parallel** | **Serial** on In Target vs `WP-I-CLONE-001`. Parallel with import-only hunks. Serial with A0 on zap-in first-deposit. |

### 6.3 [SEC-SE-U3-003] — Zap-out `pretransferred` burns sitting `vaultShare` and refunds `max − used`

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U3-003` |
| **Title** | Require inbound `vaultShare` delta on zap-out; cap leftover to this-call unused |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high / **RUNTIME_UNPROVEN** |
| **Catalog IDs** | I1, E6, D, K1 |
| **Pattern IDs** | PAT-I-ABS (share path), PAT-E6-REFUND, PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | Trust-flag free redeem; surplus-refund |
| **Products** | Uniswap V3 SE |
| **Blast radius** | Out Target `_executeZapOutWithdrawal` only. **Not** commons `_secureSelfBurn` (Uni V3 does not inherit BVC) — do not fold into `WP-SEC-E6-COMMON-001` |
| **Attacker** | EXT; CFG two-tx share push; CAP donate `vaultShare` |
| **Attack scenario** | 1) Vault `balanceOf(this)` of `vaultShare` ≥ `sharesBurned` (victim two-tx push or donation). 2) Attacker `exchangeOut(vaultShare, maxShares, tokenOut, amountOut, attacker, pretransferred=true, deadline)` with **no** share transfer. 3) Preview burns `sharesBurned`; `ERC20Repo._burn(address(this), sharesBurned)` succeeds. 4) If `maxShares > sharesBurned` and self-balance still covers it, leftover shares are `_transfer`’d to `msg.sender`. 5) `tokenOut` (measured burn+swap) is paid to `recipient`. |
| **Preconditions** | Self-share balance ≥ `sharesBurned` (and ≥ `max` if leftover branch is taken). Atomic router that transfers shares in the **same** tx starting from 0 self-balance is safe. |
| **Impact** | Steal of sitting `vaultShare` + corresponding `pairToken`/`rateAsset` exit. Same class as `SEC-COMMON-002` but **local**. |
| **Evidence** | `UniswapV3StandardExchangeOutTarget.sol` L194–201. No `_secureSelfBurn` / share-delta check. `rg test_I` under Uni V3 spec empty. |
| **Runtime** | Not executed. Hermetic: transfer shares to vault; attacker `pretransferred=true` without transfer; assert revert **or** attacker share+pair deltas = 0. |
| **Recommended CODE** | Snapshot self-share `b0`; require `sharesBurned ≤ unbooked` (or same-tx delivered); burn `sharesBurned`; refund only `min(max−used, delivered−used)`. Never assume `address(this)` inventory is the caller’s. |
| **Recommended TEST** | `test_I1_zapOut_pretransferred_noShareDelivery_existingSelfShares_revertsOrNoExtract`; `test_E6_zapOut_doesNotSweepOtherUsersShares`. `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/**' --match-test 'test_I1_zapOut\|test_E6_zapOut'` |
| **Anti-theater** | I1 must **not** transfer shares in-call. Must redeem/exit, not only preview. |
| **Suggested WP-ID** | `WP-SEC-I-U3-SHARE-001` |
| **Link TCA / prior** | none (clone WP is token pull only). Peer: `SEC-COMMON-002` / `WP-SEC-E6-COMMON-001` is **blast**, different file. |
| **Depends / parallel** | Same Out Target as `WP-I-CLONE-001` token pull → **serial**. Parallel with In E6/A0 after Out merge. |

### 6.4 [SEC-SE-U3-004] — Empty vault first zap-in / import mints donated pair inventory (A0)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U3-004` |
| **Title** | Block empty-supply mint from unbooked pair inventory |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high / **RUNTIME_UNPROVEN** |
| **Catalog IDs** | A0, K1, A1 |
| **Pattern IDs** | PAT-A0-EMPTY, PAT-K-DONATE |
| **EVM-audit domain** | erc20, precision-math |
| **CROPS pillar** | n/a |
| **Incident theme** | Empty vault / first deposit drain |
| **Products** | Uniswap V3 SE |
| **Blast radius** | In Target first zap-in (`totalSharesBefore == 0`); Import remint (`available0/1 = balanceOf`) then share mint `amount0+amount1+tokensOwed` from **preview**, leftover via E6 |
| **Attacker** | EXT after donation; CFG unsown `deployVault(pool)` (the only deploy API) |
| **Attack scenario** | 1) `deployVault(pool)` — no seed. 2) Donate `pairToken`/`rateAsset` to diamond. 3) Attacker zap-in: `_feeFirstCompound` no-ops (`!_isPositionCreated`). 4) `available* = balanceOf` includes donation; mint uses it; `sharesOut = amount0Used + amount1Used`. 5) Attacker holds shares on donated inventory; `_refundRemainder` sends unused remainder. 6) Redeem via zap-out. Import: same `balanceOf` remint + leftover to `recipient`. |
| **Preconditions** | Unsown instance (product default). Donation or mis-routed pair tokens. |
| **Impact** | First minter / importer absorbs donated `rateAsset`/`pairToken`. Subsequent A1 test never hits empty+donate. |
| **Evidence** | InTarget L146–147, L132–133; Import L132–140, L173–174. DFPkg `deployVault` L267–271 takes only `pool` + `widthMultiplier`. No `test_A0_*`. |
| **Runtime** | Not executed. Hermetic: deploy; donate; attacker first zap-in; redeem; `assert` attacker pair profit ≤ 0 vs donation (donator ≠ attacker). |
| **Recommended CODE** | Before first mint/import remint: treat only this-call delivered amounts as mintable (or require `balanceOf == 0` before pull / NFT exit). Dead shares / reject `totalSupply==0 && freeInventory>0`. After I-ABS fix, still need an empty-supply gate. |
| **Recommended TEST** | `test_A0_donatePair_thenFirstZapIn_cannotRedeemDonation`; `test_A0_donatePair_thenImport_cannotSweepDonation`. |
| **Anti-theater** | Must redeem / import+refund; must not only assert “no immediate extra shares” on a **non-empty** vault (A1). |
| **Suggested WP-ID** | `WP-SEC-A0-U3-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Same In Target as E6 + clone WP → **serial**. Import A0 can land with E6 import hunk. |

### 6.5 [SEC-SE-U3-005] — Import `owner` + `approve(vault)` is a documented sharp edge (D16)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U3-005` |
| **Title** | Document (do not silently “fix”) NPM-only import authorization |
| **Severity** | **Medium** |
| **Class** | **ACCEPTED_RISK** / **NEEDS_OWNER** |
| **Confidence** | static-high (code + locked family PRD D16) |
| **Catalog IDs** | D, M, O |
| **Pattern IDs** | PAT-SHARP-FLAG |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | C (custody of approved NFT) |
| **Incident theme** | Approval / operator confusion |
| **Products** | Uniswap V3 SE |
| **Blast radius** | `importPosition(..., owner, recipient)` `transferFrom(owner, vault, tokenId)` |
| **Impact** | If a user `approve(vault, tokenId)` (or `setApprovalForAll(vault)`), **any** caller can import that NFT and mint `vaultShare` to their `recipient`. Family PRD D16 / §8.2 **locks** “no additional IndexedEx owner gate.” |
| **Evidence** | ImportTarget L106–107; PRD D16 + §8.3–8.4 interface includes `owner`. `test_D2` only covers missing approval. |
| **Recommended CODE** | None unless product owner revises D16 → `transferFrom(msg.sender)` / `msg.sender == owner`. |
| **Recommended TEST** | If D16 stays: NatSpec + UI “never approve the vault; approve a trusted router.” If revised: `test_D_import_ownerNotCaller_reverts`. |
| **Anti-theater** | Do not treat D2 as “import cannot be stolen under vault approval.” |
| **Suggested WP-ID** | none (`S-sharp-edges` consume) |
| **Link TCA / prior** | none |
| **Depends / parallel** | n/a |

### 6.6 [SEC-SE-U3-006] — Missing I1–I3 on Uni V3 proxy

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SE-U3-006` |
| **Title** | Uni V3 I1–I3 on production proxy after clone CODE |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed (no `test_I*` at this SHA) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 |
| **Products** | Uniswap V3 SE |
| **Blast radius** | Test-only; production pull owned by `WP-I-CLONE-001` |
| **Impact** | No SUT proof I1; happy `test_P_PRE_01` is anti-I1 |
| **Evidence** | `rg 'function test_I' test/foundry/spec/protocol/dexes/uniswap/v3` → empty. WP-I-CLONE-001 acceptance: “Per-product I1 green; Anti-theater: Proxy I1.” |
| **Recommended TEST** | As `WP-I-CLONE-001` product slice |
| **Anti-theater** | I1 no in-call transfer |
| **Suggested WP-ID** | `WP-I-CLONE-001` (no `sec_fix_*`) |
| **Link TCA / prior** | `TCA-COMMON-004` |
| **Depends / parallel** | After clone CODE |

### 6.7 Clustered Medium / Low / Info

| ID | Sev | Class | Title | Notes |
|----|-----|-------|-------|-------|
| **SEC-SE-U3-007** | Medium | TEST | J2/J3 missing; IFacet = declaration only | In/Out/Import IFacet tests check `facetFuncs` on **impl**. No loupe. No InQuery IFacet test. Static J1 looks complete (In: `exchangeIn`+2 callbacks; Query: `previewExchangeIn`; Out: preview+mutate; Import: preview+mutate). DFPkg cuts those `facetFuncs`. |
| **SEC-SE-U3-008** | Medium | THEATER | `test_F1_disabledVault_mutatesRevert` always passes | `try/catch` + `assertTrue(true)`. Production `_requireNotDisabled` is real — test does not prove it. |
| **SEC-SE-U3-009** | Medium | THEATER | A1/A3/E4 do not catch E6 | Share inequalities + `_assertNoUnexpectedFreeInventory` **after** remainder refund (free inventory is **supposed** to be 0 because it was sent to the caller). |
| **SEC-SE-U3-010** | Medium | NEEDS_OWNER / CODE | Usage fee on fee redeposit not taken | Family PRD §6.4 lock 3. `_feeFirstCompound*` remints 100% of free inventory; DFPkg declares `USAGE` fee type but no `feeTo` mint. |
| **SEC-SE-U3-011** | Medium | CODE / K | MultiAsset `R` initialized, never synced | Import PRD §8.3.7 “sync multi-asset vault reserves.” Views report empty books; pull ignores `R`. After clone WP, inheriting commons pull **without** sync would treat all live `B` as `U` (bootstrap I1). |
| **SEC-SE-U3-012** | Low | THEATER | Callback / deadline `expectRevert` bare | `Adversarial_CallbackAuth` / several E2/H. Exact selector preferred. |
| **SEC-SE-U3-013** | Info | ACCEPTED_RISK | AMM spot + `minOut=0` internals | User `minAmountOut` / `minSharesOut` is the bound. Sandwich = ACCEPTED. |
| **SEC-SE-U3-014** | Info | DEFER | L2 / I4 FoT | Product does not claim FoT. |
| **SEC-SE-U3-015** | Info | OWNED_ELSEWHERE | `STAGE3_PROGRESS.md` WP-I-CLONE-001 “closed” | Residual PAT-I-ABS still in tree. Stale close. |
| **SEC-SE-U3-016** | Info | ACCEPTED_RISK | D16 import `owner` param | See 6.5. |
| **SEC-SE-U3-017** | Info | ACCEPTED_RISK | ERC2612 on `vaultShare` only | No SE permit; O N/A. |
| **SEC-SE-U3-018** | Low | CODE hygiene | Out `_refundExcess(..., true, …)` hardcoded | Ignores caller flag; honest `false` path still refunds unused pull (UX OK). After I-ABS fix, keep refund = this-call unused only. |
| **SEC-SE-U3-019** | Low | TEST | InQuery `vaultShare→pair` preview has no In mutate | Rate-provider parity (comment L42–43). Execute is `exchangeOut`. |
| **SEC-SE-U3-020** | Info | ACCEPTED_RISK | Empty NFT left on vault (D15) | Inert; cannot second-import (`test_H3`). |

---

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|-----------------------------|-----|
| `test_P_PRE_01_pretransferred_exactIn` | Transfers full `amountIn` then `pretransferred=true` — honest UX only | `test_I1_*` zero transfer + inventory |
| `test_A1_donation_*` / `test_A3_*` | Asserts attacker **shares** ≪ incumbent; never checks pair-token refund or empty+donate redeem | `test_E6_*` + `test_A0_*` |
| `_assertNoUnexpectedFreeInventory` | Passes **because** `_refundRemainder` already swept free pair to caller | Assert **caller** did not receive donated inventory |
| `test_F1_disabledVault_*` | Both success and revert `assertTrue(true)` | Exact `VaultDisabled` on proxy after `setVaultAddressDisabled` |
| `*_IFacet_Test` | Facet **address**, not diamond loupe / proxy smoke | J2 loupe + J3 `exchangeIn`/`Out`/`import`/`preview` on **proxy** |
| `test_D2_importWithoutApproval` | Does not cover `owner≠caller` + vault approved | Document D16 or add negative if law changes |
| `test_B1_spotManip_*` | `try/catch` zap-out; `1 wei` minOut; “bounded” by deposit size | Not an I/E6 proof |
| STAGE3 “WP-I-CLONE-001 closed” | Uni V3 absolute pull still in tree | Reopen clone slice |
| Commons-pull “defer to A-se-v3-v4-lending” | Partition split this area | This file is the owner for Uni V3 residual **except** I-ABS CODE |

---

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| **TCA-COMMON-004** / **WP-I-CLONE-001** | **Yes** — `UniswapV3StandardExchange{In,Out}Target._secureTokenTransfer` + product I1 | **OWNED_ELSEWHERE**. WP already describes the **delta-pretransfer CODE** for these exact files. STAGE3 close **stale**. Do **not** `sec_fix` the pull helper. |
| **SEC-COMMON-003** / `A-commons-pull` §2.2.C | Blast listing of this package | Cited; this area confirms live. Commons must not schedule `sec_fix_*`. |
| **WP-I-COMMON-001/002** | Commons helper only | Not this package (Uni V3 does **not** inherit BVC). |
| **WP-I-CLONE-UAB-001** | Uni **V4** SE / Aave | Out of area. |
| **WP-I-SE-AC-001** / **WP-J-SE-AC-001** | Aero/Camelot/Uni **V2** | Out of area. |
| **WP-SEC-E6-COMMON-001** | Commons `_secureSelfBurn` | Blast only; Uni V3 share burn is **local** (`SEC-SE-U3-003`). |
| **WP-SEC-E6-SE-001** (amm-v2) | Aero/Camelot/Uni V2 Out Targets | Explicitly out of that WP. Uni V3 E6 is **this** program. |

**Still new (this program):** `SEC-SE-U3-002` (E6 remainder), `SEC-SE-U3-003` (share I1), `SEC-SE-U3-004` (A0), plus Medium J/F1/usage-fee/MultiAsset sync.

---

## 9. Work package stubs

### WP-SEC-E6-U3-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-E6-U3-001` |
| **Title** | Cap Uni V3 remainder refund to this-call unused pair tokens |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V3 SE |
| **Finding IDs** | SEC-SE-U3-002 |
| **Problem** | Zap-in and import transfer **entire** `balanceOf` of both pool tokens to the caller/recipient, skimming donations and uncompounded fees. |
| **Production files (touch set)** | `contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeInTarget.sol`; `…/UniswapV3StandardExchangePositionImportTarget.sol` |
| **Test files (touch set)** | `test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/Adversarial_Donation.t.sol` (extend); new `Adversarial_E6Refund.t.sol` or equivalent |
| **Out of scope files** | `BasicVaultCommon.sol`; Out Target refund-after-I-ABS (clone WP); Uni V4 / Slipstream |
| **Depends on** | Prefer land **after or inside** `WP-I-CLONE-001` Uni V3 slice (same In Target). Import file is **not** in the clone list. |
| **Parallelizable with** | Share-burn WP (Out file); A0 after merge plan on In Target |
| **Conflicts with coverage-audit WP** | **Soft serial** on `UniswapV3StandardExchangeInTarget.sol` vs `WP-I-CLONE-001`. Do not parallel `gap_cover_i-clones` on that file. |
| **Suggested worktree** | `sec_fix_se-univ3` / `sec_fix/se-univ3` (collapse E6+A0+share per L-SEC-13 **after** clone-slice idle) |
| **Implementation notes** | Refund `min(leftover, thisCallUnused)`. Skills: indexedex-testing gold TestBase. DETF role names in tests. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v3/**' --match-test 'test_E6_'` — donated pair stays on vault or compounds to incumbents; attacker token profit ≤ this-call unused |
| **Anti-theater checks** | Proxy; token deltas; donator ≠ attacker |
| **Proof-first?** | yes |
| **Estimate** | M |

### WP-SEC-I-U3-SHARE-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-I-U3-SHARE-001` |
| **Title** | Zap-out pretransfer: credit only inbound `vaultShare` delta |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V3 SE |
| **Finding IDs** | SEC-SE-U3-003 |
| **Problem** | `pretransferred=true` burns self-shares without delivery and may transfer `max−used` leftover shares to the caller. |
| **Production files (touch set)** | `contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeOutTarget.sol` (`_executeZapOutWithdrawal` burn/refund only) |
| **Test files (touch set)** | `test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/**` |
| **Out of scope files** | `BasicVaultCommon._secureSelfBurn`; In Target |
| **Depends on** | Serial vs `WP-I-CLONE-001` on the same Out file (pull helper vs burn branch — merge if both open) |
| **Parallelizable with** | E6 import hunk; not In Target A0 |
| **Conflicts with coverage-audit WP** | Soft serial on Out Target vs clone WP |
| **Suggested worktree** | `sec_fix_se-univ3` (same tree) |
| **Implementation notes** | Mirror commons intended share-delta law; do **not** edit BVC here. |
| **Acceptance** | `forge test --match-test 'test_I1_zapOut\|test_E6_zapOut'` — no extract without share delivery |
| **Anti-theater checks** | No in-call share transfer on I1 |
| **Proof-first?** | yes |
| **Estimate** | S–M |

### WP-SEC-A0-U3-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-A0-U3-001` |
| **Title** | Empty-supply / import cannot absorb unbooked pair inventory |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Uniswap V3 SE |
| **Finding IDs** | SEC-SE-U3-004 |
| **Problem** | First zap-in and import remint treat all free `balanceOf` as the minter’s contribution. |
| **Production files (touch set)** | In Target first-deposit branch; Import remint `available0/1` |
| **Test files (touch set)** | adversarial `test_A0_*` |
| **Out of scope files** | Commons; V4 |
| **Depends on** | Serial with E6 on same functions |
| **Parallelizable with** | Share-burn (Out) |
| **Conflicts with coverage-audit WP** | Soft serial on In Target vs clone WP |
| **Suggested worktree** | `sec_fix_se-univ3` |
| **Implementation notes** | Mint only this-call delivered; reject leftover free inventory at `totalSupply==0`. |
| **Acceptance** | `forge test --match-test 'test_A0_'` — donator≠attacker; redeem/import profit ≤ 0 vs donation |
| **Anti-theater checks** | Must redeem / import leftover; not A1-on-live-vault |
| **Proof-first?** | yes |
| **Estimate** | M |

**Do not schedule `sec_fix_*` for:** `WP-I-CLONE-001` (I-ABS pull + I1–I3 tests), `WP-I-COMMON-*`, `WP-SEC-E6-COMMON-001`, amm-v2 E6.

**Stage 2 merge note:** If `gap_cover_i-clones` is abandoned, **one** `sec_fix_se-univ3` may take I-ABS + E6 + A0 + share (then drop OWNED_ELSEWHERE on `001`/`006` in the remediation PRD). Until then, L-SEC-4 stands.

---

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Note |
|------|-------|------|
| DETF B1/B3 / claim D / nested G | N/A | Not a DETF |
| F5 public reclaim | N/A | Compound internal |
| M\* arbitrary calldata | N/A | NPM address constrained by pool match |
| O\* SE signatures | N/A | ERC2612 on share token only |
| Import auth without `msg.sender==owner` | ACCEPTED_RISK / NEEDS_OWNER | Locked D16 |
| Usage fee on fee compound | NEEDS_OWNER | PRD §6.4 lock 3 unimplemented |
| Include free inventory in NAV (`_totalVaultValue` vs `_totalVaultReserves`) | NEEDS_OWNER | PRD §6.4 vs code; interacts with E6 |
| FoT I4/L2 | DEFER | Not claimed |
| Full MEV sandwich on `minOut=0` internals | DEFER / ACCEPTED | User min bounds |
| Uni V4 / Slipstream / DETF | out of area | |
| Commons pull / `_secureSelfBurn` body | `A-commons-pull` | Local clones owned here except I-ABS helper |
| Runtime proof of High CODE | Stage 2 proof-first | No forge this subagent |
| `via_ir` | forbidden | not recommended |

---

## 11. Commands run

Static review only. **No `forge` / `solc`** (L-SEC-3 / forge patience). No production or test `*.sol` edits.

```bash
# Inventory
ls contracts/protocols/dexes/uniswap/v3/
ls test/foundry/spec/protocol/dexes/uniswap/v3/
ls test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/
ls test/foundry/fork/base_main/protocol/dexes/uniswap/v3/

# Pattern / catalog greps
rg -n --glob '*.sol' 'pretransferred|_secureTokenTransfer|_refundRemainder|_refundExcess|function facetFuncs|onlyOwner|diamondCut|uniswapV3SwapCallback|_requireNotDisabled' \
  contracts/protocols/dexes/uniswap/v3

rg -n 'function test_I|test_J|test_A0|test_E6|pretransferred|_refundRemainder' \
  test/foundry/spec/protocol/dexes/uniswap/v3

rg -n 'WP-I-CLONE-001|UniswapV3|_secureTokenTransfer|_refundRemainder' \
  docs/testing/coverage-audit docs/security/audit/areas/A-commons-pull.md
```

Seeds re-read: `docs/security/audit/areas/A-commons-pull.md` §2.2.C / §6.3; `docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md` WP-I-CLONE-001; `docs/testing/coverage-audit/areas/T-basic-protocol-commons.md` §2.3.B / TCA-COMMON-004; family `UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PRD.md` D16 + §6.4.
