# Kimi K3 — plan draft: legacy V4 implements ERC-5115

- **Label:** Replacement-session plan draft, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No reviewers' notes were read. This is not `REMEDIATION_PRD.plan.md`; nothing was edited.
- **Date:** 2026-10-14.
- **Status:** DRAFT. Writing this plan does not authorize code, test, config, or script edits. A later session must be explicitly asked to implement it.
- **Controlling PRD:** `docs/reviews/legacy-v4-erc5115-interface/REMEDIATION_PRD.md` (read in full; 96 lines). The named interface file `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol` is the interface, not the PRD (also read in full; eight functions, two events). Where this draft conflicts with the PRD, the PRD controls.
- **Remaining choice:** **None.** The PRD closes the selector set, the deposit flag (`:53-61`), the facet ownership, the declaration sites, the edit set, and the size gate. The coordinator's instruction this round additionally fixes: no facet split, other families keep Pendle, edit the existing yield target, no parallel class, and no `LocalCreditLib.requirePretransferCaller` on the deposit path. If an implementer believes a choice remains, stop and report rather than choosing.
- I did not run Forge.

## 0. Spot-checks performed (re-run at implementation time)

- The flattened tree is in place: the legacy V4 family has the `internal/` libraries, the callback facet, and no execution delegates.
- `UniswapV4StandardYieldExecutionTarget.sol:17-34` still holds the two Pendle-signature overrides with the REQ-V4-02 `_requireNotDisabled` at `:23` and `:32`; `:10` inherits the Pendle money/execution target; `:36-42` hold the public `isValidTokenIn/Out` overrides; `:44-75` hold `_redeemVaultHeld`, `_standardRoute`, and `_settleNamedHolder` (internal settlement + TWAP poke).
- `UniswapV4StandardExchangeInFacet.sol:22-26` declares `exchangeIn` + `_appendExecution`; `UniswapV4StandardExchangeOutMultiQueryFacet.sol:5,20,26` declares the Pendle import, ID, and `_appendQuery`; `UniswapV4StandardExchangeOutMultiQueryTarget.sol:14,40-44` holds the Pendle import and `assetInfo`; `UniswapV4StandardExchangeDFPkg.sol:18,162` holds the Pendle import and `interfaces[13]` registration.
- Test call sites (verified by grep this round): `UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol:5,42-45`; `UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol:4,37,43-54`; `UniswapV4StandardExchangeVaultHeldRedeem.t.sol:9,93,107,109,127,142,158,173,285`; `UniswapV4StandardExchange_Architecture.t.sol:8,56-58,78,80,82,88,92`; `UniswapV4StandardExchange_FullRangeBook.t.sol:760,843-847,865,910` and its decimals variant. `contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol` contains no `deposit`/`redeem`/`IStandardizedYield` reference, so the PRD's shared-directory exception (`:66`) goes unused: **no file under `contracts/vaults/standard/sy/` is edited.**

## 1. Ordered steps (compile at each boundary)

| Step | Work | Gate |
| --- | --- | --- |
| 1 | Rewrite `UniswapV4StandardYieldExecutionTarget.sol` in place | Family compiles |
| 2 | Rewrite the two facets' declaration arrays | Family compiles |
| 3 | Rewrite `UniswapV4StandardExchangeOutMultiQueryTarget.sol` | Family compiles |
| 4 | Swap the package interface registration | Package compiles |
| 5 | Retarget the named tests | Tests compile |
| 6 | Refresh artifacts, measure the two named facets, run the suites, report | See §4 |

Steps 1-4 are one logical change; the gates catch which file broke, not authorize a partial landing.

### Step 1 — the money target (PRD `:55-61`)

Edit only `UniswapV4StandardYieldExecutionTarget.sol`. It stops inheriting `NativeStandardYieldExecutionTarget` and implements `IERC5115_StandardizedYield`'s two money functions directly, keeping the existing inheritance of `UniswapV4StandardExchangeInTarget` and its internal-library calls (`Config`, `PoolOps`).

