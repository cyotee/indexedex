# MiniMax council-member response — PairToken SE stage-one PRD initial pass

## Identity

- Role: MiniMax, independent council member, `pairtoken-se-stage-one-council-20261028-01a1810f`, initial pass.
- Route: `minimax/MiniMax-M3` with the host-configured adaptive thinking setting. No provider, account, model, or region fallback was used or attempted.
- Assignment: requirements assessment of the stage-one PRD only. No peer file was read, no subagent was launched, no test, build, Git, install, wallet, or deployment action was taken. No PRD, contract, test, instruction, or configuration file was edited.
- Independence: this is a requirements assessment. It is not a runtime-correctness proof and not a security certification. No exploit procedure, payload, or reproduction recipe is included; all adversarial discussion is defensive and is confined to requirements the PRD must resolve before implementation.

## Question and targets

**Shared question.** What material requirements need owner clarification, and what concrete improvements would make the stage-one PRD coherent, implementable, testable, and faithful to the confirmed owner choices?

**Targets assessed.**

- Target PRD: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` — read in full (871 lines, 12 sections), including the confirmed-decision table (S1-D01..D05, S1-P01..P03), the deviation register (S1-X01..X14), architecture (S1-ARCH-01..05), accounting (S1-ACC-01..05), operations (S1-OP-01..05, S1-NATIVE-01), interfaces (S1-API-01..04), quotes (S1-QUOTE-01..02), deployment/security (S1-PKG-01, S1-SEC-01..02, S1-OBS-01), the acceptance matrix (S1-A01..A57), and the test discipline (S1-TEST-01).
- Required behavioral context: `contracts/pairtoken-baseline/PairToken.sol` (read in full), `contracts/pairtoken-baseline/PairTokenMath.sol` (read in full), `contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol` (read in full).
- Admitted supporting context actually read: the five reused facets, the shared vault repos/targets, the Crane SE and SY interfaces, the native SY targets, `LocalCreditLib`, the Wings package, the V4 manager interface and libraries, and the baseline test harness headers.

**Owner-confirmed choices treated as settled and not re-litigated:** staged delivery; one full-range position, no wings; ownership logic only (no dead shares, no 10 bps retention, no protocol-fee routing); baseline swap-based compounding with mandatory pre-entry/pre-exit compounding; native ETH support retained; exact-output selectors installed but explicitly unsupported; the five named reusable facets; shares-of-shares deferred.

Everything else in the PRD — including normative wording such as "shall", the whole deviation register, the acceptance matrix, and the interface and quote policies — is treated as **author-proposed**, and is labelled as such below.

## Evidence and coverage

**Locator convention.** `PRD` = the target PRD above. `Baseline` = `contracts/pairtoken-baseline/PairToken.sol`. `Math` = `PairTokenMath.sol`.

**Sources read (primary).**

| Source | What it was read for |
| --- | --- |
| PRD (all 871 lines) | Requirements under assessment. |
| `Baseline` | Basket, quote, zap, redeem, compound, callback, settlement, pull/pay sequencing. |
| `Math` | `MD`/`MU`/`A0down`/`A1down`/`Fit`/`T`/`sqrt`/`U128` semantics and rounding. |
| `contracts/pairtoken-baseline/interfaces/IPairTokenDependencies.sol` | Baseline manager/factory surface, including `maxZapBps`, `maxZapTickMove`, `feeManager`, `protocolFeeBps`. |
| `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`, `IStandardExchangeOut.sol`, `IStandardExchangeErrors.sol` | Exact-input/exact-output ABI, `ExchangeOutNotAvailable()`, pretransfer NatSpec. |
| `contracts/interfaces/IStandardExchange.sol`, `IStandardExchangeInMulti.sol`, `IStandardExchangeOutMulti.sol`, `IStandardExchangeMultiAssetLiquidity.sol` | Existing route surfaces and their declared semantics. |
| `contracts/vaults/basic/IBasicVault.sol`, `contracts/interfaces/IBasicVault.sol`, `contracts/interfaces/IStandardVault.sol` | Discovery surfaces. |
| `contracts/vaults/basic/MultiAssetBasicVaultRepo.sol`, `MultiAssetBasicVaultTarget.sol`, `MultiAssetBasicVaultFacet.sol` | Reserve storage shape and the 3 declared selectors. |
| `contracts/vaults/standard/StandardVaultRepo.sol`, `MultiAssetStandardVaultTarget.sol`, `MultiAssetStandardVaultFacet.sol` | `contentsId`/`vaultFeeTypeIds`/`vaultTypes` handling and the 4 declared selectors. |
| `lib/crane/contracts/tokens/ERC20/ERC20Facet.sol`, `ERC20/ERC20Repo.sol`, `ERC2612/ERC2612Facet.sol`, `ERC2612/ERC2612Repo.sol`, `cryptography/ERC5267/ERC5267Facet.sol`, `cryptography/EIP712/EIP712Repo.sol` | Declared selector sets, interface declarations, init entrypoints. |
| `contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol`, `NativeStandardYieldTarget.sol`, `NativeStandardYieldDiscoveryTarget.sol`, `NativeStandardYieldPreviewTarget.sol`, `NativeStandardYieldQuoteBase.sol` | The 16-method SY surface, the payable deposit and its blanket value rejection, discovery/preview semantics. |
| `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol` | Canonical `exchangeRate()` / `assetInfo()` / `deposit` / `redeem` semantics and NatSpec. |
| `contracts/utils/LocalCreditLib.sol`, `contracts/interfaces/ISecurePullErrors.sol` | Unbooked-credit arithmetic, pretransfer caller rule, surplus-refund rule. |
| `contracts/vaults/standard/exchange/StandardExchangeInExecutionBase.sol` | The shared exact-input execution seam. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol` and its `SYFacet` | Package lifecycle reference: `PkgInit`/`PkgArgs`, `facetInterfaces` dedup, `facetCuts`, `calcSalt`, `processArgs`, `initAccount`, `postDeploy`, `vaultFeeTypeIds`. |
| `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol`, `DFPkgBase.sol` | Factory-owned facet assembly, ERC-165 registration order, temporary post-deploy hook removal. |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol`, `libraries/Pool.sol`, `libraries/TickMath.sol`, `libraries/StateLibrary.sol`, `libraries/TransientStateLibrary.sol`, `libraries/Lock.sol`, `types/PoolId.sol`, `utils/UniswapV4Utils.sol` | Manager surface, price-limit validity bounds, canonical state reads, unlocked-state read. |
| `lib/crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol` | Wrapped-native adapter surface. |
| `contracts/interfaces/IVaultRegistryDeployment.sol`, `IStandardVaultPkg.sol`, `VaultFeeTypes.sol`, `contracts/registries/vault/VaultRegistryDeploymentTarget.sol` (declaration grep) | Registry deployment path and fee-type encoding. |
| `test/foundry/spec/pairtoken-baseline/harness/PairTokenTestBase.sol`, `harness/ScriptedDependencies.sol` (declaration headers) | Existence and shape of the cited comparison fixture. |

**Verified counts and facts used below.**

- The five reused facets declare exactly 9 + 3 + 1 + 3 + 4 = **20** selectors, matching PRD S1-ARCH-04's count. Verified against each facet's `facetFuncs()` body.
- The canonical SY surface is exactly the **16** selectors PRD S1-API-03 lists; `NativeStandardYieldSelectors._append` and the Wings SY facet both enumerate the same 16 in the same roles.
- `DiamondPackageCallBackFactory.initAccount` applies the factory's own four base cuts (ERC-165, Diamond Loupe, ERC-8109, temporary post-deploy hook) and registers the factory's three base interface ids **before** applying the package's `diamondConfig()` cuts and registering the package's interface ids. The temporary hook is removed by a `Remove` cut in `postDeploy`. PRD S1-ARCH-04's exclusion requirement is therefore **feasible and correct as written**.
- Crane's V4 `Pool.swap` reverts `PriceLimitOutOfBounds` unless `sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE (4295128739)` and `< TickMath.MAX_SQRT_PRICE (…342)`. The baseline's `MIN_SWAP_PRICE = 4295128740` and `MAX_SWAP_PRICE = …341` are exactly `MIN_SQRT_PRICE + 1` and `MAX_SQRT_PRICE - 1` and are therefore **valid** against the real manager. No defect; a pinning recommendation only.

**Coverage gaps and access limits (reported, not worked around).**

- Nothing was executed. Every statement about baseline runtime behaviour is a static-reading inference from `PairToken.sol`; no trace was observed.
- The Wings `TestBase_UniswapV4UpperLowerWingsStandardExchangeVault.sol` cited in the PRD's source map was not read line-by-line; only the package contract it deploys was read. The `VaultRegistryDeploymentTarget` was read at declaration level, not implementation level.
- `ERC4626StandardExchangeDFPkg`, the Morpho family, the DETF family, the Balancer V3 family, the hooks families and the frontend were not read; they are out of the stage-one scope named by the PRD and were not needed to test any claim made here.
- The baseline characterization suite was not run and its expectations were not read, so I cannot say whether the baseline already covers the residue and refund paths described in R6 and R19.
- The PRD's revision identity was not hashed; I assessed the file as found at the cited path on 2026-10-28.

**No access failures occurred.** All admitted sources needed for the claims below were readable.

## Recommendations

Priority key: **B** = implementation blocker (an implementer would otherwise have to invent a decision, or would ship a wrong number). **H** = high (materially weakens testability, fidelity, or truthfulness). **M** = medium (clarity, robustness, or a sharp edge worth recording).

---

### R1 — B — `exchangeRate()` is off by `10^d` against the canonical SY unit

1. **Locator.** PRD S1-QUOTE-02: *"the rate is the integer result of `Vraw * 10^18 * 10^18 / (S * 10^d)`"*. Canonical unit: `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol`, NatSpec on `exchangeRate()`: *"exchangeRate * syBalance / 1e18 must return the asset balance of the account"* and *"the amount of sy he can mint must be X * exchangeRate / 1e18"*.
2. **Evidence class.** Source observation (both files read).
3. **Gap and consequence.** The canonical `exchangeRate()` is **raw asset units per 1e18 shares** (`assetAmount = exchangeRate * syBalance / 1e18`). The PRD's formula equals the canonical rate multiplied by `1e18 / 10^d`. The two agree only when `d == 18`; for a 6-decimal rate asset the PRD's rate is **1e12× too large**, and for an 8-decimal asset 1e10× too large. S1-A32 ("normalize mixed decimals correctly") and S1-A33 would be satisfiable only by implementing the PRD's formula and would then encode the wrong unit. Separately, the PRD writes two `10^18` factors and one `10^d` divisor, so it is not even self-consistent under a "human units" reading (that reading needs one `10^18`).
4. **Proposed wording.** Replace the S1-QUOTE-02 rate sentence with: *"Let `Vraw` be the total basket value expressed in **raw `rateAsset` units**, `S` the total share supply (18 decimals), and `d` the `rateAsset` decimals. `exchangeRate() = floor(Vraw * 1e18 / S)`, computed as `PairTokenMath.MD(Vraw, 1e18, S)`. The rate is raw `rateAsset` units per 1e18 shares, matching `IStandardizedYield.exchangeRate()` (`assetAmount = exchangeRate * syBalance / 1e18`). `d` affects only `assetInfo().assetDecimals` and off-chain rendering; it must not appear in the rate formula. `rateAsset` decimals are read as `IERC20Metadata(rateAsset).decimals()` at query time."*
5. **Owner choice or correction.** Technical correction (the denominating unit is already implied by `assetInfo()`); one confirmatory owner nod on "raw `rateAsset` units per 1e18 shares" as the published unit.
6. **Trade-offs and confidence.** High confidence. Alternative considered: keep a "human-unit" rate, but that breaks the canonical SY invariant and every existing SY consumer's `rate * balance / 1e18` arithmetic.

---

### R2 — B — The booked/unbooked ledger is undefined; collected fees and swap settlement have no booking rule

1. **Locator.** PRD S1-X09 (booked vs unbooked), S1-ACC-01 (`B0`, `B1`), S1-ACC-03, S1-ACC-04, S1-OP-05, S1-SEC-01. Baseline `PairToken.sol`: `_compound()` (collect → `_ratioSwap` → `_requestDeploy`), `_deploy()` (swap → `_add`), `_modify()`/`_resolve()` (settle/take), `_idle()` (raw balance).
2. **Evidence class.** Source observation of the baseline's raw-balance model; inference about the consequence.
3. **Gap and consequence.** Stage one replaces "raw balance = basket" with "booked = basket" (S1-X09), but the PRD never states the deltas. Concretely: (a) the manager `take`s collected LP fees into the vault, raising the raw balance — unless those fees are **booked**, they become unbooked and are excluded from every basket query and every redemption allocation, i.e. shareholders silently lose the fees the PRD promises to retain (S1-OP-05 "Retain the full collection"); (b) the compound's ratio swap and the exit sale's swap change the raw balance with no booking instruction; (c) a `Fit`-based liquidity addition consumes booked idle and must **de-book** it; (d) the native wrap/unwrap adapter moves value between the ETH and wrapped faces and must not double-count. Without a rule, an implementer must invent the central invariant of the family, and the S1-A41 reconciliation row has nothing to reconcile against.
4. **Proposed wording.** Add a new requirement **S1-ACC-06 "Bookkeeping ledger"**: *"Stage one maintains booked shareholder inventory `B0`, `B1` that is the sole source of basket truth. A normative table states, for each operation (paired deposit, single-token deposit, paired redemption, single-token redemption, compound collect, compound swap, compound liquidity addition, donation, native wrap/unwrap), the exact signed deltas applied to `(B0, B1, S, L)`. Four rules govern the table: (1) every settled manager delta is booked by its observed amount exactly once, in the same operation; (2) collected LP fees are booked as shareholder backing at collection, before any further balance-derived computation, and are never booked again when deployed; (3) no balance-derived quantity — basket, `Fit`, `A0down`/`A1down`, redemption allocation — ever reads a raw balance; it reads booked values plus the current operation's reserved input; (4) unbooked surplus is never booked implicitly and never spent."*
5. **Owner choice or correction.** Primarily a technical correction (the PRD already implies it), but the choice of *booking at collection* vs *booking at deployment* is economic and is folded into owner question **Q3**.
6. **Trade-offs and confidence.** High confidence that the gap is real and blocking. Trade-off: an explicit ledger adds a section and forces per-operation thought; the alternative (leaving it prose-scattered) makes S1-A41 unfalsifiable.

---

### R3 — B — ERC-165 truthfulness contradiction: the PRD advertises exact-output support it forbids

1. **Locator.** PRD S1-P03 (confirmed owner choice) vs S1-API-01's row *"**`IStandardExchange`** | Combined marker agrees with the installed In/Out interfaces"*, and S1-ARCH-05's *"deduplicated package-owned vault interface declarations"*. Canonical: `lib/crane/contracts/interfaces/IStandardExchangeOut.sol` (`error ExchangeOutNotAvailable()`), `contracts/interfaces/IStandardExchange.sol` (`interface IStandardExchange is IStandardExchangeIn, IStandardExchangeOut {}`), and `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` (`initAccount` → `ERC165Repo._registerInterfaces(config.interfaces)` for the package's declared ids).
2. **Evidence class.** Source observation.
3. **Gap and consequence.** `IStandardExchange.interfaceId` is the XOR of `IStandardExchangeIn` and `IStandardExchangeOut`; `IStandardExchangeOut.interfaceId` covers the two always-reverting selectors. Registering either in the package's ERC-165 set advertises exact-output support that S1-P03 forbids and that the vault will never deliver. A consumer that probes ERC-165 routes an exact-output swap into a vault that always reverts — the opposite of the PRD's own stated principle in S1-ARCH-03 ("Use truthful zero fee-type declarations for this family rather than registering a fee that execution ignores"). The PRD asserts a "combined marker agrees" without noticing it cannot agree.
4. **Proposed wording.** Amend the S1-API-01 `IStandardExchange` row to: *"The four `IStandardExchangeIn`/`IStandardExchangeOut` selectors are installed so the ABI is present and both exact-output selectors revert with `ExchangeOutNotAvailable()` under S1-P03. The package's ERC-165 declaration set **omits** `IStandardExchangeOut.interfaceId` and `IStandardExchange.interfaceId`; it declares `IStandardExchangeIn.interfaceId`, `IStandardizedYield.interfaceId`, `IBasicVault`, `IStandardVault`, `IERC20`, `IERC20Metadata`, `IERC20Permit`, `IERC5267` and the family query interface id. A client that probes ERC-165 therefore learns that exact output is unsupported before it sends a transaction."* Add acceptance row **S1-A58**: *"The live proxy reports `supportsInterface(IStandardExchangeOut.interfaceId) == false` and `supportsInterface(IStandardExchangeIn.interfaceId) == true`, while `exchangeOut` and `previewExchangeOut` are present on the proxy and revert `ExchangeOutNotAvailable()` without transfer, burn, mint, or manager mutation."*
5. **Owner choice or correction.** Owner choice (small but real: whether the combined marker is advertised). Folded into **Q4**.
6. **Trade-offs and confidence.** High confidence the contradiction exists. Trade-off: not declaring `IStandardExchange` may surprise a consumer that expects the combined marker from the SE family; but declaring a marker whose methods always revert is the worse failure.

---

### R4 — B — Paired and single-leg route selectors are unspecified, and an existing canonical interface already declares near-identical semantics

1. **Locator.** PRD S1-OP-01 (`depositPair(amount0Max, amount1Max, minShares, recipient, deadline)`), S1-OP-02, S1-OP-03 (`redeemPair(shares, min0, min1, recipient, deadline)`), S1-OP-04, S1-API-02, S1-API-03 — all named without signatures or selectors. Canonical: `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol`: `joinProportional(uint256[] amounts, address to, uint256 sharesMin, uint256 deadline) returns (uint256 shares, uint256[] usedAmounts)`, `exitProportional(uint256 shares, address to, uint256[] amountsMin, uint256 deadline) returns (uint256[] amounts)`, `joinSingleAssetExactIn(address tokenIn, uint256 amountIn, address to, uint256 sharesMin, uint256 deadline)`, `exitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn, address to, uint256 amountOutMin, uint256 deadline)`, plus their `preview*` counterparts.
2. **Evidence class.** Source observation.
3. **Gap and consequence.** Two distinct problems. (a) The PRD names the paired methods but never gives their signatures or selectors, so S1-A06 (*"Target/interface-derived controls equal package-owned facet declarations and cuts"*) and the selector-ownership requirement cannot be written, and two implementers can produce incompatible ABIs for the same product. (b) S1-OP-03's justification for not reusing existing interfaces analyses only `IStandardExchangeInMulti` and `IStandardExchangeOutMulti` — both genuinely mismatched — and dismisses `IStandardExchangeMultiAssetLiquidity` in one clause (*"also includes unbalanced/exact-output operations beyond this stage"*) without ever analysing `joinProportional`/`exitProportional`, whose semantics are the same proportional two-leg join/exit the PRD is building, nor `joinSingleAssetExactIn`/`exitSingleAssetExactBptIn`, which are the same single-leg zap in and out the PRD is building. The PRD elsewhere forbids *"a second implementation of the same accounting behind additional aliases"*; on the current text it would create exactly that.
4. **Proposed wording.** Amend S1-OP-03: *"The paired entry/exit and the single-leg zap routes adopt the canonical `IStandardExchangeMultiAssetLiquidity` selector shapes: `joinProportional(uint256[] amounts, address to, uint256 sharesMin, uint256 deadline)`, `exitProportional(uint256 shares, address to, uint256[] amountsMin, uint256 deadline)`, `joinSingleAssetExactIn(address tokenIn, uint256 amountIn, address to, uint256 sharesMin, uint256 deadline)`, `exitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn, address to, uint256 amountOutMin, uint256 deadline)`, with `amounts` as per-leg maxima and `amountsMin` as per-leg minima, plus `previewJoinProportional`, `previewExitProportional`, `previewJoinSingleAssetExactIn` and `previewExitSingleAssetExactBptIn`. The family does not install `joinUnbalanced`, `joinSingleAssetExactOut`, `exitSingleAssetExactTokenOut`, `depositSingle`, `withdrawSingle`, `withdrawSingleExactOut` or their previews. Every installed selector and its exact signature is listed in the family query interface table."* If the owner prefers bespoke names, the PRD must state the exact signatures and selectors and record the divergence from the canonical interface as an intentional deviation.
5. **Owner choice or correction.** Owner choice. Folded into **Q1**.
6. **Trade-offs and confidence.** High confidence that the omission and the one-clause dismissal are real. Medium confidence on which the owner prefers; the canonical shape has the advantage that existing SE integrators already know it.

---

### R5 — B — Exact preview/execution parity is asserted without a feasibility argument, and the step budget has no definition

1. **Locator.** PRD S1-QUOTE-01 items 1-7, *"Bound projection work deterministically: proposed maximum 512 swap traversal steps per preview across all simulated swaps; exhaustion returns an explicit quote-work error"*, *"Execution must enforce the same accepted domain by preflighting the same plan before pulling ERC-20 funds"*; S1-X08; S1-A27 (*"Every SE and paired preview matches execution exactly"*), S1-A28. Baseline `previewDeposit`/`previewRedeem` (they read `basket()` only and perform no compound — the gap S1-X08 names); `_compound()`; `_deploy()`.
2. **Evidence class.** Inference (design risk), grounded in source observation of the baseline's preview/execute split and of the canonical V4 read surface.
3. **Gap and consequence.** A view that reproduces the mandatory compound must reproduce the pool's post-swap liquidity, tick crossings, and fee accounting for both the ratio swap and the entry swap. The canonical read surface (`StateLibrary.getSlot0`, `getLiquidity`, `getTickInfo`, `getTickLiquidity`, `getTickBitmap`, `getFeeGrowthInside`, `getFeeGrowthGlobals`) exposes current state; the post-swap state exists only inside the manager during execution. "Exactly" (S1-A27) therefore demands a full swap simulator over tick-bitmap traversal, with no argument in the PRD that this is achievable or affordable. The liveness consequence is direct: if a preview reports 100 shares and execution computes 99, the caller's `minShares` fails **after** they have paid gas and after the operation has already compounded and swapped. The "512 steps" figure is currently a bare number with no failure semantics, no direction of error, and no relationship to the quoted number.
4. **Proposed wording.** Amend S1-QUOTE-01: *"Previews are **projections, not commitments**. The preview and execution must run the same economic model over the same initial state. Where the projected path is fully determined by current on-chain state (a single swap that does not cross a tick), the preview must return the exact integer result and S1-A27 applies in full. Where the projection would require state that only the manager can produce, the preview must return a **conservative** figure — for entries, never more shares than execution can deliver; for exits, never more than the executed amount may be guaranteed and the conservative direction must be documented per route — and the interface must expose which mode produced the number. The traversal budget is a named constant `QUOTE_MAX_SWAP_STEPS = 512`; on exhaustion the preview returns a named quote-work error and never a partial or optimistic number. Execution preflights the same plan before pulling ERC-20 funds, so a preview that cannot be completed preflight reverts in execution with the same error rather than executing a different path."* Add acceptance row **S1-A59**: *"For a projected swap that crosses a tick, the preview's documented error bound holds and the preview is conservative in the stated direction; the same inputs in execution revert with the named quote-work error when the budget is exhausted."*
5. **Owner choice or correction.** Owner choice (ship a conservative preview, or fund a full simulator). Folded into **Q5**.
6. **Trade-offs and confidence.** Medium-high confidence. The conservative-preview route is cheaper and safer to ship but gives integrators a weaker quote; the simulator route is stronger but is a substantial sub-project the PRD does not currently scope.

---

### R6 — B — The native paired-deposit refund must remain reserved through the liquidity addition

1. **Locator.** PRD S1-OP-01 (*"For a native pool, require `msg.value == amount0Max`, reserve all incoming ETH before compounding, and refund `amount0Max - used0` to `msg.sender` after successful accounting"*), S1-NATIVE-01 (*"At each payable entry, reserve the complete `msg.value` before any compound or balance-derived quote"*). Baseline `PairToken.sol` `deposit()`: `_nativeReservation = msg.value;` … `_nativeReservation = token0() == address(0) ? msg.value - q.amount0 : 0;` **then** `uint128 addition = _pairedAddition();` — and `_pairedAddition()` reads `_idle(token0())`, which for native is `address(this).balance - _nativeReservation`, i.e. **with the reservation already released** — and only afterwards is the refund transferred.
2. **Evidence class.** Source observation of the baseline ordering; inference that the refund can be under-funded (I did not execute it).
3. **Gap and consequence.** In the baseline the refundable remainder leaves the native reservation *before* the paired liquidity addition, so it is eligible to be deployed into the position; the later refund transfer can then fail for insufficient balance and revert the whole deposit. The PRD's S1-OP-01 ordering ("pull accepted amounts → book contribution → add paired liquidity → …") avoids the baseline ordering by accident, but never states the invariant, so an implementer who follows the baseline's sequencing (or who reads the baseline as the reference for sequencing) reintroduces the defect. This is a case where the PRD's "same logic" framing under-specifies precisely the part that differs.
4. **Proposed wording.** Add to S1-OP-01 and S1-NATIVE-01: *"In a native paired deposit the refundable remainder `amount0Max - used0` is a reserved, unbooked liability from function entry until the refund transfer. It is never booked, never part of the eligible idle used by the paired liquidity addition, and never part of any basket or `Fit` computation. Only the accepted amount is booked and is eligible for deployment. The refund transfer uses a checked value transfer with no fixed gas stipend; a rejecting or reentrant receiver reverts the whole operation, and a failed refund rolls back the deposit, its compound, and its liquidity addition."*
5. **Owner choice or correction.** Technical correction.
6. **Trade-offs and confidence.** High confidence on the baseline ordering; medium-high that the under-funding is reachable (it depends on the deployed amount relative to the remainder). Confidence is limited by not having executed the baseline.

---

### R7 — B — The SY native override scope is wrong: `redeem` must be overridden too, not only the value check

1. **Locator.** PRD S1-API-03 (*"Override the current shared SY implementation's blanket nonzero-value rejection in this family only"*, *"Native `redeem(..., address(0), ...)` pays raw ETH; the wrapped face pays wrapped native"*), S1-NATIVE-01 (*"Never call ERC-20 methods on address zero"*). Canonical: `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` — `deposit(address,address,uint256,uint256)` is `public payable virtual` and begins `if (msg.value != 0) revert NativeStandardYieldErrors.UnsupportedNativePayment();`; `redeem(address,uint256,address,uint256,bool)` is `public virtual` (non-payable) and routes both branches through `_standardRoute(...) → _exchangeIn(...)`; `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol` — `isValidTokenIn(token) = _contains(getTokensIn(), token)`; `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol` — `previewDeposit`/`previewRedeem` return `0` for an invalid token.
2. **Evidence class.** Source observation.
3. **Gap and consequence.** Three distinct gaps. (a) The shared blanket rejection lives in `deposit`, but the shared `redeem` is non-payable and routes every redemption through `_exchangeIn`, an ERC-20 path. To pay raw ETH the family must override `redeem` **in full**, not merely the value check the PRD names. An implementer who overrides only `deposit` sends a native redemption into `_exchangeIn` with `tokenOut = address(0)` — an ERC-20 call on address zero, which S1-NATIVE-01 forbids and which would revert deep inside the shared base with an unhelpful error. (b) `getTokensIn()` returning `address(0)` for native pools makes `isValidTokenIn(address(0))` true through the shared `_contains` derivation — the desired outcome, but the PRD never states the rule, so whether `isValidTokenIn(address(0))` is false on an ERC-20-only pool is left to inference. (c) The shared preview returns `0` for an invalid token and otherwise delegates to `_previewExchangeIn`, a single-`uint256` internal that has no native awareness; the PRD requires native and wrapped previews to be "the same amounts and economic engine", which the shared base cannot supply for `address(0)`.
4. **Proposed wording.** Amend S1-API-03: *"The family overrides `deposit` and `redeem` in full — not only the shared value check. `deposit` accepts `msg.value == amount` only when `tokenIn_ == address(0)` and the pool is native, routes to the internal native deposit path, and never calls `_exchangeIn` with a zero address. `redeem` is overridden to support two delivery forms for the same share amount — `tokenOut_ == address(0)` pays raw ETH and `tokenOut_ == C0` (the bound wrapped native) pays wrapped native — both computed from one internal redemption result. The family overrides `getTokensIn`/`getTokensOut`; `isValidTokenIn`/`isValidTokenOut` are inherited from `NativeStandardYieldDiscoveryTarget` and therefore remain `_contains(getTokensIn()/getTokensOut())`: on a native pool `address(0)` is valid in and out; on an ERC-20 pool `address(0)` is invalid in and out. `previewRedeem(address(0), s)` returns exactly the wei amount `redeem(address(0), s)` pays, and `previewRedeem(C0, s)` returns that same wei amount expressed as wrapped native."*
5. **Owner choice or correction.** Technical correction, with one owner confirmation folded into **Q7** (dual ETH/wrapped delivery at identical economics).
6. **Trade-offs and confidence.** High confidence on the shared-base reading. Trade-off: overriding `redeem` means the family owns the `InvalidSYReceiver` / `ZeroSYAmount` / `InvalidSYToken` checks and the `IStandardizedYield.Redeem` event, which the PRD already requires it to preserve.

---

### R8 — B — The zap attribution issue is a real value-transfer risk, but the PRD has no threshold and no pre-committed resolution

1. **Locator.** PRD S1-OP-02 step 8 and the *"Inherited limitation"* paragraph; S1-A15; S1-A46; S1-OP-02's *"Do not silently substitute a different 'optimal zap' or value-based issuance rule"*; S1-X08..X14 preamble (*"proposed integration/correctness requirements"*). Baseline: `_deploy()` computes `result.used0/used1` from the **whole** idle balance (`_idle()`), `_add()` returns the amounts consumed, and `zapDeposit` issues `min(MD(used0,S,R0), MD(used1,S,R1))`.
2. **Evidence class.** Source observation of the baseline formula; inference about the consequence.
3. **Gap and consequence.** The baseline credits the zapper with shares proportional to the amounts the new liquidity consumed **from the entire idle balance**. If incumbent idle inventory exists, part of what the new liquidity consumes belongs to existing shareholders, so the zapper receives shares it did not earn and existing holders absorb the loss. The PRD states this honestly, then (a) mandates the baseline formula as a requirement, (b) defers the decision to comparative tests, (c) defines "unacceptable" nowhere, (d) defines no measurement, and (e) pre-commits to **not** changing the formula (S1-A15: *"unacceptable transfer is reported, not hidden by a changed formula"*). The net effect is that implementation could ship a value-losing formula while the PRD simultaneously claims no unresolved finding is presented as a correctness claim (section 11, item 4). This is the clearest place where the PRD defers an economic algorithm into implementation.
4. **Proposed wording.** Amend S1-OP-02 and S1-A15: *"S1-A15 is a **decision gate**, not a reporting obligation. Define the zapper's own contribution as `own_i = deployed_i - max(0, idleBefore_i)` where `idleBefore_i` is the booked idle of leg `i` before the zap and `deployed_i` is the amount consumed by the new liquidity, and the fair share count as `fairShares = min(floor(own_0 * S / R_0), floor(own_1 * S / R_1))`. The acceptance test must report `issuedShares` and `fairShares` across a matrix of incumbent-idle and partial-fill states. **Unacceptable** is defined as `issuedShares > fairShares` in any state the vault permits, i.e. incumbent idle is transferable to a new depositor. If the gate trips, the default resolution is that the zap credits only `own_i` and incumbent idle remains with existing holders; the owner may substitute a different formula decision before implementation, but it must be recorded in the deviation register and mirrored in S1-OP-02 step 8."* Add acceptance row **S1-A60**: *"Zap issuance credits at most the zapper's incremental contribution, or the owner's substituted formula is recorded with its own acceptance row."*
5. **Owner choice or correction.** Owner choice. Folded into **Q2**.
6. **Trade-offs and confidence.** High confidence the gap exists. The proposed fallback is one of several possible (cap the credited amounts; revert when incumbent idle would be consumed; charge the idle to existing holders) — the recommendation is the simplest one that preserves the baseline's proportional shape.

---

### R9 — H — `vaultFeeTypeIds == bytes32(0)` is asserted, not established

1. **Locator.** PRD S1-ARCH-03 (*"Use truthful zero fee-type declarations for this family rather than registering a fee that execution ignores"*), S1-ARCH-05 (*"zero stage-one fee-type IDs"*), S1-API-01 (`IStandardVault.vaultFeeTypeIds`). Canonical: `contracts/vaults/standard/StandardVaultRepo.sol` `_initialize(feeOracle, vaultFeeTypeIds, vaultTypes, contentsId)` (the id is an **argument**, the repo does not compute it); the Wings package's `vaultFeeTypeIds() = VaultTypeUtils._insertFeeTypeId(bytes32(0), VaultFeeType.USAGE, type(IUniswapV4UpperLowerWingsStandardExchangeVault).interfaceId)`; `contracts/interfaces/VaultFeeTypes.sol` (`enum VaultFeeType { USAGE, DEX, BOND, SEIGNIORAGE, LENDING }`); `contracts/registries/vault/VaultRegistryDeploymentTarget.sol` (`deployPkg`, `deployVault`).
2. **Evidence class.** Source observation.
3. **Gap and consequence.** The registry's fee machinery keys off a per-`VaultFeeType` interface id; the reference package registers a `USAGE` id pointing at its own vault interface. A zero id means no fee type maps to this family — consistent with S1-D03 — but the PRD asserts the consequence without establishing it against the registry's registration/ACL path or the fee oracle's behaviour for an unregistered vault. If the registry requires at least one fee-type id, or if any path dereferences the bound `IVaultFeeOracleQuery` for this family, deployment or fee computation fails — and the PRD gives the implementer no fallback.
4. **Proposed wording.** Add to S1-ARCH-05: *"The family registers `vaultFeeTypeIds == bytes32(0)`: no `VaultFeeType` maps to this family. The implementation must verify, before the package is registered, that (a) the registry's `deployPkg`/`deployVault` accept a package whose `vaultFeeTypeIds()` is zero, and (b) no fee path dereferences the bound `IVaultFeeOracleQuery` for this family. If either is false, the family must register a `USAGE` id pointing at its own vault interface and the oracle must be configured to return zero for it; that is a registry/fee change and must be escalated to the owner rather than worked around locally."*
5. **Owner choice or correction.** Technical verification; escalate if it fails.
6. **Trade-offs and confidence.** Medium-high confidence. The zero id is very likely correct, but the PRD currently asserts it rather than deriving it.

---

### R10 — H — The 18-decimal share decision diverges from the existing V4 package and is not registered as a deviation

1. **Locator.** PRD S1-ARCH-02 (*"Shares have 18 decimals, matching PairToken"*), S1-ARCH-05; S1-A44. Canonical: the Wings package's `initAccount` calls `ERC20Repo._initialize(tokenName, "UV4W", IERC20Metadata(args.targetToken).decimals())`, with the comment *"Native target units also denominate shares: no precision-losing bootstrap scale or permanent sink."*
2. **Evidence class.** Source observation.
3. **Gap and consequence.** The existing V4 SE package sizes the share token to the target token's decimals; the PRD sizes it to 18 for every instance. The PRD's choice is defensible (and better for mixed-decimal baskets), but it is a divergence from the family's own convention that the deviation register does not record. The S1-TEST-01 comparison ledger has no row for it, so a reviewer comparing this family to Wings would read an 18-vs-6 decimal difference as a regression rather than a decision.
4. **Proposed wording.** Add deviation row **S1-X15**: *"Baseline/prior-family: share decimals follow the target token's decimals. Stage one: share decimals are 18 for every instance, independent of the currencies' decimals, so a mixed-decimal basket needs no bootstrap scale and no precision-losing rescaling. Record as an intentional deviation in the S1-TEST-01 comparison ledger."*
5. **Owner choice or correction.** Editorial/technical correction (the decision itself is already made and is consistent with the baseline's 18 decimals).
6. **Trade-offs and confidence.** High confidence.

---

### R11 — H — Tick derivation, position identity, and the canonical state reads are not specified

1. **Locator.** PRD S1-ARCH-02 (*"Exactly one position uses the full usable tick range and salt `bytes32(0)`"*), S1-ACC-01 (*"Do not copy raw PoolManager storage offsets when canonical state libraries provide the same read"*), S1-TEST-01. Baseline: `initialize()` (`tickLower = (int24(-887272) / key.tickSpacing) * key.tickSpacing; tickUpper = (int24(887272) / key.tickSpacing) * key.tickSpacing;`), `positionLiquidity()` (hand-built slot from `keccak256(abi.encodePacked(address(this), tickLower, tickUpper, bytes32(0)))`), `_poolSlot()`/`_slot0()` (hand-built slots at `poolSlot`, `poolSlot+3`, `poolSlot+6`). Canonical: `StateLibrary.getSlot0`, `StateLibrary.getLiquidity`, `StateLibrary.getPositionLiquidity`, `StateLibrary.getPositionInfo`, `PoolIdLibrary.toId`.
2. **Evidence class.** Source observation.
3. **Gap and consequence.** (a) The tick formula is not written down, so the position key cannot be reproduced, compared across instances (S1-A47), or asserted in a test. (b) The baseline reads pool state through hand-computed storage offsets; the PRD requires the canonical state library in principle but never maps each baseline read to its replacement, so the comparison ledger has no way to classify "same value, different read path" and may misclassify it as a behavioural difference.
4. **Proposed wording.** Add to S1-ARCH-02: *"Tick derivation: `tickLower = (int24(-887272) / tickSpacing) * tickSpacing` and `tickUpper = (int24(887272) / tickSpacing) * tickSpacing`, matching the baseline `PairToken.initialize`. Pool id: `PoolIdLibrary.toId(poolKey)`. Position id: the canonical V4 position id for `(owner = address(this), tickLower, tickUpper, salt = bytes32(0))`. State reads: `StateLibrary.getSlot0` for price and tick, `StateLibrary.getLiquidity` for the active-liquidity figure the compound's quarter-cap uses, and `StateLibrary.getPositionLiquidity` for owned liquidity. The baseline's three hand-built slot reads are classified in the comparison ledger as 'unsupported scope (storage access replaced by the canonical state library)', not as behavioural differences."*
5. **Owner choice or correction.** Technical correction.
6. **Trade-offs and confidence.** High confidence.

---

### R12 — H — Price-limit constants are correct but should be pinned, not copied

1. **Locator.** PRD S1-OP-02 step 5 (*"the baseline direction and extreme price-limit convention"*), S1-OP-05. Baseline: `MIN_SWAP_PRICE = 4295128740`, `MAX_SWAP_PRICE = 1461446703485210103287273052203988822378723970341`. Canonical: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol` (reverts `PriceLimitOutOfBounds` unless `limit > TickMath.MIN_SQRT_PRICE` and `limit < TickMath.MAX_SQRT_PRICE`), `TickMath.sol` (`MIN_SQRT_PRICE = 4295128739`, `MAX_SQRT_PRICE = …342`), `utils/UniswapV4Utils.sol` (canonical `MIN_SQRT_PRICE + 1` / `MAX_SQRT_PRICE - 1`).
2. **Evidence class.** Source observation.
3. **Finding and consequence.** No defect: the baseline's two literals are exactly `TickMath.MIN_SQRT_PRICE + 1` and `TickMath.MAX_SQRT_PRICE - 1`, i.e. strictly inside Crane's V4 validity window, and they match the repo's own canonical convention. The risk is that a reader treats the baseline's literals as opaque constants or "corrects" them toward the Uniswap V3 values (`2^160 - 1`), which Crane's V4 `Pool.swap` rejects with `PriceLimitOutOfBounds`. The PRD's "extreme price-limit convention" is not specific enough to prevent that.
4. **Proposed wording.** Add to S1-OP-02 step 5: *"The extreme price limits are `TickMath.MIN_SQRT_PRICE + 1` (zero-for-one) and `TickMath.MAX_SQRT_PRICE - 1` (one-for-zero), the canonical Crane V4 bounds; `Pool.swap` reverts `PriceLimitOutOfBounds` outside them. These are numerically equal to the baseline's `MIN_SWAP_PRICE`/`MAX_SWAP_PRICE` literals and are preserved exactly; do not substitute `type(uint160).max` or the Uniswap V3 constants."*
5. **Owner choice or correction.** Technical correction (pinning only).
6. **Trade-offs and confidence.** High confidence — this was checked against the manager's own bound checks.

