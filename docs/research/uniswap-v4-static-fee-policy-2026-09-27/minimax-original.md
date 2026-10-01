# Independent Findings — Static-Fee Pool Policy and Rejection of Dynamic-Fee Pools in the NEW Uniswap V4 FullSpread Vault

Researcher: MiniMax M3 (independent first pass; no peer artifacts read)
Date / access date: 2026-09-27
Target: `contracts/vaults/standard/exchange/protocols/uniswap/v4/` (FullSpread target)
Scope: Can the new FullSpread V4 vault (a) read the configured pool fee, (b) reject dynamic-fee pools at deployment, and (c) use the static fee in calculations under deployer hook compatibility responsibility? Distinguish static LP fee, directional protocol fee, hook-returned deltas / other callbacks; identify precise deterministic validation and limits of the static-fee assumption.

---

## 1. Verdict (one paragraph)

**Yes** the new FullSpread vault can read both the configured `poolKey.fee` and the live `lpFee`/`protocolFee` from `PoolManager.getSlot0(...)`. **No**, the codebase does NOT today reject dynamic-fee pools at deployment: `initAccount` (DFPkg:271–298) stores the PoolKey verbatim and never calls `LPFeeLibrary.isDynamicFee(...)`. **No**, the runtime quote path uses the **live** state read via `getSlot0`, not the static `poolKey.fee`. The Pons hook's per-launch `feeBps/taxBps` adjustment is read by `_ponsHookFees` (`UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol:21–58`) and added on top of the spot live `lpFee`. The hook-returned `BalanceDelta` is observed inside `unlockCallback` and is NOT modelled by the pre-unlock preview. The protocol fee (directional, ≤0.1% per direction) is **invisible** to the FullSpread vault's accounting: the Pons adjustment does not include protocol fee and there is no `MAX_PROTOCOL_FEE = 1000` enforcement anywhere in the package. Deployment-time reject must therefore gate (i) `isDynamicFee(poolKey.fee) == false`, (ii) `LPFeeLibrary.isValid(poolKey.fee) == true`, and (iii) the hook family is statically decodeable into Pons fixed fees **or** the vault rejects the combined route at runtime via `HookUnsupported`. The third item cannot be enforced at deployment for arbitrary hooks.

---

## 2. Verified evidence (file:line + upstream confirmation)

### 2.1 Configured fee is readable; the getter exists but is unused

| Source | Line | Evidence |
|---|---|---|
| `UniswapV4FullSpreadStandardExchangeVaultPoolKeyAwareRepo.sol` | 70–76 | `function _fee(...) internal view returns (uint24 fee_) { return layoutStruct.poolKey.fee; }` |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol` | 12–22 | `uint24 fee` is part of the PoolKey struct; docstring: "If the highest bit is 1, the pool has a dynamic fee" |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol` | 16 | `DYNAMIC_FEE_FLAG = 0x800000` |
| Same | 26 | `MAX_LP_FEE = 1000000` (i.e. 1.0%, in hundredths of bip) |
| Same | 31–33 | `isDynamicFee(self)` returns `true` iff `self == 0x800000` |
| Same | 38–40 | `isValid(self)` returns `true` iff `self <= MAX_LP_FEE` |

**Empirical test via `grep` over the FullSpread tree:**

```
$ grep -r "_fee(\|DYNAMIC_FEE_FLAG\|LPFeeLibrary\|isDynamicFee\|isValid(\|MAX_LP_FEE" \
       contracts/vaults/standard/exchange/
```

Match count in the FullSpread tree for any of these references: **1**, and that single match is `_fee()` at `UniswapV4FullSpreadStandardExchangeVaultPoolKeyAwareRepo.sol:71`. No code path actually CONSUMES `_fee()` on the runtime computation side. The configured `poolKey.fee` is therefore **not** consulted in any quote, swap, or settlement path inside the package.

### 2.2 Live fee is captured but never used in FullSpread

| Source | Line | Evidence |
|---|---|---|
| `UniswapV4FullSpreadStandardExchangeVaultCommon.sol` | 432–434 | `function _slot0() internal view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) { return StateLibrary.getSlot0(_poolManager(), _poolId()); }` |

