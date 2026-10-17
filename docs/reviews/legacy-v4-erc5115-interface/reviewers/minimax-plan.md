# MiniMax M3 — replacement-session plan draft

- **Label:** replacement session `ses_ebdf718feffemWQNf7wuTpapqX`. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. No prior reviewer notes were read; no code was edited; no Forge was run; no exploit procedures provided.
- **Controlling PRD:** `docs/reviews/legacy-v4-erc5115-interface/REMEDIATION_PRD.md` (status DRAFT, 2026-10-15). This plan draft executes that PRD; it does not re-decide any item the PRD closed.
- **Named interface:** `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol`. Read in full: eight function declarations (deposit, redeem, exchangeRate, getTokensIn, getTokensOut, yieldToken, previewDeposit, previewRedeem) and two events (Deposit, Redeem). No inherited ERC-20 surface, no rewards, no `assetInfo`, no public `isValidToken*`.
- **Plan-draft scope:** the ordered steps a later session would execute. No facet split, no parallel class, no Pendle changes outside the legacy V4 family, no behavior changes beyond the interface swap.

---

## 0. Pre-flight (before any edit)

These checks must pass before the implementer opens any file. None are owner decisions; they are repository rules from `CLAUDE.md` and the artifact workflow.

0.1. **Toolchain.** Confirm `forge --version` reports Foundry **1.5.1**, `solc --version` reports **0.8.35**, `optimizer_runs == 1`, EVM `prague`, `via_ir == false`. Do not relax the `via_ir = false` rule to pass any size gate.

0.2. **Warm artifact cache.** Read `foundry.toml`. Confirm `cache_path = 'cache_forge'` and `out = 'out'`. If a prior green run exists in another worktree or the warm primary repo, copy both directories into the working tree per `CLAUDE.md` §9 (worktree compile seed). Do not delete `out/` or `cache_forge/` mid-program.

0.3. **Cold compile budget.** First `forge build` in a fresh worktree is expected to take 20–40+ minutes. Use a multi-hour timeout. Do not abort.

0.4. **No pending source changes outside this plan.** `git status` must show only the files this plan lists (plus generated artifacts). If unrelated modifications exist, stop and report.

0.5. **Read the IFacet test expectations.** Open `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol` and `UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol`. These tests define the structural control values that the implementer's facets must match. Plan §3 updates the tests in lockstep.

0.6. **Tag the baseline.** `git rev-parse HEAD` and record as `REQ-ERC5115 baseline`. Used to confirm only the listed files changed.

---

## 1. Source-edit phase

Six files change. Edit in the order listed; each step depends only on prior steps.

### Step 1 — `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol`

The smallest, lowest-risk change. Touch only this file's body and imports; do not touch its function signatures.

**Imports (lines 1–25):**

- Remove line 14: `import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";`
- Do not add any other import. `FixedPointMathLib` (line 15), `Math` (line 16), `Config` (line 19–20), `Accounting` (line 22–23), `NativeStandardYieldPreviewTarget as NativeStandardYieldTarget` (line 12), `ERC20Repo` (line 10), `IERC20` (line 9), `NativeStandardYieldDiscoveryTarget`/`NativeStandardYieldValidation` (line 5–7) all stay.
- The file currently declares `contract UniswapV4StandardExchangeOutMultiQueryTarget is NativeStandardYieldTarget` (line 25). The parent `NativeStandardYieldPreviewTarget` brings in `previewDeposit`/`previewRedeem`. The legacy V4 keeps using the inherited `previewDeposit`/`previewRedeem` overrides from this file's `_previewExchangeIn` path; do not re-declare them. Keep the inheritance.

**Body (lines 26–101):**

- Keep `getTokensIn()` (lines 26–30) unchanged. Two-entry array `[Config._token0(), Config._token1()]`.
- Keep `getTokensOut()` (lines 32–34) unchanged. Returns `getTokensIn()`.
- Keep `yieldToken()` (lines 36–38) unchanged. Returns `address(0)`.
- **Remove `assetInfo()` and the `IStandardizedYield.AssetType` reference entirely** (lines 40–44). No replacement. The PoolManager-as-asset fact is no longer surfaced via the SY interface.
- Keep `exchangeRate()` (lines 46–51) unchanged.
- Keep `previewExchangeOutOneToMany` (lines 53–74) unchanged.
- Keep `_previewExchangeIn` (lines 76–83) unchanged.
- Keep `isValidTokenIn`/`isValidTokenOut` (lines 85–101) as **internal** overrides. They satisfy `NativeStandardYieldValidation`'s virtuals but are not installed on the proxy as public `isValidToken*` selectors because the shared `NativeStandardYieldSelectors._appendDiscovery` is not used by the legacy V4 query facet. Confirm after Step 2 that the `_appendQuery` replacement does not emit `isValidToken*(address)`.