---

### R13 — H — Donation has two gaps: the wrapped-native case on an ERC-20-only pool, and the observation method

1. **Locator.** PRD S1-ACC-04 (*"Add a permissionless `donate(token, amount)` pull operation for either pool token"*, *"Wrapped-native input is unwrapped into the native reserve"*, *"credits the observed supported token delta to booked reserves"*), S1-NATIVE-01, S1-A55. Canonical: `contracts/utils/LocalCreditLib.sol` (`available(balance, booked)`), `contracts/interfaces/ISecurePullErrors.sol` (`TransferDeltaInsufficient(claimed, observedDelta)`, and the rule *"Surplus refunds (E6) pay only this-call unused inbound, never booked `R`"*).
2. **Evidence class.** Source observation plus inference.
3. **Gap and consequence.** (a) The wrapper is bound at package initialization for every pool, native or not. On an ERC-20-only pool a wrapped-native donation has no native reserve to credit; the PRD's sentence would unwrap into a reserve that does not exist. (b) "Observed delta" is not defined as same-call or durable. The canonical pattern distinguishes `balanceAfter - balanceBefore` (same-call) from the durable unbooked surplus `balance - booked`; using the durable form would let a donation absorb an unrelated earlier transfer, which is precisely the separation S1-X09 and S1-ACC-04 are trying to protect.
4. **Proposed wording.** Amend S1-ACC-04: *"`donate(token, amount)` is payable and accepts only `token == address(0)` or a declared pool currency face. On a pool with a native leg, `token == C0` (the bound wrapped native) is accepted and unwrapped into the native reserve; on an ERC-20-only pool a wrapped-native donation reverts. The credit is the **same-call** observed delta (`balanceAfter - balanceBefore`) of the donated leg, not a durable unbooked surplus, so a donation can never absorb an unrelated earlier transfer. If the observed delta is less than `amount`, revert `TransferDeltaInsufficient(amount, observedDelta)`. The donation requires positive supply and a positive amount, mints no shares, and the credited amount becomes booked idle eligible for the next compound."*
5. **Owner choice or correction.** Technical correction.
6. **Trade-offs and confidence.** High confidence.

