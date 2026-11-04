# Member response — minimax

## Identity

| Field | Value |
| --- | --- |
| Member | minimax |
| Run | `se-fullspread-implementation-plan-20261104` |
| Profile | research |
| Phase | initial independent response |
| Requested role | council-member |
| Requested model | `minimax/MiniMax-M3`, adaptive thinking admitted, not a selectable depth |
| Task ID | not exposed |
| Runtime identity | not exposed |
| Peers read before submission | no |
| Owned output | `docs/research/se-fullspread-implementation-plan-20261104/members/minimax/response.md` |

## Question and targets

**Question.** Write the complete implementation and testing plan for `UniswapV4FullSpreadStandardExchangeVault` from the current PRD, specific enough that an implementer can build and test it without a product decision. The plan does not authorize implementation.

**Required targets read (all of them):**

1. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` — whole file, 687 lines.
2. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md` — the `## Owner overrides, 2026-11-04` section, lines 43–70, plus the earlier lock sections for precedence context.
3. `docs/vaults/PRETRANSFER_DIRECTIVE.md` — whole file, 15 lines.
4. `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` — whole file, 218 lines.
5. `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` — whole file, 89 lines.
6. `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` — cited, not pasted.
7. `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` — the gas-ceiling sentences at lines 954–970 (`S1-GAS-01`).
8. `lib/crane/contracts/access/operable/IOperable.sol` — `setOperator(address,bool)` selector `0x558a7297`, `setOperatorFor(bytes4,address,bool)` selector `0x755dbe7c`, `isOperator` `0x6d70f7ae`, `isOperatorFor` `0xea562a25`, error `NotOperator(address)`.
9. `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol` — `_mint` at lines 329–336 writes `balanceOf` and `totalSupply` directly with the `_increaseBalanceOf` call commented out; `_increaseBalanceOf` (lines 192–200) reverts `ERC20InvalidReceiver` for `address(0)`.
10. `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol` — the disable predicate at lines 374–378: `if (address(tokenIn) != address(this)) { _requireNotDisabled(); }`.

**Additional code read to make the plan buildable (Crane package patterns and the named family files the PRD left unnamed):** `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol` and its `interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultComponentBindings.sol`; `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVault{Projection,Execution,Planner,Math}.sol`; `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol`; `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol`; `contracts/interfaces/IVaultRegistryDisableQuery.sol`; `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol`; `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol`; `lib/crane/contracts/factories/diamondPkg/PostDeployAccountHookFacet.sol`; `lib/crane/contracts/access/operable/{OperableRepo,OperableFacet}.sol`; `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/{StateLibrary,LiquidityAmounts}.sol`; `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol`; `lib/crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol`; `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol`; `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol`; the seven named `*_SeMatrixBehavior.sol` files (existence confirmed by path check).

No peer response, no coordinator draft, and no other member's file was read.

## Evidence

Observation and inference are separated. Every line below is either a quotation from a file I read or a statement I mark as inference.

**E1 — Precedence.** The PRD's own preamble states: "a dated 2026-11-04 owner lock in this file, and the same dated override in `IMPLEMENTATION_PLAN_BLOCKERS.md`, wins over a 2026-11-03 override, over an earlier sentence in that file, over an undated recap in that file, and over an older sentence here." (PRD preamble.) The blockers file repeats it: "Status sentences in this file that say the PRD has not been edited are stale. They are not locks."

**E2 — The 2026-11-04 override section (blockers file, lines 43–70).** It fixes: `Compounded()` has no arguments (final); `Donation()` has no fields, is a marker event, not an interface (final); the owner may appoint a global operator and a function-level operator through `setOperator(address,bool)` and `setOperatorFor(bytes4,address,bool)` stored in `OperableRepo`, only the live owner may appoint, and appointment must not be gated by a stored owner nor store `feeTo()` as that owner; disable follows the live V2 call site widened to every execution route, blocking every execution route except a withdrawal, `donate`, and `compound`, with views not reverting and a missed deadline still reverting `DeadlineExceeded` before the disable check; and the testing inventory is the 45-ID table restated in the PRD at FS-TEST-04, with 023, 024, 039, 044, 045, 048 replaced by the PRD rows, and no audit ID added.

**E3 — The live V2 disable predicate.** `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol` lines 374–378:
```
// CROPS: inbound-only disable. vaultShare exit stays live after registry disable.
if (address(tokenIn) != address(this)) {
    _requireNotDisabled();
}
```
`_requireNotDisabled` in `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol` lines 67–71 reverts `IVaultRegistryDisableQuery.VaultDisabled(address(this))` when `IVaultRegistryDisableQuery(address(StandardVaultRepo._feeOracle())).isDisabled(address(this))`. Observation: the V2 gate reads the disable state through the fee oracle binding, and the predicate is "the input is not this vault's share".

**E4 — The floor mint path.** `lib/crane/contracts/tokens/ERC20/ERC20Repo.sol` lines 329–336:
```
function _mint(Storage storage layoutStruct, address recipient, uint256 amount) internal {
    // _increaseBalanceOf(layoutStruct, recipient, amount);
    layoutStruct.balanceOf[recipient] += amount;
    layoutStruct.totalSupply += amount;
    emit IERC20Events.Transfer(address(0), recipient, amount);
}
```
Observation: `_mint` does not reject `address(0)`; `_increaseBalanceOf` (lines 192–200) does. This is why the floor mint uses `_mint`.

**E5 — `IOperable`.** `lib/crane/contracts/access/operable/IOperable.sol`: `setOperator(address,bool)` → `0x558a7297`; `setOperatorFor(bytes4,address,bool)` → `0x755dbe7c`; `isOperator(address)` → `0x6d70f7ae`; `isOperatorFor(bytes4,address)` → `0xea562a25`; `error NotOperator(address)` → `0x76c6c93a`; events `NewGlobalOperatorStatus(address,bool)` and `NewFunctionOperatorStatus(address,bytes4,bool)`.

**E6 — The Crane operable storage.** `lib/crane/contracts/access/operable/OperableRepo.sol` exposes `_setOperatorStatus(address,bool)`, `_setFunctionOperatorStatus(bytes4,address,bool)`, `_isOperator(address)`, `_isFunctionOperator(bytes4,address)` over the Crane slot `keccak256(abi.encode("crane.access.operable")) - 1`. Inference: the family's live-owner check reuses this storage and these accessors, and adds its own guard, because `OperableModifiers.onlyOperator`/`OperableFacet` are gated by `MultiStepOwnable` (a stored owner), which FS-OWN-14 forbids for this vault.

**E7 — The gas meter.** `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md` lines 956–962: "The release engineering ceiling is 12,000,000 gas for each supported public money/maintenance call, including conservative transaction overhead… Local cold-call tests reserve 100,000 gas for intrinsic and the fixed money-method calldata, so their measured call bodies must not exceed 11,900,000." Lines 964–965: "Use 5,000,000 gas as the local preview acceptance ceiling."

**E8 — The accepted return ABI.** `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`: `previewExchangeIn` stays `0x89d61912`, `exchangeIn` stays `0xd02d3063`, and both return `(uint256 amountOut, uint256 amountRefunded)`. The bundle selectors are `0xc2fe8c7c`, `0xe7886166`, `0xa5952fc2`, `0x11993461`, and the two interface ids are `0x2576ed1a` and `0xb40c1ba3`. I recomputed the XORs by hand: `0x89d61912 ^ 0xd02d3063 = 0x59fb2971`, `0xc2fe8c7c ^ 0xe7886166 = 0x2576ed1a`, `0xa5952fc2 ^ 0x11993461 = 0xb40c1ba3`. All three match the PRD's and the report's stated values.

**E9 — The preview consumers.** `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` names six production gates that reject a non-32-byte success (`StandardExchangeRateProviderFacet.sol` 103–106 and 121–125; `WrappedStandardExchangeRateProviderTarget.sol` 65–68; `CommonBufferMultiVaultStablePoolHookTarget.sol` 437–444; `MixedBufferMultiVaultStablePoolHookTarget.sol` 463–470; `CommonBufferMultiVaultWeightedPoolHookTarget.sol` 474–481), three one-word ABI bindings (`lib/crane/contracts/interfaces/IStandardExchangeIn.sol` 45–48; `frontend/apps/indexedex/app/insights/lib/insightsAbi.ts` 69–76; `frontend/packages/protocol/src/protocolDetfAbi.ts` 33–40), and one one-word helper without a length check (`contracts/test/bases/FundedThresholdAssertions.sol` 60–63). `INDEX.md` is the complete textual occurrence list: 1626 occurrences in 618 files. I read the header and the first rows; I did not line-audit it and I do not paste it.

**E10 — The temporary-hook facet, cited from its factory file.** `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` documents `postDeployHookFacet` as "Temporary facet implementing IPostDeployAccountHook; removed in postDeploy", installs it in `facetCuts()` and removes it in `postDeployFacetCuts()`. The facet file is `lib/crane/contracts/factories/diamondPkg/PostDeployAccountHookFacet.sol`. The V4 sibling factory `contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory.sol` has the same shape with `POST_DEPLOY_HOOK_FACET`.

**E11 — Sibling package shape.** `contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultDFPkg.sol` shows the `PkgInit`/`PkgArgs` shape on the interface, `bindingHash = keccak256(abi.encode(init_))`, `calcSalt`/`processArgs` run by delegatecall through `SELF`, `processArgs` requiring `msg.sender == REGISTRY && address(this) == DIAMOND_FACTORY`, `initAccount` writing the repo plus `ERC20Repo._initialize(name, symbol, 18)`, `EIP712Repo._initialize(name, "1")`, `MultiAssetBasicVaultRepo._initialize(faces_)`, `StandardVaultRepo._initialize(ORACLE, bytes32(0), interfaces, contentsId)`, and `_appendComponent` validating each facet's `facetFuncs()` against an explicit `_expectedSelectors(index)` list. Observation: `linkedComponents()` returns `address[6]` in the fixed order Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation, and the package compares `keccak256(abi.encode(facet.linkedComponents()))` against `linkedLibraries` for family facets.

**E12 — `MultiAssetBasicVaultFacet`.** `contracts/vaults/basic/MultiAssetBasicVaultFacet.sol` lines 35–39: `facetFuncs()` returns three selectors — `vaultTokens`, `reserveOfToken`, `reserves`. Observation: the shared facet address exposes three, but FS-OWN-07 requires the cut to install only `vaultTokens` from it. Inference: the package must build each component's installed selector list from an explicit expected list rather than from `facet.facetFuncs()` verbatim, and must validate that each expected selector is present in the facet's own `facetFuncs()`.

**E13 — Storage namespaces in use.** PairToken: `keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.pairToken")) - 1`. Wings: `keccak256("indexedex.vaults.standard.exchange.uniswap.v4.upperLowerWings")`. V3 full spread: `keccak256("indexedex.protocols.dexes.uniswap.v3.vault")`.

**E14 — The fee oracle.** `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol`: `feeTo()` returns `VaultFeeOracleRepo._feeTo()` typed as `IFeeCollectorProxy`; `usageFeeOfVault(address vault)` is the usage-fee read. `contracts/interfaces/proxies/IFeeCollectorProxy.sol` defines the proxy interface.

**E15 — The matrix surface.** `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol` is the per-family adapter contract; the sibling family adapter for the V3 full-spread vault is `SeMatrix_FullSpreadV3Fixture.sol`. All seven named `*_SeMatrixBehavior.sol` files exist at the paths the PRD names.

**E16 — The sibling library boundary.** `UniswapV4PairTokenStandardExchangeVaultProjection.sol` defines a second library `UniswapV4PairTokenStandardExchangeVaultSwapProjection` whose single public entry is `projectSwap(ProjectedState, bool zeroForOne, uint256 amountIn, uint160 sqrtPriceLimitX96, Phase)`. `UniswapV4PairTokenStandardExchangeVaultExecution.sol` defines a second library `UniswapV4PairTokenStandardExchangeVaultExecutionPreparation` whose single public entry is `prepare(Request) -> Run`. Observation: these are thin, fixed linked boundaries, not new economics.

## Assumptions

Each assumption below is an interpretation of a locked sentence where the PRD states a rule but not the mechanism. Each names the sentence it rests on, so the coordinator can check it against the lock. None of these reopens a lock, and none creates a product rule.

**A1 — Pretransfer shortfall on a one-token call is a no-op success.** FS-OWN-32 says: "If the maximum is larger than the unbooked balance on a one-token call, refund that unbooked balance. Do not spend that unbooked balance. Do not pull the shortfall. Do not refund maximum minus used. A larger maximum is not a revert on that one-token call." I read this as: when `declared maximum > unbooked balance`, the vault spends nothing of the unbooked balance, refunds the entire unbooked balance in that token, pulls nothing, does not revert, and mints/burns nothing; the call returns `(0, unbookedBalance)`. This is the only reading under which "refund that unbooked balance" and "Do not spend it" are both literally true, and it is the only reading under which "Do not refund maximum minus used" is consistent. The bundle case is the contrasting atomic revert (F1 lock, 2026-11-03), and it is treated separately in §9.4.