**Verification after Step 1:**

```bash
forge build --skip "test/**" --skip "scripts/**"
```

The build must succeed. If it fails on the removed `IStandardizedYield.AssetType` reference, stop — the implementer forgot to delete the body. If it fails on a missing import, stop.

### Step 2 — `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol`

Touch the facet's IFacet metadata only; do not touch the target.

**Imports:**

- Line 4 — remove `import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";`
- Line 5 — replace `import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";` with `import {IERC5115_StandardizedYield} from "@crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol";`
- Lines 6–10 stay.

**`facetInterfaces()` (lines 17–21):**

- `interfaces[1] = type(IStandardizedYield).interfaceId;` becomes `interfaces[1] = type(IERC5115_StandardizedYield).interfaceId;`
- The array length stays at 2. Do not drop the second slot.

**`facetFuncs()` (lines 23–27):**

- Replace the `_appendQuery` call with an explicit literal that produces the same final list. The PRD requires exactly these selectors, in this order:

```solidity
funcs = new bytes4[](7);
funcs[0] = IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector;
funcs[1] = IERC5115_StandardizedYield.exchangeRate.selector;
funcs[2] = IERC5115_StandardizedYield.yieldToken.selector;
funcs[3] = IERC5115_StandardizedYield.getTokensIn.selector;
funcs[4] = IERC5115_StandardizedYield.getTokensOut.selector;
funcs[5] = IERC5115_StandardizedYield.previewDeposit.selector;
funcs[6] = IERC5115_StandardizedYield.previewRedeem.selector;
```

This drops the six Pendle-only selectors (assetInfo, isValidTokenIn, isValidTokenOut, getRewardTokens, accruedRewards, rewardIndexesStored) and keeps the six ERC-5115 view selectors plus the multi-out preview.

**Verification after Step 2:**

```bash
forge build --skip "test/**" --skip "scripts/**"
```

### Step 3 — `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol`

The load-bearing edit. The PRD requires this file to stop inheriting `NativeStandardYieldExecutionTarget` and to implement the ERC-5115 money functions directly against `IERC5115_StandardizedYield`. **Do not create a parallel class.**

**Imports (lines 1–11):**

- Lines 3–5 (PoolOps, Config aliases): keep.
- Line 6 (`import {IERC20}`): keep.
- Line 10 (`import {NativeStandardYieldExecutionTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";`) — **remove.**
- Line 11 (`import {UniswapV4StandardExchangeInTarget} from "./UniswapV4StandardExchangeInTarget.sol";`) — keep.
- **Add** `import {IERC5115_StandardizedYield} from "@crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol";`
- **Add** `import {NativeStandardYieldErrors} from "contracts/vaults/standard/sy/NativeStandardYieldErrors.sol";` (the error declarations `InvalidSYToken`, `InvalidSYReceiver`, `ZeroSYAmount`, `SYMinimumNotMet` stay in the shared `NativeStandardYieldErrors`; the V4 target uses them.)
- **Add** `import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";` (for the `_vaultHeldShares` body).
- The `ReentrancyLockModifiers` import is on `UniswapV4StandardExchangeInTarget` (line 7 of the parent), not on this file. Do not duplicate.

**Inheritance (lines 13–16):**

```solidity
abstract contract UniswapV4StandardYieldExecutionTarget is
    UniswapV4StandardExchangeInTarget,
    IERC5115_StandardizedYield,
    NativeStandardYieldErrors
{
```

- Stops inheriting `NativeStandardYieldExecutionTarget`. The abstract class still extends `UniswapV4StandardExchangeInTarget` (for `_exchangeIn`) and now declares direct conformance to `IERC5115_StandardizedYield`.
- Inherits `NativeStandardYieldErrors` directly so the four SY error selectors remain available on this file's body and on the proxy's reverts.
- Do not re-declare error wrappers; `NativeStandardYieldErrors` already declares them.

**`deposit` body (replaces lines 17–25):**

The new function:

- Signature: `function deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_, bool depositFromInternalBalance_) public override(IERC5115_StandardizedYield) returns (uint256 shares_)` — non-payable, **explicit `override`** against the ERC-5115 interface only.
- Body order:
  1. `Config._requireNotDisabled();` (REQ-V4-02 gate; runs first).
  2. `if (receiver_ == address(0)) revert NativeStandardYieldErrors.InvalidSYReceiver();`
  3. `if (amount_ == 0) revert NativeStandardYieldErrors.ZeroSYAmount();`
  4. `if (!Config._isValidToken(tokenIn_)) revert NativeStandardYieldErrors.InvalidSYToken(tokenIn_);` — uses the internal `Config._isValidToken(token_) internal view returns (bool)` predicate at `contracts/protocols/dexes/uniswap/v4/internal/UniswapV4StandardExchangeConfig.sol:119-121`. Do not reintroduce public `isValidTokenIn`.
  5. Route through `_exchangeIn(IERC20(tokenIn_), amount_, IERC20(address(this)), minimum_, receiver_, depositFromInternalBalance_, block.timestamp)` from the inherited `UniswapV4StandardExchangeInTarget._exchangeIn`. The fifth-argument `depositFromInternalBalance_` is forwarded as the **SE pretransfer flag** `pretransferred`. The deadline is `block.timestamp` (no separate deadline parameter on the ERC-5115 deposit).
  6. `if (shares_ == 0) revert NativeStandardYieldErrors.ZeroSYAmount();`
  7. Emit `IERC5115_StandardizedYield.Deposit(msg.sender, receiver_, tokenIn_, amount_, shares_);`.
- Do NOT add `LocalCreditLib.requirePretransferCaller(msg.sender)` on the `depositFromInternalBalance_ == true` path. The existing `_exchangeIn` → `_secureTokenTransfer` pretransfer branch accepts EOAs; the PRD closes that gate.
- Do NOT keep the `if (msg.value != 0) revert NativeStandardYieldErrors.UnsupportedNativePayment();` check. The function is non-payable; `msg.value` is always 0 on a legitimate call, and the ABI rejects value before the body runs. The `UnsupportedNativePayment` error selector remains defined in the shared `NativeStandardYieldErrors` and may be reached by other code paths; do not delete it.
- Do NOT introduce a synthetic-transfer-then-pull sequence. The boolean is forwarded to `_exchangeIn` as-is.

**`redeem` body (replaces lines 27–34):**

The existing redeem function signature already matches `IERC5115_StandardizedYield.redeem(address,uint256,address,uint256,bool)`. The PRD requires keeping the body unchanged.

- Signature: `function redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool burnFromInternalBalance_) public override(IERC5115_StandardizedYield) returns (uint256)` — note the parameter name is now `burnFromInternalBalance_` (matches ERC-5115) instead of `internalBalance_`.
- Body order:
  1. `Config._requireNotDisabled();`
  2. `if (receiver_ == address(0)) revert NativeStandardYieldErrors.InvalidSYReceiver();`
  3. `if (shares_ == 0) revert NativeStandardYieldErrors.ZeroSYAmount();`
  4. `if (!isValidTokenOut(tokenOut_)) revert NativeStandardYieldErrors.InvalidSYToken(tokenOut_);` — the existing override `isValidTokenOut(token_)` (kept as a private/internal helper) calls `Config._isValidToken(token_)`. Preserve this call chain.
  5. `if (burnFromInternalBalance_) { LocalCreditLib.requirePretransferCaller(msg.sender); _requireVaultHeldShares(shares_); amount_ = _redeemVaultHeld(receiver_, shares_, tokenOut_, minimum_); } else { amount_ = _standardRoute(IERC20(address(this)), shares_, IERC20(tokenOut_), minimum_, receiver_, false); }` — preserve the existing EOA gate on the `burnFromInternalBalance_ == true` path. This gate stays.
  6. `if (amount_ < minimum_) revert NativeStandardYieldErrors.SYMinimumNotMet(minimum_, amount_);`
  7. Emit `IERC5115_StandardizedYield.Redeem(msg.sender, receiver_, tokenOut_, shares_, amount_);`.
- The `_standardRoute` and `_redeemVaultHeld` overrides (lines 52–64) stay as-is, including the `address(in_) == address(this) && !internal_` short-circuit.
- The `_settleNamedHolder` body (lines 66–75) stays.

**`_vaultHeldShares` helper:**

The current code does not declare this helper explicitly; it is inherited from `NativeStandardYieldMoneyTarget._vaultHeldShares()` at `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:65-67` which calls `ERC20Repo._balanceOf(address(this))`. After removing the inheritance, the implementer must add a private function on `UniswapV4StandardYieldExecutionTarget`:

```solidity
function _vaultHeldShares() private view returns (uint256) {
    return ERC20Repo._balanceOf(address(this));
}
```

The existing `_requireVaultHeldShares(shares_)` call in the redeem body must call this private helper. The check semantically equals the inherited helper: reverts `ISecurePullErrors.TransferDeltaInsufficient(shares_, held)` when `held < shares_`.

**`isValidTokenIn`/`isValidTokenOut` overrides (lines 36–42):**

- Remove the `isValidTokenIn`/`isValidTokenOut` overrides entirely from this file. The deposit and redeem bodies call `Config._isValidToken(token_)` directly (line 119–121 of `UniswapV4StandardExchangeConfig.sol`).
- The public `isValidTokenIn(address)` and `isValidTokenOut(address)` selectors MUST NOT be installed on the proxy. Confirm in Step 6.