---

### R14 — H — The SY interface declaration does not balance against the 16 selectors, and the PRD does not say so

1. **Locator.** PRD S1-API-01 (*"`IStandardizedYield` | All 16 native SY methods listed below"*), S1-API-03, S1-ARCH-04 (*"SY inherits the token interfaces without reinstalling their selectors"*). Canonical: `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol` (`interface IStandardizedYield is IERC20Metadata`), `contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol` (`_append` adds exactly the 16 selectors), `…/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultSYFacet.sol` (`facetFuncs()` = the same 16; `facetInterfaces()` = `[type(IStandardizedYield).interfaceId]`).
2. **Evidence class.** Source observation.
3. **Gap and consequence.** The 16-selector list is exactly right — that part of the PRD is verified. But `type(IStandardizedYield).interfaceId` also covers `name`, `symbol` and `decimals` inherited from `IERC20Metadata`, which the reused `ERC20Facet` supplies. The PRD says the SY facet does not reinstall those selectors, but never states that its **declared** interface id therefore depends on the ERC-20 facet being present. A check of the form "declared interfaces == own selectors" will not balance, and S1-A06/S1-A56 as currently worded ("Target/interface-derived controls equal package-owned facet declarations and cuts") do not anticipate that.
4. **Proposed wording.** Amend S1-API-01's `IStandardizedYield` row and S1-A56: *"The SY facet declares exactly one interface id, `type(IStandardizedYield).interfaceId`, and contributes exactly the 16 selectors listed in S1-API-03. That interface id necessarily also covers `name`, `symbol` and `decimals` inherited from `IERC20Metadata`, which are supplied by the reused `ERC20Facet`; those three selectors are absent from the SY facet's own cuts and present in the ERC-20 facet's cuts, and the package installs them exactly once."*
5. **Owner choice or correction.** Technical/editorial correction.
6. **Trade-offs and confidence.** High confidence.