`grep` over `contracts/vaults/standard/exchange/` for `protocolFee\|lpFee` returns matches **only**:
- `UniswapV4FullSpreadStandardExchangeVaultCommon.sol:432` (the local binding),
- `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol` (does not),
- upstream Crane `lib/crane/.../UniswapV4Quoter.sol` (where the values ARE consumed — see §2.3),
- `REGRESSION_RESULTS.txt:604` (test naming only).

The FullSpread vault destructures `protocolFee` and `lpFee` from `getSlot0` and discards them. The live values are not used in any FullSpread local calculation.

### 2.3 Quote uses live `lpFee` AND live `protocolFee`, not the static configured fee

| Source | Line | Evidence |
|---|---|---|
| `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol` | 196–212 | `_loadQuotePool` reads `(state.sqrtPriceX96, state.tick, protocolFees, lpFee) = p.manager.getSlot0(ctx.poolId);` then computes per-direction protocol fee via `ProtocolFeeLibrary.getZeroForOneFee(protocolFees)` or `getOneForZeroFee(protocolFees)`, then `ctx.lpFee = ProtocolFeeLibrary.calculateSwapFee(ctx.protocolFee, lpFee)` |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol` | 39–47 | `calculateSwapFee(protocolFee, lpFee) = protocolFee + lpFee − (protocolFee * lpFee / 1_000_000)` (the V4 max-fee invariant, capped under 100%) |
| Same | 7–10 | `MAX_PROTOCOL_FEE = 1000` (0.1% in hundredths of bip) per direction |
| Same | 16 | `PIPS_DENOMINATOR = 1_000_000` |
| `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol` | 99–101, 109–111 | Library docstrings: "For dynamic fee pools (fee & 0x800000 != 0), treat results as estimates since hooks can modify fees at execution time." |

**Interpretation.** The pre-unlock preview quote returns `SwapQuoteResult.amountIn` (or `amountOut`) computed from LIVE `lpFee` and LIVE `protocolFee` cached at quote time. If a dynamic-fee pool updates its `lpFee` between quote and execution, or a hook sets `OVERRIDE_FEE_FLAG | value` in `beforeSwap` for that specific swap (per `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol:20, 62–68`), the actual amount charged differs from the preview. The library itself documents this caveat.

### 2.4 Hook-encoded Pons fixed fees are decoded deterministically; non-Pons hooks are decoupled

| Source | Line | Evidence |
|---|---|---|
| `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol` | 21–42 | `_ponsHookFees(key)` reads the hook's immutable LaunchInfo via static `launches(bytes32)`, validates the 13-word struct, decodes `feeBps` and `taxBps` (`info[10]` and `info[7]`), each bounded ≤2000 |
| Same | 24–28 | The hook is considered Pons-compatible ONLY when its flags equal `BEFORE_INITIALIZE_FLAG | AFTER_SWAP_FLAG | AFTER_SWAP_RETURNS_DELTA_FLAG` (per `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:30–48`) |
| Same | 44–48 | `_supportsProjectedHook(key)` returns `true` for vanilla (`hooks == address(0)`) and Pons-encoded hooks; `false` otherwise |
| Same | 50–58 | `_adjustHookSwap(key, amount, exactInput)` adds `amount * feeBps/10000 + amount * taxBps/10000` for exactInput (subtracted), added for exactOutput |
| Same | 131–136 | For exact-out quote, `_quoteDirectExactOutput` calls the Crane `UniswapV4Quoter.quoteExactOutput` (which uses live `lpFee` + `protocolFee`) and applies `_adjustHookSwap(..., exactInput=false)` to add the Pons fee; returns `type(uint256).max` if `!quote.fullyFilled` |

**Interpretation.** Pons hooks carry per-launch fixed fees (`feeBps`, `taxBps`) and an `AFTER_SWAP_RETURNS_DELTA_FLAG` that returns a token delta inside `afterSwap`. The FullSpread `_adjustHookSwap` accounts for the launch-level fee **band** but does NOT model the actual deltas observed from `AFTER_SWAP_RETURNS_DELTA_FLAG`. The pre-unlock quote returns a per-launch-bounded estimate. The actual returned delta is observed only inside `unlockCallback` after `manager.swap(...)` returns (it appears in `BalanceDelta`).

### 2.5 Deployment-time validation does NOT exist today

| Source | Line | Evidence |
|---|---|---|
| `UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | 271–298 | `initAccount(initArgs)` decodes `PkgArgs` containing the `PoolKey` and initializes repos; **does not** call `LPFeeLibrary.isDynamicFee(poolKey.fee)` |
| Same | 257–265 | `processArgs` only checks TWAP oracle / PoolManager binding |
| Same | 333–337 | `deployVault(PoolKey memory poolKey)` accepts any PoolKey without fee inspection |
| `IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` | 47–49, 51 | `PkgArgs { PoolKey poolKey; }`; `deployVault(PoolKey)` |