**Other body content:**

- Lines 44–75 (`_redeemVaultHeld`, `_standardRoute`, `_settleNamedHolder`): stay as-is. These are the V4-specific overrides for dual-exit settlement.

**Verification after Step 3:**

```bash
forge build --skip "test/**" --skip "scripts/**"
```

The build must compile. The implementation surface for `UniswapV4StandardYieldExecutionTarget` no longer carries the four inherited money/reward selectors.

### Step 4 — `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol`

The IFacet metadata only.

**Imports:**

- Line 4 — remove `import {NativeStandardYieldSelectors} from "contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol";`
- Line 6 (`import {IFacet}`): keep.
- Line 7 (`import {IStandardExchangeIn}`): keep.
- Lines 8–10 (UniswapV4StandardExchangeInTarget): keep.
- **Add** `import {IERC5115_StandardizedYield} from "@crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol";`

**`facetInterfaces()` (lines 17–20):**

- Stays as a single-entry array `[type(IStandardExchangeIn).interfaceId]`. Do not add a second slot for ERC-5115 here — the PRD says "Do not add or drop a declaration site." The IN facet's local declaration mirrors the existing convention; ERC-5115 is declared at the package level via `UniswapV4StandardExchangeDFPkg.facetInterfaces()` (Step 5) and on the query facet (Step 2). The proxy answers the ERC-5115 interface via the composite facet set even though no single facet owns it locally.

**`facetFuncs()` (lines 22–26):**

- Replace the `_appendExecution` call with an explicit literal:

```solidity
funcs = new bytes4[](3);
funcs[0] = IStandardExchangeIn.exchangeIn.selector;
funcs[1] = IERC5115_StandardizedYield.deposit.selector;
funcs[2] = IERC5115_StandardizedYield.redeem.selector;
```