---

### R15 — H — `contentsId` and `vaultConfig().tokens` are not pinned to one ordered list

1. **Locator.** PRD S1-ARCH-05 (*"`contentsId = keccak256(abi.encode(tokens))` for that ordered token list"*), S1-API-01 (`IBasicVault`, `IStandardVault`). Canonical: `contracts/vaults/standard/StandardVaultRepo.sol` `_initialize(feeOracle, vaultFeeTypeIds, vaultTypes, contentsId)` — `contentsId` is an **argument**, not computed by the repo; the Wings package passes `keccak256(abi.encode(tokens))` over its token list and sets `vaultTypes() = facetInterfaces()`.
2. **Evidence class.** Source observation.
3. **Gap and consequence.** The PRD's formula matches the reference package's usage, but it does not say which list is hashed. For a native pool there are two candidate lists: the pool currencies (`[address(0), currency1]`) and the declared ERC-20 faces (`[wrappedNative, currency1]`). Only the second is consistent with `vaultTokens()` and `vaultConfig().tokens` per S1-NATIVE-01. If `contentsId` were computed over the pool currencies, it would disagree with the reported contents, breaking registry lookup by contents id.
4. **Proposed wording.** Add to S1-ARCH-05: *"The canonical ordered token list for this family is `tokens = [C0, C1]` in PoolKey order, with a native leg represented by its bound wrapped-native face. `contentsId = keccak256(abi.encode(tokens))` over exactly that list; `MultiAssetBasicVaultRepo` is initialised with the same list; `vaultConfig().tokens` and `vaultTokens()` report the same list. `address(0)` never appears in `vaultTokens()`, `vaultConfig().tokens`, or the `contentsId` preimage."*
5. **Owner choice or correction.** Technical correction.
6. **Trade-offs and confidence.** High confidence.