- `deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_, bool depositFromInternalBalance_) public override returns (uint256)` — non-payable. Sequence, preserving the current validation order: `_requireNotDisabled()` first (current `:23`); `receiver_ == address(0)` → `InvalidSYReceiver`; `amount_ == 0` → `ZeroSYAmount`; `!Config._isValidToken(tokenIn_)` → `InvalidSYToken(tokenIn_)`; then the route — `depositFromInternalBalance_` forwards as the SE `pretransferred` argument on the existing exact-in zap-deposit path (`pretransferred == false` is the current measured pull; `true` calls the existing token transfer helper with `pretransferred = true`). Per PRD `:59`, no `LocalCreditLib.requirePretransferCaller` is added on this token path; that gate stays on share delivery and on `redeem` with `burnFromInternalBalance == true` (current `NativeStandardYieldTarget.sol:36-39` behavior, preserved in the local redeem body). A zero-share result reverts `ZeroSYAmount`. Emit `IERC5115_StandardizedYield.Deposit(msg.sender, receiver_, tokenIn_, amount_, shares_)`.
- The Pendle-era `if (msg.value != 0) revert UnsupportedNativePayment()` check is dropped with the payable modifier (PRD `:61`); the shared `NativeStandardYieldErrors.sol` file keeps the declaration for its other consumers and is not edited.
- `redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool internalBalance_) public override returns (uint256)` — body unchanged from the current chain (validation order, `requirePretransferCaller` + `_requireVaultHeldShares` on the true flag, `_redeemVaultHeld`/`_standardRoute` overrides, `SYMinimumNotMet`, `_requireNotDisabled` at the current `:32`, and `IERC5115_StandardizedYield.Redeem` emitted with identical arguments). Only the declared interface changes.
- `_redeemVaultHeld`, `_standardRoute`, and `_settleNamedHolder` (`:44-75`) stay as they are. The public `isValidTokenIn`/`isValidTokenOut` overrides (`:36-42`) are deleted with the Pendle parent; internal callers use `Config._isValidToken` directly.
- No parallel class. No facet split. No new error.

### Step 2 — `UniswapV4StandardExchangeInFacet.sol`

`facetFuncs` becomes exactly three entries, in this order: `IStandardExchangeIn.exchangeIn.selector`, `IERC5115_StandardizedYield.deposit.selector`, `IERC5115_StandardizedYield.redeem.selector`. Remove the `NativeStandardYieldSelectors` import and the `_appendExecution` call. `facetInterfaces` keeps its single `IStandardExchangeIn` entry (the current facet declares no Pendle ID; nothing to swap here).

### Step 3 — `UniswapV4StandardExchangeOutMultiQueryTarget.sol`

Remove the Pendle import (`:14`) and `assetInfo` (`:40-44`). Stop inheriting the Pendle preview/discovery aggregate (the aliased import at `:4-13`). Implement the six ERC-5115 reads directly on the file: `getTokensIn`, `getTokensOut`, `yieldToken`, `exchangeRate` keep their current bodies (`:26-51`); `previewDeposit(address,uint256)` and `previewRedeem(address,uint256)` become thin wrappers over the existing `Accounting._previewExchangeIn` route (`:76-83`), preserving the shared preview's current invalid-token/zero-return behavior (a non-pool token returns 0, not a revert — current `NativeStandardYieldPreviewTarget.sol` semantics). The `isValidTokenIn/Out` public overrides (`:85-101`) are deleted with the interface. `previewExchangeOutOneToMany` (`:53-74`) is untouched.

### Step 4 — facets' query declaration and the package

- `UniswapV4StandardExchangeOutMultiQueryFacet.sol`: `facetFuncs` becomes exactly seven entries — `IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector`, then `IERC5115_StandardizedYield.exchangeRate.selector`, `yieldToken.selector`, `getTokensIn.selector`, `getTokensOut.selector`, `previewDeposit.selector`, `previewRedeem.selector`. No `_appendQuery`. `facetInterfaces` (`:17-21`) replaces the Pendle ID with `type(IERC5115_StandardizedYield).interfaceId` and keeps `IStandardExchangeOutMulti`.
- `UniswapV4StandardExchangeDFPkg.sol`: replace the import at `:18` and `interfaces[13]` at `:162` with the ERC-5115 type and ID. No other registration changes; no cut changes.