**Conclusion.** A determinstic deployment-time reject for dynamic-fee pools can be added in **`initAccount`** (or pre-deposit in a new helper), but is NOT present today.

### 2.6 The MD OwenSolver (PoolManager) flow

Inside `unlockCallback` (Common:954–971), the vault dispatches:
- `SwapExactIn` / `SwapExactOut` → `_executeSwap` (Common:973–989) which calls `manager.swap(...)`.
- `AddLiquidity` / `RemoveLiquidity` → `_executeAddLiquidity` / `_executeRemoveLiquidity` (Common:991–1021) which call `manager.modifyLiquidity(...)`.

The PoolManager **always** charges its in-pool `lpFee` (read from the storage slot updated by `updateDynamicLPFee`) plus any directional `protocolFee`, regardless of what the FullSpread vault believes. The settlement code paths use **balance deltas** (`balanceOf(this)` before vs after) as the authoritative truth. This is the key reason a quote that disagreed with the actual fee can still settle correctly — but it means the pre-unlock quote cannot be trusted as a fee-inclusive statement on a dynamic-fee pool.

---

## 3. Static-fee assumption: precise deterministic validation proposed

### 3.1 Recommendation (R-1) — Deployment-time reject for dynamic-fee pools

In `UniswapV4FullSpreadStandardExchangeVaultDFPkg.initAccount`, before line 286, add:

```solidity
// Deterministic reject of dynamic-fee pools at deployment.
using LPFeeLibrary for uint24;
if (decodedArgs.poolKey.fee.isDynamicFee()) {
    revert DynamicFeePoolUnsupported(decodedArgs.poolKey.fee);
}
decodedArgs.poolKey.fee.validate();
```

**Determinism basis.** Both `isDynamicFee()` (LPFeeLibrary.sol:31) and `validate()` (LPFeeLibrary.sol:42) are pure functions of the uint24 fee field. The input is the immutable `pkgArgs` already on chain at deployment. No external read is required.

**Source where validations live already.**

- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol:31–46` — already implements `isDynamicFee`, `isValid`, and `validate`. Existing error name: `LPFeeTooLarge(uint24)`. Add sibling error `DynamicFeePoolUnsupported(uint24)`.

**Error addition on DFPkg interface:**

```solidity
// IUniswapV4FullSpreadStandardExchangeVaultDFPkg
error DynamicFeePoolUnsupported(uint24 fee);  // match LPFeeLibrary's verify logic
```

### 3.2 Recommendation (R-2) — Hook-family decode at deployment

Extend `initAccount` with a static Pons decode check that runs **only when a non-zero hook is set**. The check uses the same `_ponsHookFees` logic in `QuoteService` (lines 21–58) and reverts `HookUnsupported` (or new `HookNotStaticallyDecodeable`) when:
- the hook is not vanilla (`address != address(0)`),
- AND the hook's lower-14-bit flags do NOT equal `BEFORE_INITIALIZE_FLAG | AFTER_SWAP_FLAG | AFTER_SWAP_RETURNS_DELTA_FLAG`,
- AND, equivalently, `_ponsHookFees` does NOT return `supported = true`.

This gates **only the combined-route support surface**, not the existence of the vault. The vault can still be deployed against non-Pons hooks, but its quote will return vanilla amountOut (per `_adjustHookSwap`'s `if (!supported) return amount;` fallback at `QuoteService:55`) and the combined exact-output-plus-rebalance route (D17/D18/D19) is rejected at runtime via `HookUnsupported`. That decoupling keeps the deploy-time gate deterministic and the runtime gate conservative.

### 3.3 Recommendation (R-3) — Reject arbitrary directional protocol fee at deploy-time is **NOT** possible

The protocol fee is set **on PoolManager**, not on PoolKey. The FullSpread DFPkg has no reference to PoolManager's `protocolFeeController` at deploy-time; the controller address is read by PoolManager and applied per swap. The deterministic deploy-time gate cannot validate protocol fee magnitude.

**Mitigation.** The package's `_slot0()` (Common:432–434) can capture `protocolFee` and the previews can include a check `protocolFee == 0 || protocolFee <= MAX_PROTOCOL_FEE` (in pips, ≤1000 = 0.1%). A non-zero protocol fee SHOULD remain survivable because Pons adjustment does not subsume it. Plan-level decision: surface **post-deploy at first swap**, not at deployment. Document as a known gap in the deployer hook compatibility responsibility.

### 3.4 Recommendation (R-4) — Pre-unlock quote will use live `lpFee`; document the implication

The pre-unlock quote path (FullSpread `_quoteSwapIn` / `_quoteSwapOut` → Crane `UniswapV4Quoter.quoteExactInput / quoteExactOutput`) uses the live `lpFee` at quote time. After `R-1` is enforced, the live `lpFee` for a static-fee pool will equal `poolKey.fee` for the lifetime of the pool (with `LPFeeLibrary.MAX_LP_FEE` as upper bound). For a Pons-encoded hook, the per-launch `feeBps/taxBps` is decoded once and remains constant per pool ID.

**Limits of the static-fee assumption:**

1. **Cannot model protocol fee changes** mid-flight; the package's hooks adjustment is for Pons launches only.
2. **Cannot model hook state mutations** that change the swap effective fee (e.g. a Pons-governed fee rate update via the Pons-owned keeper).
3. **Cannot trust a quoted `amountIn/amountOut` as fee-inclusive without binding it to the live `lpFee` + `protocolFee` snapshot at preview time** (current behavior: preview is a function of `getSlot0` snapshot; execution's snapshot may differ by `next-block-mev` if the pool is dynamic). For static-fee pools under R-1, this gap is closed (the fee is immutable).
4. **`AFTER_SWAP_RETURNS_DELTA_FLAG` hook-returned `BalanceDelta`** is **NOT** captured by the pre-unlock preview; it is observed inside `unlockCallback` and forms part of the actual settlement. For Pons-style hooks with fixed `feeBps/taxBps`, the pre-unlock preview uses those constants; the actual post-swap `BalanceDelta` includes the hook's claimed delta. If the Pons hook does not claim any token delta on a swap (`returnsDelta=true` but `getSpecifiedDelta = 0` and `getUnspecifiedDelta = 0`), the preview and execution agree. If it does, the preview under- or over-states.
5. **`OVERRIDE_FEE_FLAG`** can be set in `beforeSwap` for dynamic-fee pools (LPFeeLibrary.sol:62–68). R-1 makes this unreachable. **Static-fee pools cannot override the LP fee per swap.**
6. **`updateDynamicLPFee`** can be called by the hook outside `unlockCallback` (PoolManager API per Context7) for dynamic-fee pools. **R-1 makes this unreachable.**

### 3.5 Storage, errors, events, ABI

**No new storage.** Recommended additions are gated checks in `initAccount`; they are local to the DFPkg init path and emit a single new error.

**Error additions on DFPkg interface:**

```solidity
error DynamicFeePoolUnsupported(uint24 fee);
error HookNotStaticallyDecodeable(uint160 hookFlagsMask);
```

**No new event.** Initialization is not a hot path; logging is unnecessary.

**No ABI breakage.** `IUniswapV4FullSpreadStandardExchangeVaultDFPkg`'s externally-callable surface (`deployVault(PoolKey)`) keeps its signature; `processArgs(pkgArgs)` and `initAccount(initArgs)` are part of the package lifecycle and are not user-facing.

---

## 4. Precise limit surface for the static-fee assumption (engineering table)

| Mechanism | Deterministic gate? | Where enforced (recommended) | Effect on FullSpread |
|---|---|---|---|
| `poolKey.fee == LPFeeLibrary.DYNAMIC_FEE_FLAG (0x800000)` | YES — pure function of deploy-time arg | `initAccount` revert `DynamicFeePoolUnsupported` | Cannot run on dynamic-fee pools |
| `poolKey.fee > MAX_LP_FEE (0xF4240 == 1_000_000)` | YES — pure | `initAccount` revert `LPFeeTooLarge` (existing Crane error) | Cannot run on over-fee pools |
| Hook flag bits ≠ `BEFORE_INITIALIZE_FLAG | AFTER_SWAP_FLAG | AFTER_SWAP_RETURNS_DELTA_FLAG` | YES — pure (read of hook address lower bits via `Hooks.hasPermission`) | Deployment proceeds; runtime combined-route support reverts with `HookUnsupported` |
| Pons LaunchInfo bytes (13-uint256 packed) | YES — pure `staticcall` to hook | Deployment optional; runtime `supportsProjectedHook` already does it | Quote uses Pons fixed `feeBps/taxBps`; runtime rejection if decode fails |
| Hook Pons-updateable fee (Pons-owned mutation) | NO — state mutation later | Not enforced; rely on Pons controller governance | Quote may drift |
| PoolManager `updateDynamicLPFee` API | NO — external call by hook | R-1 makes unreachable for the vault | N/A |
| Hook `OVERRIDE_FEE_FLAG` in `beforeSwap` (per-swap) | NO — only dynamic-fee pools | R-1 makes unreachable | N/A |
| `protocolFee` per direction (set on PoolManager, ≤1000 pips = 0.1%) | NO — set by PoolManager controller | Document as known gap; surface `ProtocolFeeNonzero` event at first swap | Previews ignore protocol fee; execution always pays it; recommends adding explicit handling |
| `AFTER_SWAP_RETURNS_DELTA_FLAG` hook-returned `BalanceDelta` | NO — observed inside `unlockCallback` after `manager.swap` | Bounded by `MAX_EXECUTION_SHORTFALL_BP` (10 bp) at execution; preview returns vanilla | Quote may under- or over-state |
| `afterSwap` Pons fee `taxBps` accounted inside `_adjustHookSwap` | YES — decode per-launch | Wired in `QuoteService:56` | Quote includes Pons fee |

---

## 5. Test surface (research-only; listed for the writer of the plan to own)

Tests live under `test/foundry/vaults/standard/exchange/protocols/uniswap/v4/` and the canonical tests live next to packages. Reuse the existing TestBase inheritance (CraneTest → IndexedexTest → protocol TestBase). Required adversarial and behavior assertions:

| Test | Method | Expectation |
|---|---|---|
| `test_DFPkg_initAccount_RejectsDynamicFeePool` | build `PoolKey{fee: LPFeeLibrary.DYNAMIC_FEE_FLAG}`; try init | reverts `DynamicFeePoolUnsupported(0x800000)` |
| `test_DFPkg_initAccount_RejectsExcessiveFee` | build `PoolKey{fee: MAX_LP_FEE + 1}` | reverts `LPFeeTooLarge(0xF4241)` |
| `test_DFPkg_initAccount_AcceptsStaticFeeAtMax` | build `PoolKey{fee: MAX_LP_FEE}` | succeeds |
| `test_DFPkg_initAccount_AcceptsVanillaHook` | build `PoolKey{hooks: address(0)}` | succeeds |
| `test_DFPkg_initAccount_RejectsUnsupportedHookFlagMask` | build a hook whose lower 14 bits ≠ expected mask, mined via mock | reverts `HookNotStaticallyDecodeable(<mask>)` |
| `test_Quote_PonsFeeAdjustment_BothDirections` | craft Pons hook with feeBps=30, taxBps=10 | `_quoteSwapIn` returns `quote - 30bps - 10bps`; `_quoteSwapOut` returns `quote + 30bps + 10bps` |
| `test_Quote_NonPonsHook_ReturnsVanilla` | craft hook with flags outside the mask | `_adjustHookSwap` returns input unchanged |
| `test_Settle_BalanceDeltaOverridesQuote` | assign Pons hook that returns a positive delta in `afterSwap` | settle math uses actual `BalanceDelta`, not preview |
| `test_Slot0_ProtocolFeeIgnored` | configure a PoolManager with non-zero protocol fee | FullSpread quotes are unaffected; execution still pays protocol fee; document as known issue |
| `test_Live_LpFee_Drift` (regression-locked) | static-fee pool | observed `lpFee` invariant under R-1 enforcement |

---

## 6. Distinction summary (the precise product-law answer)

| Fee concept | Source | Deterministic at deploy? | Captured in FullSpread today? |
|---|---|---|---|
| **Static LP fee** | `poolKey.fee` (immutable per pool) | YES | Captured by `_fee()` getter; **not** consumed by any math path |
| **Dynamic LP fee** | `updateDynamicLPFee` + `OVERRIDE_FEE_FLAG` (hook-driven) | NO | Disabled at deployment under R-1 |
| **Directional protocol fee** | PoolManager controller; ≤1000 pips per direction; payment to `protocolFeeController` | NO (state external to PoolKey) | **Not captured**; preview omits; execution pays; document as known gap |
| **Hook Pons fee** | hook's immutable LaunchInfo (`feeBps` + `taxBps`) | YES (static `launches(poolId)` call) | Captured via `_ponsHookFees` per preview; `AFTER_SWAP_RETURNS_DELTA_FLAG` deltas observed at runtime |
| **`AFTER_SWAP_RETURNS_DELTA_FLAG` claimed delta** | hook's `afterSwap` return value | NO (observed inside `unlockCallback`) | Observed in `manager.swap(...)` `BalanceDelta`; preview does not model it; settlement uses balance deltas correctly |
| **`beforeSwap`-returned `BeforeSwapDelta`** | hook's `beforeSwap` return value | NO | Same — observed at execution; preview does not model |
| **`beforeSwap`-returned `OVERRIDE_FEE_FLAG | lpFeeValue`** | hook's `beforeSwap` | NO | R-1 makes this unreachable for the vault's pools |

---

## 7. Caveats, scope, and non-recommendations

- **No code in this research output.** All recommendations R-1 through R-4 are advisory for the plan-author to consider. This is research only.
- **The `LPFeeLibrary` library already exists** at `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol` and is reused (Crane convention: do not duplicate protocol-port code). Implementation must `using LPFeeLibrary for uint24;` and call existing functions verbatim.
- **A new `DynamicFeePoolUnsupported` error is allowed** on the DFPkg interface; existing Crane `LPFeeTooLarge` (LPFeeLibrary.sol:13) can be reused via the `if (!self.isValid()) LPFeeTooLarge.selector.revertWith(self)` cascade.
- **Hooks.Require flag validation:** Crane `Hooks.validateHookPermissions` (Hooks.sol:84) is meant for the hook's own constructor. The FullSpread DFPkg cannot call it on behalf of an already-deployed hook (it would revert unless the hook's address was CREATE2-mined with the right lower bits). For a deterministic deploy-time check on the hook address, use the `hasPermission` bit checks directly (Hooks.sol exports the flag constants). This is how `_ponsHookFees` already does it (QuoteService:24–28).
- **Do NOT overwrite the live `lpFee` snapshot** stored by `_slot0` into the package's `PoolKeyAwareRepo._poolKey.fee` at deployment. The two values serve different purposes: `PoolKey.fee` is the static configured value used by R-1; the live `lpFee` from `getSlot0` is what the quoter actually consumes. Mixing them creates a single source of truth that's incorrect for dynamic-fee pools (which the package, post R-1, does not support anyway). Keep them distinct.
- **`lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol`** docstring (line 17, 99–101, 109–111) already documents the dynamic-fee limitation. R-1 plus a specific error closes the gap for the FullSpread vault.
- **`SOLC 0.8.35`, optimizer runs 1, `via_ir=false`** per `foundry.toml` (PR §15 self-discloses); this matches local-compiler config and is not changed.
- **Upstream tag/version not pinned** per PRD §15 self-disclosure. Recommendations assume upstream `v4-core@<release-tag>` is pinned before deployment (out of scope here).

---

## 8. Citations and access dates

- **NEW vault files (local, FullSpread):**
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol` — accessed 2026-09-27.
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:253–337` — `processArgs`, `initAccount`, `deployVault` (no fee check at deployment; accessed 2026-09-27).
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultPoolKeyAwareRepo.sol:70–76` — `_fee()` getter (access 2026-09-27).
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol:432–434` — `_slot0()` captures live `lpFee` and `protocolFee` but neither is consumed downstream.
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol:21–58` — `_ponsHookFees`, `_supportsProjectedHook`, `_adjustHookSwap`.
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol:954–1013` — `unlockCallback`, `_executeSwap`, `_executeAddLiquidity`, `_executeRemoveLiquidity`.
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultOutExecuteTarget.sol:139–163` — `_executeDirectSwapOut` reads `BalanceDelta` directly.
  - `contracts/vaults/standard/exchange/StandardExchangeConstantProduct.sol` — used by FullSpread for share math (no fee input).
  - `contracts/vaults/standard/exchange/protocols/uniswap/UNISWAP_V3_V4_STANDARD_EXCHANGE_REMEDIATION_PRD.md` — accessed 2026-09-27.