---

### R16 — M — `DUST` is a raw-unit constant applied across mixed decimals

1. **Locator.** PRD S1-OP-05 (*"If either eligible idle balance exceeds `DUST = 1000` native units"*), S1-A23, S1-A44. Baseline: `PairToken.sol` `uint256 public constant DUST = 1000;`, used as `idle0 > DUST || idle1 > DUST` in `_compound()` and `leftover <= DUST` in `_ratioSwap()`.
2. **Evidence class.** Source observation plus inference.
3. **Gap and consequence.** `DUST` is compared against raw balances of both legs, so on a 6-decimal leg 1000 units is 0.001 token (the dust branch is effectively disabled) while on an 18-decimal leg 1000 wei is negligible (the branch is effectively always taken). The constant decides whether a compound swaps at all, so the same vault behaves very differently depending on the currencies' decimals. S1-A44 requires mixed 6/8/18-decimal currencies to work but says nothing about this.
4. **Proposed wording.** Add to S1-OP-05: *"`DUST = 1000` is a raw-unit constant inherited from the baseline and compared against both legs' raw units; it is **not** decimals-normalised. The implementation keeps this value (baseline fidelity), and S1-A44 must additionally record that on a 6-decimal leg the dust branch is effectively disabled. If the owner prefers decimals-normalised dust, that is a separate decision and must be recorded as a deviation."*
5. **Owner choice or correction.** Optional owner decision; otherwise editorial.
6. **Trade-offs and confidence.** High confidence the effect is real; low priority.

