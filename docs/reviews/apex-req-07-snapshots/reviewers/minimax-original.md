# MiniMax M3 — REQ-07 / OD-02 snapshot investigation (replacement-session original)

- **Session:** Labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. Not continuity. Does not recall `ses_ebdf718feffemWQNf7wuTpapqX`.
- **Scope:** Owner question: are any IndexedEx vaults taking or keeping the snapshots discussed for REQ-07? Explain from current source.
- **Inputs read:** `StandardExchangeRateProviderFacet.sol` (172 lines, full), `vaults/standard/exchange/protocols/uniswap/v4/fullSpread/{ponsFamilyV2Hook,hookless}/*.sol`, `vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVault*.sol`.
- **No code edit. No PRD write. No Forge. No exploit procedures.**

---

## Headline — **No implementation gap.**

Three distinctions from current source:

### 1. A vault or hook that stores snapshot bytes in contract storage — **None found.**

I searched the entire `contracts/` tree for storage of `bytes` representing snapshot state. No vault or hook persists snapshot bytes in contract storage. The hook and vault files store:
- **`Portfolio` struct** (wings vault `UniswapV4UpperLowerWingsStandardExchangeVaultProjection.sol:41-55` and `Harvest.sol:41-55`) — the snapshot is built and returned as a memory struct via `function snapshot(...) public view returns (Portfolio memory book_)`, not stored.
- **`Position` struct** (e.g. `PositionRepo.sol:12` `bytes32 salt`) — stores a bytes32 salt, not the snapshot.
- **`Types.Snapshot` struct** (Pons/hookless `Common.sol:985-1022`) — built in memory inside `_snapshot(0, 0)` and returned as `Types.Snapshot memory state`, not stored.
- **`bytes32` keys** for storage slot calculation — not snapshot bytes.

The only `bytes` types in `IUniswapV4UpperLowerWingsStandardExchangeVaultTransitionTarget.sol:15` are the ephemeral `quoteState` parameters passed between calls, not stored state.

No `mapping(bytes => ...)`, no `bytes state` storage variable, no `Snapshot` struct stored in a `mapping`. Snapshot data lives only in memory during a single transaction.

### 2. A vault or hook that builds an ephemeral `quoteState` during a call — **Yes, extensively, but always in memory.**

All three FullSpread families (Pons, hookless) and the wings vault build an in-memory snapshot inside the same call and pass the bytes to the SE for a quote. These are not stored; they are passed forward as function arguments and discarded when the call returns.

Examples:
- **Pons hook** `UniswapV4FullSpreadPonsFamilyHookInBase.sol:59, 66, 114, 197, 272, 290, 364`:
  ```solidity
  Types.Snapshot memory state = _snapshot(0, 0);  // line 272
  ```
  or
  ```solidity
  Quotes.Params memory params = _quoteParams(_snapshot(0, 0), zeroForOne, entitlement);  // line 66
  ```
- **Hookless** `UniswapV4FullSpreadHooklessStandardExchangeVaultInBase.sol:59, 66, 114, 197, 272, 364` — same pattern.
- **Wings** `UniswapV4UpperLowerWingsStandardExchangeVaultProjection.sol:41-55`:
  ```solidity
  function snapshot(address asset_, address holder_) public view returns (State memory q_) {
      ...
      q_.book = Harvest.snapshot();
  ```

The snapshot is a `memory` struct, built by reading the current pool and vault state, passed to a `quoteAssets` or `quoteTotalSupply` call, and discarded when the call returns. There is no `mapping` or storage write of this data.

### 3. A rate provider that calls `quoteState` when `getRate` or empty-state `_getRate` is invoked — **No, the empty-state path does not call `quoteState`.**

`StandardExchangeRateProviderFacet.sol:45-47, 61-83`:

```solidity
function getRate() external view returns (uint256) {
    return _getRate("");
}
...
function _getRate(bytes memory state) private view returns (uint256) {
    StandardExchangeRateProviderRepo.Storage storage layoutStruct = StandardExchangeRateProviderRepo._layout();
    IERC20 subject_ = layoutStruct.rateSubject;
    if (address(subject_) == address(0)) {
        subject_ = IERC20(address(layoutStruct.reserveVault));
    }
    uint256 totalShares = state.length == 0 ? subject_.totalSupply()
        : IStandardExchangeTransitionQuote(address(layoutStruct.reserveVault)).quoteTotalSupply(state);

    if (totalShares == 0) {
        // D60 (2026-09-22): an empty Standard Exchange still has a well-defined initial mint rate.
        ...
        return _initialRate(subject_, layoutStruct);
    }
    ...
}
```

The empty-state path at line 67 is:
```solidity
uint256 totalShares = state.length == 0 ? subject_.totalSupply()
    : IStandardExchangeTransitionQuote(address(layoutStruct.reserveVault)).quoteTotalSupply(state);
```

When `state.length == 0` (empty state, the `getRate()` entry at line 46 passes `""`), the code reads `subject_.totalSupply()` directly from the token contract. It does NOT call `quoteState`. The `quoteTotalSupply(state)` call is on the alternative branch, which only runs when `state` is non-empty.

The `quoteRate` function at line 49-59 passes `state` through to `_getRate(state)`. It does not call `quoteState` itself.

So the current `StandardExchangeRateProviderFacet` empty-state path:
1. Does **not** call `quoteState`.
2. Does **not** read `gasleft()`.
3. Reads the live `totalSupply()` of the subject token directly.

This matches the OD-02 ruling at PRD:128-132: "Empty-state `getRate` and `_getRate` do not call `quoteState` and do not read remaining gas. The rate is the live preview path." The current source complies.

---

## Verdict — **No implementation gap.**

The owner is correct: vaults do not keep snapshots. Snapshots are built ephemerally inside a call, passed forward as function arguments, and discarded. The rate provider's empty-state path does not call `quoteState` and does not read `gasleft()`.

I did not run Forge.