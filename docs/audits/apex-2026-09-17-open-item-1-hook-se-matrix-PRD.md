# PRD: Hook × Standard Exchange matrix (APEX open item 1, D20 / R10.3)

- **Parent plan:** [apex-2026-09-17-remediation-and-regression-tests.plan.md](./apex-2026-09-17-remediation-and-regression-tests.plan.md) (D20, D26, R10.3, R14 table)
- **Open-items file:** [apex-2026-09-17-review-open-items.md](./apex-2026-09-17-review-open-items.md) item 1
- **Evidence to update:** `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json`, `docs/audits/apex-2026-09-17-evidence.md`, `acceptance.json` R10.3
- **Created:** 2026-09-20
- **Status:** executed 2026-09-21; findings F1 to F7 ruled and closed or reclassified 2026-09-21 to 2026-09-22 (D50 to D60), F8 recorded 2026-09-22; M14 decimal rows written 2026-09-23 for the two fixtures that can vary the face (28 rows), with per-leg SE addresses and face decimals recorded per row (A9 / A10); see the evidence file sections "Gap 1 execution", "D60 work packages 2 to 5" and "Gap 4"
- **Execution boundary:** tests, test harnesses and evidence only. No production source change is expected. A row that exposes a production defect is reported as a finding and fixed under a separate request; it is not patched around in the harness.

## 1. Objective

Replace the 146 placeholder `test_INCOMPATIBLE_*` matrix files with executed integrations that bind each of the seven Standard Exchange buffer-hook families to every current D16 SE package through the package's own deployment path, run the R10.3 controls on every row, and record `INCOMPATIBLE` only where a named production check is asserted. The matrix must leave no unexplained missing package row and count no incompatible row as a passing integration.

## 2. Current state (verified 2026-09-20)