---

### R17 — M — The comparison ledger has no bucket for capabilities with no baseline counterpart

1. **Locator.** PRD S1-TEST-01 (*"Maintain a comparison ledger with **preserved**, **intentional deviation**, or **unsupported scope** for each baseline behavior being compared"*), S1-ACC-04, S1-API-02, S1-A34..S1-A37, S1-A38. Baseline `PairToken.sol`: no `pretransferred` flag anywhere; `_pull()` is a plain `transferFrom` with a balance-delta check; no donation entrypoint.
2. **Evidence class.** Source observation.
3. **Gap and consequence.** The pretransfer contract, the booked/unbooked split, the donation operation, and the native wrap/unwrap adapter are **new capabilities with no baseline counterpart**. The three-value taxonomy has no place for them, so an implementer will either force them into "preserved" (wrong) or omit them (also wrong, and the S1-TEST-01 requirement then reads as if they were covered). Related: S1-ACC-04's *"As with the canonical SE contract, cross-transaction pretransfers have no ownership guarantee"* attributes pretransfer semantics to "the canonical SE contract", which is the Crane interface NatSpec, not the baseline — an implementer reading the baseline for pretransfer semantics will find nothing.
4. **Proposed wording.** Amend S1-TEST-01: *"Extend the ledger taxonomy with a fourth class, **'new capability (no baseline counterpart)'**, used for the pretransfer flag, the booked/unbooked split, the donation operation, and the native wrap/unwrap adapter. Pretransfer semantics are defined by the NatSpec of `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` and `IStandardExchangeOut.sol` and by `contracts/utils/LocalCreditLib.sol`; the baseline `PairToken` has no pretransfer path, no donation path and no booked/unbooked split, so no comparison row is defined for them and none may be recorded as 'preserved'."*
5. **Owner choice or correction.** Technical correction.
6. **Trade-offs and confidence.** High confidence.

---

### R18 — M — The two zap parameters have a coupled, undocumented effect and a sharp edge at zero

