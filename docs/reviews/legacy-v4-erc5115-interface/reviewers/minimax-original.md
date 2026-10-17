# MiniMax M3 — replacement-session review, independent pass

- **Label:** replacement session (not continuity with any prior MiniMax session). I do not recall ses_ec41255ceffeVhrySLQe8hwwMC. No cross-review artifacts read; no peer notes read.
- **Task (per coordinator):** write notes for a PRD that removes the Pendle `IStandardizedYield` implementation from the legacy Uniswap V4 Standard Exchange family and replaces it with `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol`. Close the change so an implementer does not choose.
- **Scope guardrails I am enforcing here:**
  - Other families (V3 FullSpread, hookless V4, Pons V4, V4 hook packages, Aave, Morpho, Balancer, Lido/Rocket/EtherFi, rebasing, Camelot, Aerodrome, all `vaults/standard/sy/*` non-V4 consumers, DETF SY, etc.) **keep Pendle unless the owner has separately ruled otherwise** — they are not in scope for this PRD.
  - The PRD is a notes-only artifact. I am not writing `REMEDIATION_PRD.md`. The coordinator owns that path.
  - No code edits. No Forge. No exploit procedures.
- **Files examined for this review (no defect means "not changed by this PRD"):**
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiQueryFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiQueryTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecuteTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackFacet.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackTarget.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol`
  - `contracts/protocols/dexes/uniswap/v4/IUniswapV4StandardExchangeDFPkg.sol`
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol`
  - `contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol`
  - `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol`
  - `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol`
  - `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol`
  - `contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol`
  - `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol`
  - `contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol`
  - `contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol`
  - `contracts/utils/LocalCreditLib.sol`
  - `contracts/interfaces/ISecurePullErrors.sol`
  - `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol`
  - `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol`
  - `lib/crane/contracts/interfaces/IStandardExchangeIn.sol`
  - `lib/crane/contracts/interfaces/IStandardExchangeOut.sol`
  - `contracts/interfaces/IStandardExchangeOutMulti.sol`
  - `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol`
  - `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol`
  - `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Architecture.t.sol`
  - `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol` (only lines 1–120 read for SY interface usage; full lifecycle impact is out of scope for this selector-manifest pass)
  - `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol` (lines 750–849 read for the `assetInfo`/`IStandardizedYield` usage)
  - `test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol` (line-9 import only confirmed)
  - `contracts/protocols/dexes/uniswap/v4/legacy-v4-standard-exchange-architecture-redesign.md` (PRD context; owner ruled interface switch)
  - `contracts/protocols/dexes/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_FULL_RANGE_DEPLOYED_BOOK_IMPLEMENTATION_AND_TEST_PLAN.md` (referenced for intent)

- **Files examined with no defect (i.e., no change required for the interface switch in this PRD):**
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryFacet.sol` — declares transition/external quote selectors; no `IStandardizedYield` or `NativeStandardYieldSelectors._append*` use.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInQueryTarget.sol` — quotes-only target; no SY interface surface.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiFacet.sol` — declares only `IStandardExchangeInMulti.exchangeInManyToOne`; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiTarget.sol` — `ReentrancyLockModifiers` only; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiQueryFacet.sol` — declares only `previewExchangeInManyToOne` + `IStandardExchangeIn.previewExchangeIn`; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInMultiQueryTarget.sol` — quote-only; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutFacet.sol` — declares only `IStandardExchangeOut.exchangeOut`; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutExecuteTarget.sol` — execution-only; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryFacet.sol` — declares only `IStandardExchangeOut.previewExchangeOut` + `IStandardExchangeTransitionQuote.quoteState`; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutQueryTarget.sol` — quote-only; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiFacet.sol` — declares only `IStandardExchangeOutMulti.exchangeOutOneToMany`; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiTarget.sol` — `ReentrancyLockModifiers` only; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveFacet.sol` — declares only liquid-reserve selectors; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeLiquidReserveTarget.sol` — reserve/pool-ops only; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportFacet.sol` — declares only `importPosition`; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangePositionImportTarget.sol` — import-only; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackFacet.sol` — declares only `IUnlockCallback.unlockCallback`; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCallbackTarget.sol` — callback-only; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol` — declares only `IStandardExchangeIn.exchangeIn`; no SY.
  - `contracts/protocols/dexes/uniswap/v4/IUniswapV4StandardExchangeDFPkg.sol` — PkgInit/PkgArgs; no SY.
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol` — CREATE3 deployment only; no SY selectors.

---

## 1. Required behavior — closing notes for the implementer

The owner ruling the coordinator delivered is: the legacy V4 Standard Exchange vault must implement `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol` and must not advertise any selector whose only justification is the Pendle `IStandardizedYield` surface. The selector set on the legacy V4 proxy must be exactly the ERC-5115 view set + the legacy V4 execution/quote/import/reserve/callback surface that the family already retains, with the **one signature change** the ERC-5115 standard mandates on `deposit`.

The implementer must not choose between alternatives; the notes below fix:

1. Which selectors are removed from each legacy V4 facet.
2. Which selectors are added or whose signature changes.
3. The pretransfer mapping that ties ERC-5115's `depositFromInternalBalance` to the legacy V4 pretransfer rule already enforced by `contracts/utils/LocalCreditLib.sol` and `contracts/interfaces/ISecurePullErrors.sol`.
4. Which shared files serve other families and must be left untouched.
5. The package interface id list (`IUniswapV4StandardExchangeDFPkg.facetInterfaces()`) replacement.

The "size is measured after this interface change" rule means: facet runtime sizes are re-measured after this PRD's edits, not before. This PRD does not declare the target split; it only enforces the surface.

---

## 2. Surface diff between the two interfaces (reference)