This drops `rewardIndexesCurrent` and `claimRewards` (the four-arg `deposit` is gone — its selector does not match the new 5-arg `deposit`'s selector, and the old one is no longer installed).

**Verification after Step 4:**

```bash
forge build --skip "test/**" --skip "scripts/**"
```

### Step 5 — `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol`

The package interface registration only.

**Imports:**

- Line 18 (`import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";`) — replace with `import {IERC5115_StandardizedYield} from "@crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol";`.

**`facetInterfaces()` (lines 147–164):**

- `interfaces[13] = type(IStandardizedYield).interfaceId;` becomes `interfaces[13] = type(IERC5115_StandardizedYield).interfaceId;`
- The array length stays at **15**. Do not drop the slot, do not add another.
- The other 14 entries (lines 149–161, 163) stay byte-identical.

**`facetCuts()` (lines 170–252):** unchanged. The 16 facet cuts are unchanged because no facet is added or removed.

**`facetAddresses()` (lines 309–327):** unchanged. The 16 facet addresses are unchanged.

**`vaultFeeTypeIds()`, `vaultTypes()`, `initAccount()`, `deployVault()`:** unchanged.

**Verification after Step 5:**

```bash
forge build --skip "test/**" --skip "scripts/**"
```

The compile output's `UniswapV4StandardExchangeDFPkg.facetInterfaces()` byte length must remain 15 × 32 + 32 = 512 bytes (15 entries × 32-byte interface id plus 32-byte length prefix). If it differs, stop.

### Step 6 — Verify the selector/cut/interface manifest

After Steps 1–5, the legacy V4 proxy must satisfy:

| Selector | Owner | Notes |
|---|---|---|
| `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `UniswapV4StandardExchangeInFacet` | Unchanged |
| `deposit(address,address,uint256,uint256,bool)` | `UniswapV4StandardExchangeInFacet` | New |
| `redeem(address,uint256,address,uint256,bool)` | `UniswapV4StandardExchangeInFacet` | Selector unchanged |
| `quoteAssets`, `quoteShareBalance`, `quoteTransition`, `quoteExternalExchange`, `quoteTotalSupply`, `quoteExternalDeposit` | `UniswapV4StandardExchangeInQueryFacet` | Unchanged |
| `importPosition(IPositionManager,uint256,uint256,address,address,uint256)` | `UniswapV4StandardExchangePositionImportFacet` | Unchanged |
| `exchangeOut(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | `UniswapV4StandardExchangeOutFacet` | Unchanged |
| `previewExchangeOut(IERC20,IERC20,uint256)`, `quoteState(address,address)` | `UniswapV4StandardExchangeOutQueryFacet` | Unchanged |
| `canOpenPoolManagerUnlock`, `localReserve`, `deployedReserve`, `targetLiquidReservePercentage`, `actualLiquidReservePercentage`, `rebalanceLiquidReserve`, `twapOracle` | `UniswapV4StandardExchangeLiquidReserveFacet` | Unchanged |
| `exchangeInManyToOne(address[],uint256[],IERC20,uint256,address,bool,uint256)` | `UniswapV4StandardExchangeInMultiFacet` | Unchanged |
| `previewExchangeInManyToOne`, `previewExchangeIn(IERC20,uint256,IERC20)` | `UniswapV4StandardExchangeInMultiQueryFacet` | Unchanged |
| `exchangeOutOneToMany(IERC20,uint256,address[],uint256[],address,bool,uint256)` | `UniswapV4StandardExchangeOutMultiFacet` | Unchanged |
| `previewExchangeOutOneToMany(IERC20,address[],uint256[])`, `exchangeRate()`, `yieldToken()`, `getTokensIn()`, `getTokensOut()`, `previewDeposit(address,uint256)`, `previewRedeem(address,uint256)` | `UniswapV4StandardExchangeOutMultiQueryFacet` | 7 selectors |
| `unlockCallback(bytes)` | `UniswapV4StandardExchangeCallbackFacet` | Unchanged |
| ERC-20 / ERC-20 metadata / ERC-20 permit / ERC-5267 | `erc20Facet`/`erc5267Facet`/`erc2612Facet` | Unchanged |

**Removed selectors (must NOT resolve on the proxy after deployment):** `deposit(address,address,uint256,uint256)` payable, `claimRewards(address)`, `rewardIndexesCurrent()`, `assetInfo()`, `isValidTokenIn(address)`, `isValidTokenOut(address)`, `getRewardTokens()`, `accruedRewards(address)`, `rewardIndexesStored()`.

The proxy's declared interfaces (per `UniswapV4StandardExchangeDFPkg.facetInterfaces()`):

```solidity
interfaces[0]  = type(IERC20).interfaceId;
interfaces[1]  = type(IERC20Metadata).interfaceId;
interfaces[2]  = type(IERC20).interfaceId ^ type(IERC20Metadata).interfaceId;
interfaces[3]  = type(IERC5267).interfaceId;
interfaces[4]  = type(IERC20Permit).interfaceId;
interfaces[5]  = type(IStandardVault).interfaceId;
interfaces[6]  = type(IStandardExchangeIn).interfaceId;
interfaces[7]  = type(IStandardExchangeOut).interfaceId;
interfaces[8]  = type(IUniswapV4StandardExchangePositionImport).interfaceId;
interfaces[9]  = type(IUniswapV4StandardExchangeLiquidReserve).interfaceId;
interfaces[10] = type(IStandardExchangeInMulti).interfaceId;
interfaces[11] = type(IStandardExchangeOutMulti).interfaceId;
interfaces[12] = type(IStandardExchangeTransitionQuote).interfaceId;
interfaces[13] = type(IERC5115_StandardizedYield).interfaceId;
interfaces[14] = type(IStandardExchangeExternalQuote).interfaceId;
```

ERC-165 must answer `true` for `type(IERC5115_StandardizedYield).interfaceId` and `false` for `type(IStandardizedYield).interfaceId` on a fresh registry-deployed proxy.

---

## 2. Refresh artifacts before tests

Per `CLAUDE.md` §10:

```bash
python3 scripts/forge-artifacts.py test \
    contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol \
    contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol \
    contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol \
    contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol \
    contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol \
    --test-root test/foundry/spec/protocol/dexes/uniswap/v4/
```

Repeat the `--test-root` flag for each affected test directory below. Do not change `FOUNDRY_TEST` or `FOUNDRY_PROFILE` mid-program. Use `via_ir = false` (default).

After artifacts are fresh:

```bash
forge build --skip "test/**" --skip "scripts/**"
```

---

## 3. Test-edit phase

The PRD requires retargeting legacy V4 tests that call `IStandardizedYield` on this vault to `IERC5115_StandardizedYield` and adding the new bool argument to deposit calls. Six test files change. Edit in the order listed.

### Step 7 — `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol`

- Line 5 — replace `import {IStandardizedYield}` with `import {IERC5115_StandardizedYield}` from the ERC-5115 path.
- `controlFacetFuncs()` (lines 39–46): array length 5 → 3. Drop `IStandardizedYield.rewardIndexesCurrent.selector` and `IStandardizedYield.claimRewards.selector`. Replace `IStandardizedYield.deposit.selector` (4-arg) with `IERC5115_StandardizedYield.deposit.selector` (5-arg).

The final array:

```solidity
controlFuncs[0] = IStandardExchangeIn.exchangeIn.selector;
controlFuncs[1] = IERC5115_StandardizedYield.deposit.selector;
controlFuncs[2] = IERC5115_StandardizedYield.redeem.selector;
```

### Step 7.5 — `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol`

- Line 4 — swap the import.
- `controlFacetInterfaces()` (lines 34–38): keep the 2-entry array. Replace `controlInterfaces[1] = type(IStandardizedYield).interfaceId;` with `controlInterfaces[1] = type(IERC5115_StandardizedYield).interfaceId;`.
- `controlFacetFuncs()` (lines 40–55): array length 13 → 7. Replace with:

```solidity
controlFuncs[0]  = IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector;
controlFuncs[1]  = IERC5115_StandardizedYield.exchangeRate.selector;
controlFuncs[2]  = IERC5115_StandardizedYield.yieldToken.selector;
controlFuncs[3]  = IERC5115_StandardizedYield.getTokensIn.selector;
controlFuncs[4]  = IERC5115_StandardizedYield.getTokensOut.selector;
controlFuncs[5]  = IERC5115_StandardizedYield.previewDeposit.selector;
controlFuncs[6]  = IERC5115_StandardizedYield.previewRedeem.selector;
```

### Step 7.6 — `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Architecture.t.sol`

- Line 8 — swap the import.
- `test_packageCuts_keepOwnersAndInstallSingleCallback` (lines 19–59):
  - Line 52–53 (`cuts[5].functionSelectors.length, 1` and `cuts[5].functionSelectors[0], IUnlockCallback.unlockCallback.selector`): unchanged.
  - Line 54: `assertEq(cuts[6].functionSelectors.length, 5);` → `assertEq(cuts[6].functionSelectors.length, 3);`
  - Line 55: `assertEq(cuts[15].functionSelectors.length, 13);` → `assertEq(cuts[15].functionSelectors.length, 7);`
  - Line 56: `assertEq(IDiamondLoupe(address(vault)).facetAddress(IStandardizedYield.deposit.selector), expected[6]);` → `assertEq(IDiamondLoupe(address(vault)).facetAddress(IERC5115_StandardizedYield.deposit.selector), expected[6]);`
  - Line 57: keep the `redeem` assertion, swap the interface reference to `IERC5115_StandardizedYield.redeem.selector`.
  - Line 58: keep the `previewRedeem` assertion, swap to `IERC5115_StandardizedYield.previewRedeem.selector`.
- `test_disabledSY_rejectsDepositAndBothHoldersBeforeMovement` (lines 66–89):
  - Line 78: `IStandardizedYield(address(vault)).deposit(recipient, address(token0), 1 ether, 0);` → `IERC5115_StandardizedYield(address(vault)).deposit(recipient, address(token0), 1 ether, 0, false);`
  - Lines 80, 82: keep the redeem calls; cast as `IERC5115_StandardizedYield`.
  - Line 88: `IStandardizedYield(address(vault)).previewRedeem(address(token0), shares)` → `IERC5115_StandardizedYield(address(vault)).previewRedeem(address(token0), shares)`.
- `test_deposit_hasNoSelfCall` (lines 91–94):
  - Line 92: `uint256 shares = IStandardizedYield(address(vault)).deposit(recipient, address(token0), 1 ether, 1);` → `uint256 shares = IERC5115_StandardizedYield(address(vault)).deposit(recipient, address(token0), 1 ether, 1, false);`
  - The no-self-call modifier (`noSelfCalls(address(vault))`) remains valid because the V4 deposit routes through `_exchangeIn` which routes through the SE in target's `_secureTokenTransfer` and `_executeZapInDeposit` — no `address(this)` self-call to a `deposit` selector.

### Step 7.7 — `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`

- Line 9 — swap the import.
- All `IStandardizedYield(address(vault)).redeem(...)` and `...previewRedeem(...)` calls (lines 93, 107, 109, 127, 142, 158, 173, 285): re-cast as `IERC5115_StandardizedYield(address(vault))`. Selector is unchanged; only the interface reference changes.
- The RC-01 EOA-rejection test (lines 86–97) must still revert `ISecurePullErrors.EOAPretransferNotAllowed` on `redeem(..., true)` because the existing gate stays. No body change in the V4 target for that gate.

### Step 7.8 — `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol`

- Line 1042 (or wherever the import lives in the actual file) — swap to `IERC5115_StandardizedYield`.
- Lines 760–763: `IStandardizedYield sy = IStandardizedYield(address(bound));` → `IERC5115_StandardizedYield sy = IERC5115_StandardizedYield(address(bound));`. The `exchangeRate`/`previewRedeem`/`redeem` calls are unchanged selectors.
- Lines 841–848 (`test_nativeSYMetadataRateAndFacetSize`):
  - Line 844: `supportsInterface(IStandardizedYield)` → `supportsInterface(IERC5115_StandardizedYield)`.
  - Lines 846–848: delete the `assetInfo()` test entirely. The function no longer exists on the proxy.
- Any `IStandardizedYield.AssetType` reference (lines 847, 848): delete with the test.
- Any `deposit(...)` call in the file: append the trailing `false` (or `true` for pretransfer scenarios, with the contract-caller harness that already exists in the test base).

### Step 7.9 — `test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol`

- Line 9 — swap the import.
- Line 234: re-cast as `IERC5115_StandardizedYield`. The redeem-side selectors are unchanged; only the interface reference changes.

### Step 7.10 — Out-of-scope test files: do not edit

The PRD explicitly says "Do not rewrite another family's tests." Files in `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/`, `test/foundry/spec/vaults/standard/sy/` (the SY-surface tests for non-V4 families), `test/foundry/spec/protocols/staking/`, `test/foundry/spec/protocols/lending/`, `test/foundry/spec/vaults/standard/erc4626/`, `test/foundry/spec/hooks/`, and the hookless/Pons/Wings V4 suites are not in scope. They import `IStandardizedYield` for their respective vaults and remain unchanged.

The plan must not edit any of them.

---

## 4. Verification phase

Run after Steps 1–7.10 and the artifact refresh in §2.

### Step 8 — IFacet structural tests (fastest gate)

```bash
forge test --match-path \
    "test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol" \
    --match-path \
    "test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol" \
    -vvv
```

Pass criteria:

- `UniswapV4StandardExchangeInFacet` declares exactly `exchangeIn` + 5-arg `deposit` + 5-arg `redeem`. Control funcs (Step 7) match.
- `UniswapV4StandardExchangeOutMultiQueryFacet` declares `IStandardExchangeOutMulti.interfaceId` + `IERC5115_StandardizedYield.interfaceId`. Control funcs (Step 7.5) match.
- `supportsInterface(IERC5115_StandardizedYield.interfaceId)` returns `true` on the deployed facet; `supportsInterface(IStandardizedYield.interfaceId)` returns `false`.

If any fails: stop and report. Do not continue to Step 9.

### Step 9 — Architecture and lifecycle tests

```bash
forge test --match-path \
    "test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Architecture.t.sol" \
    --match-path \
    "test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol" \
    --match-path \
    "test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol" \
    --match-path \
    "test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol" \
    -vvv
```

Pass criteria:

- `test_packageCuts_keepOwnersAndInstallSingleCallback` passes with the new cut sizes (`cuts[6].length == 3`, `cuts[15].length == 7`).
- `test_disabledSY_rejectsDepositAndBothHoldersBeforeMovement` passes: the disabled-vault revert fires on both 5-arg `deposit(..., false)` and 5-arg `redeem(..., false)`.
- `test_deposit_hasNoSelfCall` passes: no `address(this).deposit(...)` self-call in the trace.
- `test_RC01_codeLessCaller_rejectedBeforeBurn` passes: the EOA gate stays on `redeem(..., true)` (`EOAPretransferNotAllowed` reverts before burn).
- `test_RC01_contractCaller_redeemsOnlyRequestedVaultShares` passes: contract caller with `true` flag burns only the requested vault-held shares; no self-call.
- `test_nativeSYMetadataRateAndFacetSize` passes with the `assetInfo()` test deleted; `yieldToken()` still returns `address(0)`; `exchangeRate()` still returns a positive value; `supportsInterface(IERC5115_StandardizedYield.interfaceId)` returns true.

If any fails: stop and report. Do not continue.

### Step 10 — Adversarial and cross-family tests

```bash
forge test --match-path \
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/" \
    --match-path \
    "test/foundry/spec/vaults/standard/sy/" \
    -vvv
```

Pass criteria:

- The non-V4 SY tests (ConstantProduct, LiquidStaking, V3FullRange, WeightedBufferHook, SingleConstantProductHook, DualBufferHook, CurveQuadBufferHook, BalancerStableBufferHook, BalancerPool, MorphoBlue, AaveStata) all still pass. They declare `IStandardizedYield` on their respective vaults and are not affected by the legacy V4 cut.
- No test in `release/` or `vaults/standard/sy/` references the legacy V4 family. If a test does, it must be left alone (the PRD says do not edit other families' tests).

If any fails: stop and report. A failure here indicates the shared SY surface was unintentionally changed.

### Step 11 — Full hermetic sweep

```bash
forge test -vvv
```

Pass criteria:

- All tests pass with the default hermetic profile.
- No `via_ir` was used.
- No self-call to `deposit(..., ...)` on the legacy V4 proxy (no `NativeSYExecutionSelfCall` revert from `Behavior_NativeStandardYieldExecution`).
- Other families' Pendle surfaces are intact (their own `release/` and `sy/` tests pass).

If any fails: stop and report.

---

## 5. Size-measurement phase

Per the PRD's size rule and `legacy-v4-standard-exchange-architecture-redesign.md` requirement 9.

### Step 12 — Measure `UniswapV4StandardExchangeInFacet` and `UniswapV4StandardExchangeOutFacet`

After Step 11 passes:

```bash
forge inspect contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol:UniswapV4StandardExchangeInFacet deployedBytecode | wc -c
forge inspect contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet.sol:UniswapV4StandardExchangeOutFacet deployedBytecode | wc -c
```

Record both sizes in the implementation report.

Pass criteria (per the PRD):

- Each runtime is at most **24,576 bytes** (hard limit).
- If either exceeds 24,576 bytes: **stop and report**. Do not split facets. Do not restore a delegate hop, a self-call, or `via_ir`. A later item may split only after this measurement.

The other 14 facet runtimes are not in scope for this PRD's size rule, but record their sizes for the report if convenient.

### Step 13 — Acceptance evidence roll-up

Write a single Markdown file `docs/reviews/legacy-v4-erc5115-interface/implementation_report.md` containing:

1. The toolchain output (`forge --version`, `solc --version`, `optimizer_runs`, `via_ir == false` confirmation).
2. The git diff stats (must show only the files this plan listed).
3. The two facet bytecode sizes from Step 12.
4. The pass/fail summary of every `forge test` invocation above.
5. A confirmation that no other family's Pendle surface changed (`git diff` on the shared `vaults/standard/sy/` directory must be empty).
6. The acceptance criteria from the PRD's `## Acceptance criteria` section, each marked pass/fail with evidence.

This file is the closure artifact. The plan terminates here.

---

## 6. Out-of-scope (do not do)

The PRD's `## Non-goals` and `## Dissent` sections are explicit. The plan must not:

- Split facets. The PRD closes this.
- Remove Pendle from other families. The shared `vaults/standard/sy/` files and every other family's `*StandardExchangeDFPkg.sol` are untouched.
- Add `rewardIndexesCurrent`, `claimRewards`, `getRewardTokens`, `accruedRewards`, `rewardIndexesStored`, `assetInfo`, or public `isValidToken*` functions. The named file (`IERC5115_StandardizedYield.sol`) is the interface, not a fuller EIP-5115 text.
- Change `exchangeIn` or `exchangeOut` signatures.
- Restore a delegate hop or self-call to fix a size limit.
- Enable `via_ir`.
- Create a parallel execution-target class. The PRD explicitly says "Edit the existing yield target." (`dissent` item 2 in the controlling PRD closes a prior cross-review position; this plan honors the PRD.)
- Drop or add a declaration site for ERC-5115 / Pendle interface ids. The PRD says "Do not add or drop a declaration site."
- Claim a passing suite proves the size gate. The PRD says "Consensus is not proof."

If any of these tempting simplifications appears to fix a failing test or a size miss, the plan must stop and report instead.

---

## 7. Plan-draft self-checks

The implementer must verify, before starting Step 1, that they have:

- The latest `docs/reviews/legacy-v4-erc5115-interface/REMEDIATION_PRD.md` (status DRAFT). If the PRD's status moves from DRAFT to ACCEPTED or REVISED, the plan must be re-read against the new text before any edit.
- A fresh `git status` showing only the files this plan lists (plus generated artifacts).
- A warm `cache_forge/` and `out/` per CLAUDE.md §9.
- The Foundry version **1.5.1** and `solc` **0.8.35**.
- The four reviewer session IDs (Astra `ses_ec412bcc2ffejKLo7nuoEAqbV0`, Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`, Kimi `ses_ec3d04e91ffeJa0is24e2jZv06`, MiniMax M3 `ses_ebdf718feffemWQNf7wuTpapqX`) and the four originals they produced, available for cross-reference if the implementer is unsure about a reviewer position.

If any of these is missing, the plan cannot start cleanly.

---

## 8. Final plan summary

- **6 production files** change: query target, query facet, yield target, IN facet, DFPkg.
- **6 test files** change: the two IFacet tests, the architecture test, the vault-held-redeem test, the full-range-book test, the full-range-book decimals test.
- **0 new files** are added. **0 files are deleted.** The PRD's "Do not create a parallel class" rule is honored.
- **0 facet splits.** The 16-facet cut stays as 16 facets; the 15-entry `facetInterfaces` stays as 15 entries.
- **Other families untouched.** ~145 production and test files keep their Pendle interface.
- **One signature change:** `deposit(address,address,uint256,uint256)` payable → `deposit(address,address,uint256,uint256,bool)` non-payable.
- **One behavior gate preserved:** the existing `LocalCreditLib.requirePretransferCaller` on `redeem(..., burnFromInternalBalance=true)` stays.
- **One behavior gate not added:** `LocalCreditLib.requirePretransferCaller` is **not** added to the deposit's token-credit branch, even when `depositFromInternalBalance == true`. The PRD closes this in favor of the existing custody convention.

I did not run Forge.