1. **Locator.** PRD S1-ARCH-03 items 4-5, S1-OP-02 steps 3 and 7, S1-OP-05 (*"capped by the baseline active-pool reserve estimate times `maxZapBps / 10000 / 4`"*). Baseline: `zapDeposit` (`amountIn > reserve * maxZapBps / BPS` → `ZapTooLarge`; `movement > maxZapTickMove` → `ZapMovesPrice`), `_ratioSwap` (`cap = reserve * maxZapBps / BPS / 4`).
2. **Evidence class.** Source observation.
3. **Gap and consequence.** One immutable parameter has two distinct effects — it caps a single-depositor zap and it caps the compound's ratio swap at a quarter of itself — and this coupling is nowhere stated as a single rule, so an implementer may treat the compound cap as an independent constant. Separately, `maxZapTickMove` is measured against the live pool price, so a configured value of 0 makes every single-token zap revert in any pool whose price moves during the swap; the PRD's only constraint is "nonnegative and representable as the baseline tick bound", which permits that configuration without warning.
5. **Proposed wording.** Add to S1-ARCH-03: *"`maxZapBps` has exactly two effects, both inherited: it caps a single-depositor zap at `floor(inputReserve * maxZapBps / 10000)`, and it caps the compound's ratio swap at `floor(activeReserve * maxZapBps / 10000 / 4)`. `maxZapTickMove` bounds only the entry zap swap's absolute tick movement and is not applied to the compound. Because `maxZapTickMove` is measured against the live pool price, a value of 0 makes every single-token zap revert in any pool whose price moves during the swap; instance configuration must document this."*
6. **Owner choice or correction.** Editorial plus a configuration caveat; optionally an owner decision on a minimum sensible `maxZapTickMove`.
7. **Trade-offs and confidence.** High confidence on the coupling; the zero-value edge is a direct consequence of the baseline's measurement.

---

### R19 — M — Terminal-exit residue has no stated destination

1. **Locator.** PRD S1-ACC-05 (*"After successful payout, `S`, `L`, and both booked balances are zero. Unbooked unsolicited balances are not assigned to the last holder or the next bootstrap"*), S1-A20, S1-A21, S1-A54.
2. **Evidence class.** Inference.
3. **Gap and consequence.** A terminal exit is preceded by a mandatory compound and, on the single-token path, by a sale. Rounding residue from the liquidity removal and swap output not consumed by the payout are **operation-generated**, not unsolicited — the PRD's sentence does not cover them. Such residue would leave the raw balance permanently non-zero while the book is zero, which makes "raw basket" queries disagree with the book and leaves value stranded with no owner.
4. **Proposed wording.** Add to S1-ACC-05: *"After a terminal exit the booked book is zero. Any residue produced by the operation itself — rounding dust from the removal, or swap output not consumed by the payout — is classified as unbooked and is explicitly abandoned: it is either left in the contract and permanently unbooked, or swept to a fixed dead address at the end of the terminal operation. It must never be carried into the next bootstrap or attributed to the last holder. The chosen disposition is emitted as a family event."*
5. **Owner choice or correction.** Owner choice (where the dust goes). Folded into **Q6**.
6. **Trade-offs and confidence.** Medium-high confidence the gap is real; the magnitude is small but the principle matters for the rebootstrap invariant S1-A20/S1-A54.

---

### R20 — M — The rate algorithm should be named instead of "an overflow-safe algorithm"

1. **Locator.** PRD S1-QUOTE-02 (*"Use overflow-safe full-precision integer algorithms with documented rounding, not floating point or an overflowing `P*P`"*). Baseline `PairToken.sol` `_ratioSwap()` already contains the needed two-step construction: `value0 = PairTokenMath.MD(PairTokenMath.MD(state.leftover0, state.price, Q96), state.price, Q96)`.
2. **Evidence class.** Source observation plus inference.
3. **Gap and consequence.** The PRD requires a property ("overflow-safe, documented rounding") rather than an algorithm. `PairTokenMath.MD` already computes the full 512-bit product and the baseline already uses the two-step composition to convert a token0 amount into token1 units, so the exact construction needed for `A0 * r²` and `A1 / r²` is available and characterized. Leaving it unnamed means an implementer may pick a single 512-bit division with different rounding, and S1-A32 then has no independent ground truth. The PRD also does not cross-reference S1-X13's clamped removable amounts here, so `A0`/`A1` could be read as unclamped position value.
4. **Proposed wording.** Amend S1-QUOTE-02: *"Compute the rate from the **clamped removable amounts** `A0`, `A1` (per S1-X13) and the live `P`, using `PairTokenMath` only. Token1-denominated value `V1 = A1 + MD(MD(A0, P, Q96), P, Q96)`; token0-denominated value `V0 = A0 + MD(MD(A1, Q96, P), Q96, P)`. Both are floor-rounded and overflow-safe because `MD` divides the full 512-bit product; the token1 construction is the same two-step composition the baseline uses in `_ratioSwap`. `exchangeRate()` selects the value in `rateAsset` units and normalises it per R1. The rate includes accrued LP fees exactly once and is never computed from a simulated sale."*
5. **Owner choice or correction.** Technical correction.
6. **Trade-offs and confidence.** High confidence in the construction; medium on the rounding direction (floor on both legs mirrors the baseline, and is the natural default).

---

### R21 — M — Several acceptance rows cannot fail as written

1. **Locator.** PRD section 10 preamble (*"Each row is an independent acceptance obligation"*), S1-A15, S1-A28, S1-A32, S1-A44, S1-A46.
2. **Evidence class.** Source observation of the PRD text plus inference.
3. **Gap and consequence.** S1-A15 (*"quantify attribution and dilution; unacceptable transfer is reported, not hidden by a changed formula"*), S1-A46 (*"measure gains/losses without assuming a nonexistent oracle defense"*), S1-A32 (*"it differs from price-impact-sensitive exit quotes where expected"*) and S1-A28 (*"rejects consistently in preview and execution"*) all prescribe *measurement* without a pass predicate. A row that cannot fail is not an acceptance obligation, and these four are the rows that carry the PRD's economic gates.
4. **Proposed wording.** Give each a falsifiable predicate. S1-A15: *"for every state in the matrix, `issuedShares <= fairShares + 1` (one unit of rounding), or the row fails and reports the violating state"* (with `fairShares` per R8). S1-A32: *"for a 6-decimal `rateAsset`, `exchangeRate()` equals `MD(Vraw, 1e18, S)` computed independently in the test, and it differs from the `previewRedeem` output by a non-zero amount whenever the preview includes a sale"*. S1-A46: *"the measured gain/loss of each sequence is within the bound the sequence's own inputs justify, and every sequence that transfers value from incumbents to a new depositor is listed with its magnitude"*. S1-A28: *"a preview whose simulated traversal exceeds `QUOTE_MAX_SWAP_STEPS` returns the named quote-work error, and the same inputs in execution revert with the same error and never produce a partial amount"*.
5. **Owner choice or correction.** Technical correction, except the numeric thresholds in S1-A15/S1-A46, which fold into **Q2**.
6. **Trade-offs and confidence.** High confidence.

---

### R22 — M — The "already unlocked" detection must name the canonical read