**A2 — The fee ledger is one local per-currency balance.** The PRD says "book" for `feesAccrued`, for the maintenance remainder, and for the residual owed to the other holders, and it separates that from the live "unpaid fee-owed read" used by `reserves()`. I model this as a single local ledger `booked[currency]` plus a live on-chain read, with no second ledger, no fee-origin store (FS-OWN-14), and no `feeOrigin` field. See §6.4 and §9.

**A3 — The "unbooked balance" is a balance net of the ledger.** The PRD contrasts "the unbooked held balance" with "a booked remainder" in FS-OWN-20, FS-OWN-32 and `docs/vaults/PRETRANSFER_DIRECTIVE.md`. I model it as `token.balanceOf(vault) − booked[token]`. This is the only reading under which "the unbooked remainder is not sent to `msg.sender` beyond the refund rule" (FS-OWN-20) is enforceable.

**A4 — The live owner is the `feeTo()` proxy address.** FS-OWN-14: "The read is `VaultFeeOracleQueryFacet.feeTo()`, which returns `IFeeCollectorProxy`. The owner address is that proxy's address." I read the owner as `address(IVaultFeeOracleQuery(oracle).feeTo())`, compared to `msg.sender`, with the read performed live on every authorization check.

**A5 — The operator surface sits on the family money facet.** FS-FACET-01 enumerates the family facets, and FS-OWN-07 closes the query facet with "The custom facet exposes only `reserveOfToken` and `reserves`". The PRD never says which facet carries `setOperator`/`setOperatorFor`, and every other family facet's selector list is enumerated. I place the two operator selectors on the family money facet, because the function-level grant is keyed by the `donate`/`compound` selectors that live there. This is a placement choice, recorded in §7 and §19, not a new requirement.

**A6 — The `PoolManager` getter name on the Crane facet is `poolManager()`.** FS-OWN-01 forbids a *family* `poolManager()` selector and requires the Protocol Aware facet to expose the stored components. I read the Crane facet as exposing `poolManager()` plus one getter per other stored component. FS-A01 is then asserted as "the selector resolves to the Crane facet address and is absent from the family query facet's `facetFuncs()`".

**A7 — The sibling PairToken execution file is the mechanical template.** The PRD does not specify UniV4 delta mechanics. The sibling `UniswapV4PairTokenStandardExchangeVaultExecution.sol` already implements `_account`, `_record`, `_settle`, `_fund`, `_payout`, `_send`, `_zeroDeltas`, `unlockCallback` and the committed-hash guard in this repo, against the same `IPoolManager`. The plan directs the implementer to that file for the settlement mechanics and requires only the changes this PRD names. This is a template pointer, not a new rule.

## Coverage

**Covered by the plan below, with no product question left open:** the package field set and its names; the initializer contract; the storage namespace and ledger layout; the installed selector manifest and its count; the check order on every public mutator; the five money routes; the two maintenance routes; both unlock paths; the quote engine; the event and error set; the operator model; the disable predicate; the hook matrix rows and the 64-byte preview migration; the test-file mapping for all 39 FS-A rows and all 45 inventory rows; the gas measurement; and a traceability table for every PRD identifier.

**Deliberately not done here:** no implementation, no test run, no build, no deployment, no Git operation, no PRD edit, no sub-agent, no public search. The plan authorizes nothing.

**Not claimed:** the plan does not claim that any figure in it has been executed. Every gas number is a ceiling to be measured, not a measurement. The seven hook matrix rows are proved or recorded as a cited reject; the plan does not assert they pass.

## Conclusions

The complete implementation and testing plan follows, under the nineteen headings the brief requires, in order.

---

### 1. Authority

This document is a plan. It does not authorize implementation, deployment, a registry migration, a hook-economics edit, a test run, a package publish, or any Git operation. Nothing here is a safety clearance, an audit result, a vote, or a product decision. The plan is written so that an implementer can build and test `UniswapV4FullSpreadStandardExchangeVault` without asking the owner anything; where the PRD left a name open, §19 records the chosen name and labels it as a name, not a requirement. The PRD, the blockers file, the accepted return-ABI report, the preview-consumer report and index, the pretransfer directive, and the dated owner locks are the only sources of authority for the requirements themselves.

### 2. Sources and precedence

The operative requirement is the full-spread PRD at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, read in full. Precedence, highest first:

1. A dated 2026-11-04 owner lock in the PRD and the matching `## Owner overrides, 2026-11-04` section of `IMPLEMENTATION_PLAN_BLOCKERS.md`.
2. A dated 2026-11-03 override in the blockers file, as already applied in the PRD's sentences.
3. `docs/vaults/PRETRANSFER_DIRECTIVE.md` for any call that takes `pretransferred`.
4. `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md` for the accepted return ABI and the bundle interfaces, except where a later full-spread lock replaces a sentence in it.
5. `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and `INDEX.md` for the 64-byte preview migration; the report's F13 is accepted, its F14 principal-only withdrawal sentence is not.
6. The earlier sentences of the PRD and the blockers file's 2026-11-01 and 2026-11-02 locks.
7. The repository's own law: `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md`, and the Crane architecture, IndexedEx testing, and Uniswap V4 hook-package skills.

Two boundaries: `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` is not an economics source; the November 1 plan-readiness report's open questions and any "expected result blocked" cell are not current — FS-TEST-04 wins. A status line in any source saying the PRD has not been edited is not a lock.

### 3. Adopted readings

The plan adopts the brief's readings verbatim and does not reopen them.

- A pass-through is an exact-input pool swap at `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`. It is not the FS-OWN-33 liquidity-targeting swap. That shape belongs to a one-sided deposit and a one-token `donate`/`compound` only.
- A planned manager action is one `swap` or one `modifyLiquidity`. A one-sided deposit that swaps and then adds liquidity performs two sequential unlocks in the same call, with no external call between them except the settlement of the first action.
- The gas ceilings stay 12,000,000 and 5,000,000. The meter is 11,900,000 measured call body plus 100,000 overhead, copied from `S1-GAS-01` in the stage-one PRD. A composed hook route is judged on the whole transaction under 12,000,000; where that sentence and the stage-one sentence differ, the composed-route sentence governs composed routes.
- `Donation()` and `Compounded()` are empty marker events. No `Donation` interface is added and no ERC-165 id is invented for either.
- The live `feeTo()` owner appoints global operators with `setOperator(address,bool)` and function operators with `setOperatorFor(bytes4,address,bool)`. The maintenance check has exactly three arms: the live `feeTo()` address, a global operator, or a function operator whose grant is for `msg.sig`. The stored-owner modifier is not used.
- Disable blocks every execution route except a withdrawal, `donate`, and `compound`. A missed deadline reverts before the disable check.
- FS-TEST-04 is the audit inventory. No "no" row is reopened and no audit ID is added.
- A bundle pretransfer shortfall reverts before any leg, spends nothing, and mints nothing. No new error is declared for it and the test does not pin a new selector.
- Borrowed-path initialized, idle, callback-hash, and reservation failures revert, and that revert is not `ReentrantOperation` and not `SettlementMismatch`. The plan uses an unnamed revert for those checks.
- The floor mint uses `ERC20Repo._mint`, which writes `balanceOf` and `totalSupply` directly.

### 4. File map, including Crane files and family files

All new family production files live under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`. PairToken and Wings are not edited to host this family.

**Family interfaces**

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol` — the family interface: the money, quote, out, query, callback, and operator surface, the family errors, and the two empty marker events.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` — `PkgInit`, `PkgArgs`, the package errors, `bindingHash`, `deployVault`.

**Family production files**

- `.../UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` — the package.
- `.../UniswapV4FullSpreadStandardExchangeVaultComponent_FactoryService.sol` — CREATE3 deployment of the family facets and the package, mirroring the sibling's component factory service.
- `.../UniswapV4FullSpreadStandardExchangeVaultComponentBindings.sol` — `linkedComponents()` returning `address[6]` in the fixed order Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation.
- `.../UniswapV4FullSpreadStandardExchangeVaultTypes.sol` — `Config`, `Operation`, `Action`, `Amounts`, `Phase`, and the request/run structs.
- `.../UniswapV4FullSpreadStandardExchangeVaultRepo.sol` — the family repo (storage, §6).
- `.../UniswapV4FullSpreadStandardExchangeVaultMath.sol` — `Math`: liquidity/amount math and the share ratios (§9).
- `.../UniswapV4FullSpreadStandardExchangeVaultProjection.sol` — `Projection` (pool-state projection and the tick walk) and `SwapProjection` (the single quote/execution swap kernel, §12).
- `.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` — `Planner`: turns an operation into a candidate plan (route classification, share credit/debit, minima, refunds).
- `.../UniswapV4FullSpreadStandardExchangeVaultExecution.sol` — `Execution` (actions, unlocks, settlement, payout, booking) and `ExecutionPreparation` (the fixed preparation boundary, §11).

**Family facets and targets** — one facet and one target each, with the full name in the filename (no shortened `MoneyTarget.sol` literal):

- `.../UniswapV4FullSpreadStandardExchangeVaultMoneyFacet.sol` and `.../UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol`
- `.../UniswapV4FullSpreadStandardExchangeVaultQuoteFacet.sol` and `.../UniswapV4FullSpreadStandardExchangeVaultQuoteTarget.sol`
- `.../UniswapV4FullSpreadStandardExchangeVaultOutFacet.sol` and `.../UniswapV4FullSpreadStandardExchangeVaultOutTarget.sol`
- `.../UniswapV4FullSpreadStandardExchangeVaultQueryFacet.sol` and `.../UniswapV4FullSpreadStandardExchangeVaultQueryTarget.sol`
- `.../UniswapV4FullSpreadStandardExchangeVaultCallbackFacet.sol` and `.../UniswapV4FullSpreadStandardExchangeVaultCallbackTarget.sol`

No SY money facet and no SY query facet files are created (FS-OWN-05).

**Family access-control files (new; the PRD says the modifier file names are not given — see §19)**

- `.../UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol`
- `.../UniswapV4FullSpreadStandardExchangeVaultOperableModifiers.sol`

**Crane files (new; the directive includes them and their Crane tests)**