### Step 5 — tests (PRD `:68`)

Retarget, without changing assertion semantics:

| File | Change |
| --- | --- |
| `UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol:5,42-45` | Import swap; `controlFuncs` becomes 3 entries matching step 2 |
| `UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol:4,37,43-54` | Import swap; `controlInterfaces[1]` becomes the ERC-5115 ID; `controlFuncs` becomes the 7-entry array from step 4 |
| `UniswapV4StandardExchangeVaultHeldRedeem.t.sol:9,93,107,109,127,142,158,173,285` | Cast type swap to `IERC5115_StandardizedYield`; `redeem`/`previewRedeem` signatures are unchanged, so no call-shape change |
| `UniswapV4StandardExchange_Architecture.t.sol:8,56-58,78,80,82,88,92` | Import swap; the `deposit` loupe assertion at `:56` uses the new selector; deposit calls at `:78` and `:92` gain a trailing `false`; selector-count assertions updated to the new arrays (IN facet 3, OUT multi-query 7) |
| `UniswapV4StandardExchange_FullRangeBook.t.sol:760,843-847,865,910` and the decimals variant | Import/cast swap; `supportsInterface` checks use the ERC-5115 ID; the `assetInfo` assertions at `:846-847` are deleted (the function no longer exists), not re-pointed |

Do not edit any other family's tests. Do not rewrite assertions to dodge a failure; a failing behavioral assertion is reported, not edited green.

## 2. Selector manifest (final state)

Removed from the proxy: `deposit(address,address,uint256,uint256)`, `claimRewards(address)`, `rewardIndexesCurrent()`, `assetInfo()`, `isValidTokenIn(address)`, `isValidTokenOut(address)`, `getRewardTokens()`, `accruedRewards(address)`, `rewardIndexesStored()`. Added: `deposit(address,address,uint256,uint256,bool)`. Kept, re-declared from `IERC5115_StandardizedYield`: `redeem(address,uint256,address,uint256,bool)`, `exchangeRate()`, `getTokensIn()`, `getTokensOut()`, `yieldToken()`, `previewDeposit(address,uint256)`, `previewRedeem(address,uint256)`. Owners do not move (PRD `:23`, `:49`).

## 3. What not to do

- No facet split, no new facet, no parallel execution-target class, no delegate hop, no self-call, no `via_ir`.
- No edit under `contracts/vaults/standard/sy/` (the PRD's exception goes unused — verified in step 0) and no edit to the vendored Pendle interface or to any other family.
- No `LocalCreditLib.requirePretransferCaller` on the deposit path; no new credit ledger; the stored-reserve credit residual stays unrepaired (PRD `:59`).
- No `assetInfo`, rewards surface, or public `isValidToken*` reintroduced to satisfy an old test; those tests are edited instead.
- No change to `exchangeIn`/`exchangeOut` signatures; no ERC-20/permit/SE declaration changes.

## 4. Build, measure, test, report

This is a production edit; refresh before testing:

```sh
python3 scripts/forge-artifacts.py plan \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4
python3 scripts/forge-artifacts.py test \
  <same five sources> \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4 \
  -- -vv
```

Default hermetic profile; `via_ir` stays false; `out/` and `cache_forge/` retained. Measure the deployed runtimes of `UniswapV4StandardExchangeInFacet` and `UniswapV4StandardExchangeOutFacet` after the change (PRD `:72`) and report both numbers. If either exceeds 24,576 bytes, stop and report the measurement; do not restore a hop, do not split a facet, do not enable `via_ir`. The suites named in step 5 run through the existing production TestBase; a present assertion is not a pass until the run is reported with commands and toolchain.

## Done when

- The nine removed selectors have no facet owner on the legacy V4 proxy, and the ERC-5115 deposit plus the seven retained selectors answer on their current facets (loupe check).
- The proxy reports `type(IERC5115_StandardizedYield).interfaceId` and not the Pendle ID, at both declaration sites.
- Both deposit flag modes behave per PRD `:59`; `redeem` behaves exactly as before.
- Both named facet sizes are reported; no oversize was hidden and none was fixed by a forbidden mechanism.
- The named suites' results are reported with the commands run.

I did not run Forge.