1. **Locator.** PRD S1-OP-05 (*"Calls while the manager is already unlocked fail explicitly before any nested unlock"*), S1-A40 (*"Already-unlocked PoolManager context rejects before attempted nested unlock; no stale local-sleeve fallback is used"*). Canonical: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol` (`isUnlocked(IPoolManager manager)`), `libraries/Lock.sol` (`Lock.isUnlocked()` over a transient slot), `PoolManager.sol` (`revert ManagerLocked()` / `revert AlreadyUnlocked()`), `interfaces/IPoolManager.sol` (both errors declared). Baseline `PairToken.sol`: `unlockCallback` authenticates only `msg.sender != address(poolManager)`.
2. **Evidence class.** Source observation.
3. **Gap and consequence.** The PRD requires a *pre-nested-unlock* failure but never names the mechanism. A canonical unlocked-state read exists (`TransientStateLibrary.isUnlocked`), and the manager's own errors (`ManagerLocked`, `AlreadyUnlocked`) are the alternative fallback. Without naming one, an implementer may attempt to read state the canonical manager interface does not expose, or may satisfy the requirement only by letting the manager's error propagate — which is a different behaviour from "fail explicitly before any nested unlock".
4. **Proposed wording.** Add to S1-SEC-01: *"The family's operation guard distinguishes three states: (a) no operation in flight; (b) an operation in flight on this diamond; (c) the PoolManager is unlocked but the call did not originate from this diamond's in-flight operation. Case (c) must fail with a named family error **before** any nested `unlock` is attempted. The canonical read for the manager's unlocked state is `TransientStateLibrary.isUnlocked(IPoolManager)`; the family's fallback is the manager's own `AlreadyUnlocked()` error, and the PRD must state which is normative. The callback additionally authenticates the manager, the active operation kind, and a payload commitment (S1-X11)."*
5. **Owner choice or correction.** Technical correction (naming the mechanism).
6. **Trade-offs and confidence.** Medium confidence — I confirmed the canonical read exists but did not read the whole transient-state surface.

---

### R23 — M — `rateAsset` decimals and the `contentsId` list are stated separately but never reconciled to one source

1. **Locator.** PRD S1-ARCH-03 item 2 (`rateAsset` "equal to one of the two declared ERC-20 currency faces (wrapped native when selecting the native pool leg)"), S1-QUOTE-02 (*"its actual decimals"*), S1-ARCH-05, S1-API-01. Canonical: `contracts/vaults/standard/StandardVaultRepo.sol` `Storage.decimalOfToken` (`mapping(address token => uint8 decimals) decimalOfToken`) exists but has **no writer** in the repo, and the Wings package does not populate it.
2. **Evidence class.** Source observation.
3. **Gap and consequence.** The PRD requires `assetInfo()` to report the `rateAsset`'s "actual decimals" and the rate to be denominated in that asset, but it never states where those decimals come from. The shared `StandardVaultRepo` has a decimals mapping with no setter, so the family cannot use it as-is; the decimals must be read from `IERC20Metadata(rateAsset).decimals()` at query time or snapshotted at initialization — and the two choices differ for a token with mutable decimals.
4. **Proposed wording.** Add to S1-QUOTE-02: *"`rateAsset` decimals are read from `IERC20Metadata(rateAsset).decimals()` at query time. They are not stored in `StandardVaultRepo.decimalOfToken` (that mapping has no writer in the shared repo) and are not snapshotted at initialization. `assetInfo()` reports the same value it uses for the rate normalisation."*
5. **Owner choice or correction.** Technical correction; if the owner prefers a snapshot, that is a small decision to record.
6. **Trade-offs and confidence.** Medium-high confidence.

---

### Fidelity summary (unapproved baseline deviations)

The deviation register is honest about what it changes, and I found no deviation that contradicts a confirmed owner choice. Two register entries deserve an owner-visible label rather than a silent implementation choice: **S1-X03** (removing the 10 bps retention changes the exit math for *every* holder, and it is a confirmed owner decision — it should be stated as such in the register, not only in S1-D03), and **S1-X12** (requiring the single-token exit to consume its entire unwanted allocation changes *liveness*: an exit that the baseline would have partially filled now reverts). Both are consequences of confirmed or named choices, but neither is currently written as an owner-visible consequence.

## Owner clarification questions

Each question is material, has alternatives, and carries a recommendation. None re-asks the eight settled choices.

**Q1 — Which interface shape owns the paired and single-leg routes?**
- (a) Adopt the canonical `IStandardExchangeMultiAssetLiquidity` selector shapes (`joinProportional`, `exitProportional`, `joinSingleAssetExactIn`, `exitSingleAssetExactBptIn`) — *recommended*.
- (b) Keep bespoke `depositPair`/`redeemPair` names, but then the PRD must publish exact signatures and selectors and record the divergence from the canonical interface.
- Recommendation: (a). It removes a second naming of the same accounting, matches what SE integrators already know, and makes S1-A06 writable.

**Q2 — If the zap attribution gate trips, what is the default?**
- (a) Credit only the zapper's incremental contribution; incumbent idle stays with existing holders — *recommended*.
- (b) Revert the zap when incumbent idle would be consumed.
- (c) Keep the baseline formula and accept the transfer as a documented stage-one limitation.
- Recommendation: (a), written into S1-OP-02 step 8 now, with the "unacceptable" threshold defined as `issuedShares > fairShares` (R8, R21). Without a pre-committed default, stage one can ship the value-losing formula.

**Q3 — When are collected LP fees and swap proceeds booked?**
- (a) Booked at collection (fees) and at settlement (swap deltas), so the book always equals shareholder backing — *recommended*.
- (b) Booked only when deployed into the position, with uncollected/undeployed value held unbooked.
- Recommendation: (a), encoded as the S1-ACC-06 ledger (R2). (b) would make `B0/B1` diverge from what shareholders can redeem, which contradicts S1-ACC-03.

**Q4 — Does the package advertise exact-output support in ERC-165?**
- (a) Install the two exact-output selectors (they revert) but omit `IStandardExchangeOut.interfaceId` and `IStandardExchange.interfaceId` from the package's ERC-165 set — *recommended*.
- (b) Register them, accepting that ERC-165 advertises a route the vault always refuses.
- Recommendation: (a). It is the only option consistent with S1-P03 and with the PRD's own "truthful declaration" principle (R3).

**Q5 — What preview guarantee does stage one ship?**
- (a) Conservative preview (never over-promises) plus an execution-authoritative preflight; exact parity asserted only for the deterministic subset — *recommended for stage one*.
- (b) Full swap simulator over the canonical state libraries, with exact parity asserted everywhere.
- Recommendation: (a), with (b) recorded as a stage-two candidate. (b) is a substantial sub-project the PRD does not scope, and (a) protects liveness: a caller's minimum is checked against the executed result, not against an optimistic quote (R5).

**Q6 — Where does terminal-exit residue go?**
- (a) Swept to a fixed dead address at the end of the terminal operation and emitted as a family event — *recommended*.
- (b) Left in the contract, permanently unbooked.
- Recommendation: (a). (b) leaves a permanently non-zero raw balance that contradicts the "book is zero" invariant and complicates the rebootstrap assertions in S1-A20/S1-A54 (R19).

**Q7 — Does native redemption offer both ETH and wrapped-native delivery?**
- (a) Yes, at identical economics, with `previewRedeem` matching each delivery form exactly — *recommended, and consistent with what S1-API-03 already says*.
- (b) Native delivery only (the wrapped face is out of scope).
- Recommendation: (a), but it doubles the payout surface, so the refund/settlement branches and the S1-A50 equality requirement must be stated explicitly, and `redeem` must be overridden in full rather than only its value check (R7).

## Assumptions and limits

1. **Assessment type.** This is a static requirements assessment of a draft PRD. It is not a runtime-correctness proof, not a security audit, and not a certification. No exploit procedure or payload is included; the adversarial content is limited to requirements the PRD must resolve before implementation.
2. **No execution.** Nothing was built, run, deployed, or installed, and no Git operation was performed. Every claim about baseline runtime behaviour is an inference from reading `PairToken.sol`; where an inference depends on a reachable state I could not verify without execution (R6's refund under-funding, R8's incumbent-idle transfer magnitude), I said so.
3. **Verified facts are limited to what was read.** The 20-selector count, the 16-method SY surface, the factory's facet-assembly order, and the V4 price-limit bounds were checked against the named sources. The Wings `TestBase` and the registry implementation were not read in full.
4. **Owner decisions vs author proposals.** I treated S1-D01..D05 and S1-P01..P03 as settled and did not re-ask them. I treated every other normative statement in the PRD — including all of the deviation register S1-X01..X14, all of S1-ARCH/ACC/OP/API/QUOTE/PKG/SEC/OBS, and all 57 acceptance rows — as author-proposed, which is what the brief instructs. Where I proposed wording that changes a PRD statement, I marked whether it is an owner choice or a correction.
5. **No peer evidence.** I read no other member's file, no earlier council report, and no private memory. Where I refer to "the reference package" I mean the checked-in Wings package, read as packaging context only, not as economic authority.
6. **Write mechanism.** No `apply_patch` tool is exposed in this session (verified by tool catalogue search), and the harness's sanctioned Markdown-creation capability is its file-creation tool, which I used at exactly the assigned path. I did not use shell redirection, scripting, or any other write workaround, and no file other than the assigned `response.md` was created or modified.
7. **Coverage I did not pursue.** The ERC-4626, Morpho, DETF, Balancer V3 and hook families, the frontend, and the retired V4 families were not read; none is in the stage-one scope named by the PRD, and none was needed to test any claim above. I did not read `PairTokenTestBase.sol`'s assertions, so I cannot say whether the baseline suite already exercises the residue and refund paths in R6 and R19.
8. **Single-file scope of the deliverable.** This response is my only written artifact for this assignment. It does not modify, and must not be read as modifying, the PRD.