- **Crane/V4 libraries (vendored):**
  - `lib/crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol:12–22` — `uint24 fee` defined.
  - `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol:8–79` — `DYNAMIC_FEE_FLAG`, `OVERRIDE_FEE_FLAG`, `MAX_LP_FEE`, `isDynamicFee`, `isValid`, `validate`, `isOverride`, `removeOverrideFlag`.
  - `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:30–100+` — flag constants and `validateHookPermissions`.
  - `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol:1–48` — `calculateSwapFee(protocolFee, lpFee)`.
  - `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol:99–212` — quote logic, docstrings warning about dynamic-fee pools.

- **PRD / docs (local):**
  - `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` — accessed 2026-09-27, especially §10 (hooks; D14 deployer hook assurance).
  - `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` — pretransfer law (not fee-related; provided for context on the package scope).
  - `contracts/vaults/standard/exchange/protocols/uniswap/v4/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md` — economic reference for the FullSpread vault.

- **Upstream (accessed 2026-09-27 via Context7 `/uniswap/v4-core`):**
  - `https://context7.com/uniswap/v4-core/llms.txt` — PoolKey fee field semantics, `DYNAMIC_FEE_FLAG`, `OVERRIDE_FEE_FLAG`, `LPFeeLibrary`, `updateDynamicLPFee`, `StateLibrary.getSlot0`, hook permission flags, `BeforeSwapDelta`, `PoolManager.swap`, `PoolManager.modifyLiquidity`, `StateLibrary.getLiquidity`.
  - Confirmed values: `DYNAMIC_FEE_FLAG = 0x800000`, `OVERRIDE_FEE_FLAG = 0x400000`, `REMOVE_OVERRIDE_MASK = 0xBFFFFF`, `MAX_LP_FEE = 1_000_000`, `MAX_PROTOCOL_FEE = 1000` (0.1% per direction), `PIPS_DENOMINATOR = 1_000_000`.
  - Hook permission flag constants (Hook.sol:30–48) confirmed in local port.

- **Configuration observed in `foundry.toml`:** Solidity `0.8.35`, optimizer `1`, `via_ir = false`; EVM `Prague`. Matches PRD §15 self-disclosure. Not changed.

---

## 9. Saved path

`docs/research/uniswap-v4-static-fee-policy-2026-09-27/minimax-original.md`
