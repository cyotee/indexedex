# Exact CP transition-quote remediation design

**Status: proposed and unimplemented.** This document records the remaining implementation dependency for exact raw/pair CP deposit previews. It is not an approval requirement or a deployment-readiness statement. No production implementation or runtime validation of this design has occurred.

## Confirmed problem and evidence

The selected package is `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`. Production filenames abbreviated below use the prefix `UniswapV4SingleStandardExchangeBufferConstantProductHook`.

- `DepositPreviewTarget.sol`, `previewDepositSingle`, clamps and prices additions against pre-swap reserves; execution in `DepositCommon.sol`, `_proportionalAddAfterZap`, uses post-swap reserves. Correcting currency-order subtraction in execution does not resolve this preview defect.
- `ClaimLib.sol`, `_claimIn`, projects aggregate claim using proportional arithmetic. In [fee-capital-rounding-trace.log](evidence/fee-capital-rounding-trace.log), the raw/pair growth regression quotes pair claim delta `10978032956054934078` and LP `10008306762287216147`; execution obtains delta `10978032956054934077` and LP `10008306762287216146`. Reserves and fee-adjusted supply agree. The one-unit overquote triggers `InsufficientLpOut()` when the public preview is used as the minimum.
- That focused run passed three tests and failed the raw/pair growth test. The corrected SE-share preview now passes: transferring existing SE shares changes holder balance without changing conversion state, so current-state aggregate-claim differences suffice for that separate path.

The CP PRD requires post-inventory reserve reads, pre-intake protocol fee accrual, and SE-aware previews (`D43`, `D45`, `D61`, `D73`, `D78`, and section 4.1). Its scope permits qualifying SE implementations beyond the ERC4626 wrapper (`D4`/`D63T`); the wrapper is the prescribed test integration, not a universal production conversion model. See `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md` in the package directory.

## Missing capability

`lib/crane/contracts/interfaces/IStandardExchangeIn.sol` and `IStandardExchangeOut.sol` quote one exchange in current state. They do not return hypothetical conversion state or the holder's aggregate claim after that exchange. Calling the current preview repeatedly therefore cannot quote a second buffer operation against the state left by an earlier unwrap or buffer.

Add a separate optional interface, without changing the existing exchange interfaces:

```solidity
enum Operation {
    BufferPairExactIn,
    UnwrapPairExactOut,
    UnwrapSeExactIn
}

function quoteState(address holder)
    external view
    returns (bytes memory state, uint256 aggregateClaim);

function quoteTransition(
    bytes calldata state,
    Operation operation,
    uint256 amount
) external view returns (
    bytes memory nextState,
    uint256 amountIn,
    uint256 amountOut,
    uint256 aggregateClaimAfter
);
```

These signatures are a design sketch, not a finalized interface or selector commitment. The opaque state binds the SE, pair asset, holder, relevant fee context, holder share balance, SE backing/supply, and downstream conversion state. Each returned state must support another transition without consulting unchanged live balances in place of projected balances. The quote domain is holder-funded buffer/unwrap routes used by this CP hook; outputs and newly minted SE shares return to that holder. Other recipients/routes are outside this initial capability.

Malformed, incompatible, or unsupported state must fail explicitly. Quotes do not authorize transfers or execution; execution still enforces its existing caller, minimum, maximum, and deadline rules. Interface detection must identify support without inferring it merely from `protocolVault()` being callable.

## ERC4626 wrapper projection

Let `H` be holder SE shares, `S` total SE supply, and `V` the protocol-vault shares held by the SE. Current aggregate claim is computed with the actual layered conversion:

```text
vaultShares = floor(H × V / S)
claim = protocolVault.previewRedeem(vaultShares)
```

The implementation must preserve the zero-supply/first-mint branches and checked arithmetic used by the existing wrapper.

For pair buffer amount `a`, project the actual protocol-vault deposit to obtain vault shares `d`. User SE shares are `q = floor(d × S / V)` with the existing first-mint branch. Existing dilution adds `f = floor(q × usageFee / 1e18)` only when applicable. Update `V`, `S`, holder shares, and the downstream vault state before evaluating the new aggregate claim. Account for fee shares also reaching the holder if the holder equals `feeTo`.

For exact-input unwrap, project the existing floor conversion from burned SE shares to redeemed protocol-vault shares, then the actual vault redemption and remaining aggregate claim.

For exact-output unwrap, preserve the implementation in `contracts/vaults/standard/erc4626/ERC4626StandardExchangeOutTarget.sol`:

1. Compute required protocol-vault shares using `previewWithdraw(requestedPair)`.
2. Round required SE shares upward.
3. Convert those SE shares back to protocol-vault shares with the existing floor operation.
4. **Redeem** those vault shares, rather than withdrawing the requested pair amount directly.

The actual pair receipt can exceed the requested output. CP measures that receipt in `_unwrapPairLeavingDust`; the transition quote must return the same actual output, not merely echo the requested amount. It must also permit the hook to select its existing capped exact-input fallback when required SE shares exceed spendable shares.

### Why generic vault snapshots are insufficient

`IERC4626.totalAssets()` and `totalSupply()` alone do not specify conversion behavior. Implementations may use virtual assets/shares, decimal offsets, entry/exit fees, implementation-specific rounding, or conversion state beyond those two totals. Even a proportional vault can change its ratio through deposit/redeem rounding; the wrapper then applies another rounded conversion. Collapsing these stages into one aggregate fraction loses information, as the trace demonstrates.