- `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareRepo.sol` — one repo holding the seven Uniswap V4 architecture components.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareTarget.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareFacet.sol` — the externally callable getters.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/position/UniswapV4SinglePositionAwareRepo.sol` — one repo holding `PoolKey`, `tickLower`, `tickUpper`, `salt`.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/position/UniswapV4SinglePositionAwareTarget.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/position/UniswapV4SinglePositionAwareFacet.sol` — `poolKey()`, `tickLower()`, `tickUpper()`, `positionSalt()`, `positionLiquidity()`.
- Crane tests, inside the Crane tree: `lib/crane/test/foundry/spec/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAwareFacet.t.sol` and `lib/crane/test/foundry/spec/protocols/dexes/uniswap/v4/position/UniswapV4SinglePositionAwareFacet.t.sol`.

Neither Crane pair is placed inside the full-spread family directory, and neither is a second per-vault copy of the protocol addresses.

**Family test files**

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol`
- Specs under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` — the seven files listed in FS-TEST-02, §17.
- Hook matrix adapter: `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol`, implementing `SeMatrixFixture`, modelled on `SeMatrix_FullSpreadV3Fixture.sol`.

### 5. Package, initialization, and validation, with the chosen field names

**`PkgInit` field order** (the order is the binding order, and `bindingHash = keccak256(abi.encode(init_))` covers every field):

| # | Field | Type | Kind |
| --- | --- | --- | --- |
| 1 | `erc20Facet` | `IFacet` | shared |
| 2 | `erc2612Facet` | `IFacet` | shared |
| 3 | `erc5267Facet` | `IFacet` | shared |
| 4 | `basicVaultFacet` | `IFacet` | shared — `MultiAssetBasicVaultFacet` |
| 5 | `standardVaultFacet` | `IFacet` | shared |
| 6 | `moneyFacet` | `IFacet` | family |
| 7 | `quoteFacet` | `IFacet` | family |
| 8 | `outFacet` | `IFacet` | family |
| 9 | `queryFacet` | `IFacet` | family — `reserveOfToken`, `reserves` |
| 10 | `callbackFacet` | `IFacet` | family |
| 11 | `uniswapV4ProtocolAwareFacet` | `IFacet` | **Crane facet input** |
| 12 | `uniswapV4SinglePositionAwareFacet` | `IFacet` | **Crane facet input** |
| 13 | `poolManager` | `IPoolManager` | infrastructure |
| 14 | `positionDescriptor` | `IPositionDescriptor` | **architecture address** |
| 15 | `positionManager` | `IPositionManager` | **architecture address** |
| 16 | `quoter` | `IV4Quoter` | **architecture address** |
| 17 | `stateView` | `IStateView` | **architecture address** |
| 18 | `reservesLens` | `address` | **architecture address** |
| 19 | `universalRouter` | `IV4Router` | **architecture address** |
| 20 | `registry` | `IVaultRegistryDeployment` | infrastructure |
| 21 | `oracle` | `IVaultFeeOracleQuery` | infrastructure |
| 22 | `diamondFactory` | `IDiamondPackageCallBackFactory` | infrastructure |
| 23 | `linkedLibraries` | `address[6]` | Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation |
| 24 | `weth` | `IWETH` | the WETH face |

There is no `wrappedNative` field, no `rateAsset`, no `maxZapBps`, no `maxZapTickMove`, and no SY facet field. `reservesLens` is typed `address` because no Reserves Lens interface exists in this repository; the vault never calls it (§12).

**`PkgArgs`**

```solidity
struct PkgArgs {
    PoolKey poolKey;
    string name;
    string symbol;
}
```

**Package constructor validation** (reverts `InvalidComponent()`): every facet field and every library address has code; every architecture address has code; the family facets' `linkedComponents()` hash equals `linkedLibraries`; the `basicVaultFacet` address is `MultiAssetBasicVaultFacet` by interface, not by a stored owner; `weth` has code and 18 decimals.

**`calcSalt` / `processArgs`**: `calcSalt(bytes) = keccak256(abi.encode(bindingHash, abi.decode(args, (PkgArgs))))`. `processArgs` reverts `NotCalledByRegistry()` unless `msg.sender == address(REGISTRY)` **and** `address(this) == address(DIAMOND_FACTORY)`; both conjuncts are required. It validates the pool key and returns the re-encoded arguments.

**`deployVault(PkgArgs)`** calls `REGISTRY.deployVault(this, abi.encode(args))`. There is no second factory and the PoolManager is never CREATE3'd by this package.

**`initAccount`** writes, in this order: `Repo._initialize(...)`; the initialized flag; `ERC20Repo._initialize(name, symbol, 18)`; `EIP712Repo._initialize(name, "1")`; `MultiAssetBasicVaultRepo._initialize(faces)` where `faces` is `vaultTokens()` order — `currency0` then `currency1`, with native `address(0)` replaced by the `weth` field; `StandardVaultRepo._initialize(ORACLE, bytes32(0), facetInterfaces(), contentsId)`; the Uniswap V4 Protocol Aware Repo, written with all seven architecture addresses — the PoolManager and the six others; the `UniswapV4SinglePositionAware` Repo, written with the full `PoolKey`, `tickLower = TickMath.minUsableTick(poolKey.tickSpacing)`, `tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing)`, and `salt = bytes32(0)`; and `WETHAwareRepo._setWeth(weth)`.

The full-range ticks are the position's ticks and the salt is zero. `feeTo()` is not stored as an owner. No designated rate token is stored.

**Validation rules** (FS-PKG-02), each reverting before any partial diamond exists:

| Condition | Error |
| --- | --- |
| Missing or code-empty component; family facet whose `linkedComponents()` hash does not match `linkedLibraries`; a cut that installs `getRate` or `rateAsset` | `InvalidComponent()` |
| Pool key not initialized on the bound manager (`getSlot0` price zero), or a nonzero hook, or a currency face that is `address(0)` after substitution | `InvalidPoolKey()` |
| `processArgs` called by the wrong caller or in the wrong account | `NotCalledByRegistry()` |
| Proxy initialization that does not match the bound package and arguments | `InvalidInitializationContext()` |
| A second initialization | `AlreadyInitialized()` |

There is no inherited-domain reject, no rate-asset reject, no wrapped-native argument to reject, and no zap-limit reject. "Initialized on the bound manager and hookless" is the whole pool-key rule; any initialized hookless pool is accepted and no minimum tick spacing is imposed.

### 6. Storage

**Namespace (implementation name).** `"indexedex.vaults.standard.exchange.uniswap.v4.fullSpread"`, and the slot is `bytes32(uint256(keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.fullSpread"))) - 1)`. This is not PairToken's `keccak256(abi.encode("indexedex.vaults.standard.exchange.uniswap.v4.pairToken")) - 1` and not Wings' `keccak256("indexedex.vaults.standard.exchange.uniswap.v4.upperLowerWings")`; FS-A04 asserts both inequalities against the constants.

**Family repo layout** (`UniswapV4FullSpreadStandardExchangeVaultRepo.sol`):

| Field | Purpose |
| --- | --- |
| `bool initialized` | one-time initialization guard |
| `address poolManager` | the bound manager (also stored in the Protocol Aware Repo; the two are written from the same immutable at initialization) |
| `PoolKey poolKey` | the pool key, mirrored for the family target's convenience; the canonical copy is in `UniswapV4SinglePositionAware` |
| `int24 tickLower`, `int24 tickUpper` | the full-range position's ticks, mirrored; canonical copy in the position repo |
| `bytes32 positionSalt` | `bytes32(0)`; canonical copy in the position repo |
| `address registry`, `address oracle` | the disable query and fee oracle bindings |
| `uint256[2] booked` | the local per-currency ledger: tokens and fee claims attributable to shareholders that are neither deployed into the position nor paid out |
| `bytes32 operationHash` | the committed unlock payload hash for the locked path (FS-UNLOCK-03) |
| `uint64 operationKind` | the committed operation kind that goes with `operationHash` |

The family repo holds no share balance and no share supply: those live in the Crane `ERC20Repo` under its own slot. There is no second share ledger, no fee-origin store, no last-committed snapshot, and no local-reserve balance.

**Ledger semantics (A2).** `booked[c]` is the shareholder-attributable local balance for currency `c`. It is written when a deposit recognizes `feesAccrued`, when a maintenance call re-books the actual held balance, and when an exit pays a booked claim. The "unbooked balance" of currency `c` is `IERC20(c).balanceOf(address(this)) − booked[c]` (A3).

**Shared repos used unchanged:** `ERC20Repo` (shares, `totalSupply`, `balanceOf`), `EIP712Repo` (permit domain), `MultiAssetBasicVaultRepo` (`vaultTokens` faces), `StandardVaultRepo` (fee oracle binding, `contentsId`, `vaultTypes`), `OperableRepo` (operator grants), `WETHAwareRepo` (the WETH face), the Crane Protocol Aware Repo, and the Crane `UniswapV4SinglePositionAware` Repo.

### 7. Selector cut

The cut names the installed selectors. It does not install every selector a facet exposes. The package builds each component's installed selector list from an explicit expected list, exactly as the sibling's `_expectedSelectors` does, and validates that every expected selector appears in the component's own `facetFuncs()` (E12). `MultiAssetBasicVaultFacet.facetFuncs()` returns three selectors but only `vaultTokens` is installed from it (FS-OWN-07); `reserveOfToken` and `reserves` come from the family query facet.

| Component | Installed selectors | Count |
| --- | --- | --- |
| `erc20Facet` | `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `allowance`, `approve`, `transfer`, `transferFrom` | 9 |
| `erc2612Facet` | `permit`, `nonces`, `DOMAIN_SEPARATOR` | 3 |
| `erc5267Facet` | `eip712Domain` | 1 |
| `basicVaultFacet` | `vaultTokens` | 1 |
| `standardVaultFacet` | `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig` | 4 |
| `moneyFacet` | `exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, `compound`, `setOperator`, `setOperatorFor` | 7 |
| `quoteFacet` | `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut` | 3 |
| `outFacet` | `previewExchangeOut`, `exchangeOut` | 2 |
| `queryFacet` | `reserveOfToken`, `reserves` | 2 |
| `callbackFacet` | `unlockCallback` | 1 |
| `uniswapV4ProtocolAwareFacet` | `poolManager`, `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter` | 7 |
| `uniswapV4SinglePositionAwareFacet` | `poolKey`, `tickLower`, `tickUpper`, `positionSalt`, `positionLiquidity` | 5 |

**Total installed by the package: 45 selectors.** The old 61-selector count included `getRate` and is not the manifest; the count is recomputed from the built package, not copied.

**Explicitly absent from the cut** and asserted absent by FS-A01: `getRate`, `rateAsset`, `basket`, `wrappedNative`, `localReserves`, `previewWithdrawalMode`, `previewZapCredit`, `maxZapBps`, `maxZapTickMove`, `depositPair`, `previewDepositPair`, `redeemPair`, `previewRedeemPair`, every Standardized Yield selector (`deposit`, `redeem`, `exchangeRate`, `rewardIndexesCurrent`, `claimRewards`, `previewDeposit`, `previewRedeem`, `getTokensIn`, `getTokensOut`, `yieldToken`, `assetInfo`, `exchangeRate`, `isValidTokenIn`, `isValidTokenOut`, `rewardTokens`, `accruedRewards`, `rewardIndexesStored`), and the family-only `poolManager()`/`poolKey()` (those selectors are installed from the Crane facets, not from the family query facet).

**Factory-owned surfaces excluded from `PkgInit`, `facetCuts`, and the package interface aggregation, but still callable on the factory-built proxy:** ERC-165 introspection, ERC-8109 introspection, the diamond loupe, and the factory-owned temporary-hook facet. The temporary-hook facet is named here from its factory file: `contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory.sol` and `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` both install `POST_DEPLOY_HOOK_FACET` in `facetCuts()` and remove it in `postDeployFacetCuts()`; the facet file is `lib/crane/contracts/factories/diamondPkg/PostDeployAccountHookFacet.sol`, implementing `IPostDeployAccountHook` (E10). The temporary hook is present during deployment and removed by the factory's own lifecycle after `postDeploy`.

**ERC-165 ids advertised by the proxy** (computed in the package, and rechecked with `type(I).interfaceId` before registration):

- `IStandardExchangeIn` → `0x59fb2971` (the XOR of `0x89d61912` and `0xd02d3063`, E8). `0x8c8035da` and `0x676ec907` are not advertised.
- `IStandardExchangeBundleInForSingleOut` → `0x2576ed1a`.
- `IStandardExchangeBundleOut` → `0xb40c1ba3`.
- No id is advertised for `Donation` or `Compounded`.

`linkedComponents()` is facet metadata and is not an installed proxy selector.

### 8. Check order for each public mutator

The order below is the plan's check order. It is consistent with FS-OWN-26 (a missed deadline reverts before the disable check), FS-OWN-28 (the deadline reverts before any other work on a route that takes `deadline`), FS-OWN-32 (the pretransfer refund rule), and the V2 call site's predicate (E3).

**Common prologue, every money mutator**

1. Not payable: a value-bearing call fails at the ABI boundary, not as an internal `msg.value` check (FS-A20). There is no internal value check anywhere in the family.
2. The vault's public-operation guard is taken and held for the whole call — across the plan, the token calls, and the final payout (FS-UNLOCK-03). It reverts `ReentrantOperation()`.
3. Deadline, for every route that takes one: `block.timestamp > deadline` reverts `IStandardExchangeErrors.DeadlineExceeded(deadline, block.timestamp)`. This is the first substantive check.
4. Route and argument validation, in the order listed per route below.
5. Disable check, where the route is subject to it (§15).
6. Authority and funding.
7. Manager-state dispatch: `TransientStateLibrary.isUnlocked(boundManager)` selects the locked path (FS-UNLOCK-03) or the borrowed path (FS-UNLOCK-02).
8. Plan, execute, settle, pay, refund, mint or burn, book.

`unlockCallback` does not re-take the public-operation guard; it is entered inside it. It verifies the caller is the bound manager, that the guard is held, and that the committed hash matches (§11.1).

**`exchangeIn`** — checks 1–3 above, then:

4. `address(tokenIn) == address(0)` or `address(tokenOut) == address(0)` → `TokenNotExchangeable(token)`. `tokenIn == tokenOut` → the family error `InvalidRoute()` (no arguments). `amountIn == 0` → `EmptyExchange()`. `recipient == address(0)` or `recipient == address(this)` → `InvalidRecipient()`.
5. Disable: if `tokenIn != address(this)` the vault calls `_requireNotDisabled()`, which reverts `IVaultRegistryDisableQuery.VaultDisabled(address(this))`. Only a share input — a withdrawal — survives a disabled vault.
6. Funding:
   - Input is the share (a withdrawal): the vault burns `amountIn` shares from `msg.sender`'s own balance. `pretransferred` is irrelevant for a share input; shares parked on the vault are never credit.
   - Input is an underlying, `pretransferred == false`: the vault pulls the declared `amountIn` from `msg.sender` with `safeTransferFrom`, then refunds the unkept part of that same token (§9.6).
   - Input is an underlying, `pretransferred == true`: the caller must have code, else `EOAPretransferNotAvailable` is not the name — the existing revert is `EOAPretransferNotAllowed()`. The unbooked balance of the input token must cover the declared maximum, else the shortfall rule applies (§9.4, A1).
   - A share-minting route additionally requires the caller to hold the shares being burned on exit and to have funded the underlying.
7. Dispatch and execution as above.

**`exchangeBundleInForSingleOut`** — checks 1–3, then:

4. `amountsIn.length != vaultTokens().length` → `AmountsLengthMismatch(amountsIn.length, vaultTokens().length)`. `tokenOut` is not the share → `ExchangeBundleInForSingleOutNotAvailable()`. A nonzero `amountsIn[i]` whose token equals `tokenOut` → `InvalidRoute(tokenIn, tokenOut)` from the accepted interface. `minAmountOut` binds on the share output.
5. Disable: a bundle deposit is not a withdrawal → `_requireNotDisabled()`.
6. Funding: the bundle is atomic. Before any leg, every declared `amountsIn[i]` must be covered by the unbooked balance of `vaultTokens()[i]`; otherwise the call reverts before any leg, spends nothing, and mints nothing, with an unnamed revert and no new error and no new selector pinned by the test (§9.4).

**`exchangeBundleOut`** — checks 1–3, then:

4. `tokenIn` is not the share → `ExchangeBundleOutNotAvailable()`. `tokensOut.length != 2` or `minAmountsOut.length != tokensOut.length` → `TokenAmountsLengthMismatch(tokensOut.length, minAmountsOut.length)`. A duplicate output → `DuplicateOutput(token)`. The share appearing in `tokensOut` → `InvalidRoute(tokenIn, tokenOut)` from the accepted interface. `minAmountsOut[i]` binds on output `i`.
5. Disable: a bundle out with the share as `tokenIn` is a withdrawal → the disable check is skipped.
6. Funding: the share input is burned from the caller's balance. There is no share refund.
7. Dispatch: a bundle route reverts `ManagerAlreadyUnlocked()` when the manager is unlocked, before any funding is taken.

**`donate(address token, uint256 amount, bool pretransferred)`**

1. The three-arm maintenance authorization (§14) — `onlyLiveOwnerOrOperator`.
2. `totalSupply() == 0` → revert before any swap. The PRD names no error for this; the plan uses an unnamed revert (`vm.expectRevert()` with no selector) and declares no new error.
3. `token` is neither a `vaultTokens()` entry nor the share → `TokenNotExchangeable(token)` (an already-named accepted error).
4. Disable: not applied. `donate` may run while the vault is disabled.
5. Funding: `pretransferred == false` pulls `amount` from `msg.sender`; `pretransferred == true` uses the unbooked held balance up to `amount`, subject to §9.4.
6. Execution: §10.

**`compound()`**

1. The three-arm maintenance authorization (§14).
2. Disable: not applied.
3. Execution: §10. There is no donation input and no deadline.

**`exchangeOut`** — `exchangeOut` takes a deadline, so check 3 runs first: a missed deadline reverts `DeadlineExceeded`. Then the disable check: a disabled vault reverts `VaultDisabled(address(this))` because an exact-out route is not a withdrawal. On an enabled vault, `exchangeOut` reverts `ExchangeOutNotAvailable()` without taking funds or changing state, and it does not gain a refund return.

**`setOperator(address,bool)` and `setOperatorFor(bytes4,address,bool)`** — the live-owner authorization only (§14). They take no deadline, are not subject to the disable check, and are not payable.

### 9. One-sided deposit, bundle deposit, one-token exit, both-token exit, and pass-through

**Route classification** (the `Planner` performs it; the money target dispatches on it):

| `tokenIn` | `tokenOut` | Route |
| --- | --- | --- |
| underlying in `vaultTokens()` | underlying in `vaultTokens()`, different | pass-through swap (§9.5) |
| underlying in `vaultTokens()` | the share | one-sided deposit (§9.1) |
| the share | underlying in `vaultTokens()` | one-token exit (§9.3) |
| the share | a set of two ERC-20 faces | both-token exit (§9.4, via `exchangeBundleOut`) |

Any other combination is unsupported and reverts the already-named `ExchangeBundleInForSingleOutNotAvailable` or `ExchangeBundleOutNotAvailable` for the bundle functions, and the family `InvalidRoute()` for `exchangeIn`. No success path is added.

**9.1 — One-sided deposit (underlying → share).**

The deposit runs the balancing swap (FS-OWN-33). A bundle deposit does not.

1. The vault holds the declared input of token `X` (pulled or pretransferred, per §8).
2. The planner computes the target: the greatest liquidity `L` that the following add can take, given the pool's current price and the stored ticks. The add consumes `aX` of token `X` and `aY` of the other token `Y`. The swap converts `input − aX` of token `X` into `aY` of token `Y`. Rounding leaves a remainder of token `X`; that remainder is the unkept declared input.
3. Two sequential manager actions, hence two sequential unlocks in the same call, with no external call between them except the settlement of the first action (the brief's adopted reading):
   - action 1: `swap` with the unbounded limit `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1` for the direction taken;
   - action 2: `modifyLiquidity` with `liquidityDelta = L`, `tickLower`/`tickUpper` = the stored full-range ticks, `salt = bytes32(0)`, position owner = the diamond.
4. The add returns `feesAccrued`. The vault books it: `booked[c] += feesAccrued[c]`. Those fees are not in the deposit, not in the caller's share credit, and not swapped.
5. Share minting: `grossShares = addedLiquidity − 1_000` on the first deposit, and `grossShares = addedLiquidity * totalSupply / existingLiquidity` afterwards, where `totalSupply` is read before the mint and the denominator is the existing liquidity before this deposit is added. Idle balances, booked remainders, and `feesAccrued` are not in that denominator. The usage fee is the clamped fee of §9.7: `feeShares = mulDiv(grossShares, clampedFee, 1e18)`; mint `feeShares` to `feeTo` when `feeTo != address(0)` and `feeShares > 0`; mint `grossShares − feeShares` to the depositor when positive; mint nothing beyond `grossShares`; never mint a fee on the fee shares.
6. On the first deposit: reject `addedLiquidity <= 1_000` with `MinLiquidityNotMet()`. The floor `MIN_SHARES = 1_000` is minted to `address(0)` through `ERC20Repo._mint(address(0), 1_000)`, which writes `balanceOf` and `totalSupply` directly (E4) and does not revert `ERC20InvalidReceiver`. The floor is not part of `grossShares` and is not a fee mint. On the first deposit, supply grows by `grossShares` plus the floor; on a later deposit, supply grows by `grossShares` only.
7. The unkept declared input is refunded to the payer under §9.6. It is not booked and it is not minted. There is no `IncompleteConversion` check: a single-token entry does not require the swap to consume the entire input.
8. The share credit goes to `recipient`, who need not be the payer. `recipient` may be a hook's recipient, including a user on unwrap.

**9.2 — Bundle deposit (`exchangeBundleInForSingleOut`).**

1. `amountsIn` is positional in `vaultTokens()` order; its length must equal `vaultTokens().length`.
2. The declared amounts are added in proportion to the underlying pool. The bundle does not run the one-sided balancing swap.
3. One manager action: `modifyLiquidity` with the greatest liquidity the declared amounts can take.
4. The add returns `feesAccrued`; the vault books it.
5. The bundle remainder is refunded per token under §9.6. It is not booked.
6. Share minting is identical to §9.1 steps 5–6, including the fee taken from the new shares and the `MinLiquidityNotMet()` reject on the first deposit.
7. The call emits `PairDeposited(msg.sender)` and the ERC-20 `Transfer` events for the mint. It emits no vault swap or liquidity event.

**9.3 — One-token exit (share → one underlying, canonical `exchangeIn`).**

1. Measure before the burn. `supplyBeforeBurn = totalSupply()` includes the floor.
2. `principalLiquidity = liquidity * sharesBurned / supplyBeforeBurn`, rounded down by that same integer division. Do not divide the share fraction before multiplying by the balance.
3. The caller's fee claim per currency is `floor(feeOwedLive[c] * sharesBurned / supplyBeforeBurn)`, where `feeOwedLive` is the live unpaid fee-owed read that `reserves()` also uses. The caller's booked claim per currency is `floor(booked[c] * sharesBurned / supplyBeforeBurn)`. Tokens booked from an earlier `modifyLiquidity` return are only in the booked term and are not counted again.
4. The total claim per currency is `principal[c] + feeClaim[c] + bookedClaim[c]`.
5. The unwanted currency's whole claim — principal, plus the caller's opposing-token fee, plus the caller's opposing booked claim — is converted into the selected token by one `swap` at the unbounded entry limit. The purpose is pool volume; it is a quantity rule, not a cap.
6. If the swap output is below the caller's `minAmountOut`, the call reverts `AmountOutNotMet(amountOut, actualOut)` and **no shares are burned**. The vault does not pay, book, or keep the residual.
7. The selected currency's claim — its principal, its fee claim, and its booked claim — is paid to the caller in the selected token.
8. The other holders' residual is booked for them: `booked[c]` is reduced by the amounts paid from it and retains the rest. The vault does not swap the other holders' booked fees and does not sell the staying holders' inventory.
9. The shares are burned from the caller's balance. The exit does not call `compound()` and does not deploy the staying holders' booked balance.

**9.4 — Both-token exit (`exchangeBundleOut`, share → the two ERC-20 faces).**

1. The route is the mapped redeem. It pays the caller's claim in both tokens and does not swap. It does not sell one leg to pay the other.
2. The claim is the same apportioning as §9.3: `floor(feeOwedLive[c] * sharesBurned / supplyBeforeBurn)` plus `floor(booked[c] * sharesBurned / supplyBeforeBurn)`, over the principal removed as `liquidity * sharesBurned / supplyBeforeBurn`.
3. `minAmountsOut[i]` binds on output `i`; a shortfall reverts `MinAmountNotMetAt(index, minAmount, actualAmount)`. There is no `MinAmountNotMet`.
4. The rest is booked for the other holders.
5. The call emits `PairRedeemed(msg.sender)` and the ERC-20 `Transfer` event for the burn. `amountRefunded` is zero: the share input is fully consumed by the burn.
6. `exchangeBundleOut` with a single output token is unsupported and reverts `ExchangeBundleOutNotAvailable`. The one-token exit is the canonical `exchangeIn` of §9.3, never a one-output bundle.

**9.5 — Pass-through (underlying → underlying).**

1. The route is an exact-input pool swap on the bound pool: one `swap` at `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`.
2. It mints no shares, so it takes no usage fee, and it is not the FS-OWN-33 liquidity-targeting shape.
3. The unkept declared input is refunded under §9.6.
4. The output goes to `recipient`.
5. On a disabled vault a pass-through reverts `VaultDisabled(address(this))`: a pass-through is not a withdrawal (§15).

**9.6 — The refund rule (FS-OWN-32).**

- Pull path (`pretransferred == false`): pull the declared amount from `msg.sender`, then refund the unkept amount of that same token to `msg.sender`. Pulling only the consumed amount is not the rule. The declared amount equals the amount consumed plus the amount refunded. The output goes to `recipient`. A zero refund transfers nothing. Refunded wei are never credited as a deposit.
- Pretransfer path (`pretransferred == true`), one-token call, declared maximum within the unbooked balance: the refund is the maximum minus the amount used, in the token the caller provided. The vault does not refund the whole remaining unbooked balance; that balance may be staged for another call and the vault has no instruction to process it.
- Pretransfer path, one-token call, declared maximum larger than the unbooked balance (A1): the vault spends nothing of the unbooked balance, refunds the entire unbooked balance in that token, pulls no shortfall, does not revert, and mints or burns nothing. The call returns `(0, unbookedBalance)`.
- Pretransfer path, bundle: atomic. If any declared maximum exceeds that token's unbooked balance, the call reverts before any leg is processed, spends nothing, and mints nothing. The revert is unnamed; no error is declared and the test does not pin a selector.
- A donation or compound remainder is booked, not refunded. A deposit's `feesAccrued` is booked, not refunded.
- These are execution rejects. A view does not revert them; an unsupported view route returns zero.
- `recipient == address(0)` reverts `InvalidRecipient()`; the vault as recipient reverts `InvalidRecipient()`. `tokenIn == tokenOut` reverts `InvalidRoute()`. `amountIn == 0` reverts `EmptyExchange()`. A zero-address token reverts `TokenNotExchangeable(token)`. The functions are not payable.
- The preview of a refund does not transfer and does not read a balance; it assumes the declaration is available. Execution may refund a different amount, and bit-exact equality of the refund word is not required. `minAmountOut` and `minAmountsOut` bind.

**9.7 — The usage fee.**

`fee = min(usageFeeOfVault(address(this)), 3e17)`, read live from the bound oracle and clamped in this vault's read. The oracle is not restricted and is not written by the vault. The same clamped fee is used in the netting formula and in the previews and in `minAmountOut`; the raw oracle fee is never previewed while the clamp is executed. A configured fee of zero stays zero. A configured fee above 30% does not give the depositor zero shares. The precision is the existing `mulDiv` against `1e18`; the fee is not rounded to three digits and no minimum fee is added. A pass-through takes no fee.

### 10. `donate` and `compound`

**10.1 — Common maintenance shape.** Both routes are authorized by the three-arm maintenance check (§14) and neither is subject to the disable check. Both take the collected fees and the booked remainder and process that combined balance. Both use the simplest secure process: no extra attempt, no fallback, no swallowed failure; a failed step reverts. The remainder of the simplest deposit is booked, not returned, and its size does not matter — call `compound()` again to process it. A deposit, a withdrawal, and `exchangeIn` never call either route.

**10.2 — `donate(address token, uint256 amount, bool pretransferred)`.**

1. Authorization; then the zero-supply revert (§8).
2. `token` is the share: the vault burns the donated shares. It does not withdraw, does not swap the shares, and mints no shares for the donation. It emits `Donation()`.
3. `token` is an underlying: the donation is deployed into the pool before `donate` returns; it is not left idle.
   - The vault takes the combined one-token maintenance balance — the collected fees plus the booked remainder of that token plus the directed donation — and swaps it into the position's ratio using the FS-OWN-33 shape and the same unbounded price limit, then adds the liquidity. The swap spends the combined one-token maintenance balance. It does not take an opposing token that is not part of that balance, and it does not swap the deployed position. The remainder is booked, not returned to the donor.
   - If the combined balance already holds both tokens, the call is a proportional deposit and does not swap: the scarcer token — the proportionally smaller amount relative to the position ratio, not the smaller raw balance — is fully used, and the excess of the other token is booked.
4. `pretransferred == true` uses the tokens already transferred, up to the caller's maximum; `pretransferred == false` pulls the directed amount. The pretransfer maximum rule is §9.6.
5. Events: `Donation()` on every successful call, with no arguments and no fields. `Compounded()` is emitted only when the call actually deposited (§10.4).

**10.3 — `compound()`.**

1. Authorization only. No donation input, no deadline, no disable check.
2. `compound()` with no collected fees and no booked remainder returns with no state change and no event.
3. One token held: the vault swaps the combined one-token balance into the ratio (FS-OWN-33 shape, unbounded limit) and deploys it. The remainder is booked and must be in the token being processed.
4. Both tokens held: no swap. The matched pair is deposited; the scarcer token is fully used and the excess of the other token is booked.
5. After the deposit, the vault books the **actual held balance**, not a calculated leftover: `booked[c] = IERC20(c).balanceOf(address(this))` for each currency, read after the deposit settles. That books a stray transfer as well, and it books a non-atomic pretransfer.
6. `compound()` does not swap the deployed position.

**10.4 — Events of the maintenance routes.** `Donation()` is emitted by every successful `donate()` call, with no arguments. `Compounded()` is emitted when a deposit is made from collected fees or from booked tokens, including a `compound()` call that deposits and a `donate()` call that deposits collected fees or booked tokens. `Compounded()` has no arguments; that empty list is final as of 2026-11-04. A call that deposits nothing emits no `Compounded()`. A reverting call emits neither event. The vault does not emit its own swap or liquidity-add event: the PoolManager's `Swap` and `ModifyLiquidity` events carry the vault as `sender`, and the caller correlates them with the Standard Exchange event in the same transaction.

### 11. Locked and borrowed unlock paths

**11.1 — The locked path (FS-UNLOCK-03).**

For each planned manager action that needs an unlock, the vault commits `keccak256(abi.encode(operation, payload))`, calls `unlock` once for that action, accepts the callback only from the bound manager, only while the guard is held, and only once for that payload, settles that action, and verifies the manager has relocked before the next action. Nested unlock and replay stay forbidden. The public-operation guard stays active across the plan, the token calls, and the final payout. The callback does not call `compound()` before a deposit or a withdrawal. `unlockCallback` remains unusable as a deposit, and an external unlock does not satisfy a committed hash.

Because one planned manager action is one `swap` or one `modifyLiquidity`, a one-sided deposit performs two sequential unlocks in the same call, with no external call between them except the settlement of the first action.

**11.2 — The borrowed path (FS-UNLOCK-02), taken by `exchangeIn` only.**

After the ordinary route, deadline, amount, and authority checks, `exchangeIn` reads `TransientStateLibrary.isUnlocked` on the bound manager. Unlocked selects this path. The unlocked flag is not authorization: allowance, minima, deadline, and share authority still apply. The PoolManager is not the depositor, and inclusion of this vault in a batch swap with other Uniswap V4 pools is not a revert.

The borrowed path:

1. Requires that the vault is initialized and idle, that the callback hash is empty, that reservations are zero, and that this diamond's own backing-currency deltas on the bound manager are zero. A reentrant borrowed entry reverts `ReentrantOperation()`. A close that cannot settle this diamond's own deltas reverts `SettlementMismatch()`. The initialized, idle, callback-hash, and reservation checks have no separately named error and revert unnamed; they are not `ReentrantOperation` and not `SettlementMismatch`.
2. Requires that the caller has code, pays the input, and is the share owner burned on exit. `pretransferred` is false on this path. The function is nonpayable, so a value-bearing call fails at the ABI boundary; `InvalidUnlockedContext()` is not used for `msg.value`. `recipient` may be the caller or another address, but not zero and not the vault. A failed funding or route check uses the inherited error; a borrowed-path context miss uses `InvalidUnlockedContext()`.
3. Accepts no payer, callback payload, or foreign creditor. Only the caller's own shares are burned.
4. Dispatches each selected action to the same internal action, account, and settlement code the locked path uses. It does not call `unlock` and does not call `unlockCallback`. It does not copy the locked callback's final `getNonzeroDeltaCount` check, because that count is global and the hook or router may hold open deltas. It does not call `compound()`.
5. `modifyLiquidity` and `swap` run only on this diamond's hookless pool key. The position owner remains this diamond, and the only position written is the full-range salt-zero position. A one-token exit pulls the caller's deployed fraction and swaps only the FS-OWN-30 exiting claim, not principal alone.
6. Settlement of a debt is atomic for that currency: sync, transfer or value, settle, then take credits. The vault never calls `settleFor` for a foreign address. `PoolManager.sync` writes the global transient `CURRENCY_SLOT` and `RESERVES_OF_SLOT` in `CurrencyReserves`, so the vault does not assume an outer actor's sync checkpoint remains valid, and it does not clear another address's sync to hide a clobber. If the sequence cannot close this diamond's own touched deltas without taking a foreign credit, the call reverts `SettlementMismatch()`.
7. Before returning, this diamond's touched currency deltas are zero, asserted per address. The global nonzero-delta count is not required to be zero, and the hook's or the router's deltas are not settled.
8. A failure reverts the vault call and its descendant effects. If the outer caller catches it, the vault state is restored and the caller still owes its own settlement. The catch does not relock the manager. There is no sleeve fallback.

**11.3 — The routes that are not borrowed.** `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked()` when the manager is unlocked. `AlreadyUnlocked` is the PoolManager's own error from `unlock()` while unlocked and is not `ManagerAlreadyUnlocked`.

**11.4 — The library placement inside the fixed link set.** `SwapProjection` (the second library in `UniswapV4FullSpreadStandardExchangeVaultProjection.sol`) holds the FS-OWN-33 unbounded exact-input swap projection over the bound hookless full-range pool key — the canonical swap kernel, `projectSwap`, evaluated against the live pool state. `ExecutionPreparation` (the second library in `UniswapV4FullSpreadStandardExchangeVaultExecution.sol`) holds the FS-UNLOCK-03 per-action preparation: it stages the planned manager action's payload — the swap parameters or the liquidity delta, plus the operation kind — and returns the `Run` that `Execution` executes, before any unlock is opened. `Planner` holds the route classification, the share credit and debit, the minima, and the refund computation. `Projection` holds the pool-state read and the tick walk that `SwapProjection` consumes. `Math` holds the liquidity and amount math and the share ratios. The slots and the link order are unchanged; only the assignment of already-specified operations is fixed here.

### 12. Quotes and previews

**12.1 — One engine, shared by preview and execution.** The single quote engine is `UniswapV4FullSpreadStandardExchangeVaultSwapProjection`: the analytic exact-input swap projection over the bound hookless pool, evaluated against live pool state through `StateLibrary`/`Pool`. Both `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, and `previewExchangeBundleOut`, and the execution path, evaluate this same library. The V4 `Quoter`, the `StateView`, and the Reserves Lens are stored addresses only; the vault never calls them on any path. The quote is the mathematical result of the operation. There is no 64-step cap, no minimum tick spacing, no partial fill, and no failure mode for a quote that cannot finish; `QuoteWorkLimit` is not declared. The liveness consequence is the APEX-2026-041 regression and is a test (§17), not a spacing rule.

**12.2 — The previews.**

| Preview | Returns | Behavior |
| --- | --- | --- |
| `previewExchangeIn(tokenIn, amountIn, tokenOut)` | `(uint256 amountOut, uint256 amountRefunded)` | Selector `0x89d61912`, unchanged. For a one-sided deposit, the quoted shares are the depositor's **net** shares under the clamped fee; existing accrued fees are not credited to the new depositor. For a one-token exit, the quote uses the same apportioning and the same swap as the execution, so the quoted `amountOut` matches execution. For a pass-through, the quoted output is the swap result and the quoted refund is the unkept input. |
| `previewExchangeBundleInForSingleOut(amountsIn, tokenOut)` | `(uint256 amountOut, uint256[] amountsRefunded)` | Selector `0xc2fe8c7c`. `amountsIn` and `amountsRefunded` are in `vaultTokens()` order. `amountOut` is the net share credit. |
| `previewExchangeBundleOut(tokenIn, amountIn, tokensOut)` | `(uint256[] amountsOut, uint256 amountRefunded)` | Selector `0xa5952fc2`. The both-token exit quote uses the same apportioning as the execution and does not swap, so the quoted outputs match that execution. It includes accrued fees. This quote is the share valuation. It is not `getRate()`. |
| `previewExchangeOut(tokenIn, tokenOut, amountOut)` | `(uint256 amountIn)` | Selector unchanged. Returns zero. It does not gain a refund return and it does not revert. A zero preview is not a promise that `exchangeOut` succeeds. |

**12.3 — What the previews never do.** They do not revert by a vault error. An unsupported view route returns zero. `reserveOfToken` returns zero for an address that is not in `vaultTokens()`. `reserves()` and `reserveOfToken` wrap the deployed-reserve reads: the token amounts implied by this position's liquidity at the current pool price with the stored ticks, plus the fees owed to this position and not yet collected. There is no local term, no last-committed snapshot, and no sleeve balance; a booked remainder is not in the read. A busy or unlocked manager is not a view revert. `previewExchangeOut` returns zero. There is no `getRate()`, no `rateAsset()`, no `exchangeRate()`, no `basket()`, no `localReserves()`, and no `wrappedNative()`.

**12.4 — The migration of the 64-byte preview return.** The accepted definition is in `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`. `previewExchangeIn` and `exchangeIn` keep their parameters and their selectors `0x89d61912` and `0xd02d3063` and return `(uint256 amountOut, uint256 amountRefunded)`. `exchangeOut` and `previewExchangeOut` do not gain a refund return. The migration touches three classes of consumer, enumerated in `docs/research/se-fullspread-preview-consumers-20261103/REPORT.md` and indexed completely in `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` (1626 textual occurrences in 618 files; the index is cited here, not pasted):

1. The six production gates that reject a non-32-byte success: `StandardExchangeRateProviderFacet.sol` (empty-supply preview at 103–106 and live preview at 121–125), `WrappedStandardExchangeRateProviderTarget.sol` (65–68), `CommonBufferMultiVaultStablePoolHookTarget.sol` (437–444), `MixedBufferMultiVaultStablePoolHookTarget.sol` (463–470), and `CommonBufferMultiVaultWeightedPoolHookTarget.sol` (474–481). Each must decode the tuple and must not treat the 64-byte success as failure.
2. The three one-word ABI bindings that must be widened to the tuple: `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` (45–48), `frontend/apps/indexedex/app/insights/lib/insightsAbi.ts` (69–76), and `frontend/packages/protocol/src/protocolDetfAbi.ts` (33–40). The Crane interface's stale comment selector `0x05562cc8` is not adopted; `0xd02d3063` is.
3. Every other one-word reader of `previewExchangeIn` in `INDEX.md`, including `contracts/test/bases/FundedThresholdAssertions.sol` (60–63), which decodes one word and does not check the length. A call that ignores the returned word is still bound to the old interface and migrates with the others.

`IStandardExchangeInWithRefund`, `previewExchangeInWithRefund`, `exchangeInWithRefund`, and `ExchangeInWithRefundNotAvailable` are not part of the accepted definition. `ExchangeInNotAvailable` remains the unavailable error on that interface.

### 13. Events and errors

**13.1 — Events.**

| Event | Signature | Emitted by |
| --- | --- | --- |
| `Transfer` | ERC-20, from the Crane `ERC20Repo` | share mint, share burn, and any share transfer |
| `Donation` | `Donation()` — empty | every successful `donate()` call |
| `Compounded` | `Compounded()` — empty | a maintenance call that actually deposits |
| `PairDeposited` | `PairDeposited(address indexed caller)` | `exchangeBundleInForSingleOut` |
| `PairRedeemed` | `PairRedeemed(address indexed caller)` | `exchangeBundleOut` |
| `Swap`, `ModifyLiquidity` | the PoolManager's own events, with the vault as `sender` | the pool, not the vault |

`Donation()` and `Compounded()` are empty marker events. No `Donation` interface is added, no ERC-165 id is invented for either, and no field-bearing variant is added. The paired events carry the indexed caller and no other argument. The vault does not emit a second amount-bearing event of its own.

**13.2 — Family errors**, declared on the family interface, selectors computed at implementation time with `cast sig` and recorded in the NatSpec `@custom:selector` tag:

| Error | Meaning |
| --- | --- |
| `InvalidUnlockedContext()` | a borrowed-path context miss |
| `SettlementMismatch()` | execution cannot close this diamond's own touched deltas |
| `ManagerAlreadyUnlocked()` | the vault guard when a non-`exchangeIn` route finds the manager unlocked |
| `ReentrantOperation()` | the vault guard for a reentrant borrowed entry and the public-operation guard |
| `InvalidRoute()` | the vault guard when `tokenIn == tokenOut` |
| `MinLiquidityNotMet()` | a first deposit that does not exceed 1_000 liquidity |
| `InvalidRecipient()` | a recipient of `address(0)` or this vault |

The family `InvalidRoute()` takes no arguments. The accepted bundle interfaces use the accepted `IStandardExchangeErrors.InvalidRoute(address tokenIn, address tokenOut)` for the "token appears in `tokensOut`" case, as the accepted report specifies. The two are referenced by their qualified names in code (`IVault.InvalidRoute.selector` and `IStandardExchangeErrors.InvalidRoute.selector`) so the collision never becomes an ambiguity.

**13.3 — Accepted interface errors**, used as they are and not redeclared: `EmptyExchange()`, `TokenNotExchangeable(address token)`, `ExchangeInNotAvailable()`, `AmountsLengthMismatch(uint256,uint256)`, `ExchangeBundleInForSingleOutNotAvailable()`, `TokenAmountsLengthMismatch(uint256,uint256)`, `DuplicateOutput(address token)`, `MinAmountNotMetAt(uint256 index, uint256 minAmount, uint256 actualAmount)`, `ExchangeBundleOutNotAvailable()`, `DeadlineExceeded(uint256 deadline, uint256 currentTimestamp)`, `AmountOutNotMet(uint256 amountOut, uint256 actualOut)`, and the existing `EOAPretransferNotAllowed()` for a caller with no bytecode that sets `pretransferred`.

**13.4 — Errors that are not declared.** `InsufficientRateSupply`, `RateNormalizationOverflow`, `RateUnavailable`, `IncompleteConversion`, `QuoteWorkLimit`, `ExchangeInWithRefundNotAvailable`, `UnderlyingUnavailable`, `MinAmountNotMet` (as a family error), `Donation` (as an interface), and any new error for the bundle pretransfer shortfall, the zero-supply `donate`, or the borrowed-path initialized/idle/callback-hash/reservation checks.

### 14. Operators

**14.1 — The owner is a live read.** The maintenance authorization compares `msg.sender` against `address(IVaultFeeOracleQuery(oracle).feeTo())`, read live on every check. The read returns an `IFeeCollectorProxy`; the owner address is that proxy's address. `feeTo()` is not stored at initialization, is not exposed as a getter on this vault, and is not used with a stored-owner modifier. `MultiStepOwnableRepo._onlyOwner` does not gate the appointment calls, and `OperableModifiers.onlyOwnerOrOperator` is not used.

**14.2 — The three-arm maintenance check.** The modifier passes when any one of these holds:

1. `msg.sender == address(IVaultFeeOracleQuery(oracle).feeTo())` — the live owner;
2. `OperableRepo._isOperator(msg.sender)` — a global operator;
3. `OperableRepo._isFunctionOperator(msg.sig, msg.sender)` — a function operator whose grant is for this exact selector.

A global operator may call both maintenance functions. A function operator for another selector reverts. Any other caller reverts. The check is implemented as a new family modifier (§19), not by reusing an existing owner facet.

**14.3 — Appointment.** Only the live owner may call `setOperator(address newOperator, bool approval)` and `setOperatorFor(bytes4 func, address newOperator, bool approval)`. The grants are stored in the Crane `OperableRepo` through `_setOperatorStatus` and `_setFunctionOperatorStatus`, so the Crane events `NewGlobalOperatorStatus(address,bool)` and `NewFunctionOperatorStatus(address,bytes4,bool)` are emitted. `isOperator(address)` and `isOperatorFor(bytes4,address)` are readable from the same repo. The appointment calls are not payable, take no deadline, and are not subject to the disable check. The function-operator arm is keyed by `msg.sig`, so a grant for the `donate` selector does not authorize `compound` and vice versa.

**14.4 — What the operator model does not do.** It does not authorize a deposit, a withdrawal, or an `exchangeIn`. It does not authorize a swap of the deployed position, and it does not introduce a price check, a tick bound, or a fee cap on the maintenance swap. The sandwich exposure of an owner or operator `compound()`/`donate()` is accepted by the owner and is not claimed absent.

### 15. Disable

**15.1 — The predicate.** The vault calls `_requireNotDisabled()`, which reads `IVaultRegistryDisableQuery(oracle).isDisabled(address(this))` through the bound fee oracle — the live V2 call site — and reverts `IVaultRegistryDisableQuery.VaultDisabled(address(this))`. The predicate is widened from `exchangeIn` to every execution route: a route whose input is not this vault's share is blocked.

**15.2 — The blocked and the allowed routes.**

| Route | Disabled vault |
| --- | --- |
| `exchangeIn` with the share as `tokenIn` (a withdrawal) | allowed |
| `exchangeBundleOut` with the share as `tokenIn` and the two ERC-20 faces as `tokensOut` (a withdrawal) | allowed |
| `exchangeIn` underlying → underlying (a pass-through) | reverts `VaultDisabled(address(this))` |
| `exchangeIn` underlying → share (a bundle deposit's single-token sibling, a deposit) | reverts `VaultDisabled(address(this))` |
| `exchangeBundleInForSingleOut` (a bundle deposit) | reverts `VaultDisabled(address(this))` |
| `exchangeOut` | reverts `VaultDisabled(address(this))` |
| `donate` | allowed |
| `compound` | allowed |
| every view, including `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`, `previewExchangeOut`, `reserves`, `reserveOfToken` | allowed; views do not revert `VaultDisabled` |

**15.3 — Ordering.** A missed deadline reverts `DeadlineExceeded(deadline, block.timestamp)` before the disable check, on every route that takes a deadline. A buffered withdrawal still succeeds while the manager is unlocked; a buffered non-withdrawal reverts `VaultDisabled` while the manager is unlocked. The disable check is on the borrowed path too.

**15.4 — The enabled vault.** On an enabled vault, `exchangeOut` still reverts `ExchangeOutNotAvailable()` and moves no tokens.

### 16. Hook integration, matrix rows, and 32-byte preview migration

**16.1 — The families.** The plan binds one row per family in FS-HOOK-01, using the package interface in each family's `interfaces/` directory and a new adapter `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol` that implements `SeMatrixFixture` and deploys this vault through its real package and registry path, exactly as `SeMatrix_FullSpreadV3Fixture.sol` deploys the V3 sibling.

| Family | The row proves |
| --- | --- |
| `single/` | one-vault borrowed `exchangeIn` through the hook's `beforeSwap`, both exact-input directions |
| `constantProduct/single/` | FullSpread as the buffered leg, the raw leg a transfer unless the fixture shows a conversion; the row names which leg converted |
| `dual/` | the canonical cross-vault proof of §16.2 |
| `orbital/` | a valid three-leg bind with FullSpread buffered on one leg and another SE share on another, roles named |
| `weighted/` | a 2-leg setup and one larger supported setup |
| `stable/quad/curve/` | four valid legs; a volatile share is not treated as a peg |
| `stable/quad/balancer/` | a 2-leg setup and a 5-leg setup |

**16.2 — The canonical cross-vault fixture (FS-HOOK-02).** FullSpread is the buffered leg; `standardExchange` is this vault; the hook is configured with an `IStandardExchangeRateProviderDFPkg` instance for this vault and one rate target. The other SE is not asked to mint or redeem inside the outer unlock; if the current package rejects the identity bind without `asset()`, that is recorded as an FS-HOOK-04 reject and the row does not pass. The two backing pool keys differ. One direction mints FullSpread shares while the manager is unlocked; the reverse burns them. The row asserts balances, position owner, ticks, salt, and per-address deltas. The identity-only share trade is a separate case and does not prove underlying entry or exit. Two buffered legs that share one pair token and overwrite `standardExchangeOf[pair]` are not a required fixture; if the package cannot represent that bind, it is recorded. Same-backing-pool sequential composition is unverified and is not reported as passed by the disjoint-pool fixture.

**16.3 — The rate rows.** This vault exposes no `getRate()` and is not bound to the full-book provider. The hook configures an already deployed `IStandardExchangeRateProviderDFPkg` instance for this vault and one rate target; the vault does not know the provider and stores no provider address. The required rows are: one scenario per underlying token, so the integrated token can be `token0` or `token1`, and two separate pools holding the same vault with different `rateTarget` values. The provider reads the tuple of §12.4. A pumped external provider is not a vault rate.

**16.4 — The matrix rows.** The plan adds a row for this vault beside the seven live behavior contracts named in FS-TEST-04, under `test/foundry/spec/hooks/uniswap/v4/standardExchange/`: `single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol`, `constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol`, `dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol`, `orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol`, `weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`, `stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol`, and `stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol`. The plan does not edit their assertions for other families. Exact-output success rows cannot pass here: `exchangeOut` reverts `ExchangeOutNotAvailable()` and `previewExchangeOut` returns zero. A user's unused input is refunded, and a donation or compound remainder is booked, so those rows stay. These are adaptations of this family's rows, not permission to weaken the other families.

**16.5 — The evidence files.** `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json` carries historical V4 FullSpread compatibility rows whose cited tests are not current proof of this family. The plan replaces the stale V4 FullSpread rows rather than treating them as passed, and preserves the V3 rows. The followup-review snapshots are not the current matrix. The evidence files to update, not to treat as passed, are `hook-se-matrix.json`, `hook-se-matrix-findings.json`, `hook-se-matrix-finding-descriptions.json`, `docs/audits/apex-2026-09-17-evidence.md`, and `docs/audits/apex-2026-09-17-evidence/acceptance.json` item R10.3.

**16.6 — The 32-byte preview migration.** The migration is the consumer migration of §12.4, driven by the complete occurrence index `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md`, which is cited here and not pasted. The index is the file list; the report names the decoders that reject a non-32-byte success. The migration is a prerequisite for the hook rows: a hook or rate provider that still reads one word will read the first word of a 64-byte success and must be migrated before this family's rows can pass.

### 17. Test plan

**17.1 — The harness.** `TestBase_UniswapV4FullSpreadStandardExchangeVault.sol` lives under the family's `test/bases/`. It extends `IndexedexTest` and the canonical native-wrapper base, calls the parent setups in the current order, deploys the PoolManager through the existing artifact-backed CREATE3 helper, deploys the facets and the package through the current factory and manager paths, and binds the hook under test and this vault to that same manager. Two managers do not prove FS-UNLOCK-02. Bootstrap shares only through the accepted public entry routes; `depositPair` is not installed. The current non-SUT mintable funding tokens are reused, and nothing is mocked, etched, `vm.mockCall`-ed, or storage-injected into this vault or the PoolManager. Hermetic tests use the default Foundry profile with `viaIR=false` and the current runtime and initcode limits. `recordLogs` is not a receipt. A snapshot restore asserts pre-state and post-state equality before the restore. The Crane tests for the Protocol Aware facet and for `UniswapV4SinglePositionAware` live in the Crane tree (§4).

**17.2 — The spec files** under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/`:

| Short name | File |
| --- | --- |
| PKG | `UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol` |
| MONEY | `UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol` |
| NATIVE | `UniswapV4FullSpreadStandardExchangeVaultNative.t.sol` |
| QUOTES | `UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol` |
| CB | `UniswapV4FullSpreadStandardExchangeVaultCallbacks.t.sol` |
| UNLOCKED | `UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol` |
| HOOK | `UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol` |

**17.3 — The gas measurement.** The meter is the stage-one `S1-GAS-01` meter: the measured call body of each supported public money or maintenance call must not exceed **11,900,000** gas, and **100,000** gas is reserved for intrinsic cost and the fixed money-method calldata, giving the **12,000,000** gas transaction ceiling. The local preview acceptance ceiling is **5,000,000** gas, including the bundle previews and both attempted candidates. A composed hook route is judged on the **whole transaction** under 12,000,000 gas, including both vault operations and the hook's work; where the composed-route sentence and the stage-one sentence differ, the composed-route sentence governs composed routes. A route that does not fit is an unresolved narrowed route, not a passing measurement and not a waiver. No `getRate` read is inside any measurement.

**17.4 — The FS-A rows.** Every row below is asserted; the comparison is over supply, holder balances, both positions, booked and reserved custody, wrapper balances, and per-address deltas, not merely "no tokens moved".

| Row | File | What the test asserts |
| --- | --- | --- |
| FS-A01 | PKG | The cut is exactly the 45 selectors of §7; ERC-165, ERC-8109, loupe, and `PostDeployAccountHookFacet` are absent from the cut and callable on the proxy; `getRate`, `rateAsset`, `basket`, `wrappedNative`, `localReserves`, every SY selector, and the family-only `poolManager()`/`poolKey()` are absent; the Crane getters are callable and resolve to the Crane facet addresses; the factory selectors stay disjoint. |
| FS-A02 | PKG | `bindingHash` changes when any facet, library, or infrastructure binding changes. |
| FS-A03 | PKG | Invalid component, uninitialized pool key, hooked pool key, double initialization, wrong `processArgs` caller, and right registry in the wrong account all revert and leave no usable vault; there is no rate-asset, wrapped-native, or zap-limit argument to reject and no inherited-domain reject. |
| FS-A04 | PKG | The storage slot differs from PairToken's and from Wings'. |
| FS-A05 | MONEY | The first deposit creates one full-range salt-zero position owned by the diamond; `addedLiquidity <= 1_000` reverts `MinLiquidityNotMet()`; the floor is 1,000 of supply minted to `address(0)` through `_mint`; the depositor receives gross minus fee shares; no performance fee is added. |
| FS-A06 | MONEY | The bundle deposit and the bundle redeem follow the mapped routes; the bundle redeem pays both tokens and does not swap. |
| FS-A07 | MONEY | Unused declared entry input is refunded to the payer, not booked and not minted; no `IncompleteConversion` revert; `feesAccrued` on a share-minting deposit is booked and is not share credit. |
| FS-A08 | MONEY | A one-token exit pays only the selected token or reverts `AmountOutNotMet` without burning; it converts the unwanted principal plus the caller's opposing fee and booked claim and does not pay, book, or keep the residual; a both-token exit pays the claim in both tokens and does not swap. |
| FS-A09 | QUOTES | `previewExchangeOut` returns zero and changes no balance; on an enabled vault `exchangeOut` reverts `ExchangeOutNotAvailable` with unchanged balances; neither gains a refund return. |
| FS-A10 | NATIVE | Callers send and receive WETH only; native wrap or unwrap happens only at the pool boundary; the vault does not accept or produce native ETH. |
| FS-A11 | MONEY | A deposit, a withdrawal, and `exchangeIn` do not call `compound()`; a withdrawal pays the FS-OWN-30 claim and books the rest; it does not pay another holder's booked balance; there is no collection-only fallback. |
| FS-A12 | QUOTES | `exchangeRate` is not installed. |
| FS-A13 | QUOTES | `getRate` is not installed. |
| FS-A14 | QUOTES | `InsufficientRateSupply` is not declared. |
| FS-A15 | QUOTES | A planner failure is not observable through `getRate`. |
| FS-A16 | QUOTES | Issuance does not read `exchangeRate`; there is no `getRate` to read. |
| FS-A17 | CB | A multi-action locked deposit and a multi-action locked withdrawal perform one unlock and one consumed callback per planned action; a replay after each callback reverts; the guard stays active between actions; the borrowed equivalent performs zero unlocks. |
| FS-A18 | CB | `unlockCallback` from any caller but the bound manager reverts and moves no tokens. |
| FS-A19 | UNLOCKED | While the manager is unlocked, `exchangeIn` does not call `unlock`; this diamond's touched deltas are zero before return; the global delta count may be nonzero; the position owner, ticks, and salt are unchanged; liquidity may change. |
| FS-A20 | UNLOCKED | A borrowed `exchangeIn` that is not self-funded, or that sets `pretransferred`, reverts `InvalidUnlockedContext` or the inherited funding error; a value-bearing call fails at the nonpayable boundary. |
| FS-A21 | UNLOCKED | An unlocked caller who does not hold the input or the shares does not mint; the unlocked flag is not authority. |
| FS-A22 | UNLOCKED | `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` revert `ManagerAlreadyUnlocked` while the manager is unlocked; `depositPair` and `redeemPair` are absent; there are no SY mutators. |
| FS-A23 | UNLOCKED | A reverting borrowed `exchangeIn` restores shares, liquidity, and token balances. |
| FS-A24 | HOOK | An identity bind of `token == this vault` is attempted; if the current package rejects it without `asset()`, the row records that reject under FS-HOOK-04 and does not pass; `asset()` is not added. |
| FS-A25 | HOOK | Buffered configuration mints and burns through `exchangeIn` while unlocked; the recipient may be the hook or the hook's unwrap recipient; the position owner, ticks, and salt hold; the fee handling follows FS-OWN-24 and FS-OWN-30; no performance fee is added; no `token == rateAsset` is required; the required rate rows use the configured external provider. |
| FS-A26 | HOOK | The FS-HOOK-02 fixture completes exact-input `zeroForOne` and `oneForZero` on two different backing pool keys; exact-out is not part of the row. |
| FS-A27 | HOOK | Each FS-HOOK-01 family has the proof its topology can express, or a cited FS-HOOK-04 record; a cited reject does not replace FS-A26; the FS-OWN-29 rows are not closed by an incompatibility record. |
| FS-A28 | HOOK | A hook path that calls `exchangeOut` on this vault reverts and pays neither token. |
| FS-A29 | HOOK | The required hook rows use a configured external rate-provider instance for this vault and one rate target, including one row per underlying token and two pools holding the same vault at different `rateTarget` values; the provider reads the tuple; the full-book provider is not bound and called this family's rate. |
| FS-A30 | HOOK | A same-backing-pool sequential composition is not reported as passed by FS-A26. |
| FS-A31 | MONEY, HOOK | Every claimed composed fixture, including both vault operations and the hook work, fits 12,000,000 gas; previews fit 5,000,000; an oversized route is unresolved, not passed; no `getRate` read is in the measurement. |
| FS-A32 | QUOTES | No economic view reverts by a vault error, including while the manager is busy or unlocked; `reserves()` wraps the deployed-reserve reads, including unpaid fees, and has no local snapshot. |
| FS-A33 | UNLOCKED | Borrowed execution uses the same settlement as the locked path from the same economic state; it does not call `compound()`; there is no collection-only fallback, no sleeve fallback, and no performance fee. |
| FS-A34 | UNLOCKED | A nonzero own delta at borrowed entry reverts; each action closes only this diamond's deltas; outer debts remain until the outer unlock returns. |
| FS-A35 | NATIVE, UNLOCKED | Native borrowed settlement syncs the native currency immediately before the value settle, does not double-count wrapped and native backing, and does not spend another actor's sync credit; caller-facing amounts stay on the WETH face. |
| FS-A36 | UNLOCKED | A propagated outer failure restores the swap; a caller that catches a rejected vault call keeps only its own prior effects, sees the vault restored, and still settles its own deltas. |
| FS-A37 | UNLOCKED | A funded non-hook contract that meets FS-UNLOCK-02 succeeds; the missing allowlist is the specified permissionless funding rule. |
| FS-A38 | MONEY | A disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate`, and `compound`; a pass-through and a bundle deposit revert; views do not; a missed deadline reverts `DeadlineExceeded` before the disable check; a buffered withdrawal succeeds and a buffered non-withdrawal reverts `VaultDisabled` while the manager is unlocked; the enabled `exchangeOut` revert is also asserted. |
| FS-A39 | MONEY | The live `feeTo()` owner may appoint a global operator through `setOperator` and a function operator through `setOperatorFor`; a global operator may call `donate` and `compound`; a function operator may call only the granted selector; a stranger reverts; appointment is not gated by a stored owner; `feeTo()` is not stored as that owner at initialization; the maintenance modifier is not `OperableModifiers.onlyOwnerOrOperator`. |

**17.5 — The audit inventory (010–054).** The marks are copied from FS-TEST-04. A "no" stays no; an "integration only" stays integration only; no audit ID is added; no "no" row is reopened.

| ID | Mark | File | What the row proves in this plan |
| --- | --- | --- | --- |
| 010 | yes | MONEY | A direct transfer to the vault is not redeemable idle and not caller credit; the shares parked on the vault are not the caller's credit. |
| 011 | yes | UNLOCKED | Borrowed and own-unlock entry and exit do not over-mint; the deletion of the old family is not the evidence. |
| 012 | no | — | Wings liquidation-quote pricing is absent; the borrowed-path parity is the 011 test. |
| 013 | yes | PKG | The generic ERC-4626 `deposit` selector is absent; a pre-existing balance does not mint shares. |
| 014 | integration only | HOOK matrix rows | The rated-versus-face drain is in the hook; the weighted, Curve, Balancer, and orbital rows do not treat this share as an unrated raw leg. |
| 015 | integration only | HOOK matrix rows | Curve quad join and exit accounting is hook code; the matrix row is not counted as a vault fix. |
| 016 | no | — | Weighted partial-book dust seed is hook code; this vault's first deposit is the 034 test. |
| 017 | no | — | Balancer caller-supplied router callback. Not this vault. |
| 018 | no | — | Balancer `computeBalance`. Not this vault. |
| 019 | yes, as a negative | QUOTES | There is no exact-out route: on an enabled vault the test is `ExchangeOutNotAvailable`; a disabled vault is not used as this fixture. |
| 020 | no | — | DETF mint and bond pricing. Not this vault. |
| 021 | no | — | Balancer DETF bond pricing. Not this vault. |
| 022 | yes | UNLOCKED | The same borrowed-path loop as 011, named against both identifiers. |
| 023 | yes | MONEY | Permissionless sleeve placement is absent; the authorized callers are the live `feeTo()` and an operator that owner appointed, global or function-level for that selector; a stranger still reverts; the accepted sandwich is not claimed gone. |
| 024 | yes | MONEY | A one-token exit swaps only the FS-OWN-30 exiting claim and does not sell the staying holders' inventory; the unbounded limit stays; the absence test is the quantity, not a price check. |
| 025 | no | — | Wings rebalance and loss cap are absent. |
| 026 | no separate Wings test | QUOTES | The 512-step liquidation quote is absent; the dust-tick liveness of this vault's own quote is the 041 test; no spacing rule is added. |
| 027 | no | — | Staking withdrawal queues are absent. |
| 028 | yes | HOOK | A dual identity-leg attempt does not burn the caller's position and pay zero. |
| 029 | yes, as a negative | QUOTES, HOOK | No `getRate()` is exposed and the full-book provider is not bound; a pumped external provider is not a vault rate. |
| 030 | integration only | HOOK matrix rows | Balancer quad phantom fee LP is pool code; the quad row is not counted as a vault fix. |
| 031 | no | — | Balancer virtual-TTA join. Not this vault. |
| 032 | yes | PKG | Deployment through the shared factory leaves no unprivileged post-deploy selector; the temporary hook is removed by the factory's own lifecycle. |
| 033 | no | — | DETF primary redemption. Not this vault. |
| 034 | yes | MONEY | Direct transfers and the 1,000-share floor prevent first-deposit inflation. |
| 035 | no | — | Aave cross-version loop. Not this vault. |
| 036 | yes | HOOK | Hook integration does not credit a staged pretransfer to a later caller. |
| 037 | no | — | Re-enabling a named frozen legacy vault. Not this vault. |
| 038 | no | — | sDETF staking weights. Not this vault. |
| 039 | yes | MONEY | A pretransfer uses the unbooked balance up to the caller's maximum; it does not take parked shares or the whole sitting balance; a bundle whose declared maximum exceeds that token's unbooked balance reverts before any leg, spends nothing, and mints nothing; no error is added for that revert and no new selector is pinned. |
| 040 | yes | MONEY | A pool donation followed by `compound` does not round a later deposit to dust shares. |
| 041 | yes | QUOTES | Seed dust ticks and show that a normal deposit and a normal redeem are not frozen by an undocumented step cap; no cap and no minimum spacing are added. |
| 042 | yes | PKG | Deployment succeeds for a token whose `approve` returns no bool; no typed Permit2 approval is required. |
| 043 | integration only | HOOK matrix rows | Orbital radius pinning is hook code; the orbital row is not counted as a vault fix. |
| 044 | yes | MONEY | Fee shares come out of the new shares with no extra mint; the fee is clamped at 30%; a round trip does not move existing holders' value to `feeTo`; `previewExchangeIn` and `minAmountOut` use the net shares. |
| 045 | yes | MONEY | A disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate`, and `compound`; views do not revert; a missed deadline reverts `DeadlineExceeded` before the disable check; a disabled `exchangeOut` reverts `VaultDisabled`, not the 019 fixture. |
| 046 | no | — | Balancer composite-router settlement. Not this vault. |
| 047 | no | — | Stata one-wei donation freeze. Not this vault; the nearest vault case is 040. |
| 048 | yes | MONEY | `compound()` with no fees and no booked remainder returns unchanged and emits nothing; a deposit from collected fees or booked tokens emits `Compounded()` with no arguments; a successful `donate()` emits `Donation()` with no arguments; both empty lists are pinned; a booked remainder does not freeze a later route. |
| 049 | yes, as a negative | QUOTES | Exact-out is absent: on an enabled vault the test is the locked revert, not a Camelot equality check. |
| 050 | no | — | This vault does not read the truncated TWAP oracle and does not add one. |
| 051 | yes | QUOTES | A preview that returns an amount is not rejected by an impact check that does not run; the one quote engine of §12.1 is shared by preview and execution; no step cap is added. |
| 052 | yes | PKG | `permit` works for a standard signer after initialization; the EIP-712 domain name and version initialized are the share name and `"1"`. |
| 053 | no | — | Crane ownership-transfer buffering. This PRD does not change the manager. |
| 054 | yes | HOOK | Each required hook that unwraps this share approves the vault and completes the exit; a missing approval does not freeze the user. |

**17.6 — The secondary-audit regression set.** The plan tests that the vulnerabilities in `docs/security/audit/second_review` are not present in this new vault, and it does so by the rule rows above. A locked sentence that keeps a reported mechanism is not tested as absent: the accepted sandwich of an owner or operator `compound()`/`donate()` stays, the unbounded entry and exit limits stay, and the absence test for 023 is the operator authorization of §14 rather than a price check. The tracker closes APEX-2026-011, 041, 042, and 051 by deleting the old FullSpread code; that deletion is not evidence for this vault, and rows 011, 041, 042, and 051 are re-proved here against the new code.

**17.7 — The test discipline.** No test asserts a product decision the PRD withdrew, and no test pins a prose string, a prompt, or a doc sentence. Tests assert machine-consumed values: selectors, balances, supply, positions, deltas, events, and revert selectors. Where the PRD forbids a new error, the test asserts the revert without a selector and does not pin one. No test waits on a sleep or a poll: async behavior is awaited by subscribing to the exact event or state change and awaiting it with a bounded timeout. Mocks preserve the behavior under test; the vault, the package, the proxy, the registry, and the PoolManager are always the real ones.

### 18. Traceability

Every PRD identifier points to a section of this plan.

| Identifier | Plan section |
| --- | --- |
| FS-OWN-01 | §5 (architecture addresses in `PkgInit`), §4 (the Crane Protocol Aware pair), §7 (the Crane getters) |
| FS-OWN-02 | §4 (the `UniswapV4SinglePositionAware` pair), §7 |
| FS-OWN-03 | §5 (no `rateAsset` field), §7 (`getRate`/`rateAsset` absent), §12.3 |
| FS-OWN-04 | §6 (no sleeve field), §12.3 (`reserves()` has no local term) |
| FS-OWN-05 | §4 (no SY facet files), §7 (no SY selectors), §13.4 |
| FS-OWN-06 | §5 (ticks and salt at initialization), §4 and §7 (the position getters) |
| FS-OWN-07 | §5 (`MultiAssetBasicVaultRepo` faces), §7 (`vaultTokens` from the shared facet; `reserveOfToken`/`reserves` from the family facet), §12.3 |
| FS-OWN-08 | §7 (the accepted selectors and ids), §12.4 (the 64-byte migration) |
| FS-OWN-09 | §9.2 and §9.4 (the mapped bundle routes), §7 (`depositPair`/`redeemPair` absent), §13.1 (the paired events) |
| FS-OWN-10 | §5 (no `wrappedNative`), §7 (no `previewWithdrawalMode`, `previewZapCredit`, `maxZapBps`, `maxZapTickMove`) |
| FS-OWN-11 | §9.1 step 6 (the floor mint through `ERC20Repo._mint`), §6 (no second ledger) |
| FS-OWN-12 | §6 (no sleeve target), §9 and §10 (no sleeve movement) |
| FS-OWN-13 | §11.2 and §11.3 (the borrowed and blocked paths) |
| FS-OWN-14 | §10 (the maintenance routes), §13.1 (the empty events), §14 (the live owner), §15.2 (`donate`/`compound` not disabled) |
| FS-OWN-15 | §9.3 (the one-token exit swaps only the exiting claim) |
| FS-OWN-16 | §5 (the seven stored addresses, one write) |
| FS-OWN-17 | §5 (the `weth` field and `WETHAwareRepo._setWeth`), §7 (no `wrappedNative()`) |
| FS-OWN-18 | §5 (the seven architecture addresses) |
| FS-OWN-19 | §12.3 (no view reverts; unsupported views return zero) |
| FS-OWN-20 | §9.6 and §6 (the unbooked balance definition), §17.4 row 010 |
| FS-OWN-21 | §8 (the `donate` check order), §10.2 |
| FS-OWN-22 | §5 (the pool-key rule; no inherited-domain reject) |
| FS-OWN-23 | §7 (the cut names the installed selectors) |
| FS-OWN-24 | §9.1 and §9.7 (the fee netting and the clamp) |
| FS-OWN-25 | §9.2 (the bundle adds in proportion, books the fees, refunds the remainder, and does not swap) |
| FS-OWN-26 | §15 (the disable predicate) |
| FS-OWN-27 | §5 and §9.1 (raw liquidity as the share unit; `decimals()` is metadata) |
| FS-OWN-28 | §8 (the deadline precedes the disable check on every deadline route) |
| FS-OWN-29 | §16.3 (the configured external rate provider) |
| FS-OWN-30 | §9.3 and §9.4 (the apportioning), §6 (the ledger), §12.2 (the exit quote) |
| FS-OWN-31 | §11.2 (no sleeve fallback, no `UnderlyingUnavailable`) |
| FS-OWN-32 | §9.6 (the refund rule), §9.4 (the atomic bundle revert) |
| FS-OWN-33 | §9.1 and §10 (the balancing swap shape and the unbounded limit), §11.4 (`SwapProjection`) |
| FS-X01 | §11.2 (the unlocked path is `exchangeIn` only), §11.3 |
| FS-X02 | §7 (`getRate` absent), §12.3 |
| FS-X03 | §16.3 and §16.4 (the rate rows and the fixture) |
| FS-X04 | §9.1 step 7 (no `IncompleteConversion`), §9.6 (the refund) |
| FS-ARCH-01 | §4 (the file map) |
| FS-FACET-01 | §7 (the facet fields and their selectors), §5 (the package fields) |
| FS-FACET-02 | §7 (the factory-owned exclusions and the temporary-hook facet named from its factory file) |
| FS-PKG-01 | §5 (`PkgInit` and `PkgArgs`, the field names, the binding order) |
| FS-PKG-02 | §5 (the validation table) |
| FS-MONEY-01 | §9 (the five routes), §9.7 (the fee) |
| FS-UNLOCK-01 | §11.2 (the `isUnlocked` dispatch) |
| FS-UNLOCK-02 | §11.2 (the borrowed path) |
| FS-UNLOCK-03 | §11.1 (the locked path), §11.4 (`ExecutionPreparation`) |
| FS-RATE-01 | §12.3, §16.3 |
| FS-HOOK-01 | §16.1 (the family rows) |
| FS-HOOK-02 | §16.2 (the canonical fixture) |
| FS-HOOK-03 | §8 (the `exchangeOut` check order), §12.2 (`previewExchangeOut` returns zero) |
| FS-HOOK-04 | §16.2 (a cited reject is an unresolved integration record) |
| FS-TEST-01 | §17.1 (the harness) |
| FS-TEST-02 | §17.2 (the spec files) |
| FS-TEST-03 | §17.4 (the FS-A rows) |
| FS-TEST-04 | §17.5 (the 010–054 inventory), §16.4, §16.5 (the matrix and the evidence files) |
| FS-A01 … FS-A39 | §17.4, one row each |

### 19. Implementation names the PRD left open

Each entry below is a name, chosen once so the implementer does not have to choose. None is a new requirement, and none changes a locked behavior.

| # | What the PRD left open | The name this plan picks |
| --- | --- | --- |
| 1 | The six architecture-address `PkgInit` fields | `positionDescriptor`, `positionManager`, `quoter`, `stateView`, `reservesLens`, `universalRouter` |
| 2 | The two Crane facet input fields | `uniswapV4ProtocolAwareFacet`, `uniswapV4SinglePositionAwareFacet` |
| 3 | The modifier file names | `UniswapV4FullSpreadStandardExchangeVaultOwnerModifiers.sol` and `UniswapV4FullSpreadStandardExchangeVaultOperableModifiers.sol`, holding the modifiers `onlyLiveFeeToOwner` and `onlyLiveOwnerOrOperator` |
| 4 | The storage namespace | `"indexedex.vaults.standard.exchange.uniswap.v4.fullSpread"`, slot `keccak256(abi.encode(namespace)) - 1` |
| 5 | Which already-specified operation sits in `SwapProjection` | The FS-OWN-33 unbounded exact-input swap projection over the bound hookless full-range pool key — the canonical swap kernel `projectSwap` |
| 6 | Which already-specified operation sits in `ExecutionPreparation` | The FS-UNLOCK-03 per-action preparation: staging the planned manager action's payload and returning the `Run` that `Execution` executes, before any unlock is opened |
| 7 | The temporary-hook facet filename | `PostDeployAccountHookFacet` (`lib/crane/contracts/factories/diamondPkg/PostDeployAccountHookFacet.sol`), named from its factory files `lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol` and `contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory.sol` |
| 8 | The one quote engine shared by preview and execution | `UniswapV4FullSpreadStandardExchangeVaultSwapProjection`, the analytic exact-input swap projection over live pool state. The V4 `Quoter`, `StateView`, and the Reserves Lens are stored addresses and are never called |
| 9 | Which facet carries `setOperator`/`setOperatorFor` | The family money facet, beside `donate` and `compound`, whose function-operator grant is keyed by those selectors (assumption A5) |
| 10 | The local ledger field names | `booked[2]`, `operationHash`, `operationKind`, `initialized` in `UniswapV4FullSpreadStandardExchangeVaultRepo.sol` |
| 11 | The Crane position pair's directory | `lib/crane/contracts/protocols/dexes/uniswap/v4/position/` |
| 12 | The hook matrix adapter's file name | `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol` |
| 13 | The position repo's salt getter name | `positionSalt()` on the Crane `UniswapV4SinglePositionAware` facet |

---

## Limits

- This response is a plan. It authorizes no implementation, no test run, no build, no install, no deployment, no wallet operation, no Git operation, no PRD edit, and no configuration change. It was written by one member on the initial independent pass; no peer response, no coordinator draft, and no other member's file was read before submission, and no sub-agent was launched.
- Nothing here was executed. Every gas figure is a ceiling to be measured, not a measurement. No selector in this plan was computed by a compiler run; the interface ids in §7 and §12.4 were cross-checked by hand against the accepted report and the PRD and must be rechecked with `type(I).interfaceId` before any ERC-165 registration.
- `docs/research/se-fullspread-preview-consumers-20261103/INDEX.md` was read at its header and its opening rows to confirm its shape and its counts. It was not line-audited, and it is cited rather than reproduced.
- The plan asserts that the seven hook matrix rows exist and that a row is added through `SeMatrixFixture`; it does not claim that any row passes. A family whose topology cannot express the canonical fixture is recorded as a cited FS-HOOK-04 reject, which does not close FS-A26.
- Assumptions A1 through A7 are interpretations of locked sentences, each quoted against its source in the Evidence and Assumptions sections. A1 (the one-token pretransfer shortfall as a no-op success) is the one with the most behavioural weight and should be checked against the F1 lock and FS-OWN-32 by the coordinator before the plan is published.
- The FS-TEST-04 inventory marks are copied, not re-derived. No audit ID is added, and no "no" row is reopened. The plan does not claim that the old FullSpread code's deletion, or the historical evidence snapshots, prove anything about this vault.
- The accepted sandwich of an owner or operator `compound()`/`donate()`, the unbounded entry and exit price limits, and the absence of a sleeve are all accepted exposures. The plan does not claim they are absent, and it adds no disclosure function for them.
