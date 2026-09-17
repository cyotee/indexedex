# Implementation plan: Uniswap V3/V4 FullSpread Standard Exchange vault liquidity leak fixes

- **PRD:** [uniswap-se-v2-liquidity-leak-fixes.md](./uniswap-se-v2-liquidity-leak-fixes.md)
- **Created:** 2026-09-16
- **Status:** implemented and validated (2026-09-16)
- **Input:** reviewed PRD, ninth pass; decisions D1–D26 locked.

This file is the execute artifact. Give implementation execution this path. Follow this plan and the PRD without reopening their product decisions. Planning itself performed no implementation or validation. Execution is now complete: acceptance below is supported by the final local build/test evidence in `VALIDATION.md`. No live deployment was performed.

Execution baseline: `/private/tmp/fullspread-baseline-dpp0i66f` contains the starting working-tree diff, revision, status, and original evidence files. The initial 96/96 preserved-source gate passed. Existing unrelated skill/documentation changes are retained. Final FullSpread artifact build and all 654 tests in 49 suites passed. Both 64 × 96 invariant campaigns completed without unexpected reverts. All 26 deployed artifacts fit (largest: V3 InQueryFacet, 24,099 bytes), so AC74 requires no split. The final 96/96 preserved-source gate and unchanged-manifest checks passed. See `VALIDATION.md`, `REGRESSION_RESULTS.txt`, and `VALIDATED_ARTIFACTS.json`.

## Objective

Rename the current Uniswap V3/V4 Standard Exchange V2 packages in place to FullSpread and close the specified first-mint, delivery, refund, and imported-position allowance leaks. Book only diamond-held ERC-20 balances in `reserveOfToken`; continue pricing shares from live free assets, deployed assets, and uncollected fees. Deliver production-proxy regression evidence, preserve old packages byte-for-byte, and leave live deployments untouched.

## Execution context and paths

Run commands from the repository root. Before implementation read `CLAUDE.md`, `.github/ASSISTANT_RULES.md` and its coding/deployment/testing documents, `docs/agent/INDEXEDEX_AGENT_LAW.md`, and `docs/testing/ARTIFACT_BUILDS.md`. Apply canonical `lib/crane/.claude/skills/crane-{architecture,deployment,testing,adversarial-testing}/SKILL.md` and `.claude/skills/indexedex-{testing,adversarial-testing}/SKILL.md`. The source PRD overrides the older Uniswap remediation PRDs on the conflicts it names. Preserve their remaining economics/release gates.

Path shorthand in this document:

| Shorthand | Repository-relative path |
|---|---|
| `P` | `contracts/vaults/standard/exchange/protocols/uniswap` |
| `T` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap` |
| `F3` | `UniswapV3FullSpreadStandardExchangeVault` |
| `F4` | `UniswapV4FullSpreadStandardExchangeVault` |

`F3`/`F4` in filenames mean literal substitution, not new directories. Paths described as renamed are replacement paths created by moving existing files. New files are explicitly identified below. Existing V3/V4 production and test paths were inspected while preparing the plan.

## In scope

- R1: scaled minimum-liquidity shares on dual-join and NFT-import activation, shared math, previews, residual sink shares, and decimal/attack controls.
- R2/R7: balance-only reserve booking, measured push/pull delivery, exact-in equality, exact-out used-input checks and capped refunds, Native SY holder redemption, and router paths.
- R3/R8: remove V4 imported-increase approvals; verify empty V3/V4 imported NFT custody and V3 original-owner collect rejection.
- R4/R5/R6: permissionless sleeve and locked-exit controls, configured FoT rejection, hostile callbacks, disable behavior, proxy selector coverage, and greppable adversarial suites.
- R9: in-place component/test rename, FullSpread-only name salts, conditional facet splitting, historical-evidence labeling, source map, final runtime/test evidence, and preserved-source verification.

## Out of scope

- Do not modify preserved implementations or live deployments. Preserve baseline test assertions and deployment targets. The sole preserved-test cleanup exception is requirement 6's removal of the unused `_prepare` helper/import from `StandardExchangePreservedBehavior.sol`; the shared `StandardExchangeLockedCaller` rewrite must preserve its empty-token-array behavior used by those baselines. Neither exception permits changing preserved vault behavior or expected results.
- Do not deprecate the preserved old vaults in this work. That is a separate effort.
- Do not infer an upgrade or migration path for immutable old instances.
- Do not repoint DETF, Pendle, hook, or router consumers onto FullSpread as part of this work.
- Do not build the open `CP-09` production consuming-hook integration. Bound-pool lock and PoolManager outer-unlock harnesses already in `release/` stay. Record `CP-09` as still open in `VALIDATION.md`. Push-only callers that already did `transfer` then `pretransferred=true` without prepare are the intended sequence; they still must not use `storedTotal - deployed`.
- Do not replay the historical Robinhood deposit/withdraw (`CP-07`).
- Do not change constant-product economics beyond the first-mint minimum-liquidity subtraction. Do not switch to oracle-NAV issuance.
- Do not add fee-on-transfer support. Do not add a `PkgArgs` token allowlist.
- Do not add a public skim, leftover-ETH refund, or `balance - floor` payout. `exchangeOut` this-call unused-inbound refunds to `msg.sender` (catalog E6) stay; they are not a public skim.
- Do not auth-gate `rebalanceLiquidReserve`.
- Do not require `preparePretransfer`. Do not add `contributePretransfer`. Do not require the caller's token balance to fall. Routers `transferFrom(user, vault)` then `exchangeIn(..., pretransferred=true)`.
- Do not treat a stray `transfer` onto a live vault as an LP principal bug. Here, “stray transfer” or “unsolicited donation” means a direct ERC-20 transfer without a vault operation that processes and books it. Such transfers are outside expected usage and require no sender-attribution ledger, donation-protection mechanism, or additional release gate. Tokens processed into reserves by a vault function are booked inventory and remain protected. Requirement 1's explicit first-mint attack regression remains in scope.
- Do not mock the SUT. Do not `new` facets or vault DFPkgs.
- Do not wrap Permit2 or `modifyLiquidities` in try/catch so a revert can be swallowed or continued.
- Do not keep `_increaseImportedPositionCommon` / `_deployExcessImported`. Do not `Permit2.approve` or `IERC20.approve` the Position Manager.
- Do not leave a parallel `*V2` package beside FullSpread in this tree.
- Do not add a second `held` mapping. Do not persist deployed position amounts. `reserveOfToken` is booked diamond ERC-20 only.
- Do not implement the repository-wide CREATE3 salt correction here. `docs/create3-release-salt-input-correction.md` owns shared helper signatures, library-linking salts, other FactoryServices/scripts, and global deployment compatibility tests. This effort changes only the renamed FullSpread component/package salt expressions under requirement 9.

## Constraints

- Crane first: CREATE3 facets, vault DFPkg through `indexedexManager.deploy*DFPkg`, instances through `deployVault` / registry. Final component/package salts are directly `keccak256(abi.encode("<FullSpread contract name>"))`, without `releaseSalt` wrapping (D22). Vault-instance salt derivation remains unchanged.
- Token policy: FoT forbidden; rebasing underlyings forbidden; non-18 decimals allowed; pause/blacklist accepted; no `PkgArgs` allowlist.
- Role names on IndexedEx surfaces: `rateAsset`, `pairToken`, `underlyingVault`, `vaultShare`. These SE tests may use `token0` / `token1` / `asset0` / `asset1` for pool faces.
- Delivery for `pretransferred=true` is `balanceOf - reserveOfToken`. `exchangeIn` requires `actualIn == amountIn`. `exchangeOut` requires `actualIn >= used` and refunds this-call surplus to `msg.sender`. `reserveOfToken` is diamond ERC-20 booked at the end of vault ops (after that refund). Delivery never uses deployed amounts, pool price, uncollected fees, or a transient prepare snapshot. Share math may still read live deployed from the pool / position.
- `via_ir` forbidden. Artifact build before test. Forge patience: first compile may take hours; do not kill `forge`.
- Every deployed FullSpread facet, execution delegate, and DFPkg stays within the 24,576-byte runtime limit. An overflowing facet is split per D25; `via_ir`, global optimizer changes, and dropping specified behavior are not remedies.
- Shared helpers stay in `StandardExchangeConstantProduct` when both families need the same math (`MINIMUM_LIQUIDITY`, `InsufficientMinimumLiquidity`). Do not keep a second prepare ledger.

## Decisions (locked)

| ID | Decision | Status | Rationale |
|----|----------|--------|-----------|
| D1 | First-mint defense mints `MINIMUM_LIQUIDITY` dead shares and gives the caller `mulSqrt - MINIMUM_LIQUIDITY`, reverting if `mulSqrt <= MINIMUM_LIQUIDITY`. | Decided | Owner chose a decimal-scaled floor rather than Uniswap V2's 1000 or a virtual offset. |
| D2 | No `preparePretransfer`. Push is `pretransferred=true` plus `actualIn = balanceOf - reserveOfToken`. FullSpread does not cut the prepare selector. `exchangeIn` vs `exchangeOut` credit rules are D15. | Decided | Owner: the flag is the push facility. Prepare is not needed if `reserveOfToken` is booked diamond ERC-20. A preparer-balance check would also block `transferFrom(user, vault)`. |
| D3 | `rebalanceLiquidReserve` stays permissionless. Fix is tests plus NatSpec, not an onlyOwner/operator gate. | Decided | Owner confirmed. Matches the earlier liquid-reserve PRD D10 (not this file's D10). A non-zero oracle target already leaves a sleeve. Rebalance must write `reserveOfToken` from `balanceOf`. |
| D4 | `CP-09` production hook/router integration stays out of this PRD. | Decided | Owner confirmed. Record as still open in `VALIDATION.md`. |
| D5 | `MINIMUM_LIQUIDITY = 10 ** ((d0 + d1) / 2 - 3)` (or `1` if that exponent is negative); widen the decimal sum and floor integer division. | Decided | Owner asked for `1e15` on 18-decimal pairs, scaled by decimals. 18/18 → `1e15`, 6/18 → `1e9`, 6/6 → `1e3`. Odd decimal sums follow the integer formula (6/9 → `1e4`), rather than an exact fractional exponent. |
| D6 | FullSpread never `Permit2.approve`s or `IERC20.approve`s the Position Manager. Init keeps its existing max-approval of Permit2 for the PoolManager. | Decided | Owner: expire-at-timestamp and no try/catch. Position Manager `_pay` pulls ERC-20 via Permit2, not ERC-20 `allowance(pm)`. Native ETH and the NFT are not Permit2. The imported-increase helper is removed (D14), so there is no PM spender leftover to zero. |
| D7 | In-place rename of the current V2 tree to UniswapV3/V4FullSpreadStandardExchangeVault. CREATE3 salts and tests follow the new names. | Decided | Owner: distinguish these packages; salts change; tests switch. Old vaults are not deprecated here. No parallel `*V2` package in this tree. |
| D8 | FoT configured-token test is a revert test, not a DFPkg allowlist. | Decided | Agent law forbids a `PkgArgs` token allowlist. Measured pull delta already rejects FoT. Owner confirmed the L2 revert test. |
| D9 | Stray transfer onto a live vault is not an LP-security requirement (K1 deferred). | Decided | Owner: that is the donor's problem, not a vault exploit. First-mint donation remains A0. |
| D10 | `reserveOfToken` is booked ERC-20 on this diamond (`balanceOf` after vault ops). Do not add a `held` mapping. Do not persist deployed amounts. `_syncVaultReserves` writes `balanceOf`, not `_totalVaultReserves()`. | Decided | Owner: the mapping name caused agents to store free + deployed. Intended meaning is tokens the vault holds, not inventory in Uniswap. Share math still reads live deployed and live uncollected fees from the pool / position. TWAP is the oracle. `IBasicVault.reserveOfToken` is the public view. |
| D11 | Delivery reverts `TransferDeltaInsufficient`. First-mint floor miss reverts `InsufficientMinimumLiquidity` from `StandardExchangeConstantProduct`. | Decided | Owner: shared I1 error for push; do not reuse `ZeroAmount` for the floor. |
| D12 | External SY redeem: transfer shares then `pretransferred=true` using `balanceOf(share) - reserveOfToken(share)`. Internal SY redeem: fixed proxy self-call with `pretransferred=false`, burning its own shares through requirement 2's confined holder-burn exception. | Decided | Owner chose the base SY holder-burn behavior. Repo review confirms the current generic self-transfer has zero measured delivery, so routing alone is insufficient. |
| D13 | Catalog I2 (short push) and I3 (second unfunded push after a successful one) are required P0 tests. | Decided | Catalog I1–I3 are mandatory on SE pull-or-credit paths. I3 is the `reserveOfToken` write after a successful push. I2 is `exchangeIn` vs `amountIn` and `exchangeOut` vs `used`. |
| D14 | Delete `_increaseImportedPositionCommon` / `_deployExcessImported`. Import converts off the NFT, then organic rebalance. | Decided | Owner: that helper is unreachable after today's conversion order. Removing it closes M3. Permit2 does not move the ERC-721. |
| D15 | `exchangeIn` requires `actualIn == amountIn`. `exchangeOut` requires `actualIn >= used` (not claimed max). Fat max + transfer only `used` is `exchangeOut` only. Unused inbound refunds to `msg.sender` from this-call surplus only. | Decided | Owner confirmed the entry-point split. Matches catalog E6 on exact-out and keeps router `exchangeIn` exact. |
| D16 | Catalog E6 tests every `exchangeOut` refund path: token exact-out, zap-out unused shares, dual-exit unused shares. No E6 refund test on `exchangeIn`. V4 `_refundExcess` uses the V3 this-call unused-inbound cap. | Decided | Owner: all current residual-return paths. `exchangeIn` extra push reverts rather than refunds. |
| D17 | Locked-exit H tests: 10% of supply → `assertApproxEqAbs(..., 190 ether, 5)` and 1% of supply → `assertApproxEqAbs(..., 19.9 ether, 5)` after a 20% sleeve rebalance on a 1000/1000 book. Path is locked `exchangeIn` zap-out exact-in. Do not mix 1% with 190 ether. | Decided | Owner: both assertions. 190 ether is `_singleExit` at 10% (100 + 900*100/1000); 19.9 ether is `_singleExit` at 1% (10 + 990*10/1000). 20% sleeve (~200) covers both. |
| D18 | Apply D1 to every activation, including NFT import; retain the existing invalid single-token activation behavior. | Decided (derived from D1 and repository routes) | Both import targets can activate at zero supply and already use the shared issuance calculation. Excluding them would bypass the specified first-mint defense. |
| D19 | D15's over-max push refund remains capped; book the excess above max. Capture delivery before internal settlement and retain existing pull/holder-burn behavior outside D12: dual exits pull max shares and refund unused shares on both families; single-output exact-out zap-out burns only used shares directly from the caller. | Decided (derived from D10/D15 and repository routes) | This makes the existing formula and end-of-operation booking explicit without changing the owner's refund policy. |
| D20 | Preserve the existing sleeve rounding/dust policy and release artifact limits; prove FoT rejection at the first join on a successfully deployed configured-token fixture. | Decided (repository requirements) | The current rebalance helpers, configurable-fee fixture, and validation record supply concrete acceptance conditions; no new sleeve minimum or token allowlist is introduced. |
| D21 | The balanced 18/18 A0 regression requires no net profit in either token after a proportional dual exit of all attacker-issued shares. Initial deposit and donation both count as attacker costs. | Decided | Owner confirmed the per-token nonpositive net-profit bound; profit merely below the donation is insufficient. |
| D22 | Use `keccak256(abi.encode("<new contract name>"))` directly as the final CREATE3 salt for FullSpread facets, execution delegates, and DFPkgs; remove their current `releaseSalt` wrapping. | Decided | Owner's latest decision standardizes all component names to the ABI-encoded name hash, superseding the earlier raw-name formula. The shared helper, unrelated deployments, and vault-instance salt derivation remain unchanged within this effort. |
| D23 | Track removal of creation-code/constructor salt inputs from contract deployments through the CREATE3 Factory in the separate `docs/create3-release-salt-input-correction.md` effort. Keeping a namespace-only `releaseSalt` function is permitted there. Proxy deployment, `PkgArgs`, and `calcSalt` are excluded. | Decided | Owner requested correction everywhere within CREATE3 Factory deployment scope, explicitly separated it from liquidity fixes, and confirmed that proxy deployment is unchanged. D22's unchanged-shared-helper boundary applies to this effort only. |
| D24 | Internal SY holder-burn credits the diamond's existing share balance in `_secureShareDelivery` and burns only in the existing zap-out/execute path. Internal redeem uses `super._standardRoute`. | Decided (derived from D12 and current zap-out burn) | A diamond-to-itself `transferFrom` has zero delta. Burning in the delivery helper would double-burn with `ERC20Repo._burn` in `_executeZapOutExactIn`. `NativeStandardYieldTarget` already self-calls with `pretransferred=false`. |
| D25 | A FullSpread facet that exceeds the 24,576-byte runtime limit is split into the mapped facet plus an `Ext` facet with its own name, salt, FactoryService helper, and DFPkg cut. `via_ir`, global optimizer changes, and dropping specified behavior are not remedies. | Decided | Owner chose the facet split over relocating logic into execution delegates. Five artifacts are already within 1.8 KB of the limit (tightest: `UniswapV3StandardExchangeInQueryFacetV2` at 23,737 bytes), and requirements 1, 2 and 7 add code to those surfaces, so the effort needed a named remedy rather than an implementor choice. |
| D26 | `DeliveryTestToken` gains `setCallbackPropagates(bool)`, default `false`, so C1 covers both the existing swallow-and-record callback and a rethrowing one. | Decided | Owner chose one switched fixture over a second hostile token. Defaulting to `false` keeps today's behavior, including the `require(!ok, ...)` guard, for every suite already using the token. |

## Work order

Each step's **Files** list uses the path shorthand above. The union of those lists is the implementation edit boundary. Keep changes to existing shared helpers/tests within the explicit purposes below. Do not perform the separate global salt correction during this execution.

### Step 1: Record the baseline and rename the FullSpread deployment graph

- **Files:** Rename all `.sol` files below `P/v3/` and `P/v4/`, including interfaces and `test/bases/`, according to R9. Rename FullSpread-targeting `.sol` tests/helpers below `T/remediation/`, `T/release/`, and `T/invariants/`; preserve the `*PreservedBaseline*` files and deployment targets. Modify `P/VERSION_SOURCE_MAP.json`. Read, but do not modify, `P/PRESERVED_SOURCE_SHA256.json` and `P/PRESERVED_BUILD_CONTEXT.json`.
- **Do:** Snapshot the starting working-tree diff and evidence files before edits; retain unrelated user work. Verify all 96 preserved hashes using Verification V1. Use R9's exact component, FactoryService, TestBase, off-pattern repo/service, and leading-`I` mappings. For test-only names, replace the `UniswapV3StandardExchange`/`UniswapV4StandardExchange` prefix with F3/F4 and remove the `V2` suffix/marker, preserving the test-purpose suffix. Rename `V3FullRangeNativeSY.t.sol` to `F3_NativeSY.t.sol`, `UniswapV3BoundPoolLockSeCallerV2.sol` to `F3BoundPoolLockSeCaller.sol`, `PoolManagerUnlockSeCallerV2.sol` to `F4PoolManagerUnlockSeCaller.sol`, and V4 `UniswapV4SeDecimals*` helpers to `F4Decimals*` without `V2`. Generic shared behavior filenames stay unchanged. Rewrite their imports and references.
- **Do:** In each renamed `F3_Component_FactoryService.sol` / `F4_Component_FactoryService.sol`, change every facet/delegate/package salt to the direct ABI-encoded contract-name hash. Change artifact IDs, labels, library extension method names, and all callers together. `indexedexManager.deploy*DFPkg` here is supplied by those FactoryService extensions; do not add manager selectors. Keep constructor payloads, registry routing, storage slots/field order, and instance salt derivation unchanged. Preserve source-map old keys; change replacement values.
- **Tests:** Renamed `T/release/v3/F3DFPkg_Deploy.t.sol`, `T/release/v4/F4DFPkg_Deploy.t.sol`, and all existing facet declaration tests. Add exact salt-argument assertions for facets, delegates, and packages through the real CREATE3/registry path, including rejection of the raw-string hash as the expected salt. Preserve constructor and registry checks.
- **Done when:** No active Solidity import/artifact ID targets a removed V2 file; every renamed component has its new name salt and current artifact ID; preserved files still match the manifest. Do not count historical document/log mentions as live V2 dependencies.

### Step 2: Replace preparation with balance delivery and settle every refund path

- **Files:** Renamed `P/v{3,4}/F{3,4}{Common,InTarget,InBase,InMultiTarget,InExecutionDelegate,OutTarget,OutBase,OutExecuteTarget,OutExecutionDelegate,OutMultiTarget}.sol`; both renamed In facets and DFPkgs; renamed LiquidReserve targets for booking/NatSpec. The family number must match the directory. Rewrite preparation use in every existing FullSpread test/helper below `T/`. Rename `T/release/PreparedTestInput.sol` to `T/release/TransferredTestInput.sol` and update its references. Stage deletion of `P/StandardExchangeDeliveryRepo.sol` and `P/IStandardExchangePretransfer.sol` after Step 3 removes their remaining SY consumers.
- **Do:** In both Common helpers, book token0, token1, and self-share `balanceOf` values. Replace prepared-credit reads with entry-time `balanceOf - reserveOfToken` for pushed inputs. Capture every input before internal collect/wrap/swap/burn/refund/rebalance/sync and carry measured values through settlement; capture both dual-join legs before any booking. Preserve live share-pricing reads. ERC-20 pull paths retain exact measured-delta equality.
- **Do:** Enforce exact-in equality at the exact-in route boundary, not a common helper used by exact-out. For exact-out, keep `used <= max` and require `actualIn >= used`; on pushed share exits validate before either idle or blocked burn. Cap refunds at `min(max - used, actualIn - used)` to `msg.sender`, using V3's this-call accounting in both families. Book the over-max remainder after refunds and final rebalance. Do not introduce donation attribution.
- **Do:** Preserve V3 token exact-out quote-plus-capped-buffer pulls, V4 token exact-out max pulls, both dual-exit max-share pulls/refunds, and both single-output exact-out direct holder burns. Changing push semantics must not change those pull routes. Remove `inputOperation`, preparation selectors/interface registrations, and preparation-only test assertions while keeping `nonReentrant` and independent route/error checks.
- **Tests:** Existing `StandardExchangeDeliveryBehavior.sol` and `StandardExchangeReleaseBehavior.sol`, renamed V3/V4 delivery/native-delivery suites, multi-join/exit and locked-caller suites. Cover I1/I2/I3/L1, excess exact-in, partial dual-leg failure, reserve sync after swap/rebalance, and all E6 refund cases in R7. Test exact-out pull balance/finite-allowance requirements separately from pushed transfer-only-used success. Snapshot rollback at exchange entry when the transfer occurred earlier.
- **Done when:** Booked inventory cannot fund minting, burns, or refunds; exact-in extra delivery fails; exact-out used-only delivery succeeds; over-max leftovers are booked; pulls preserve D19. Proxy reserve assertions use ERC-20 balances, including the WETH face for native pools. Remaining preparation references are only the Step 3 SY code pending removal and permitted historical/negative-surface text.

### Step 3: Complete Native SY redemption and remove the preparation files

- **Files:** Renamed `P/v3/F3OutQueryTarget.sol`, `P/v4/F4OutMultiQueryTarget.sol`, both Common helpers and InBase zap-out paths; `T/remediation/StandardExchangeReleaseBehavior.sol`, renamed delivery/native-delivery and `T/release/sy/F3_NativeSY.t.sol` tests. Remove only the unused `_prepare` helper/import from `T/remediation/StandardExchangePreservedBehavior.sol`. Delete the two preparation files staged in Step 2. Read `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` without editing it.
- **Do:** External SY redeem transfers shares internally from the caller then invokes the fixed exchange route with `pretransferred=true`. Internal SY redeem calls `super._standardRoute`; retain its proxy `.call` with `pretransferred=false`. In `_secureShareDelivery`, credit exactly the requested amount from the diamond only when input is self-share, caller is the diamond, the flag is false, and `NativeStandardYieldContextRepo._initiator()` is nonzero. Do not transfer or burn in that helper. Existing execute code performs the only burn. Insufficient self-balance reverts `TransferDeltaInsufficient(amount_, selfBalance)`.
- **Do:** Remove `_prepareOwnShares` and `_routePrepared`. Preserve minimum-output, reentrancy, and context restoration. Replace obsolete SY ownership/prepared-recipient tests with the D12 success/failure controls; ordinary external calls never acquire the self-holder exception. Delete the production prepare interface/ledger only after all direct imports and the `IPretransfer` re-export have been removed. Keep the shared locked caller's empty-token-array path used by preserved baselines.
- **Tests:** V3, V4 ERC-20, and V4 WETH/native: external redemption without allowance, booked internal shares, second redemption exceeding the remainder with exact payload, minimum-output rollback, subsequent ordinary-call denial, and recipient delivery. Verify the deleted prepare selector has zero loupe address, unsupported ERC-165 interface, and `Proxy.NoTargetFor(selector)` on low-level call.
- **Done when:** Each successful redeem burns once from the actual holder; failures roll back balances/supply; no caller inherits stale context; neither removed file has a Solidity importer. Preserved-baseline assertions and package targets are unchanged.

### Step 4: Apply the shared activation floor to joins, imports, and previews

- **Files:** `P/StandardExchangeConstantProduct.sol`; renamed Common, InBase, InMultiQueryTarget, InQueryTarget, and PositionImportTarget files in both families wherever they call initial issuance; `T/remediation/StandardExchangeConstantProduct.t.sol`; renamed release import, multi-join/exit, preview, full-range-book, and decimal tests under `T/release/v3/` and `T/release/v4/`.
- **Do:** Put the scaled-floor computation and `InsufficientMinimumLiquidity(raw, minimum)` in the existing shared math library. Resolve token decimals with the per-token 18-decimal failure fallback; widen the sum, floor its division, and use the specified integer exponent. Route both families' initial quote/execute calculations through that math. Keep noninitial issuance and zero/single-token activation behavior unchanged. Mint the floor exactly once in each successful zero-supply activation, plus `_initialResidualShares` computed using caller-issued shares. Previews mint nothing.
- **Do:** Use only newly collected NFT principal/fees for import issuance, excluding pre-existing sleeve assets. Update V3's existing import preview and both import execution paths; add no V4 import preview. Preserve import authorization and atomicity.
- **Tests:** Exact minimum/minimum-plus-one; 18/18, 6/18, 6/6, 6/9, decimal sum below six, and reverting decimals. Use a small external token fixture colocated with the adversarial test helpers for the reverting metadata case; do not mock vault/pool state. Check idle/blocked dual activation preview parity, V3 principal/fee import parity, below-floor import rollback on both families, and the R1 A0 profit bounds. Adjust old first-mint supply assertions to include sink shares without weakening subsequent accounting.
- **Done when:** All activation routes apply the same floor, quotes and execution agree, exactly one minimum is minted, residual sink shares stack, and the fully exited attacker earns no positive net amount in either token.

### Step 5: Remove V4 imported increases and verify NFT custody

- **Files:** Renamed `P/v4/F4Common.sol`, `F4InBase.sol`, and `F4PositionImportTarget.sol`; inspect renamed `F4DFPkg.sol` approvals without changing its required PoolManager approvals. Renamed V3/V4 release import/routes tests and the Step 7 adversarial suites.
- **Do:** Delete `_increaseImportedPositionCommon`, `_deployExcessImported`, and the InBase `_increaseImportedPosition` wrapper, including dead callers. Preserve NFT decrease/collect, `_finishImportedConversion`, and organic full-range rebalance. Do not add Position Manager ERC-20/Permit2 approvals or swallow protocol reverts. Preserve V3's empty-NFT custody behavior.
- **Tests:** `test_M3_noImportedIncrease_permit2AllowanceToPositionManagerStaysZero` uses a real configured PositionManager, import, and rebalance; checks both ERC-20 and Permit2 allowances for both token faces and zero remaining NFT liquidity. `test_import_emptyNft_originalOwnerCannotCollect` checks V3 NFT owner, cleared approval/owed balances, rejected original-owner collect, and unchanged vault balances.
- **Done when:** No imported-increase helper/caller survives; required PoolManager approvals remain; imported NFTs are empty and owned by the vault; the original V3 owner cannot collect.

### Step 6: Migrate regression policies and stateful accounting

- **Files:** Existing shared `T/remediation/{StandardExchangeDeliveryBehavior,StandardExchangeReleaseBehavior,StandardExchangeLockedCaller,DeliveryTestToken}.sol`; renamed family tests, `T/release/TransferredTestInput.sol`, renamed lock harnesses, `T/invariants/StandardExchangeHandler.sol`, and renamed invariant suites. This includes all importer migrations enumerated in PRD R6.
- **Do:** Replace caller/recipient-bound preparation tests with funded router delivery; disposition the live-book donation-rejection assertion as K1 donor loss. Remove preparation-only malformed/pending/call-hash/consume-credit assertions; preserve route validation, slippage, permit replay, disable exits, reentrancy, and rollback coverage. `DeliveryTestToken.setCallbackPropagates(bool)` defaults false and preserves today's recording/guard behavior; true bubbles nested revert data.
- **Do:** Rewrite the invariant handler to use pull or transfer-plus-push. Delete prepared attack invocations and their error assertions. Keep six operation families, independent funded traders, custody/supply ghost accounting, and existing 64-run × 96-depth, fail-on-unexpected-revert campaigns. A bare donation is unbooked D9 surplus, so do not assert a zero-delivery failure against it: the handler's donation operation must process/book it through the existing public rebalance before running the booked-inventory attack probe. This is fixture ordering, not new on-chain donor protection. Probe only after booking; use exact `TransferDeltaInsufficient` errors rather than preparation errors. Preserve dead-share contributions in the supply ledger.
- **Tests:** All renamed remediation, release, and invariant tests, including preserved baselines. C1 checks funded outer success plus recorded nested `IsLocked`, and propagating outer revert with state/allowance/book rollback. Preserve existing post-bootstrap FoT test; add first-join configured FoT rejection in Step 7.
- **Done when:** No active regression requires a prepare ledger or contradicts D2/D9/D12. Legitimate push operations transfer once and call once. Both stateful campaigns still check custody and supply with their existing depth/run policy.

### Step 7: Add greppable adversarial suites on real production proxies

- **Files (new):** `T/adversarial/StandardExchangeFullSpreadAdversarialBehavior.sol`, `T/adversarial/TestBase_UniswapV3FullSpreadStandardExchangeVault_Adversarial.sol`, `T/adversarial/TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial.sol`, `T/adversarial/F3_Adversarial.t.sol`, `T/adversarial/F4_Adversarial.t.sol`, and `T/adversarial/F4_NativeAdversarial.t.sol`. Extend the existing renamed family TestBases and reuse the existing trader/locked-caller/token helpers. Put the small transferFrom router and reverting-metadata external token fixture in the new shared test-helper file; these are external fixtures, not SUT replacements.
- **Do:** The two new TestBases inherit the renamed production TestBases and the shared adversarial behavior; V4 exposes ERC-20/native fixture setup so the native concrete suite exercises WETH-facing inputs. Deploy vaults through the same manager/registry packages. Test entry points use the exact catalog names required by R1–R8. Shared cases cover A0, I1/I2/I3/router, L1/L2/L3, E6, F5/H, C1, J1/J2/J3, and CROPS; family-specific import cases cover M3 and V3 NFT collect rejection. Reuse the final release assertions rather than a second accounting model.
- **Tests:** Router forwards 25 ether from the user to the vault with user recipient and keeps zero tokens/shares. Seed E6 token fixtures with a 100% sleeve and real external pool liquidity; seed share fixtures with booked self-shares. Execute all four delivered-versus-max refund cases, share idle/blocked branches, and short-share failure controls with enough booked shares to expose an unchecked burn. H uses independent 1000/1000, 20%-sleeve fixtures for 10% and 1% exits; verify 190 and 19.9 ether within five wei and positive-target insufficient-capacity rollback. L2 seeds the pool with fees disabled then enables the configured token fee before the first join; only its exact transfer-delta revert passes.
- **Tests:** J controls come from retained Target/product ABI, then facet metadata, cuts, live loupe, and proxy calls. Use Crane Behavior libraries for standard declarations. Do not copy an incomplete `facetFuncs` as the control. Deferred IDs and their reasons are exactly R6's K1/M1/M2/N1/O1/O2 dispositions, with share permit negatives retained. Calls with valid funded fixtures must reach the intended money path; an unrelated setup failure cannot pass a security gate.
- **Done when:** Every applicable catalog case runs on both families and the V4 native face where specified, through real deployed proxies. Every R1–R8 criterion is covered by a named test; record test-to-criterion mapping in `P/VALIDATION.md` during Step 9.

### Step 8: Enforce runtime limits and finish facet surfaces

- **Files:** Renamed facets/targets, package interfaces/DFPkgs, FactoryServices, and corresponding declaration/deployment/adversarial tests; `P/VERSION_SOURCE_MAP.json`. Conditional new files only for an actual overflow: matching `P/v3/F3<Surface>FacetExt.sol` / `F3<Surface>TargetExt.sol`, or the matching V4 pair, plus `T/release/v{3,4}/F{3,4}<Surface>FacetExt_IFacet_Test.t.sol`.
- **Do:** Build current artifacts before measuring, using Verification V2's build mode. Check every deployed facet, execution delegate, and DFPkg, not just previously large facets. A facet over 24,576 bytes takes D25's prescribed split: fewest whole selectors, import previews first, other previews/quotes next, non-core operations next, core routes last. Keep mapped retained names and append `Ext` for the new Target/Facet. Wire constructor dependencies, metadata, own name salt, FactoryService helper, and package cut; preserve the public product selector union without duplicate cuts. Do not split preemptively, move partial selector logic into new delegates, change compiler settings, or drop behavior.
- **Tests:** Refresh and rerun affected declaration/deployment/proxy suites after a split, then the final whole-family gate. Extend J1/J2/J3 and salt assertions to every new facet. Enumerate conditional artifacts in the source map/evidence without repurposing existing old-source keys.
- **Done when:** All deployed artifacts fit, each retained selector reaches its intended facet on the proxy, removed prepare surface stays absent, and every new facet has declaration and deployment evidence. An unexpected non-facet overflow is a blocker to report against the PRD; no alternate architecture is authorized.

### Step 9: Run final gates and publish local validation evidence

- **Files:** `P/README.md`, `P/VALIDATION.md`, `P/VERSION_SOURCE_MAP.json`, `P/VALIDATED_ARTIFACTS.json`, `P/REGRESSION_RESULTS.txt`, and checkbox/evidence updates to this plan. The preserved manifest/build-context files remain read-only.
- **Do:** Execute Verification in order against the final source. Record exact commands, exit status, source revision plus working-tree context, compiler/profile settings, suite counts, test-to-AC mapping, and final runtime sizes/hashes. Only mark acceptance boxes backed by final evidence. Keep historical V2 counts explicitly historical; preserve the old validation record as history while replacing current preparation guidance with FullSpread usage. Keep CP-09 open and CP-07 historical replay excluded. Do not claim coverage of live instances or out-of-scope compositions.
- **Tests:** Final full `T` tree includes adversarial, release, remediation, invariants, and preserved baselines, with artifact refresh first; no skipped/failed required suite is acceptance. Run repository build/test gates before an implementation PR per `.github/ASSISTANT_TESTS.md`, reporting unrelated failures without changing out-of-scope code. The present planning request does not authorize creating that implementation PR.
- **Done when:** All 76 acceptance criteria below have traceable evidence; 96 hashes still match; preserved build context is unchanged; every final deployed artifact fits; final regression output and README/VALIDATION match the actual FullSpread run. Record completion before the separate global CREATE3 effort begins.

## Requirement-to-step traceability

| PRD requirement | Implementation / verification steps |
|---|---|
| R1 first mint | 4, 6, 7, 9 |
| R2 delivery, reserves, SY | 2, 3, 6, 7, 9 |
| R3 PositionManager allowances | 5, 7, 9 |
| R4 sleeve / locked exits | 2, 7, 9 |
| R5 configured FoT | 6, 7, 9 |
| R6 adversarial / regression / proxy surface | 1–3, 6–9 |
| R7 exact-out refunds | 2, 7, 9 |
| R8 V3 empty NFT | 5, 7, 9 |
| R9 rename / salts / evidence | 1, 8, 9 |

## Acceptance criteria

The following 76 criteria are copied from the reviewed PRD in requirement order. `R<number>.<ordinal>` locates the original nested criterion. Historical `V2` paths inside a criterion identify today's source; apply Step 1's rename when implementing it. Do not weaken these criteria to accommodate an implementation.

- [x] **AC01 (R1.1)** On both FullSpread packages, when `totalSupply() == 0`, `raw = mulSqrt(amount0, amount1)` in raw token units. `MINIMUM_LIQUIDITY = 10 ** ((d0 + d1) / 2 - 3)` with `d0`/`d1` from `decimals()` (18 if the call fails), and `1` if `(d0+d1)/2 < 3`. Floor math and the revert live in `StandardExchangeConstantProduct`. If `raw <= MINIMUM_LIQUIDITY` the join reverts `InsufficientMinimumLiquidity(raw, minimum)`. Mint `MINIMUM_LIQUIDITY` to `DEAD_SHARES_SINK` (`address(0x000000000000000000000000000000000000dEaD)`). The caller receives `raw - MINIMUM_LIQUIDITY`. Do not reuse `ZeroAmount` / `ZeroDeposit` for the floor miss.

- [x] **AC02 (R1.2)** Apply that first-mint rule to both `exchangeInManyToOne` and `importPosition`, including their existing previews. For imports, `amount0`/`amount1` are the assets actually collected from the NFT, excluding pre-existing sleeve inventory. Mint the minimum exactly once per activation, in addition to residual dead shares. A below-floor import reverts atomically: NFT ownership, NFT liquidity, vault balances, and supply remain as before the import call. Test above-floor imports on both families with `recipientShares == raw - minimum` and `supply == recipientShares + minimum + residual`.

- [x] **AC03 (R1.3)** Import-preview scope is V3's existing `previewImportPosition` only; V4 exposes `importPosition` without an import preview. Do not invent a V4 preview API. On V3, retain exact preview/execution parity for principal-only and earned-fee imports under unchanged pool state, applying the minimum subtraction to both. Test a below-floor V3 preview with the same `InsufficientMinimumLiquidity` payload as execution; separately test V4 execution rollback.

- [x] **AC04 (R1.4)** That formula is `1e15` for 18/18, `1e9` for 6/18, `1e3` for 6/6. Compute the decimal sum in `uint256` and floor its division by two before subtracting three. The stated geometric-mean scaling is exact for even decimal sums of at least 6; odd sums use the specified integer exponent. Test 6/9 → `1e4`, a sum below 6 → `1`, and a reverting `decimals()` call → the 18-decimal fallback.

- [x] **AC05 (R1.5)** Pre-existing local inventory still mints additional dead shares via `_initialResidualShares`, using the caller's issued shares as `shares`. Those stack with `MINIMUM_LIQUIDITY`. The first minter never owns the pre-seeded inventory.

- [x] **AC06 (R1.6)** `previewExchangeInManyToOne` on the live proxy returns the same caller shares as `exchangeInManyToOne` for the same two-token activation, including the floor subtraction. That holds idle (`canOpenBoundPoolOps()` / `canOpenPoolManagerUnlock()` true) and blocked (those views false).

- [x] **AC07 (R1.7)** With both input amounts positive, preview and execution reject `raw == minimum` with `InsufficientMinimumLiquidity(raw, minimum)` and return/mint one caller share when `raw == minimum + 1`. Quotes do not mint dead shares. Preserve the existing zero-input/single-token invalid-activation behavior.

- [x] **AC08 (R1.8)** `test_A0_dustFirstMint_reverts` on 18/18: dual-join with `mulSqrt <= 1e15` reverts `InsufficientMinimumLiquidity`; `totalSupply() == 0`. Same test on a 6/6 fixture with `mulSqrt <= 1e3`.

- [x] **AC09 (R1.9)** `test_A0_dustFirstMint_thenDonate_victimJoin_attackerCannotTakeHalf` on both families (balanced 18/18): attacker dual-joins the smallest equal amounts that mint, donates an equal amount of at least `1e18` of each token, and the separately funded victim dual-joins that donation size. Attacker share fraction after the victim join is strictly less than 50% of `totalSupply`. The attacker then exits all issued shares through the proportional dual-exit route; assert the attacker has no shares remaining. For each token independently, require `exitReceived_i <= initialDeposit_i + donation_i`: net profit, counting both the initial deposit and donation as attacker costs, is nonpositive. Snapshot attacker token balances after fixture funding and before the first join; after the exit each balance must be no greater than its snapshot. Do not fund the attacker again between those snapshots, offset a gain in one token against a loss in the other, or count gas costs toward passing this bound.

- [x] **AC10 (R1.10)** Preserve the V3 `test_A0_residualDeadShares_firstMinterNotWhole` and add its counterpart on V4; the repository currently has that exact test name only in V3. 6/18 and 6/6 decimal fixtures still activate (their first joins already exceed the scaled floor).

- [x] **AC11 (R1.11)** Single-token first mint still returns zero shares and reverts. Two-token activation remains mandatory.

- [x] **AC12 (R2.1)** Use existing `MultiAssetBasicVaultRepo.reserveOfToken` / `IBasicVault.reserveOfToken`. After deposit, withdraw, rebalance, fee collect, vault swap, wrap/unwrap, and import, `_syncVaultReserves` writes `reserveOfToken[token] = IERC20(token).balanceOf(address(this))` for `_token0()`, `_token1()`, and the vault share (today's three writes). Do not persist a changed-token subset if that would leave a moved token unbooked. It must not write `_totalVaultReserves()` / free + deployed. Never persist deployed position amounts, pool price, or uncollected fee growth. On V4 native ETH pools, `reserveOfToken` is the WETH ERC-20 face, not native ETH. Leftover native ETH is not booked and is not a public skim (non-goals). Wrap/unwrap during an op happens after delivery capture; end-of-op booking uses the WETH `balanceOf`.

- [x] **AC13 (R2.2)** Do not add `StandardExchangeHeldRepo` or a public `held(address)`. Tests read `vault.reserveOfToken(token)` on the proxy. `localReserve` stays the live free sleeve. `deployedReserve()` stays a live position read. Rewrite any existing test that expects `reserveOfToken == free + deployed`.

- [x] **AC14 (R2.3)** Share mint/burn still uses live free + live deployed + live uncollected position fees (both families; today's `_totalVaultReservesForShareMath` / `_freeBalancesForShareMath`) computed from the pool / position on that call. That is not stored vault state. TWAP remains the oracle.

- [x] **AC15 (R2.4)** ERC-20 pull paths with `pretransferred=false`: `transferFrom(msg.sender)` and require the measured delta to equal the requested pull, otherwise revert `TransferDeltaInsufficient(requestedPull, actualIn)`. Preserve existing exact-out pull sizes: V3 token swap pulls the quote plus its existing capped buffer; V4 token swap pulls max; `exchangeOutOneToMany` on both families pulls `maxAmountIn` shares into the diamond, burns only `sharesBurned` from the diamond, and refunds `maxAmountIn - sharesBurned` to `msg.sender`. Refund only unused tokens actually pulled. Only single-output exact-out zap-out (`exchangeOut` with share input) burns `sharesBurned` directly from `msg.sender` without pulling the max or requiring share allowance. These are distinct existing paths in `OutMultiTargetV2` and `OutExecutionDelegateV2`; preserve that distinction under D19. Internal SY holder burns are specified below. Then write `reserveOfToken` from `balanceOf`.

- [x] **AC16 (R2.5)** Verify that pull-path distinction on both families, idle and blocked, with a payable output and `max > used`: dual exit requires caller share balance and allowance covering max, refunds exactly `max - used`, reduces caller shares and supply by exactly used, and leaves any pre-existing booked self-shares intact. With caller balance covering max but finite allowance only used, dual exit reverts atomically; with allowance max but caller balance only used, it also reverts atomically. Single-output exact-out zap-out succeeds with caller balance only used and zero share allowance even when max exceeds that balance, and burns exactly used. Failed cases preserve balances, supply, allowance, and booked reserves. These controls preserve D19's pull behavior; D15's transfer-only-used success rule remains for `pretransferred=true`.

- [x] **AC17 (R2.6)** `pretransferred=true`: `actualIn = balanceOf(token) - reserveOfToken(token)`. Do not credit `amountIn` / `maxAmountIn` from existing `reserveOfToken`. Then write `reserveOfToken` from `balanceOf` after the op (and after any this-call refund).

- [x] **AC18 (R2.7)** Capture push delivery for all input tokens before this operation collects fees, wraps/unwraps, swaps, burns, refunds, rebalances, or syncs reserves. Keep those values through settlement; these internal balance changes cannot become user delivery. Do not sync one leg of a dual join before capturing the other. End-of-operation booking includes any final automatic rebalance.

- [x] **AC19 (R2.8)** `exchangeIn` (zap-in, token swap exact-in, zap-out exact-in, dual-join `exchangeInManyToOne`, external SY redeem): `actualIn == amountIn` or revert `ISecurePullErrors.TransferDeltaInsufficient(amountIn, actualIn)`. No fat-max short transfer. Extra push above `amountIn` reverts; it is not refunded.

- [x] **AC20 (R2.9)** `exchangeOut` (token exact-out, zap-out exact-out, dual-exit `exchangeOutOneToMany`): revert `TransferDeltaInsufficient(used, actualIn)` only when `actualIn < used`. `used` is the amount actually consumed (`amountIn` returned / `sharesBurned`), not `maxAmountIn` / `maxSharesToBurn`. Fat max plus transfer of only `used` succeeds. Refund unused inbound above `used` only from this call's surplus, using the V3 `_refundThisCallUnusedInbound` accounting pattern and the cap `min(max - used, actualIn - used)`. Booked `reserveOfToken` cannot fund the refund. D2 defines measured input; no separate attribution of unsolicited transfers is required. Refund recipient is `msg.sender`, matching today's `_refundUnusedShares` / `_refundThisCallUnusedInbound`. V4 `_refundExcess` must use that same this-call cap.

- [x] **AC21 (R2.10)** Keep `used <= max` as an independent slippage bound, with the existing family-specific insufficient-input error when it fails. For pushed input exceeding max, D15's refund formula leaves `actualIn - max` on the vault and books it after settlement; it is not refunded or left as next-call credit. On share exits, check `used <= actualIn` before burning on both idle and blocked branches, including both `OutMultiTarget` paths.

- [x] **AC22 (R2.11)** Do not add `preparePretransfer` to FullSpread In facet cuts, ERC-165, README, or caller tests. Delete `StandardExchangeDeliveryRepo.sol` and `IStandardExchangePretransfer.sol` (the shared files beside this PRD) after FullSpread production code and FullSpread-targeting tests no longer import them. Preserved packages under `contracts/protocols/dexes/uniswap/v3` and `v4` never import those files. Do not keep a transient prepare ledger. Do not add `contributePretransfer`.

- [x] **AC23 (R2.12)** External Native SY redeem (`_standardRoute` override when `in_ == address(this)` and `internal_ == false`; today that override lives in `v3/UniswapV3StandardExchangeOutQueryTargetV2.sol` and `v4/UniswapV4StandardExchangeOutMultiQueryTargetV2.sol`, so the two families host it in different Query targets and both files carry the renamed FullSpread versions of this rule): `ERC20Repo._transfer(msg.sender, address(this), amount_)` then `exchangeIn(..., pretransferred=true)` crediting `balanceOf(share) - reserveOfToken(share)`. No prepare. Internal SY redeem (`internal_ == true`): call `super._standardRoute` so `NativeStandardYieldTarget` keeps its fixed proxy `.call` self-call with `pretransferred=false`. Do not keep the current override's `delegatecall` plus `_routePrepared` for `internal_ == true`. Do not credit booked self-shares as new delivery. Delete `_prepareOwnShares` and `_routePrepared` with the prepare ledger.

- [x] **AC24 (R2.13)** D12 requires an actual holder-burn path for that Native SY proxy self-call. In that context, `_secureShareDelivery(..., false)` credits `amount_` from the diamond's existing share balance without `transferFrom` and without burning. The existing zap-out/execute `ERC20Repo._burn(address(this), sharesBurned)` is the only burn; burning in the delivery helper would double-burn. Read `selfBalance = IERC20(address(this)).balanceOf(address(this))`. If `selfBalance < amount_`, revert exactly `ISecurePullErrors.TransferDeltaInsufficient(amount_, selfBalance)` before settlement; otherwise credit exactly `amount_`, not the whole self-balance. Assert that exact payload in the insufficient-self-balance regression. Preserve the route's reentrancy, minimum-output, and balance checks. The current `_secureShareDelivery(..., false)` `transferFrom` is not a substitute: a diamond-to-itself transfer has zero measured delta. Keep this exception confined to the Native SY internal-redemption context and `msg.sender == address(this)`; ordinary external callers cannot invoke it to spend booked self-shares through `exchangeIn`. Do not change the shared `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` behavior for other families.

- [x] **AC25 (R2.14)** Reuse `NativeStandardYieldContextRepo._initiator()` from `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` to identify that context: the exception requires a nonzero initiator, `msg.sender == address(this)`, share input, and `pretransferred == false`. Do not introduce another context ledger or a public setter. Test that an ordinary external `exchangeIn(..., pretransferred=false)` caller without shares/allowance cannot spend booked self-shares. After successful and reverted internal redemptions, the existing context must be cleared/restored; a subsequent ordinary call cannot inherit holder-burn authority.

- [x] **AC26 (R2.15)** On V3, V4 ERC-20, and V4 native WETH fixtures, test external SY redemption without share allowance, internal SY redemption from already-booked self-shares, a second internal redemption exceeding the remaining self-balance, and minimum-output rollback. Successful redemption reduces supply and the actual holder balance by exactly `amount_`; remaining self-shares are booked and cannot fund an unfunded pushed exchange. Failed redemption preserves balances and supply relative to entry to that call.

- [x] **AC27 (R2.16)** `test_I_routerTransferFromUserToVault` on V3, V4 ERC-20, and V4 native WETH face: router with the user's allowance does `transferFrom(user, vault, 25 ether)` then `exchangeIn(..., 25 ether, ..., recipient=user, pretransferred=true)`. No prepare call. User receives the shares. Router token and share balances stay 0.

- [x] **AC28 (R2.17)** `test_I1_pretransferredTrue_noDelivery_noFreeMint`: vault already holds sleeve, attacker calls `exchangeIn(..., pretransferred=true)` with no new transfer. Revert `TransferDeltaInsufficient`. Attacker shares unchanged. Supply unchanged. Same I1 on `exchangeOut` token exact-out and zap-out exact-out (`test_I1_exchangeOut_pretransferredTrue_noDelivery`): no new transfer, revert `TransferDeltaInsufficient`, attacker token and share balances unchanged.

- [x] **AC29 (R2.18)** `test_I2_shortPush_pretransferred_claimedGtDelta_reverts`: `exchangeIn` with transfer less than `amountIn`, `pretransferred=true`. Revert `TransferDeltaInsufficient(amountIn, actualIn)`. Shares and supply unchanged.

- [x] **AC30 (R2.19)** Also test extra exact-in push (`actualIn > amountIn`) with that same exact error, plus a dual join with one valid leg and one short/excess leg. No leg mints shares or changes booked reserves on failure. A transfer made in a separate prior transaction remains on the vault after a failed exchange; rollback assertions use exchange-entry balances, not balances before that earlier transfer.

- [x] **AC31 (R2.20)** `test_I2_exchangeOut_usedGtActualIn_reverts`: `exchangeOut` token exact-out and zap-out exact-out with a fat max, transfer less than `used`, `pretransferred=true`. Revert `TransferDeltaInsufficient(used, actualIn)`. Attacker token and share balances unchanged. Supply unchanged.

- [x] **AC32 (R2.21)** `test_I3_residualAfterSuccessfulPush_cannotFundSecondFreePretransfer`: successful funded `pretransferred=true` `exchangeIn` writes `reserveOfToken`; a following unfunded `pretransferred=true` `exchangeIn` reverts `TransferDeltaInsufficient`. Shares of the second caller unchanged. Same I3 after a successful funded `exchangeOut` (`test_I3_exchangeOut_residualAfterSuccessfulPush`): the next unfunded `pretransferred=true` `exchangeOut` reverts.

- [x] **AC33 (R2.22)** `test_L1_poolTradeThenFalsePretransfer_noCredit`: honest deposit creates a deployed position, separately funded trader moves the pool, attacker calls `pretransferred=true` with no transfer. Revert `TransferDeltaInsufficient`. This is the auditor P0: delivery must not use `storedTotal - deployed`.

- [x] **AC34 (R2.23)** `test_I_reserveOfTokenWrittenAfterRebalanceAndSwap`: after `rebalanceLiquidReserve` and after a vault exact-in swap, `reserveOfToken(token) == token.balanceOf(vault)` for both pool tokens. A following `pretransferred=true` with no transfer reverts.

- [x] **AC35 (R2.24)** Stray `transfer` onto a live vault is not an LP-security test. `actualIn` still equals `balanceOf - reserveOfToken` and includes that unbooked surplus. `exchangeIn` still requires `actualIn == amountIn`: an honest transfer of `T` reverts when surplus makes `U != T`; a caller who sets `amountIn = U` may receive the surplus as paid delivery. That is catalog K1 (deferred as donor loss), not a reason to exclude stray from `actualIn` or to refund it on exact-in. NatSpec on the I suite: catalog K1 (donation-to-next-depositor on a live book) is deferred as donor loss, not LP principal drain. First-mint donation remains requirement 1.

- [x] **AC36 (R3.1)** Delete `_increaseImportedPositionCommon`, `_deployExcessImported`, and the InBase `_increaseImportedPosition` wrapper. Import still burns the NFT liquidity, calls `_finishImportedConversion`, then organic rebalance onto the full-range book. Do not keep a path that `modifyLiquidities(INCREASE_LIQUIDITY)` on the imported NFT.

- [x] **AC37 (R3.2)** Do not `IERC20.approve` the Position Manager. Do not `Permit2.approve` the Position Manager. Permit2 is ERC-20 only and is not used for the imported ERC-721 (`IERC721.transferFrom`) or for native ETH (`poolManager.settle{value: ...}`). Init keeps its existing `IERC20.approve(Permit2, max)` and `Permit2.approve(token, PoolManager, max)` (today in `UniswapV4StandardExchangeDFPkgV2` vault init) for organic PoolManager settlement; that spender is the PoolManager, not the Position Manager.

- [x] **AC38 (R3.3)** `test_M3_noImportedIncrease_permit2AllowanceToPositionManagerStaysZero` on the V4 FullSpread package: deploy a vault bound to a real Position Manager, complete `importPosition`, then `rebalanceLiquidReserve`. After that, Permit2 `allowance(vault, token0, positionManager)` and `allowance(vault, token1, positionManager)` are 0. ERC-20 `allowance(vault, positionManager)` for both pool tokens is 0. The imported NFT is owned by the vault with liquidity 0.

- [x] **AC39 (R3.4)** Suite NatSpec: M3 is closed by removing the imported-increase surface, not by amount-capping a leftover max.

- [x] **AC40 (R4.1)** `rebalanceLiquidReserve` remains callable by any EOA when the vault is not disabled and the bound pool / PoolManager is idle. It never transfers pool tokens or vault shares to `msg.sender`.

- [x] **AC41 (R4.2)** Preserve the existing rebalance target, integer rounding, and dust policy: `target_i = floor(total_i * liquidPct / 1e18)`, `floor_i = 10 ** max(0, decimals_i - 6)`, `tolerance_i = max(floor_i, floor(target_i * 0.05e18 / 1e18))`. On the balanced 1000/1000 fixture, assert each free balance is within that tolerance after rebalance. Do not introduce a positive-balance guarantee for a target that rounds to zero or lies within the dust tolerance. Write `reserveOfToken` from `balanceOf` for both pool tokens.

- [x] **AC42 (R4.3)** `test_F5_rebalancePaysCallerNothing` on both families: snapshot caller and vault token balances, call `rebalanceLiquidReserve` from `attacker`, assert attacker token and share balances are unchanged.

- [x] **AC43 (R4.4)** Locked-exit path is `exchangeIn` zap-out exact-in (shares in, token1 out) while the bound pool / PoolManager is locked, same as existing `test_lockedExitSettlesBothEntitlements`. Quote is `_singleExit` against the full book (free + deployed + live uncollected fees). Payment is from the free sleeve only.

- [x] **AC44 (R4.5)** `test_H_lockedExitAfterPermissionlessRebalance` on both families: sleeve target 20%, bootstrap `1000 ether` of each pool token, attacker rebalances, then a locked-pool caller burns `totalSupply() / 10` (10%) for token1. The exit succeeds and pays `assertApproxEqAbs(..., 190 ether, 5)` (100 + 900*100/1000). Free token1 after rebalance is about 200, so 190 is payable.

- [x] **AC45 (R4.6)** `test_H_lockedExit_onePercentOfSupply` on both families: same sleeve, bootstrap, and rebalance, then burn `totalSupply() / 100` (1%) for token1. The exit succeeds and pays `assertApproxEqAbs(..., 19.9 ether, 5)` (10 + 990*10/1000). Do not assert 190 ether on the 1% burn.

- [x] **AC46 (R4.7)** When the fee oracle target is 0%, a following locked single-asset exit may revert `InsufficientLocalReserve`. NatSpec on `rebalanceLiquidReserve` states that. No extra minimum sleeve is introduced beyond the oracle target and the existing dust floor.

- [x] **AC47 (R4.8)** Add a locked exit with a positive sleeve target but a quote exceeding the actual free output balance. It reverts with the existing `UniswapV3Exchange_InsufficientLocalReserve` / `UniswapV4Exchange_InsufficientLocalReserve` error and preserves shares, supply, and token balances. H tests use independent fresh 1000/1000 fixtures for the 10% and 1% examples, with no intervening trades or earned fees; neither example runs after the other exit.

- [x] **AC48 (R5.1)** `test_L2_FoT_forbidden` on both families uses a real FoT ERC-20 as one configured pool token and successfully deploys the FullSpread package through `indexedexManager.deploy*DFPkg` / `deployVault`. Use the existing configurable-fee token fixture to seed the real external pool with transfer fees disabled, then enable its fee before the vault's first two-token join. That join with `pretransferred=false` reverts `TransferDeltaInsufficient(requested, received)` and `totalSupply()` stays 0. Assert full rollback of both join legs and booked reserves. Unrelated pool/factory/setup reverts fail the test; they do not establish FoT rejection. Do not add a `PkgArgs` token allowlist or credit reduced `actualIn` for FoT.

- [x] **AC49 (R5.2)** The existing post-bootstrap `test_feeOnTransferInputRejectedAndRolledBack` stays. It does not replace `test_L2_FoT_forbidden`.

- [x] **AC50 (R6.1)** Add `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/adversarial/` with `TestBase_UniswapV3FullSpreadStandardExchangeVault_Adversarial` and `TestBase_UniswapV4FullSpreadStandardExchangeVault_Adversarial` extending the renamed FullSpread TestBases. Suites use `test_<ID>_...` names. No mock of the vault, manager, registry, fee oracle, pool, or PoolManager.

- [x] **AC51 (R6.2)** P0 tests present on both families (V4 native WETH face included where the surface exists): `A0` (pre-seed and dust-then-donate), `I1` `I2` `I3` `I_routerTransferFromUserToVault` (I1/I3 cover `exchangeIn` and `exchangeOut`; I2 is requirement 2's exact-in short-push plus `test_I2_exchangeOut_usedGtActualIn_reverts`), `E6` on every `exchangeOut` refund path (requirement 7), `C1` (hostile ERC-20 callback during `transferFrom` cannot nest `exchangeIn` / `exchangeOut` / `rebalanceLiquidReserve`; keep existing `nonReentrant`; drop `inputOperation` with the prepare ledger; callback assertions below), `J1` `J2` `J3` (each FullSpread Target ABI ⊆ that Facet's `facetFuncs` ⊆ diamond cuts ⊆ proxy loupe, and a proxy call of each product selector succeeds or reverts with a product error, not the routing error `Proxy.NoTargetFor(selector)` from `lib/crane/contracts/proxies/Proxy.sol`), `L1` (pool trade then false `pretransferred=true`), `CROPS` (`setVaultAddressDisabled(true)` then inbound `exchangeIn` of pool tokens reverts `VaultDisabled`; `exchangeOut` of existing shares and SY share redeem still succeed).

- [x] **AC52 (R6.3)** For each C1 nested entry, use the recording callback in `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/remediation/DeliveryTestToken.sol`: the funded outer call succeeds, the recorded nested error is exactly `IReentrancyLock.IsLocked`, and the nested attacker recipient gains no shares or tokens. Add a propagating mode to that same external test token rather than a second hostile token: a `setCallbackPropagates(bool)` setter, default `false`. When `false`, `transferFrom` keeps today's behavior exactly, including the `require(!ok, "reentry unexpectedly succeeded")` guard and the `callbackError` record, so every existing suite that uses this token is unchanged. When `true`, `transferFrom` bubbles the nested revert data instead of catching it, and that `require` does not apply. Exercise both modes: with propagation on, the outer call reverts with `IsLocked`, preserving supply, balances, allowances, and booked reserves relative to outer-call entry. Do not expect an outer revert from the existing callback that catches and records the nested failure; do not assert persisted callback records from a reverted transaction.

- [x] **AC53 (R6.4)** `test_L3_spotSkew_noUnfundedMint`: separately funded trader moves the pool, then an unfunded `pretransferred=true` deposit reverts. Skewed mint/burn that pays real tokens may change share value; that is documented AMM arbitrage, not a pass for unfunded credit.

- [x] **AC54 (R6.5)** Deferred IDs in suite NatSpec, not silence: `K1` (stray transfer on a live book is donor loss), `M1`/`M2` (no user-supplied `target+calldata` helper), `N1` (no multi-step bond hook; bound-pool lock / outer unlock already in release harnesses), `O1`/`O2` for Permit2 user money paths (no Permit2 deposit entry; share ERC-20 permit remains in release tests). `F5` is requirement 4. `M3` is requirement 3 (no imported-increase surface).

- [x] **AC55 (R6.6)** Keep the existing remediation/release/invariant trees that target this package, renamed to FullSpread, and rewrite any of those tests that currently require `preparePretransfer` so push is `transfer` then `pretransferred=true` only. Named helpers that still import `IStandardExchangePretransfer`: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/remediation/StandardExchangeLockedCaller.sol` (when `tokens.length != 0`, `transfer` to the vault then the existing `pretransferred=true` call; no prepare), `remediation/StandardExchangeDeliveryBehavior.sol` (requirement 6's policy replacements; it also re-exports the interface as the `IPretransfer` alias that `remediation/StandardExchangeReleaseBehavior.sol` imports, so ReleaseBehavior is rewritten with it even though it has no direct import), `release/PreparedTestInput.sol`, and `invariants/StandardExchangeHandler.sol`. The same rewrite applies to every other current importer of that interface, all of which target this package: the two lock harnesses the non-goals retain (`release/v3/harness/UniswapV3BoundPoolLockSeCallerV2.sol`, `release/v4/harness/PoolManagerUnlockSeCallerV2.sol`), `release/sy/V3FullRangeNativeSY.t.sol`, `release/v3/UniswapV3StandardExchange_Import.t.sol`, `release/v3/UniswapV3StandardExchange_Previews.t.sol`, `release/v3/UniswapV3StandardExchange_MultiJoinExit.t.sol`, `release/v3/UniswapV3StandardExchange_FullRangeBook.t.sol`, `release/v3/UniswapV3StandardExchangeV2_Decimals.t.sol`, `release/v4/UniswapV4StandardExchangeRoutes_TestV2.t.sol`, `release/v4/UniswapV4StandardExchange_MultiJoinExitV2.t.sol`, `release/v4/UniswapV4StandardExchange_FullRangeBookV2.t.sol`, and the two `*InFacet_IFacet_TestV2.t.sol` files, which additionally drop `preparePretransfer` from their expected `facetFuncs` and ERC-165 sets. Production importers are the six FullSpread files `v{3,4}/UniswapV{3,4}StandardExchangeInFacetV2.sol`, `v{3,4}/UniswapV{3,4}StandardExchangeInTargetV2.sol`, and `v{3,4}/UniswapV{3,4}StandardExchangeDFPkgV2.sol`, plus `StandardExchangeDeliveryRepo.sol` itself and the `README.md` entry requirement 9 rewrites. No file outside `contracts/vaults/standard/exchange/protocols/uniswap/` and `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/` imports that interface, so the deletion has no out-of-tree consumers. Leave `*PreservedBaseline*` tests pointing at the preserved packages; do not retarget them at FullSpread. Those baselines inherit unused `_prepare` from `StandardExchangePreservedBehavior.sol` and call `LockedCaller` with empty token arrays (prepare already skipped). Strip that unused prepare helper/import from `StandardExchangePreservedBehavior` so deleting `IStandardExchangePretransfer.sol` still compiles the baselines. Do not add prepare to preserved packages.

- [x] **AC56 (R6.7)** Migrate obsolete policy assertions, not just prepare calls. In `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/remediation/StandardExchangeDeliveryBehavior.sol`, replace `test_callerAndRecipientBoundToPreparedInput` with D2's funded router/recipient assertions; replace `test_donationBeforePreparationIsNotInput` with D9's explicit live-book donor-loss disposition (suite NatSpec), not a donation-rejection gate. In `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/remediation/StandardExchangeReleaseBehavior.sol`, replace `test_nativeSYPreparedInternalBalanceCannotClaimOldShares` with D12's successful internal holder burn and insufficient-self-balance rollback, and replace `test_nativeSYPreparedRecipientBinding` with successful delivery to the requested SY receiver plus the ordinary-external-caller negative from requirement 2. Remove preparation-only zero/duplicate-token, pending-preparation, call-hash, and consume-all-credit tests; preserve their independent route-validation, reentrancy, delivery, refund, and rollback coverage through requirements 2 and 7. No FullSpread regression may still require a `Pretransfer*` ledger error or authenticated ownership of the unbooked balance. Historical preparation tests/counts remain identified as historical evidence under requirement 9.

- [x] **AC57 (R6.8)** Verify removal on each production-deployed FullSpread proxy: loupe `facetAddress` for the former `preparePretransfer(address[],uint256[],bytes32)` selector is zero, ERC-165 reports the former pretransfer interface unsupported, and a low-level call to that selector reverts with the existing `Proxy.NoTargetFor(selector)` error from `lib/crane/contracts/proxies/Proxy.sol`. Use the legacy ABI signature in the test without retaining the deleted production interface. The J surface-success requirement applies to retained product selectors, not this deliberately removed selector.

- [x] **AC58 (R7.1)** Recipe on both families: seed booked `reserveOfToken` `R`, fat `max`, `pretransferred=true`, transfer only `used`. The op succeeds and pays zero input-token/share refund to `msg.sender`: its input balance after the call equals its balance immediately after the pretransfer (the full transfer-plus-call net delta is `-used`). Refund uses the V3 `_refundThisCallUnusedInbound` this-call unused-inbound snapshot (balance before this operation's settlement, adjusted for this call's delivery). The refund cap is `min(max - used, actualIn - used)` using D2's measured input. Attribution or protection of unsolicited transfers is outside this requirement under D9. Never refund `max - used` against raw `balanceOf` or booked `R`. Refund recipient is `msg.sender`, even when output `recipient` differs.

- [x] **AC59 (R7.2)** Isolate the token-for-token E6 refund recipe with a 100% sleeve target set before bootstrap, real external pool liquidity, and no vault deployed liquidity or pending position fees. Then the input-token book after the complete call equals `R`. For zap-out and dual-exit E6 tests, use booked vault shares as `R`; after burn/refund, `reserveOfToken(share) == share.balanceOf(vault) == R` for the transfer-only-used recipe. In over-max variants the remaining input book is `R + actualIn - max`. Do not require an underlying-token sleeve to remain unchanged across legitimate liquidity withdrawal or automatic rebalance.

- [x] **AC60 (R7.3)** `test_E6_exchangeOut_tokenExactOut_fatMax_transferOnlyUsed_doesNotPayBooked` : token-for-token `exchangeOut`. V4 `_refundExcess` must use the same this-call unused-inbound cap as V3 `_refundThisCallUnusedInbound`.

- [x] **AC61 (R7.4)** `test_E6_pretransferredZapOut_cannotBurnMoreThanDelivered` : zap-out exact-out (`maxSharesToBurn` fat, `sharesBurned` = used). Both families, when `pretransferred=true`, `actualIn = share.balanceOf(vault) - reserveOfToken(share)`. Revert `TransferDeltaInsufficient` if `sharesBurned > actualIn` before burning. Refund unused inbound shares above `sharesBurned` only from this call's surplus, to `msg.sender`. V3 Out execution delegate gains the same `sharesBurned <= actualIn` check V4 already has. No prepare call.

- [x] **AC62 (R7.5)** `test_E6_dualExit_unusedShares_fatMax_transferOnlyUsed_doesNotPayBooked` : `exchangeOutOneToMany` unused-share refund. Same recipe; unused shares to `msg.sender`; booked share `reserveOfToken` intact.

- [x] **AC63 (R7.6)** On each of the three refund routes, also test `used < actualIn < max`, `actualIn == max`, and `actualIn > max` using the isolated E6 recipe (no unbooked stray). Assert refund exactly `min(max - used, actualIn - used)` from the this-call unused-inbound snapshot, output delivered to `recipient`, and no later unfunded claim against the booked remainder. Run share-refund cases both idle and blocked. Add short-share dual exits on both branches with sufficient booked shares to make an unchecked burn possible: `actualIn < used` must revert `TransferDeltaInsufficient(used, actualIn)` before consuming `R`.

- [x] **AC64 (R8.1)** After a successful V3 `importPosition`, `positions(tokenId).liquidity == 0` and `tokensOwed0 == tokensOwed1 == 0`. `ownerOf(tokenId)` is the vault. `getApproved(tokenId) == address(0)`.

- [x] **AC65 (R8.2)** `test_import_emptyNft_originalOwnerCannotCollect`: original owner calling NPM `collect` reverts. Vault token balances unchanged.

- [x] **AC66 (R9.1)** Rename every current `*V2` component in the V3/V4 vault trees in place. Directory stays `protocols/uniswap/v3` and `v4`. Mapping: `UniswapV{3,4}StandardExchange<Rest>V2` → `UniswapV{3,4}FullSpreadStandardExchangeVault<Rest>`; `UniswapV{3,4}_Component_FactoryServiceV2` → `UniswapV{3,4}FullSpreadStandardExchangeVault_Component_FactoryService`; `TestBase_UniswapV{3,4}StandardExchangeV2` → `TestBase_UniswapV{3,4}FullSpreadStandardExchangeVault`. Shared file `StandardExchangeConstantProduct.sol` keeps that name. Do not add `StandardExchangeHeldRepo.sol`.

- [x] **AC67 (R9.2)** Complete the mapping for declarations outside that pattern: `UniswapV3VaultRepoV2` → `UniswapV3FullSpreadStandardExchangeVaultRepo`; `UniswapV3{FactoryAwareRepo,PoolAwareRepo}V2` → `UniswapV3FullSpreadStandardExchangeVault{FactoryAwareRepo,PoolAwareRepo}`; `UniswapV4{PositionRepo,PoolManagerAwareRepo,PoolKeyAwareRepo,QuoteService}V2` → `UniswapV4FullSpreadStandardExchangeVault{PositionRepo,PoolManagerAwareRepo,PoolKeyAwareRepo,QuoteService}`. Preserve an interface's leading `I` and apply the same mapping to filenames, declarations, imports, and references. Preserve storage field order and existing slot strings; new CREATE3 names do not imply a storage-layout redesign.

- [x] **AC68 (R9.3)** For every renamed FullSpread facet, execution delegate, and DFPkg, the final salt passed by its FactoryService to the factory/registry is directly `keccak256(abi.encode("<new contract name>"))`. This follows the owner's global component-name encoding decision and supersedes the earlier raw-name hash. Remove the current `ArtifactCreationCode.releaseSalt(nameHash, creationCode, constructorArgs)` wrapping at those deployment call sites; do not include bytecode or constructor-argument hashes in these final salts. This deliberately changes the current V3/V4 release-binding behavior. Keep the shared `ArtifactCreationCode.releaseSalt` helper and unrelated callers unchanged within this effort; vault-instance salt derivation remains unchanged. `vm.label` strings match the new names. Artifact paths use the new `.sol:<Contract>` ids. FactoryService deploy helpers and `indexedexManager.deploy*DFPkg` names follow the same mapping (for example `deployUniswapV3FullSpreadStandardExchangeVaultDFPkg`).

- [x] **AC69 (R9.4)** FullSpread deployment tests verify the salt arguments on the real factory/registry deployment path for facets, execution delegates, and DFPkgs against `keccak256(abi.encode("<new contract name>"))`; the raw-name hash must not satisfy that assertion. Artifact loading and constructor arguments remain intact even though they no longer contribute to those salts.

- [x] **AC70 (R9.5)** Tests under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/` that target this package use the FullSpread names (including `*IFacet_TestV2.t.sol` → FullSpread facet tests, invariant files, decimal fixtures, Native SY on the vault, remediation delivery suites). Do not leave a parallel `*V2` package in this tree. `*PreservedBaseline*` tests stay on the preserved packages.

- [x] **AC71 (R9.6)** `README.md` documents: FullSpread product names; the scaled `MINIMUM_LIQUIDITY` formula and examples (18/18 → `1e15`, 6/18 → `1e9`, 6/6 → `1e3`); push is `transferFrom` to the vault then `pretransferred=true`; `exchangeIn` requires `actualIn == amountIn`; `exchangeOut` checks `actualIn` against `used` and refunds this-call surplus to `msg.sender`; `reserveOfToken` is booked ERC-20 on this diamond (`balanceOf` after vault ops), not free + deployed; `localReserve` is the live sleeve; `deployedReserve()` is a live position read and is not stored; `preparePretransfer` is not used; there is no imported-increase / Position Manager Permit2 approve; 0% sleeve can block locked exits; preserved packages remain vulnerable because they treat `reserveOfToken` as free + deployed.

- [x] **AC72 (R9.7)** `VALIDATION.md` gains a section for this PRD's tests. It does not claim DETF, Pendle market / external SY wrapper, arbitrary hook, or live-instance coverage. Native SY on the FullSpread vault itself is requirement 2. It records that old vaults are not deprecated here.

- [x] **AC73 (R9.8)** `README.md`, `VALIDATION.md`, `VERSION_SOURCE_MAP.json`, `VALIDATED_ARTIFACTS.json`, `REGRESSION_RESULTS.txt`, `PRESERVED_SOURCE_SHA256.json`, and `PRESERVED_BUILD_CONTEXT.json` here mean the files beside this PRD. Update source-map values to the renamed paths while preserving old-source keys. Refresh runtime sizes/hashes and regression results from the final FullSpread build/test run; all deployed facets, delegates, and packages must remain within the existing 24,576-byte runtime release limit. Headroom is tight today: `UniswapV3StandardExchangeInQueryFacetV2` 23,737 bytes, `UniswapV4StandardExchangeInQueryFacetV2` 23,337, `UniswapV3StandardExchangeOutFacetV2` 23,269, `UniswapV3StandardExchangeOutQueryFacetV2` 23,080, `UniswapV4StandardExchangeOutQueryFacetV2` 22,871. The sanctioned remedy for an overflow is D25's facet split. Do not enable `via_ir`, change global optimizer settings, or drop specified behavior to fit. Keep preserved hashes and preserved build context unchanged. Label old V2 preparation/binding test counts as historical; do not present them as FullSpread evidence or leave current guidance requiring preparation.

- [x] **AC74 (R9.9)** If a FullSpread facet exceeds 24,576 bytes, split that facet (D25). The retained half keeps the mapped FullSpread name; the new half is that name with `Ext` appended, and its Target is the original Target name with `Ext` appended (for example `UniswapV3FullSpreadStandardExchangeVaultInQueryFacetExt` / `...InQueryTargetExt`). Move whole external selectors only; never split one selector's implementation across facets. Move the fewest selectors that bring both halves under the limit, choosing in this priority order: import previews first, then remaining preview/quote selectors, then non-core operations. Core `exchangeIn` / `exchangeOut` / `exchangeInManyToOne` / `exchangeOutOneToMany` / `rebalanceLiquidReserve` selectors move last. The new facet gets its own CREATE3 salt `keccak256(abi.encode("<new contract name>"))` per D22, its own FactoryService deploy helper under requirement 9's mapping, and a cut in the same DFPkg. Record it in `VERSION_SOURCE_MAP.json`, `VALIDATED_ARTIFACTS.json`, and `README.md`, and extend requirement 6's J1/J2/J3 surface matrix to cover it. Only facets that actually overflow are split; do not split preemptively.

- [x] **AC75 (R9.10)** All 96 hashes in `PRESERVED_SOURCE_SHA256.json` still match. No edits under `contracts/protocols/dexes/uniswap/v3` or `v4`.

- [x] **AC76 (R9.11)** After production edits, run `python3 scripts/forge-artifacts.py test` with the FullSpread sources and `--test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap` (repeat `--test-root` for `adversarial/` if split). Default hermetic profile, no `via_ir`. Record the command and result.

## Verification

These are implementation-time commands, not commands run during plan creation. Run from the repository root, serially against one artifact/cache tree. The Python snippets use only the standard library. Keep `foundry.toml` paths/settings unchanged, use the default hermetic profile, and seed both `out/` and `cache_forge/` from a warm checkout before the first compile in a new/empty worktree. Do not delete either directory. Wait for Forge/solc to exit; cold builds can take hours. Copy successful worktree artifacts back to the warm seed afterward.

### V1: Preserved-source gate, before edits and after final validation

```bash
python3 - <<'CHECK'
import hashlib, json
from pathlib import Path
base = Path('contracts/vaults/standard/exchange/protocols/uniswap')
manifest = json.loads((base / 'PRESERVED_SOURCE_SHA256.json').read_text())
assert len(manifest) == 96
for name, expected in manifest.items():
    source = Path(name)
    assert source.is_file(), name
    assert hashlib.sha256(source.read_bytes()).hexdigest() == expected, name
print('96/96 preserved-source hashes match')
CHECK
```

Compare the preserved manifest and build-context bytes with the Step 1 snapshot as well; never regenerate them to make this check pass.

### V2: Refresh renamed artifacts, then test the full feature tree

Use the following snippet with `fullspread_action = 'plan'` first to inspect the selected commands, then `'build'` for Step 8 size inspection, then `'test'` for the final gate. These are three ordered invocations. All renamed sources are passed explicitly because deleted filenames cannot seed the artifact dependency graph. Consumer globs include preserved-baseline runtime artifacts without editing their sources. The existing invariant source directives retain 64 × 96 campaigns; the final command retains the prior 128 fuzz runs.

```bash
python3 - <<'RUN'
from pathlib import Path
import subprocess
base = Path('contracts/vaults/standard/exchange/protocols/uniswap')
tests = Path('test/foundry/spec/vaults/standard/exchange/protocols/uniswap')
fullspread_action = 'plan'
sources = [str(base / 'StandardExchangeConstantProduct.sol')]
for family in ('v3', 'v4'):
    sources += sorted(str(p) for p in (base / family).rglob('*.sol'))
assert sources and all(Path(p).is_file() for p in sources)
cmd = ['python3', 'scripts/forge-artifacts.py', fullspread_action, *sources]
if fullspread_action == 'build':
    cmd += ['--consumer', str(tests / '**/*.t.sol')]
else:
    cmd += ['--test-root', str(tests), '--', '--fuzz-runs', '128']
print('Command:', ' '.join(cmd), flush=True)
if fullspread_action == 'test':
    # Write the exact command/status into VALIDATION.md after inspecting this log.
    log_path = base / 'REGRESSION_RESULTS.txt'
    with log_path.open('w') as log:
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            print(line, end='', flush=True)
            log.write(line)
        code = process.wait()
    if code:
        raise SystemExit(code)
else:
    subprocess.run(cmd, check=True)
RUN
```

For intermediate focused checks, use the same wrapper with the edited production sources and an exact renamed test file/directory as `--test-root`. Do not run direct tests against stale artifact IDs. After the final whole-feature command passes, repeat it only after source changes or new failures justify another run.

### V3: Validate final runtime artifacts and refresh their evidence

After a successful current build, run this first with `fullspread_write_evidence = False` for Step 8; set it to `True` only after the final test gate passes. It preserves the existing evidence convention: SHA-256 over the unlinked runtime object string including its `0x` prefix. The length check remains valid for fixed-width library placeholders; tests must also prove deployment through the real linker/factory path.

```bash
python3 - <<'SIZES'
import hashlib, json
from pathlib import Path
base = Path('contracts/vaults/standard/exchange/protocols/uniswap')
fullspread_write_evidence = False
records = {}
for family in ('v3', 'v4'):
    for source in sorted((base / family).glob('*.sol')):
        name = source.stem
        if name.startswith('I') or 'FullSpreadStandardExchangeVault' not in name:
            continue
        if not name.endswith(('Facet', 'FacetExt', 'ExecutionDelegate', 'DFPkg')):
            continue
        artifact = Path('out') / source.name / (name + '.json')
        obj = json.loads(artifact.read_text())['deployedBytecode']['object']
        if not obj.startswith('0x'):
            obj = '0x' + obj
        assert len(obj) > 2 and (len(obj) - 2) % 2 == 0, name
        size = (len(obj) - 2) // 2
        print(name, size)
        assert size <= 24576, f'{name}: runtime exceeds 24576 bytes'
        records[name] = {'runtime_bytes': size,
                        'unlinked_runtime_sha256': hashlib.sha256(obj.encode()).hexdigest()}
assert len(records) >= 26, 'Missing renamed facet/delegate/package artifacts'
if fullspread_write_evidence:
    (base / 'VALIDATED_ARTIFACTS.json').write_text(json.dumps(records, indent=2) + '\n')
SIZES
```

Reconcile this enumeration against actual DFPkg cuts and FactoryService deployed artifacts, including any D25 additions; stale `out/` entries are not evidence of active components.

### V4: Source/document boundaries and final review

```bash
rg -n 'IStandardExchangePretransfer|StandardExchangeDeliveryRepo|inputOperation|_prepareOwnShares|_routePrepared|_increaseImportedPositionCommon|_deployExcessImported' \
  contracts/vaults/standard/exchange/protocols/uniswap \
  test/foundry/spec/vaults/standard/exchange/protocols/uniswap --glob '*.sol'
rg -n 'preparePretransfer|releaseSalt|StandardExchange.*V2' \
  contracts/vaults/standard/exchange/protocols/uniswap/v3 \
  contracts/vaults/standard/exchange/protocols/uniswap/v4 --glob '*.sol'
git diff --check
```

The first search must have no remaining executable/import references to removed mechanisms; the second must have no active FullSpread preparation, old-name, or releaseSalt call sites. Inspect any text-only hits. Deleted-selector negative tests deliberately retain the legacy ABI signature under the test tree. `rg` exit 1 means no matches. Review the scoped diff and source map, re-run V1, verify the Step 1 snapshots, and ensure existing unrelated changes are untouched.

### V5: Repository gate before an implementation PR

The repository requires a local build and hermetic test run before opening an implementation PR. Refresh runtime-loaded artifacts as well as statically imported contracts:

```bash
forge build
python3 scripts/forge-artifacts.py build --all-artifacts
forge test
```

Record any unrelated failure distinctly, including its test and error, without weakening the FullSpread gate or expanding the edit scope. These commands belong to implementation verification; creating this plan does not run them or open a PR.

## Do not

- Do not change files outside the work-order Files lists without a PRD update.
- Do not reopen D1–D26, start the separate global salt correction, or add scope from Non-goals.
- Do not patch shared `NativeStandardYieldTarget`, `BasicVaultCommon`, `ArtifactCreationCode`, preserved production sources, compiler settings, deployment scripts, or downstream consumers as a shortcut.
- Do not invent a second reserve/context ledger, V4 import-preview API, public skim, token allowlist, or authenticated ownership of unbooked surplus.
- Do not mark planning, static inspection, stale artifacts, unrelated setup reverts, or historical tests as completed runtime acceptance.