| Fact | Evidence |
| --- | --- |
| All 147 files `test/foundry/spec/hooks/uniswap/v4/standardExchange/<hook dir>/<Prefix>_SeMatrix_<SeFamily>.t.sol` exist (7 hooks × 21 SE names, including the `SimpleYieldERC4626Control` row). | `ls` of the seven hook test directories |
| 146 files contain one `test_INCOMPATIBLE_*` that deploys the SE on fresh fixture tokens unrelated to the hook's face tokens, then asserts the resulting package-init revert (`TokenNotInVaultTokens`, `InvalidSE`, `InvalidDecimals`, or a bare `expectRevert()`). | e.g. `dual/UniswapV4DualSEBCPHook_SeMatrix_LidoWstETHStandardExchange.t.sol`, `SeMatrix_LidoDeploy.sol` deploys a new `HermeticWETH` |
| The six `<Prefix>_SeMatrix_ERC4626StandardExchange.t.sol` files for orbital, weighted, curve-quad, Balancer-quad, single-CP and dual run two real tests: `test_bufferFirst_restingFace_notPaidToJoiner` and `test_underConsumption_leaveDust_doesNotPayCaller`. | those files |
| The 21 non-CP `single/` rows, including the ERC-4626 and SimpleYield controls, inherit `TestBase_ERC4626StandardExchange`, deploy a Crane ERC-4626 diamond with the receipt-backed facet and expect `UnsupportedAccountingFamily`. They never touch the non-CP hook. | `single/UniswapV4SingleSEBufferHook_SeMatrix_*.t.sol` |
| Hook packages take face tokens and SEs as explicit arguments: weighted `tokens[] / standardExchanges[] / tokenDecimals[] / seDecimals[]`, curve-quad and Balancer-quad the same as fixed-4 or dynamic arrays, orbital `token0..2 / se0..2 / decimals0..2`, single-CP `standardExchange / pairToken / rawToken / *Decimals`, dual `standardExchange0 / token0 / standardExchange1 / token1`, non-CP `standardExchange / pairToken`. | the six `I*HookPackage.sol` interfaces |
| Hooks buffer a face token by `forceApprove(se, amount)` then `IStandardExchangeIn(se).exchangeIn(face, amount, IERC20(se), …, false, …)`, and unwrap by `exchangeIn(IERC20(se), shares, face, …)` or `exchangeOut(IERC20(se), cap, face, amountOut, this, false, …)`. Hooks never use `pretransferred=true` toward the SE. | weighted `HookTarget.sol` `_bufferToken`, single-CP `HookSeTarget.sol` `_bufferPair`, orbital `_unwrapExactTokenOut` |
| Every hook binds `IERC20(se)` as the share token. | D20 note in the plan; hook Commons |
| Decimal validation at package init: face token decimals 6 to 18 (or 19 to 36 on a wrapper-share inventory leg); SE decimals 6 to 36 and equal to `IERC20Metadata(se).decimals()`; face token decimals must equal the declared value. | weighted `DFPkg.sol` lines 396 to 432; the other families share `UniswapV4SeBufferHookLegLib.wrapperShareDecimalsOk` |
| Camelot SE shares are reserve decimals plus 9 (27 for 18-decimal reserves); custody wrapper shares are asset decimals plus the configured offset. Both are inside 6 to 36. | `CamelotV2StandardExchangeDFPkg.sol:565`, `RebasingAwareERC4626Common.sol:71` |
| The Balancer pool SE diamonds are their own BPT (`IERC20(address(this)).totalSupply()` is the pool supply; the Vault mints the diamond's token on `addLiquidity`). | `BalancerV3PoolStandardExchangeTarget.sol:80,165,209` |
| The standalone `BalancerV3SinglePoolStandardExchange` issues an external `bptToken()`; it has no matrix file by decision. | plan D20 / R10.3 |
| Balancer buffer-pool packages constructed under a hook TestBase hit `ReentrancyGuardReentrantCall()` on `router.initialize` (nested vault lock). The existing stubs skip `_initPool` for that reason. | plan Deviations |

Conclusion: the stubs are unimplemented placeholders, not demonstrated incompatibilities. Every SE family in the list is expected to bind to every hook family once the hook is faced on a token the SE accepts and the declared decimals match.

## 3. Locked decisions

| ID | Decision |
| --- | --- |
| M1 | Keep the D26 file names and locations. Replace stub bodies; do not add a second file per row. |
| M2 | Compatibility is decided by production, not by the harness. A row is `INCOMPATIBLE` only when the test asserts the exact production error selector at the exact production site (package init, first buffer, first unwrap) and the file comment names the constraint. A real technical limitation that prevents implementing the row is recorded the same way, with the limitation named (owner decision 2026-09-20). A bare `vm.expectRevert()` is not an incompatibility proof. |
| M3 | The hook is faced on the SE's native input token. The SE is deployed on its own protocol fixture (hermetic ports for Lido, Rocket, EtherFi, Morpho; the real Crane Aave pool for Stata and the cross-version loop; real Uniswap V2/V3/V4, Camelot, Aerodrome, Slipstream and Balancer V3 deployments for the AMM and pool families) and the hook `PkgArgs` leg under test uses that token and that SE. The SE is never redeployed on the hook TestBase's throwaway tokens. |
| M4 | Multi-leg hooks (orbital 3, curve-quad 4, Balancer-quad 4, weighted n) use the SE family under test on every SE leg: one SE instance per leg, each deployed on that leg's face token through the family's package. Dual binds the family on both legs. Single-CP and non-CP bind it on their single SE leg. No ERC-4626 control legs are mixed into a family row (owner decision 2026-09-20). |
| M5 | One abstract behavior contract per hook family, `<Prefix>_SeMatrixBehavior.sol` beside the matrix files, owns the deployment glue and the row test bodies. Each `<Prefix>_SeMatrix_<SeFamily>.t.sol` is a thin concrete file that supplies the SE fixture (face token, SE address, decimals, R14 partial-consumption trigger) through virtual hooks. This keeps 147 rows to seven behavior implementations plus 21 SE fixture adapters. |
| M6 | One SE fixture adapter per SE family, `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_<Family>Fixture.sol`, replacing today's `SeMatrix_<Family>Deploy.sol` libraries. The adapter deploys the SE through its real package or CREATE3 path, exposes `faceToken()`, `se()`, `faceDecimals()`, `seDecimals()`, `fund(address,uint256)`, `openCapacity()` / `closeCapacity()` (the R14 case), and `seedLiquidity()` where the SE needs a live position before it can quote. |
| M7 | Every executed row runs the full row test set in §6. A row whose SE has no R14 leftover case (Morpho, Balancer native BPT, custody) runs the rounding-to-zero control in place of the partial-consumption control. |
| M8 | Hook-side pretransfer controls use `contracts/test/stubs/AtomicPretransferCaller.sol` for the contract path and a plain `vm.prank` EOA for the rejection path (D9, D27). No new fixture types. |
| M9 | `SimpleYieldERC4626Control` rows stay as controls and follow the same behavior contract; they are not counted toward D16 coverage. |
| M10 | Balancer-in-Balancer nesting is out of scope (owner decision 2026-09-20). A Balancer V3 pool whose Standard Exchange leg is itself a Balancer-hosted vault on the same Vault cannot be seeded or operated without re-entering the Vault's transient reentrancy guard; this is an external protocol limitation, not a product defect. The matrix therefore never composes such a stack: the six Balancer buffer-pool SE fixtures use non-Balancer SE legs (the ERC-4626 control or the family's existing pool TestBase legs), are deployed through their package (whose `postDeploy` registers the pool) and seeded with `router.initialize` before the hook is deployed, exactly as the pool TestBases do. Any row that would require a Balancer vault as the SE leg of a Balancer pool is recorded `INCOMPATIBLE` with the named limitation `Balancer V3 Vault ReentrancyGuardTransient (nested pool)`. No production change and no package-level initial deposit. |
| M11 | No production source, `foundry.toml`, `out/` or `cache_forge/` layout change. No `via_ir`. New test contracts must compile without stack-too-deep under the current settings; split helpers rather than change compiler settings. |
| M13 | Reduced quantity for the heavy families (owner decision 2026-09-20): Aave V3 Stata, Aave Cross-Version Loop and the six Balancer buffer-pool packages are executed against one hook family, the single-CP hook (`UniswapV4SingleStandardExchangeBufferConstantProductHook`, the production DETF reserve hook). Their other six rows keep a one-line `test_DEFERRED_<reason>` marker and are recorded `DEFERRED` in the evidence, never `INCOMPATIBLE` or `COMPATIBLE`. The light families (ERC-4626, Morpho, custody, Uni V2, Camelot, Aerodrome, Slipstream, Lido, Rocket, EtherFi, FullSpread V3/V4) run all seven hook families. |
| M14 | Face-token decimals (owner decision 2026-09-20): every executed row also runs on the hook family's existing `_Decimals` TestBase, with 6- and 9-decimal test ERC-20 face tokens in the combinations that TestBase already enumerates. SE share decimals are not varied. Families whose face token is a protocol token with fixed decimals (Lido, Rocket, EtherFi on `HermeticWETH`) run at 18 only and record that. Stata uses the existing 6-decimal `usdx` and 9-decimal `NINE` markets of `TestBase_AaveV3StataStandardExchange_Decimals`; the loop uses `TestBase_AaveCrossVersionLoop_Decimals`. Decimal rows live under `<hook dir>/decimals/` as `<Prefix>_SeMatrix_<SeFamily>_<Combo>.t.sol`, following the repository's existing combo naming. |
| M12 | Evidence: `hook-se-matrix.json` gains one record per row with `state` in `COMPATIBLE | INCOMPATIBLE | BLOCKED | DEFERRED`, the exact test names, the asserted production error for non-compatible rows, and the log name. `apex-2026-09-17-evidence.md` "Still open" item 1 is rewritten from the JSON. |
| M15 | SE transition-quote conformance (owner decision 2026-09-24, plan D68). Buffered hooks project an SE's state for wei-exact multi-step previews through `IStandardExchangeTransitionQuote` (`quoteState` `0x844c633c`, interfaceId `0x185ec0ef`) — a third interface beyond `IStandardExchangeIn`/`IStandardExchangeOut`, needed because a `view` preview cannot persist intermediate state (no SSTORE/TSTORE under STATICCALL) and so must thread an opaque encoded state struct through each step. **Every SE Vault must implement it** to be fully bufferable (alongside In/Out and the external ERC-4626 / ERC-5115 / Pendle-SY set). Verified 2026-09-24: the six Balancer V3 buffer-pool SEs are the only family that does not, which is the true cause of their R10.3 DEFERRALs on the five non-single-CP hooks — not the M13 scoping alone. Symptom: orbital reverts `NoTargetFor(quoteState)`; dual degrades via its `supportsTransitionQuote`/`supportsInterface(0x185ec0ef)` guard. Decision: implement the interface on the Balancer pool SE family (a shared transition-quote target mirroring `BalancerV3PoolStandardExchangeTarget._previewPoolLiquidity` via `BasePoolMath`, invariant through `IBasePool(address(this))` on projected balances; wired into all six packages with ERC-165 registration). The facet is MANDATORY: each package requires `transitionQuoteFacet` (reverts if omitted) and wires it and `0x185ec0ef` unconditionally, so a Balancer pool SE cannot be deployed without the transition-quote surface. This lifts the 30 Balancer DEFERRALs (5 hooks × 6 families) to executed/gold once landed; the 12 Aave × hook DEFERRALs remain under M13 pending multi-reserve fixtures. This supersedes, for the Balancer buffer-pool families, the part of M13 that treated their non-single-CP rows as permanently deferred. **Completed and verified 2026-09-24:** all six `*StandardVaultPkg` constructors revert (`TransitionQuoteFacetRequired`) when the facet is codeless, size their interface (19) and facet-address (12) arrays unconditionally, and always register `0x185ec0ef`; six `*_FactoryService` gained a `deployTransitionQuoteFacet` CREATE3 helper; all `PkgInit` callers pass it. Full hermetic run 19 green (3,013 suites, 34,316 passed, 0 failed, exit 0). SE matrix re-classified from the complete run-19 log: 141 COMPATIBLE, 24 DEFERRED, 3 INCOMPATIBLE, 7 DEPRECATED, 0 FAILING, 0 BLOCKED — the 18 Balancer transition-quote cells moved DEFERRED→COMPATIBLE. Of the 30 Balancer cells, 18 are now gold and 12 stay DEFERRED for distinct execution gaps (single-noncp custody `TransferFromFailed` ×6, balancer-quad `Slippage()` ×6), separate from the transition-quote surface. R12: 565 compared, 0 oversize, the six packages add only `+TRANSITION_QUOTE_FACET()`. |
| M16 | R10.3 closed (owner decision 2026-09-24/25, plan D69). Every hook x SE matrix cell must be COMPATIBLE or INCOMPATIBLE; no cell stays DEFERRED. The 24 DEFERRED cells (run 19) were all resolved and verified in full hermetic run 21 (34,532 passed, 0 failed) — final matrix 165 COMPATIBLE / 3 INCOMPATIBLE / 7 DEPRECATED (owner-retired Slipstream) / 0 DEFERRED-BLOCKED-FAILING. Resolution: 12 Balancer cells via production hook execution fixes (single-noncp SE-share approval on unwrap; balancer-quad buffered-leg join = min(round-up share inversion, provided amount)); 5 Aave cells via multi-leg fixtures (backward-compatible salt discriminator, disc 0 = canonical address, so launch/production addresses unchanged); 3 Stata + 4 Loop cells via new SE feature routes — a wrap-exact-out (mint) route on both the Stata and cross-version-loop SEs, and IStandardExchangeTransitionQuote on the loop SE (projecting the leveraged position with execution's conservative floor/ceil math for wei-exact previews). The D61 borrow-headroom safety invariant is preserved (loop production suite 312 tests green, no assertion loosened). This supersedes M13's deferral of the heavy families on multi-leg hooks and completes M15's product law (every SE Vault implements IStandardExchangeTransitionQuote) for the loop SE. Acceptance R10.3 -> EVIDENCED (108/108). |

## 4. Scope

**In.** The 147 base rows (with the M13 reduction: 12 light families × 7 hooks = 84 executed rows, 8 heavy families × 1 hook = 8 executed rows, 48 `DEFERRED` markers, 7 control rows) plus the M14 decimal combinations for each executed row: seven hook families × the 21 SE names in the existing file set (`AaveCrossVersionLoop`, `AaveV3StataStandardExchange`, `AerodromeStandardExchange`, `CamelotV2StandardExchange`, `CommonBufferMultiVaultStablePool`, `CommonBufferMultiVaultWeightedPool`, `ERC4626StandardExchange`, `EtherFiWeETHStandardExchange`, `LidoWstETHStandardExchange`, `MixedBufferMultiVaultStablePool`, `MixedLegWeightedBufferPool`, `MorphoBlueStandardExchange`, `MultiPairStandardExchangeBufferPool`, `RebasingAwareERC4626`, `RocketPoolRETHStandardExchange`, `SimpleYieldERC4626Control`, `SlipstreamStandardExchange`, `StandardExchangeBufferPool`, `UniswapV2StandardExchange`, `UniswapV3FullSpreadStandardExchangeVault`, `UniswapV4FullSpreadStandardExchangeVault`). The seven behavior contracts and 21 fixture adapters. Evidence updates.

**Out.** The standalone Balancer adapter (decided incompatible, no file). Any production change. Non-SE swap hooks under `contracts/hooks/uniswap/v4/{orbital,weighted,stable/quad/*}`. Fork-only evidence. The three invariant campaigns of open item 2.

## 5. Per-SE-family fixture requirements

Face token is the token the hook leg uses and the SE accepts as `tokenIn` with `tokenOut == se`. "R14 case" is the partial-consumption trigger from the plan's R14 table. "Base" is the existing TestBase whose deployment code the adapter reuses; adapters must not reimplement package wiring.

| SE family | Face token | Base to reuse | R14 case (control trigger) | Notes |
| --- | --- | --- | --- | --- |
| ERC4626StandardExchange | underlying (18-dec `SimpleMintableERC20`) | `TestBase_ERC4626StandardExchange` | `CappedPausableERC4626.setDepositCap` / `setPaused` | Existing six real rows are the template; extend them to §6 and add the non-CP row. |
| SimpleYieldERC4626Control | underlying | same | rounding-to-zero control | Control only. |
| MorphoBlueStandardExchange | loan token | `TestBase_MorphoBlueStandardExchange` (hermetic Morpho) | none; rounding-to-zero control | Hard `supply`; zero leftover. |
| RebasingAwareERC4626 | configured asset (hermetic rebasing token) | `TestBase_RebasingAwareERC4626` | none; rounding-to-zero control | Asset pretransfer is rejected on the SE (`AssetPretransferNotSupported`); the hook uses the pull route, so this does not affect binding. Share decimals = asset decimals + offset; pass that as `seDecimals`. |
| UniswapV2StandardExchange | pair token A | `TestBase_UniswapV2StandardExchange_MultiPool` | exact-out quote leftover; unpaired remainder held (D33) | Both pair tokens are valid faces; test token A. |
| CamelotV2StandardExchange | pair token A | `TestBase_CamelotV2StandardExchange` | same as Uni V2 | `seDecimals` = reserve decimals + 9 (27). |
| AerodromeStandardExchange | pair token A | Aerodrome V1 TestBase (`test/foundry/spec/protocol/dexes/aerodrome/v1/`) | same as Uni V2 | Volatile pool; router created through the factory as in `SeMatrix_AerodromeDeploy.sol`. |
| SlipstreamStandardExchange | pool token0 | `TestBase_SlipstreamStandardExchange` | exact-out quote leftover; unpaired zap remainder booked | Hermetic CL book. |
| LidoWstETHStandardExchange | `HermeticWETH` | `TestBase_LidoWstETHStandardExchange` (or the Lido adversarial base) | `HermeticStETH.setStakeLimit` / `setStakingPaused` (only affects `rebalance` and `exchangeInEth`; WETH→SE credits the sleeve, so the hook row's partial case is the sleeve itself: assert `liquidReserveEth` grows by the buffered amount and no stake happens) | D47. |
| RocketPoolRETHStandardExchange | `HermeticWETH` | `TestBase_RocketPoolRETHStandardExchange` | `HermeticDepositPool.setMaxDepositAmount`, `HermeticRocketDAOProtocolSettingsDeposit.setMinimumDeposit` | Default 20% sleeve; D39 minimum. |
| EtherFiWeETHStandardExchange | `HermeticWETH` | `TestBase_EtherFiWeETHStandardExchange` | `HermeticLiquidityPool.setPaused` / `setPausedUntil` / blacklister | D40. |
| AaveV3StataStandardExchange | Aave underlying (WETH, 18-dec variant) | `TestBase_AaveV3StataStandardExchange_Decimals` with `_underlyingDecimals() == 18` | `IPoolConfigurator.setSupplyCap(underlying, 1)` after a first deposit (see `AaveV3StataStandardExchange_APEX_R14.t.sol` `_setSupplyCap`) | Heavy setup (full Aave market). Consider one shared fixture instance per test contract. |
| AaveCrossVersionLoop | tokenA (18-dec) | `TestBase_AaveCrossVersionLoopV3Market` + registry deploy as in `AaveCrossVersionLoop_APEX_D43.t.sol` | `setSupplyCap(tokenA, 1)` after a first deposit | Heavy setup (V3 + V4 markets). `exchangeIn(tokenA → vault)` requires `pretransferred=false`, which is the hook's route. |
| UniswapV3FullSpreadStandardExchangeVault | pool token0 | `TestBase_UniswapV3FullSpreadStandardExchangeVault_Adversarial` (`_seedMarket`, `_configureSleeve`) | `LiquidReserve` sleeve: buffered input above the sleeve target stays local until `rebalanceLiquidReserve` | Needs a seeded V3 pool and independent LP. |
| UniswapV4FullSpreadStandardExchangeVault | pool currency0 (ERC-20 variant) | V4 adversarial TestBase | same | Native-ETH variant out of scope for the hook row. |
| StandardExchangeBufferPool | pool token 0 | constProd buffer-pool TestBase under `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/` | none; rounding-to-zero control (D38 native BPT) | Initialize the Balancer pool in the adapter before deploying the hook (M10). |
| CommonBufferMultiVaultStablePool | pool token 0 | its buffer-pool TestBase | none; rounding control | M10 applies. |
| MixedBufferMultiVaultStablePool | pool token 0 | its buffer-pool TestBase | none; rounding control | M10 applies. |
| CommonBufferMultiVaultWeightedPool | pool token 0 | its buffer-pool TestBase | none; rounding control | M10 applies. |
| MixedLegWeightedBufferPool | pool token 0 | its buffer-pool TestBase | none; rounding control | M10 applies. |
| MultiPairStandardExchangeBufferPool | pool token 0 | its buffer-pool TestBase | none; rounding control | M10 applies. |

Where an SE family's existing TestBase and the hook TestBase both define `setUp`, the concrete matrix contract inherits the hook TestBase and composes the SE fixture as a separately deployed helper contract or library that receives the shared `create3Factory`, `indexedexManager`, `owner` and `permit2` handles (the pattern of today's `SeMatrix_<Family>Deploy.sol`, extended per M6).

## 6. Row test set

Every `COMPATIBLE` row executes all of the following, named exactly, on the hook deployed through its real package, registry and hook-factory path:

| Test | Assertion |
| --- | --- |
| `test_row_bind_deploysThroughPackage` | Hook deploys with the SE under test on the leg; `standardExchanges()`/leg views report it; pool initializes; `previewExchangeIn(face, 1e18, se)` on the SE is nonzero. |
| `test_row_bufferFirst_restingFace_notPaidToJoiner` | Third-party resting face on the SE leg; an unrelated join or deposit never increases the joiner's face balance by more than `offered - used`; SE shares from buffering are owned by the hook. |
| `test_row_partialConsumption_bookedNotRefunded` | Trigger the family's R14 case (§5); join or swap into the leg; record the actual consumed amount; the SE booked the remainder (`reserveOfToken` on the SE for depositing families, sleeve for LSTs, held remainder for AMMs); no prior inventory became the caller's refund; the hook holds no operation-created face residual on the non-identity leg (orbital) or retains it as buffer-first credit (other families). Rounding-to-zero control for families without a leftover case. |
| `test_row_hookSwap_exactIn_eoaPretransferRejected` | `exchangeIn(face, amt, other, …, true)` from a code-less address reverts `EOAPretransferNotAllowed()`; no state change. |
| `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` | Through `AtomicPretransferCaller`: pretransfer `3 × quote`, `exchangeOut(face, 3×quote, other, amountOut, …, true)`; recipient receives exactly `amountOut`; refund equals `credit - used`; SE burned only what it used. |
| `test_row_hookSwap_exactOut_falseFlag_pullsUsedOnly` | Pull route pulls exactly the quoted `used`; refund nothing. |
| `test_row_poolManagerSwap_bothDirections_noFaceResidual` | Real PoolManager swap through the repository's router fixtures, exact-in and exact-out, both directions across the SE leg; swapper receives the quoted amount; closing face balance on the non-identity buffered leg equals its opening resting credit (zero in the no-outside-transfer fixture). |
| `test_row_seFailure_rollsBack` | With the SE made to revert on the operative call (family's own gate: paused underlying, closed pool, or the `APEXDependencyFailureStubs` pattern where the protocol cannot express it), the hook operation reverts with the SE's original bytes and every balance, book and allowance is unchanged. |
| `test_row_previewMatchesExecution` | Join, withdraw and swap previews equal execution for the leg under test. |
| `test_row_ammCallerFundSeparation` (AMM families only) | Reserved unpaired leftover on the SE is unchanged by a later caller who supplies only the other token (D33). |

`INCOMPATIBLE` rows contain exactly one test, `test_INCOMPATIBLE_<constraint>`, asserting the specific production error selector at the site named in the comment. `BLOCKED` rows contain `test_BLOCKED_<reason>` asserting the exact revert and are listed in the evidence as blockers, not as coverage.

## 7. Work packages (parallelizable)

Each package is independent: it touches its own fixture adapter and the seven concrete files for its SE family, plus nothing else. The behavior contracts (WP0) must land first.

| WP | Deliverable | Depends on |
| --- | --- | --- |
| WP0 | Seven `<Prefix>_SeMatrixBehavior.sol` contracts implementing §6 against the existing ERC-4626 control fixture; the six ERC-4626 rows and the non-CP ERC-4626 row rewritten to use them (non-CP row moved onto `TestBase_UniswapV4SingleStandardExchangeBufferHook`). | none |
| WP1 | Lido, Rocket, EtherFi adapters and 21 rows (18-decimal only). | WP0 |
| WP2 | Uni V2, Camelot, Aerodrome, Slipstream adapters, 28 rows plus decimal combos. | WP0 |
| WP3 | FullSpread V3 and V4 adapters, 14 rows plus decimal combos. | WP0 |
| WP4 | Morpho and RebasingAware adapters, 14 rows plus decimal combos. | WP0 |
| WP5 | Stata and Aave loop adapters; 2 executed single-CP rows plus their 6- and 9-decimal combos; 12 `DEFERRED` markers. | WP0 |
| WP6 | Six Balancer buffer-pool adapters; 6 executed single-CP rows plus decimal combos; 36 `DEFERRED` markers; M10 initialization per §11. | WP0, §11 decision |
| WP7 | SimpleYield control rows (7) and evidence regeneration (`hook-se-matrix.json`, evidence markdown, `acceptance.json` R10.3). | WP1 to WP6 |

Each WP records, per row, the package or CREATE3 path used, the face token and decimals, the exact test names and the log.

## 8. Acceptance criteria

- [x] A1. Every one of the 147 base files contains either the full §6 set (`COMPATIBLE`), one `test_INCOMPATIBLE_<constraint>` with a named production error selector or technical limitation, one `test_BLOCKED_<reason>`, or one `test_DEFERRED_<reason>` (heavy families only, M13). No bare `expectRevert()` remains in any matrix file.
- [ ] A2. Every executed row (84 light-family rows, 8 heavy-family single-CP rows, and their M14 decimal combinations) is `COMPATIBLE` unless a named production check or a named technical limitation forbids it. `DEFERRED` rows carry only the marker. Any `INCOMPATIBLE` or `BLOCKED` row is explained in the evidence with the exact check and is raised to the owner before the WP is closed.
- [x] A9. Multi-leg rows bind the SE family under test on every SE leg (M4); every behavior emits `matrix.se<i>` / `matrix.faceDecimals<i>` in `setUp` and `hook-se-matrix.json` records them per row as `legs` (2026-09-23).
- [x] A10. Decimal combinations (2026-09-23): the matrix behaviors bind every face leg to the fixture, so the face decimals are the fixture's argument, not the `_Decimals` base's (which only varies base-owned tokens the rows never bind); 28 `_F6` / `_F9` rows run the ERC-4626 and SimpleYield fixtures at 6 and 9 decimals on all seven hooks, and `hook-se-matrix.json` records `faceDecimals` per row (`legs`, `combo`). Stata (`usdx` / `NINE`) and the Aave loop need fixture wiring before they can vary the face; LST and pool families record 18. Recorded for the owner as the M14 interpretation.
- [x] A3. Every `COMPATIBLE` row's tests pass on the production deployment path (package, registry, hook factory) with no SUT mocks, no storage writes to manufacture state, and no `vm.etch`.
- [x] A4. The R14 partial-consumption control on every depositing SE row asserts the actual consumed amount, the booked remainder on the SE, and that no prior inventory was refunded to the caller.
- [ ] A5. The PoolManager swap control on every row asserts zero operation-created face residual on non-identity buffered legs (orbital) or unchanged resting credit (buffer-first families).
- [x] A6. `hook-se-matrix.json` has one record per row with state, tests, error (if any) and log; the evidence markdown item 1 is rewritten from it; `acceptance.json` R10.3 moves to `EVIDENCED` only when A1 to A5 hold.
- [x] A7. Full hermetic `forge test -vv` stays green; runtime sizes of production artifacts are unchanged (no production edit); `git diff --check` clean.
- [x] A8. No new file-level `forge-config` fuzz or invariant pins; no compiler-setting change.

## 9. Verification

```bash
# per WP, after writing the rows
python3 scripts/forge-artifacts.py test <touched test files> --test-root 'test/foundry/spec/hooks/uniswap/v4/standardExchange/<hook dir>' -- -vv

# matrix only
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/**/*_SeMatrix_*.t.sol' -vv

# stub scan: must return nothing when the program is complete
rg -n 'vm\.expectRevert\(\);' test/foundry/spec/hooks/uniswap/v4/standardExchange --glob '*_SeMatrix_*.t.sol'
rg -c 'function test_' test/foundry/spec/hooks/uniswap/v4/standardExchange --glob '*_SeMatrix_*.t.sol'

# release
forge build && forge test -vv
git diff --check
```

## 10. Risks and open questions

- **Setup weight.** Stata and the loop each stand up a full Aave market per test contract; Balancer families stand up a Vault and router. Expect long compile and run times for WP5 and WP6; keep one fixture instance per contract and use `vm.snapshotState` between rows where the hook TestBase allows it.
- **Rate providers on stable and weighted legs.** The existing ERC-4626 rows pass with the TestBase default `rateProviders`. If an SE family's leg needs an explicit provider for `rateAfterExchange` (D41), the adapter supplies the family's real provider package (`StandardExchangeRateProvider` DFPkg), not a mock.
- **Nested Balancer locks (M10).** If pre-initialization does not remove the `ReentrancyGuardReentrantCall`, those rows become `BLOCKED` and feed open item 2, which has the same root cause.
- **Real incompatibilities.** Any row that fails a named production check after the harness is correct is a finding: report it with the check and the affected package before deciding whether the check or the package is wrong. Do not relax the check in the harness.
- **Stack depth.** Seven-argument `exchangeIn` calls inside loops overflow the stack under the current compiler settings (seen during the review). Put each row body in its own internal function with a struct parameter.

## 11. Nested Balancer pools (decided)

**Mechanism (corrected 2026-09-20).** The `ReentrancyGuardReentrantCall()` recorded on 2026-09-18 was the pool hook re-entering its own Vault: `onAfterInitialize` in the CommonBufferMultiVaultWeighted and MixedBufferMultiVaultStable hook targets folded the initial physical buffer into the SE legs through `Vault.sendTo` / `addLiquidity` while `Vault.initialize` still held the `nonReentrant` guard. At HEAD that fold was wrapped in `try ... catch {}` and never executed; D37 exposed it; the fold was then removed from `onAfterInitialize`. The fixtures' SE legs are Aerodrome SEs, not Balancer vaults. The packages' `postDeploy` only registers the pool and is unrelated.

**Decision (owner, 2026-09-20).** A Standard Exchange leg that is itself a Balancer-hosted vault on the same Vault would re-enter the Vault from inside a pool hook and is not a supported configuration. It is treated as an external technical limitation, never composed by the matrix, and recorded `INCOMPATIBLE` with the limitation named if a row would need it. This is a general policy; it was not the cause of the three R11 campaign failures, which pass on the current tree (`review-20260920/r11-nested-lock-*.summary.log`).

**Consequence for this PRD.** The Balancer buffer-pool SE fixtures (WP6) use non-Balancer SE legs and seed with `router.initialize` from the fixture before the hook deploys. No production change, no `PkgArgs` initial-deposit fields, no `BLOCKED` state is expected from this cause.