**Pendle `IStandardizedYield` (current) — installed on legacy V4 today:**
- `deposit(address,address,uint256,uint256) payable returns (uint256)` ← *signature changes*
- `redeem(address,uint256,address,uint256,bool) returns (uint256)` ← *unchanged*
- `exchangeRate() view returns (uint256)` ← *unchanged*
- `yieldToken() view returns (address)` ← *unchanged*
- `assetInfo() view returns (AssetType,address,uint8)` ← **removed**
- `getTokensIn() view returns (address[])` ← *unchanged*
- `getTokensOut() view returns (address[])` ← *unchanged*
- `isValidTokenIn(address) view returns (bool)` ← **removed**
- `isValidTokenOut(address) view returns (bool)` ← **removed**
- `previewDeposit(address,uint256) view returns (uint256)` ← *unchanged*
- `previewRedeem(address,uint256) view returns (uint256)` ← *unchanged*
- `getRewardTokens() view returns (address[])` ← **removed**
- `accruedRewards(address) view returns (uint256[])` ← **removed**
- `rewardIndexesStored() view returns (uint256[])` ← **removed**
- `rewardIndexesCurrent() returns (uint256[])` ← **removed**
- `claimRewards(address) returns (uint256[])` ← **removed**
- (inherited from `IERC20Metadata`): `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `transfer`, `transferFrom`, `approve`, `allowance`, `permit` — Pendle carries these; ERC-5115 does **not** inherit ERC-20 metadata. The legacy V4 already installs `IERC20`/`IERC20Metadata`/`IERC20Permit`/`IERC5267` separately via the standard vault facets in `UniswapV4StandardExchangeDFPkg.facetInterfaces()`. **No additional change is needed for ERC-20 surface** — the proxy still answers the ERC-20 selectors from the canonical facet cuts, just not from the SY declaration.

**ERC-5115 `IERC5115_StandardizedYield` (new) — what the proxy must advertise on legacy V4:**
- `deposit(address,address,uint256,uint256,bool) returns (uint256)` ← **new signature; selector changes** vs. Pendle's payable 4-arg `deposit`
- `redeem(address,uint256,address,uint256,bool) returns (uint256)` ← same selector as Pendle (identical signature)
- `exchangeRate() view returns (uint256)` ← same selector
- `getTokensIn() view returns (address[])` ← same selector
- `getTokensOut() view returns (address[])` ← same selector
- `yieldToken() view returns (address)` ← same selector
- `previewDeposit(address,uint256) view returns (uint256)` ← same selector
- `previewRedeem(address,uint256) view returns (uint256)` ← same selector

`IERC5115_StandardizedYield.interfaceId` = XOR of the eight function selectors above; `IStandardizedYield.interfaceId` (Pendle) is replaced by this value in the package's declared interfaces.

---

## 3. Selectors to REMOVE (legacy V4 only)

### 3.1 `UniswapV4StandardExchangeInFacet.sol` (line 25, `_appendExecution`)

The facet currently calls `NativeStandardYieldSelectors._appendExecution(funcs)`, which appends four Pendle selectors after `IStandardExchangeIn.exchangeIn`:

| # | Selector | Source | Disposition |
|---|---|---|---|
| 1 | `IStandardizedYield.deposit(address,address,uint256,uint256)` payable | `_appendExecution` | **Remove** (replaced by the new ERC-5115 `deposit` selector — see §4.1) |
| 2 | `IStandardizedYield.redeem(address,uint256,address,uint256,bool)` | `_appendExecution` | **Remove from this helper, re-add as the ERC-5115 `redeem` selector** (identical selector — the removal/addition is conceptual; the resulting `funcs` array contains the same selector under the new interface declaration) |
| 3 | `IStandardizedYield.rewardIndexesCurrent()` | `_appendExecution` | **Remove** — ERC-5115 has no equivalent |
| 4 | `IStandardizedYield.claimRewards(address)` | `_appendExecution` | **Remove** — ERC-5115 has no equivalent |

After the change the IN facet exposes exactly **3** function selectors: `exchangeIn` + `IERC5115_StandardizedYield.deposit` + `IERC5115_StandardizedYield.redeem`. The current count is **5**.

The implementer must replace the `_appendExecution` call with a V4-specific helper (e.g. `LegacyV4Erc5115Selectors._appendExecution` or an inline `funcs` literal) so that the existing shared `NativeStandardYieldSelectors._appendExecution` continues to serve other families unchanged.

### 3.2 `UniswapV4StandardExchangeOutMultiQueryFacet.sol` (lines 5, 20, 26)

The facet currently:

- imports `IStandardizedYield` from `@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol` (line 5),
- declares `type(IStandardizedYield).interfaceId` as the second `facetInterfaces()` entry (line 20),
- appends 12 SY selectors via `NativeStandardYieldSelectors._appendQuery(funcs)` (line 26), on top of `IStandardExchangeOutMulti.previewExchangeOutOneToMany`.

| # | Selector | Disposition |
|---|---|---|
| 1 | `IStandardizedYield.exchangeRate()` | **Keep** — present in ERC-5115 with identical selector |
| 2 | `IStandardizedYield.yieldToken()` | **Keep** |
| 3 | `IStandardizedYield.assetInfo()` | **Remove** — no ERC-5115 equivalent |
| 4 | `IStandardizedYield.getTokensIn()` | **Keep** |
| 5 | `IStandardizedYield.getTokensOut()` | **Keep** |
| 6 | `IStandardizedYield.isValidTokenIn(address)` | **Remove** — no ERC-5115 equivalent |
| 7 | `IStandardizedYield.isValidTokenOut(address)` | **Remove** — no ERC-5115 equivalent |
| 8 | `IStandardizedYield.previewDeposit(address,uint256)` | **Keep** |
| 9 | `IStandardizedYield.previewRedeem(address,uint256)` | **Keep** |
| 10 | `IStandardizedYield.getRewardTokens()` | **Remove** |
| 11 | `IStandardizedYield.accruedRewards(address)` | **Remove** |
| 12 | `IStandardizedYield.rewardIndexesStored()` | **Remove** |

After the change the query facet exposes **7** function selectors (1 multi preview + 6 ERC-5115 view selectors) and **1** interface (`IStandardExchangeOutMulti`; the second interface slot disappears — see §4.2). The current count is **13** selectors and **2** interfaces.

The implementer must replace `NativeStandardYieldSelectors._appendQuery(funcs)` with a V4-specific helper that emits only the six kept ERC-5115 selectors, and must change the import to `@crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol`. The shared `_appendQuery` keeps serving other families unchanged.

### 3.3 `UniswapV4StandardExchangeDFPkg.sol` (lines 18, 162)

The DFPkg:

- imports `IStandardizedYield` (line 18) for the interface declaration,
- emits `type(IStandardizedYield).interfaceId` as `interfaces[13]` in `facetInterfaces()` (line 162).

| Item | Disposition |
|---|---|
| Import of `IStandardizedYield` from Pendle (line 18) | **Remove** |
| `interfaces[13] = type(IStandardizedYield).interfaceId` (line 162) | **Remove** (ERC-5115 is no longer declared at the package-interface level because no facet emits it on a supported selector — see §4.3) |

The package's `facetInterfaces()` array length drops from **15** to **14**. The two remaining interfaces used by the facets (in/out, query, import, reserve, multi, transition/external quote) are unaffected.

### 3.4 `UniswapV4StandardExchangeOutMultiQueryTarget.sol` (lines 14, 40–44)

The target:

- imports `IStandardizedYield` for `assetInfo()` and the `AssetType` enum (line 14),
- implements `assetInfo() external view returns (IStandardizedYield.AssetType, address, uint8) returns (IStandardizedYield.AssetType.LIQUIDITY, address(Config._poolManager()), 18)` (lines 40–44).

| Item | Disposition |
|---|---|
| `import {IStandardizedYield}` (line 14) | **Remove** (no other use in the file) |
| `function assetInfo() ...` (lines 40–44) | **Remove** — no ERC-5115 equivalent; the function selector `assetInfo()` must not appear in any legacy V4 facet, and `assetInfo()` is **not** part of any other interface the legacy V4 declares |

If the implementer wishes to preserve the PoolManager-as-asset fact for off-chain consumers, they must surface it through `yieldToken()` (which currently returns `address(0)` and may stay that way) or via the existing `IUniswapV4StandardExchangeLiquidReserve.twapOracle()`/`poolManager()` paths — **not** by reintroducing `assetInfo()` under a new interface. The implementer must not invent a custom interface to retain this metadata.

---

## 4. Selectors to ADD or whose signature CHANGES

### 4.1 `UniswapV4StandardExchangeInFacet.sol` (line 25)

| Selector | Source | Notes |
|---|---|---|
| `IERC5115_StandardizedYield.deposit(address,address,uint256,uint256,bool) returns (uint256)` | **Add** | New selector (the function signature includes `bool depositFromInternalBalance`, which is why the old `IStandardizedYield.deposit` selector no longer matches). Non-payable. Must be wired to the new V4-specific deposit entrypoint in `UniswapV4StandardYieldExecutionTarget` (see §6). |

The existing `IStandardizedYield.redeem(address,uint256,address,uint256,bool)` selector is **already** identical to `IERC5115_StandardizedYield.redeem(address,uint256,address,uint256,bool)`; no selector changes. The implementer may keep the same function wiring, but must declare it under the ERC-5115 interface (i.e., the function in `UniswapV4StandardYieldExecutionTarget` must `override(IERC5115_StandardizedYield)` for the redeclare to compile and the loupe/IFacet compliance tests to pass).

### 4.2 `UniswapV4StandardExchangeOutMultiQueryFacet.sol` (lines 18–20)

| Selector / interface | Disposition |
|---|---|
| `type(IStandardizedYield).interfaceId` as second `interfaces` entry (line 20) | **Remove** — the facet no longer implements the Pendle surface |
| `type(IERC5115_StandardizedYield).interfaceId` | **Do not add** here — query selectors are *not* part of `IERC5115_StandardizedYield` (only the deposit/redeem + view set that lives on the IN/query facets together). The package-level interface declaration in `UniswapV4StandardExchangeDFPkg.facetInterfaces()` (§4.3) is where ERC-5115 is declared on the proxy. |

The facet's `facetInterfaces()` array drops to **1** entry (`IStandardExchangeOutMulti`).

### 4.3 `UniswapV4StandardExchangeDFPkg.sol` (`facetInterfaces()`, lines 147–164)

The package's proxy interface list must advertise `IERC5115_StandardizedYield` so the proxy loupe reports the correct ERC-165 supportsInterface answer and downstream integrators can rely on the interface.

| Change | Detail |
|---|---|
| `interfaces[13]` (current) | Replace `type(IStandardizedYield).interfaceId` with `type(IERC5115_StandardizedYield).interfaceId` |
| Array length | Stays at **15** (no count change; same slot) |
| Import (line 18) | Replace `@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol` with `@crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol` |

The package's `facetCuts()` and `facetAddresses()` are **unchanged in count** (16 entries each); the byte-cuts are unchanged. The change is in the *declared interface id* the proxy answers, not in which facet bytecode is installed. The `assetInfo()` selector being dropped is the *function* the proxy can no longer answer, but the proxy still answers all ERC-20, ERC-20 metadata, permit, vault, exchange-in/out, multi, transition/external quote, position-import, and reserve selectors that the family already had.

### 4.4 `UniswapV4StandardYieldExecutionTarget.sol` (lines 13–34)

This is the only file that must implement the *new* `deposit` signature.

| Current | New |
|---|---|
| `deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_) public payable override returns (uint256)` | `deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_, bool depositFromInternalBalance_) public override(IERC5115_StandardizedYield) returns (uint256)` — non-payable; declared against the ERC-5115 interface |

The override must:

1. Keep the `Config._requireNotDisabled()` guard before any state-affecting call (REQ-V4-02 gate).
2. Keep the same validation order as `NativeStandardYieldMoneyTarget.deposit`: `msg.value != 0` is impossible because the function is no longer `payable`; the unsupported-native-payment error therefore becomes unreachable on this entrypoint and the `UnsupportedNativePayment` revert remains for any sibling callers, not for this entrypoint. The implementer must **drop** the `if (msg.value != 0)` check from the V4 override (the function is non-payable) but **keep** the error selector exposed on the contract via `NativeStandardYieldErrors` for callers that still reach it from a sibling (e.g., the abstract's `_standardRoute(..., bool internal_)` path is unaffected).
4. Keep `receiver_ == address(0)` → `InvalidSYReceiver`, `amount_ == 0` → `ZeroSYAmount`, `!isValidTokenIn(tokenIn_)` → `InvalidSYToken(tokenIn_)`.
5. Route through the existing internal `_standardRoute(IERC20(tokenIn_), amount_, IERC20(address(this)), minimum_, receiver_, false)` — the `internal_=false` argument is the SE-internal "internal balance" flag, **not** the ERC-5115 `depositFromInternalBalance` flag. They are distinct semantics (see §6). The V4 deposit must **override** the inner `_standardRoute` (or insert a thin shim) so that `depositFromInternalBalance_` is forwarded as the SE `pretransferred` argument to `_exchangeIn`.
6. Emit `IERC5115_StandardizedYield.Deposit(msg.sender, receiver_, tokenIn_, amount_, shares)` (the event topic hashes happen to be identical between the two interfaces because the indexed topics + value types match; nevertheless, the emit must reference `IERC5115_StandardizedYield.Deposit` so the ERC-5115 declaration is the contract's stated event).
7. Reject zero shares with `ZeroSYAmount()` after the route, identical to the Pendle override.

Because the V4 file currently inherits `NativeStandardYieldExecutionTarget` (which carries the 4-arg payable `deposit`), the implementer must **stop inheriting from `NativeStandardYieldExecutionTarget`** for the deposit path. The two clean options, both fixed by these notes (no implementer discretion):

- **Option A (recommended):** introduce a new abstract contract `UniswapV4StandardYieldExecutionTarget5115` (or rename the existing `UniswapV4StandardYieldExecutionTarget`) that:
  - inherits only `UniswapV4StandardExchangeInTarget` and the validation helpers (`NativeStandardYieldValidation`),
  - implements `deposit(...)` (5-arg, non-payable) inline against `IERC5115_StandardizedYield`,
  - implements `redeem(...)` (5-arg, identical selector to Pendle's) inline against `IERC5115_StandardizedYield`,
  - preserves the existing `_redeemVaultHeld` and `_settleNamedHolder` overrides,
  - preserves the existing `_standardRoute(IERC20,uint256,IERC20,uint256,address,bool)` override semantics,
  - **does not** inherit from `NativeStandardYieldExecutionTarget` or `NativeStandardYieldMoneyTarget` (those carry the 4-arg payable `deposit`).

- **Option B:** keep the existing `UniswapV4StandardYieldExecutionTarget` inheritance chain but rename the inherited `deposit` away (e.g., via a `_depositLegacy` shim). This is not allowed here because it would leave the 4-arg payable `deposit` selector installed on the proxy unless the implementer adds an explicit `SelectorRemover`-style cut, which the Diamond pattern does not support on Add-only flows. Option B is therefore **closed** by these notes — only Option A is permitted.

The implementer must also re-route the existing `isValidTokenIn`/`isValidTokenOut` overrides in `UniswapV4StandardYieldExecutionTarget` so that they no longer satisfy `NativeStandardYieldValidation` via the *inherited* ERC-5115 view selectors (those selectors are removed and cannot be inherited). The V4 file already declares its own `isValidTokenIn`/`isValidTokenOut` overrides — they remain — but the *Pendle-required* `IStandardizedYield.isValidTokenIn(address)` selector must not appear on the proxy, which is already true today because the legacy V4 does not declare it on any facet (`NativeStandardYieldSelectors` never appended it; it lives only on the abstract `NativeStandardYieldValidation`). Confirm and assert this in the implementation plan's selector manifest.

### 4.5 No other signature changes

The following Pendle selectors match the ERC-5115 selectors byte-for-byte and need only a re-import + a re-declaration of the interface they belong to:

- `redeem(address,uint256,address,uint256,bool)`
- `exchangeRate()`
- `yieldToken()`
- `getTokensIn()`
- `getTokensOut()`
- `previewDeposit(address,uint256)`
- `previewRedeem(address,uint256)`

The implementer must not change any of these signatures. The only signature change in this PRD is `deposit`.

---

## 5. Pretransfer mapping closure (the rule the implementer must follow)

The legacy V4 vault already enforces an integrating-contract-only pretransfer rule via `contracts/utils/LocalCreditLib.sol::requirePretransferCaller` and `contracts/interfaces/ISecurePullErrors.sol::EOAPretransferNotAllowed()`. ERC-5115's `deposit(..., bool depositFromInternalBalance)` exposes that concept on the SY entrypoint and **must not** be silently mapped to the existing SE-internal `bool internal_` flag, because they have different semantics:

| Flag | Domain | Semantics today in legacy V4 |
|---|---|---|
| `IStandardExchangeIn.exchangeIn(..., bool pretransferred, ...)` | SE exact-in entrypoint | `true` means the caller has already transferred `amountIn` of `tokenIn` into the vault this tx and the vault must consume that exact amount (refunds nothing on excess; cross-tx unrecorded balance is consumable by the next contract caller) |
| `_standardRoute(..., bool internal_)` | Internal SE/SY routing | `true` means burn from vault-held shares (`_redeemVaultHeld`), false means pull/credit once via `_exchangeIn` |
| `IERC5115_StandardizedYield.deposit(..., bool depositFromInternalBalance)` | SY deposit entrypoint | `true` means the caller has already deposited `amountTokenToDeposit` into the vault's `tokenIn` balance this tx and the vault must consume that exact amount |

The closure rule for the legacy V4 implementer is:

1. When `depositFromInternalBalance_ == true`, the deposit must forward the **SE pretransfer flag** (`pretransferred == true`) into the underlying `_exchangeIn` call. The vault must not pull `tokenIn` from `msg.sender` in this branch; it must consume the already-transferred balance and revert `SyncMint != 0` only if observed inbound is insufficient (the existing `Custody._secureTokenTransfer` and `ISecurePullErrors.TransferDeltaInsufficient` already enforce this).
2. When `depositFromInternalBalance_ == false`, the deposit forwards `pretransferred == false` (current behavior) — `_exchangeIn` pulls `tokenIn` from `msg.sender` via `Custody._secureTokenTransfer`.
3. The code-less caller check (`requirePretransferCaller(msg.sender)` from `LocalCreditLib`) is **not** applied to the `deposit` path because the deposit's `tokenIn` is a pool currency, not vault-held shares. The current Pendle deposit has no EOA pretransfer gate, and ERC-5115 has no requirement to add one for the deposit's `tokenIn`. (The redeem path keeps the existing EOA gate from `NativeStandardYieldMoneyTarget.redeem`/`NativeStandardYieldExecutionTarget.redeem`, which is unchanged.)
4. The `depositFromInternalBalance_ == true` path must NOT route through `_redeemVaultHeld` and must NOT route through `_settleNamedHolder`. Both are share-side and redemption-only paths; deposit consumes `tokenIn`, not shares.
5. The legacy V4 `Config._requireNotDisabled()` guard runs **before** the pretransfer-flag branching (REQ-V4-02).

These five rules fix the mapping; the implementer is not given a choice.

---

## 6. Test files that must be updated by this PRD (legacy V4 only)

These are selector-manifest tests and behavior tests. I list them with the *exact* changes; the implementer must not invent alternatives.

| Test file | Current SY surface | Required change |
|---|---|---|
| `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol` | `controlFuncs[1..4]` reference `IStandardizedYield.deposit/redeem/rewardIndexesCurrent/claimRewards`; count = **5** | Replace `controlFuncs[1]` with `IERC5115_StandardizedYield.deposit` (5-arg selector); keep `controlFuncs[2]` as `IERC5115_StandardizedYield.redeem` (identical selector); drop `controlFuncs[3]` and `controlFuncs[4]`. New count = **3**. Update the import to `IERC5115_StandardizedYield`. |
| `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol` | `controlInterfaces` includes `IStandardizedYield`; `controlFuncs` enumerates 12 SY selectors | Drop `IStandardizedYield` from `controlInterfaces`. Reduce `controlFuncs` to 7 entries: `previewExchangeOutOneToMany` + the 6 ERC-5115 view selectors (`exchangeRate`, `yieldToken`, `getTokensIn`, `getTokensOut`, `previewDeposit`, `previewRedeem`). Update import to `IERC5115_StandardizedYield`. |
| `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Architecture.t.sol` | Lines 8 (`IStandardizedYield` import), 56–58 (loupe assertions for `deposit`/`redeem`/`previewRedeem` selectors), 78/80/82/88/92 (interface calls), 844–848 (`supportsInterface(IStandardizedYield)`, `sy.assetInfo()`, `IStandardizedYield.AssetType.LIQUIDITY`) | (a) Update import to `IERC5115_StandardizedYield`. (b) Lines 56/58 loupe assertions: `deposit` selector is **new** (ERC-5115 5-arg); assert `IDiamondLoupe(address(vault)).facetAddress(IERC5115_StandardizedYield.deposit.selector), expected[6]` and keep the `redeem` and `previewRedeem` assertions (identical selectors). (c) Lines 78/80/82/88: cast the vault as `IERC5115_StandardizedYield`; line 78's `deposit(recipient, address(token0), 1 ether, 0)` becomes `deposit(recipient, address(token0), 1 ether, 0, false)`; lines 80/82 redeem calls already use the 5-arg form and are unchanged. (d) Line 92: the no-self-call test becomes `deposit(recipient, address(token0), 1 ether, 1, false)` and the assertion shifts from "1 share" to the actual returned shares. (e) Lines 844–848: replace `supportsInterface(IStandardizedYield)` with `supportsInterface(IERC5115_StandardizedYield)`; **delete** the `assetInfo()` test (lines 846–848). The `cut[5].functionSelectors.length == 1` and `cut[6].functionSelectors.length == 5` assertions (lines 52/54) become `cut[6].functionSelectors.length == 3`; `cut[15].functionSelectors.length == 13` becomes `cut[15].functionSelectors.length == 7`. |
| `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol` | Line 9 imports `IStandardizedYield`; calls `IStandardizedYield(address(vault)).redeem(...)` (lines 93, 109, 127, 142, 158, 173, 285); line 107 calls `previewRedeem` | Update import to `IERC5115_StandardizedYield`. The redeem signature is unchanged; the cast type changes. The `previewRedeem` call is unchanged (identical selector). |
| `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol` | Line 1042 (or thereabouts) imports `IStandardizedYield`; lines 760–763 cast `IStandardizedYield(address(bound))` for `exchangeRate`/`previewRedeem`/`redeem`; lines 843–849 use `supportsInterface(IStandardizedYield)`, `yieldToken`, `assetInfo()`, `IStandardizedYield.AssetType.LIQUIDITY`; line 910 uses `IStandardizedYield` | Update import to `IERC5115_StandardizedYield`. `exchangeRate`/`yieldToken`/`getTokensIn`/`getTokensOut`/`previewDeposit`/`previewRedeem`/`redeem` are unchanged selectors — keep their tests. **Delete** the `assetInfo()` test (lines 846–848) and any `IStandardizedYield.AssetType` references. Replace `supportsInterface(IStandardizedYield)` with `supportsInterface(IERC5115_StandardizedYield)`. The full-range-book lifecycle tests (RC-01, import tests, no-self-call tests) are otherwise unchanged unless they assume `deposit` takes 4 args — those calls must be updated to take the 5-arg form with a final `false` for the EOA-no-pretransfer path. |
| `test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol` | Line 9 imports `IStandardizedYield`; line 234 casts `IStandardizedYield(address(bound))` for redeem-side operations | Update import to `IERC5115_StandardizedYield`. The redeem-side casts shift to `IERC5115_StandardizedYield`. No selector change for the redeem-side calls. |

The shared `contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol` no-self-call assertion remains valid for the new V4 ERC-5115 deposit because the underlying rule is unchanged — the V4 deposit must not `address(this).deposit(...)`-self-call. The test modifier `noSelfCalls(address(vault))` is still appropriate.

The size-assertion tests in `UniswapV4StandardExchange_Architecture.t.sol` (line 47: `assertLe(expected[i].code.length, 24_576)`) are unchanged in form. They are re-measured after this PRD's edits, per the coordinator's "size is measured after this interface change" rule.

---

## 7. Shared files serving other families — DO NOT REDESIGN

These files are shared by every other Pendle-SY native family (ConstantProduct/Aerodrome/Camelot, Aave v3.6 / Morpho Blue, Lido/Rocket/EtherFi rebasing, DETF SY, V3 FullSpread, V4 hookless/Pons/Hook packages, Balancer pools, etc.). The owner ruling closes only the legacy V4 change; these files must keep their Pendle surface.

| File | Role | Rule |
|---|---|---|
| `contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol` | Library of `_appendMoney/_appendRewards/_appendPreviews/_appendDiscovery/_appendExecution/_appendQuery/_append` helpers used by every other family's facets | **Keep as-is.** All `_append*` helpers continue to emit Pendle selectors. The legacy V4 implementer introduces a new V4-specific helper file (e.g. `contracts/protocols/dexes/uniswap/v4/internal/LegacyV4Erc5115Selectors.sol`) that emits only ERC-5115 selectors. |
| `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol` | Defines `NativeStandardYieldMoneyTarget` (4-arg payable deposit), `NativeStandardYieldRewardsTarget`, `NativeStandardYieldExecutionTarget`, and the `NativeStandardYieldTarget` aggregate | **Keep as-is.** Other families inherit from `NativeStandardYieldExecutionTarget` and `NativeStandardYieldTarget`. The legacy V4 stops inheriting the deposit path (per §4.4 Option A). |
| `contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol` | Defines `NativeStandardYieldValidation` (with `isValidTokenIn/Out` virtuals) and `NativeStandardYieldDiscoveryTarget` (with `getTokensIn/Out`, `yieldToken`, `assetInfo`, `exchangeRate`, `getRewardTokens`, `accruedRewards`, `rewardIndexesStored` virtuals) | **Keep as-is.** The legacy V4 does not need to redefine `NativeStandardYieldValidation`/`NativeStandardYieldDiscoveryTarget`; the V4 IN facet already overrides `isValidTokenIn`/`isValidTokenOut`, and the V4 query target already overrides the view functions it needs. The legacy V4 must not import or call `assetInfo`, `getRewardTokens`, `accruedRewards`, or `rewardIndexesStored` from this file. |
| `contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol` | Defines `NativeStandardYieldPreviewCallsTarget` (with `previewDeposit`/`previewRedeem`) and the aggregate `NativeStandardYieldPreviewTarget` | **Keep as-is.** The legacy V4 query target already implements `previewDeposit`/`previewRedeem` via the `_previewExchangeIn` path, so it does not need to inherit from this aggregate. |
| `contracts/vaults/standard/sy/ConstantProductStandardYieldTarget.sol` | Defines ConstantProduct discovery/preview/validation/execution abstracts | **Keep as-is.** Other ConstantProduct families (UniV2, Camelot V2, Aerodrome) inherit from these. |
| `contracts/vaults/standard/sy/NativeStandardYieldErrors.sol` | Defines `NativeStandardYieldErrors` (used as an error namespace) | **Keep as-is.** The legacy V4 may continue to inherit from it for the `deposit`/`redeem` body that uses `InvalidSYReceiver`/`ZeroSYAmount`/`InvalidSYToken`/`SYMinimumNotMet`. |
| `contracts/vaults/standard/sy/NativeStandardYieldQuoteBase.sol` | Defines the abstract `NativeStandardYieldQuoteBase._previewExchangeIn` | **Keep as-is.** Other families rely on it. |
| `contracts/vaults/standard/sy/Behavior_NativeStandardYieldExecution.sol` | No-self-call trace assertion library | **Keep as-is.** Used by the legacy V4 redeem tests and other families. |
| `contracts/utils/LocalCreditLib.sol` | `available`/`budget`/`requirePretransferCaller` | **Keep as-is.** Required by the redeem path and the §5 mapping rule. |
| `contracts/interfaces/ISecurePullErrors.sol` | `TransferDeltaInsufficient`/`EOAPretransferNotAllowed` | **Keep as-is.** Required by the §5 mapping rule. |
| `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol` | Pendle SY interface (vendored from Pendle) | **Keep as-is.** Other families still implement it. The legacy V4 only removes its `import` from V4-owned files. |

The shared `NativeStandardYieldSelectors.sol` and `NativeStandardYieldTarget.sol` are **not** modified by this PRD. The legacy V4 family introduces its own internal ERC-5115 selector helper and its own V4-specific yield execution target (Option A in §4.4). No other family is redesigned.

---

## 8. Selector ownership manifest (final state, after this PRD)

The legacy V4 proxy's installed facets and their declared selectors, post-PRD, must be exactly:

| Facet | Interface | Function selectors | Notes |
|---|---|---|---|
| `erc20Facet` | `IERC20`, `IERC20Metadata`, `IERC20(^-IERC20Metadata)` | (canonical ERC-20 selectors from Crane) | Unchanged |
| `erc5267Facet` | `IERC5267` | (canonical EIP-5267 selectors) | Unchanged |
| `erc2612Facet` | `IERC20Permit` | (canonical EIP-2612 selectors) | Unchanged |
| `multiAssetBasicVaultFacet` | (vault facets) | (canonical) | Unchanged |
| `multiAssetStandardVaultFacet` | `IStandardVault` | (canonical) | Unchanged |
| `uniswapV4StandardExchangeCallbackFacet` | `IUnlockCallback` | `unlockCallback(bytes)` | Unchanged |
| `uniswapV4StandardExchangeInFacet` | `IStandardExchangeIn`, `IERC5115_StandardizedYield` (via package-level declaration, not facet-local) | `exchangeIn(IERC20,uint256,IERC20,uint256,address,bool,uint256)` + `deposit(address,address,uint256,uint256,bool)` + `redeem(address,uint256,address,uint256,bool)` | **3** selectors — was 5 |
| `uniswapV4StandardExchangeInQueryFacet` | `IStandardExchangeTransitionQuote`, `IStandardExchangeExternalQuote` | (6 quote selectors) | Unchanged |
| `uniswapV4StandardExchangePositionImportFacet` | `IUniswapV4StandardExchangePositionImport` | `importPosition(IPositionManager,uint256,uint256,address,address,uint256)` | Unchanged |
| `uniswapV4StandardExchangeOutFacet` | `IStandardExchangeOut` | `exchangeOut(IERC20,uint256,IERC20,uint256,address,bool,uint256)` | Unchanged |
| `uniswapV4StandardExchangeOutQueryFacet` | `IStandardExchangeOutMulti` (no second interface) | `previewExchangeOut(IERC20,IERC20,uint256)` + `quoteState(address,address)` | Unchanged — already has no SY selectors |
| `uniswapV4StandardExchangeLiquidReserveFacet` | `IUniswapV4StandardExchangeLiquidReserve` | (7 reserve selectors) | Unchanged |
| `uniswapV4StandardExchangeInMultiFacet` | `IStandardExchangeInMulti` | `exchangeInManyToOne(address[],uint256[],IERC20,uint256,address,bool,uint256)` | Unchanged |
| `uniswapV4StandardExchangeInMultiQueryFacet` | `IStandardExchangeInMulti`, `IStandardExchangeIn` | `previewExchangeInManyToOne(...)` + `previewExchangeIn(IERC20,uint256,IERC20)` | Unchanged |
| `uniswapV4StandardExchangeOutMultiFacet` | `IStandardExchangeOutMulti` | `exchangeOutOneToMany(IERC20,uint256,address[],uint256[],address,bool,uint256)` | Unchanged |
| `uniswapV4StandardExchangeOutMultiQueryFacet` | `IStandardExchangeOutMulti` (no second interface) | `previewExchangeOutOneToMany(IERC20,address[],uint256[])` + `exchangeRate()` + `yieldToken()` + `getTokensIn()` + `getTokensOut()` + `previewDeposit(address,uint256)` + `previewRedeem(address,uint256)` | **7** selectors — was 13 |

The package's `facetInterfaces()` returns the **15** existing entries with `interfaces[13]` replaced from `type(IStandardizedYield).interfaceId` to `type(IERC5115_StandardizedYield).interfaceId`.

The package's `facetCuts()` and `facetAddresses()` return the **16** existing entries; no facet is added or removed by this PRD. Size is measured after this PRD lands and the implementer decides a later split.

---

## 9. Findings — labeled MiniMax M3

### F1 — Pendle `IStandardizedYield` is wrongly installed on the legacy V4 proxy

- **Severity:** high (interface correctness — owner ruling scope)
- **File and line:**
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol` line 25 (`funcs = NativeStandardYieldSelectors._appendExecution(funcs);` appends four Pendle selectors including `IStandardizedYield.deposit(address,address,uint256,uint256) payable`)
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol` lines 5, 20, 26 (Pendle import, interface id, `_appendQuery` appending twelve Pendle selectors including `assetInfo`, `isValidTokenIn/Out`, `getRewardTokens`, `accruedRewards`, `rewardIndexesStored`)
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol` lines 18, 162 (Pendle import + `interfaces[13] = type(IStandardizedYield).interfaceId`)
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol` lines 14, 40–44 (`assetInfo()` + `IStandardizedYield.AssetType` enum)
- **Intended behavior (per owner ruling):** the legacy V4 vault must implement `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol` and not the Pendle `IStandardizedYield`.
- **Requirement / invariant that appears broken:** the proxy advertises the Pendle `IStandardizedYield.interfaceId` and installs its `deposit`/`assetInfo`/`isValidToken*`/reward selectors, none of which belong on an ERC-5115 vault. ERC-5115 mandates a different `deposit` signature (5-arg with `bool depositFromInternalBalance`, non-payable) and has no `assetInfo`, no `isValidToken*`, and no reward surface.
- **Impact class:** interface correctness / selector ownership / external-consumer breakage. Off-chain integrators that read `supportsInterface(IStandardizedYield.interfaceId)` and call `assetInfo()` against the legacy V4 proxy will get an inconsistent answer once ERC-5115 is adopted; integrators that send `deposit(receiver, tokenIn, amount, minimum)` with the 4-arg selector will hit a non-existent function selector after the cut.
- **Fix direction:** see §3, §4. The implementer removes the four SY selectors listed in §3.1, removes the six SY selectors listed in §3.2 (only the ERC-5115 surface remains), removes the assetInfo implementation in §3.4, and replaces `type(IStandardizedYield).interfaceId` with `type(IERC5115_StandardizedYield).interfaceId` in §4.3.
- **Confidence:** high — every file/line listed is read directly from the working tree, and the surface diff between the two interfaces is deterministic from the interface sources.

### F2 — `deposit` signature change is the only signature change

- **Severity:** medium (signature-level ABI break for the SY entrypoint)
- **File and line:** `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol` lines 17–25
- **Intended behavior:** ERC-5115 requires `deposit(address receiver, address tokenIn, uint256 amountTokenToDeposit, uint256 minSharesOut, bool depositFromInternalBalance) returns (uint256 amountSharesOut)`. The current V4 override declares `deposit(..., uint256 minimum_)` payable with **no** `depositFromInternalBalance` argument and matches the Pendle signature.
- **Requirement / invariant that appears broken:** the V4 override must `override(IERC5115_StandardizedYield)` and accept the fifth `bool depositFromInternalBalance_` argument. Non-payable.
- **Impact class:** signature / event-emitter compatibility. The implementer must also drop the `if (msg.value != 0) revert UnsupportedNativePayment();` check (function is non-payable, so `msg.value` is always 0 on a legitimate call) but keep the error selector exposed for any sibling caller path through `NativeStandardYieldErrors`.
- **Fix direction:** §4.4 Option A. The implementer introduces a new abstract (e.g. `UniswapV4StandardYieldExecutionTarget5115`) that does **not** inherit from `NativeStandardYieldExecutionTarget`, declares `deposit(..., bool) override(IERC5115_StandardizedYield)`, and emits `IERC5115_StandardizedYield.Deposit`. The redeem body (5-arg) reuses the existing validation order: receiver != 0, shares != 0, token validity, internalBalance branch with `LocalCreditLib.requirePretransferCaller(msg.sender)` for `internalBalance_==true`, and `SYMinimumNotMet` on shortfall. The redeem signature is **unchanged**.
- **Confidence:** high.

### F3 — Pretransfer mapping closure (the rule the implementer must follow)

- **Severity:** medium (semantic mapping between two distinct bool flags)
- **File and line:** `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol` lines 17–34; `contracts/utils/LocalCreditLib.sol` lines 23–28; `contracts/interfaces/ISecurePullErrors.sol` lines 9–16
- **Intended behavior:** ERC-5115's `deposit(..., bool depositFromInternalBalance)` must be forwarded to the SE pretransfer flag (`pretransferred`) on the underlying `_exchangeIn` call. It must **not** be conflated with the SE-internal `bool internal_` flag that controls share-side redemption (`_redeemVaultHeld`).
- **Requirement / invariant that appears broken:** without an explicit mapping rule, an implementer can collapse the three flags and produce a vault that pulls from `msg.sender` even when `depositFromInternalBalance_==true`, breaking ERC-5115's contract.
- **Impact class:** behavioral / external-consumer integration risk.
- **Fix direction:** §5 enumerates the five rules. The implementer is not given a choice.
- **Confidence:** high — the three flags' semantics are observable from the code paths in `LocalCreditLib.sol` and `NativeStandardYieldTarget.sol`.

### F4 — Shared SY declaration files are not in scope for this PRD

- **Severity:** informational (scope reminder)
- **File and line:** `contracts/vaults/standard/sy/NativeStandardYieldSelectors.sol`, `NativeStandardYieldTarget.sol`, `NativeStandardYieldDiscoveryTarget.sol`, `NativeStandardYieldPreviewTarget.sol`, `ConstantProductStandardYieldTarget.sol`, `NativeStandardYieldErrors.sol`, `NativeStandardYieldQuoteBase.sol`, `Behavior_NativeStandardYieldExecution.sol`, plus every other family's `StandardYieldFacet.sol`/`StandardExchangeDFPkg.sol` that imports `IStandardizedYield`
- **Intended behavior:** other families keep the Pendle surface. The legacy V4 change must not delete or rewrite the shared declarations.
- **Requirement / invariant that appears broken:** none — the file is shared with many other products.
- **Impact class:** regression risk if the implementer over-reaches.
- **Fix direction:** §7 lists the shared files and the rule. The legacy V4 implementer adds V4-specific helpers/targets and does not touch the shared files.
- **Confidence:** high.

### F5 — Test files must be updated in lockstep

- **Severity:** medium (test correctness)
- **File and line:**
  - `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol` lines 5, 40–46
  - `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol` lines 4, 34–55
  - `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Architecture.t.sol` lines 8, 52–58, 78–92, 844–848
  - `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol` lines 9, 93, 107, 109, 127, 142, 158, 173, 285
  - `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol` line 1042, lines 760–763, 843–849, 910
  - `test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol` lines 9, 234
- **Intended behavior:** every test must call the ERC-5115 selectors (5-arg `deposit`, no `assetInfo`/`isValidToken*`/reward calls), declare `IERC5115_StandardizedYield` in any interface/selector-manifest assertions, and reference `IERC5115_StandardizedYield.interfaceId` for any `supportsInterface` checks.
- **Requirement / invariant that appears broken:** the IFacet control-func counts and the architecture-test loupe assertions are tied to the current Pendle selectors. They will diverge once the cuts change.
- **Impact class:** CI / test matrix drift.
- **Fix direction:** §6 lists every change. The implementer updates the test files in lockstep with the production cuts.
- **Confidence:** high — every change is mechanical and observable in the test files read.

### F6 — Files examined with no defect (no change required for this PRD)

Listed at the top of this review. Twenty-three V4 family files have no SY selector surface and require no change for the interface switch. The shared SY files (seven files) are explicitly preserved per the owner ruling. The `LocalCreditLib.sol` and `ISecurePullErrors.sol` files are unchanged; they continue to back the redeem pretransfer rule.

---

## 10. Closure summary

- This PRD's interface change touches exactly **5 production files** in the legacy V4 family and **6 test files** that consume the legacy V4 surface.
- It adds **0** new selectors, removes **8** selectors (4 from IN facet, 6 from query facet, where 2 are the same selector `redeem` re-declared under the new interface), and changes **1** selector signature (`deposit`).
- It does not redesign any other family and does not modify any shared SY declaration file.
- The pretransfer mapping is fixed by §5 (five rules, no implementer discretion).
- The package's `facetInterfaces()` keeps its 15-entry shape; only the entry at index 13 changes from `IStandardizedYield` to `IERC5115_StandardizedYield`.
- The package's `facetCuts()` and `facetAddresses()` keep their 16-entry shape.
- A later facet split for runtime-size targets is out of scope and follows after this interface change is in place, per the coordinator's "Size is measured after this interface change" rule.

---

I did not run Forge.