The wrapper therefore needs an exact downstream transition provider or an adapter tied to a supported vault implementation. That provider must project deposit/redeem conversion and subsequent hypothetical previews, including relevant limits and fees. Generic `IERC4626` does not expose this capability. A formula validated against `SimpleYieldERC4626` alone must not be presented as valid for every ERC4626 vault.

Executing and reverting mutations is also not a replacement for this view interface: existing on-chain preview callers use static calls, which prohibit those mutations. A separate non-view simulation quoter would have a different integration contract.

## CP integration sequence

1. Read the initial raw reserve and aggregate SE claim; calculate pending protocol LP from that pre-intake book.
2. Project the internal swap using the existing CP sale calculation and the exact transition provider. Preserve the spendable-SE cap, fallback behavior, actual unwrap receipt, and currency-decimal rounding.
3. Reconstruct post-swap reserves. Raw input gives `rawAfterSwap = rawBefore + soldRaw`; pair input gives `rawAfterSwap = rawBefore - rawOut`. Obtain `pairAfterSwap` from the transition's aggregate claim, not by assuming claim decreases exactly by pair received.
4. Clamp proportional additions against those post-swap reserves, preserving currency-order flooring.
5. Project the subsequent pair buffer against the returned state, producing `finalClaim`.
6. Compute LP from the mint-time deltas:

```text
LP = min(
    addedRaw × feeAdjustedSupply / rawAfterSwap,
    (finalClaim − pairAfterSwap) × feeAdjustedSupply / pairAfterSwap
)
```

Use the production decimal normalization rules; the displayed ratios assume equivalent exact scaling. The existing policy retains all added raw in inventory, including unused raw budget. Pair-dust buffering after LP mint remains outside these mint-time deltas.

For ordinary raw/pair deposits, only one buffer transition is needed. Existing-SE-share deposits continue to use current-state aggregate claim differences because no SE mint/burn or downstream conversion occurs.

`ClaimLib` supplies execution's pair-input CP quote as well as previews. Preview and execution must use the same chosen claim-in calculation. Replacing only the preview's claim model would introduce another mismatch. Any revised quote must still respect the PRD prohibition on re-quoting the CP trade after actual buffering.

## Compatibility and bounded implementation scope

- The new interface can be ABI-additive, through an SE quote facet or a supported adapter. Facet metadata, routing, package deployment, artifact reachability, and size gates must accompany any implementation.
- Requiring the capability for all existing bound SEs changes supported semantics. Preserve existing exchange ABI; identify and document which deployments support exact transition quotes. An unsupported provider must not receive an approximate fallback labeled exact.
- Implementing the ERC4626 wrapper provider does not automatically support every underlying vault. A supported downstream transition implementation remains necessary.
- This design does not change fee rates, recipients, protocol-growth timing, dust policy, or the semantics of `joinSingleAssetExactOut`, which currently spends its configured maximum and checks a minimum LP bound. Finding a minimal input for exact LP output is a separate issue.
- Do not subtract a constant haircut, loosen equality assertions, assume a fixed exchange rate, or mint the quoted LP regardless of actual reserve contribution to make the regression pass.

## Required exact property tests

Tests must use the registered CP package and real ERC4626 SE, with supported non-SUT underlying fixtures/adapters. No SUT mocks or storage overrides substitute for these checks.

1. **Each transition:** from identical initial state, compare quoted input/output, minted or burned SE shares, fee-share issuance, and aggregate holder claim with actual execution. Include initial supply, existing supply, yield, dilution fees, and rounding boundaries.
2. **Sequential transitions:** compare projected unwrap-then-buffer and buffer-then-buffer states with actual sequential execution. Assert the intermediate and final aggregate claims exactly; isolated current-state quote tests are insufficient.
3. **Exact-output receipt:** exercise rounded-up SE input where actual redeemed pair exceeds the requested output; assert the quote returns actual receipt. Cover the spendable-share cap and exact-input fallback separately.
4. **CP raw/pair deposits:** keep the failing real-growth regression's exact public preview/LP/used-amount comparisons, with the preview supplied as the execution minimum. Test both currency orders, unequal decimals/reserves, fees on/off, growth, and no-growth capital intake.
5. **CP single deposits:** compare sale amount, actual other-token receipt, proportional intake, LP, and pre-intake protocol fee exactly across both inputs and currency orders. Check ordinary live pools and existing owner-only dust/last-exit branches. Use an independent reserve/intake oracle, including retained raw and post-mint pair dust.
6. **Quote bounds and rollback:** quoted minimum succeeds; a minimum above independently established actual output reverts atomically. Verify LP, token balances, fee balances, and relevant reserves remain unchanged after rejection.
7. **Compatibility failures:** malformed state, state/provider mismatch, and unsupported downstream implementations fail explicitly. Test fee-recipient/holder coincidence and ensure quotes confer no execution authority.
8. **Integration gates:** compile production artifacts before runtime tests, validate new selector routing and deployment, measure actual facet/runtime sizes, and rerun the existing fee, callback, and reserve-order regressions. Preserve the distinction between a focused passing matrix and complete protocol coverage.

No exact-preview completion claim is justified until these properties pass against the implemented transition capability and its supported downstream vaults.
