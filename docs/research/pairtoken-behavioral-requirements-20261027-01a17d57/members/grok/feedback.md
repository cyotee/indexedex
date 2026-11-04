# Advisory feedback

## Identity

Reviewer: Grok. Run: pairtoken-behavioral-requirements-20261027-01a17d57. This is the single advisory pass. It does not replace the initial response, and it is not a rewrite of the draft.

## Draft under review

Identity: pairtoken-requirements-draft-r1. Path: `/Users/cyotee/Projects/indexedex/docs/research/pairtoken-behavioral-requirements-20261027-01a17d57/coordinator/draft.md`. SHA-256 recomputed this pass over the file bytes: `763dd6ad786ac84e61f968af77a627a2c0103a6fc6c67c8152127115083f229b` (80020 bytes). It matches the pinned fingerprint. The planner-facing baseline reviewed is that entire draft, without analyst material.

## Disposition

SUPPORT.

No change is requested. The draft is complete and accurate enough for a different agent to write a source-equivalent implementation plan without reading the target code. Parts I–III state the public surface, the integer contracts, the checkpoints, and the dependency limits. Where the source is quirky, the draft preserves the quirk instead of repairing it.

## Concerns

None.

## Dispositions of material original topics

Each topic below was checked against admitted `src/pair/PairToken.sol` in the frozen evidence bundle, plus the helper the formula names. Source text controls. These are not defects in the draft.

**Basket quote, not an offset mint.** PT-SCOPE-03, PT-QUOTE-01, PT-VIEW-02, PT-VIEW-03, and PT-DEP-04 match `_quoteShares` and `basket`. Supply zero or both reserves zero uses the checked product’s floor square root and selects both requested amounts. A zero currency0 reserve otherwise uses only currency1, and the reverse. The two-sided branch takes the minimum full-precision share and then ceiling-selects each leg, capped by the request. Genesis still uses that zero-supply branch when donations have already created basket property. There is no virtual share offset, booked liquidity-unit reserve, or target liquidation rate.

**Dead shares and gross `minShares`.** PT-DEP-02, PT-DEP-04, PT-EVENT-02, and PT-AC-08 match `deposit`. The share minimum is applied to the gross quote before either pull and before the dead-share mint. On a zero snapshotted supply, a zero computed addition reverts `BadGenesis`; otherwise the contract mints 1000 shares to `0x000000000000000000000000000000000000dEaD` and `g-1000` to the recipient. Both are supply-increasing mints. The return value and `Deposit.shares` are the net recipient amount. Positive supply does not add a positive-addition guard and does not mint dead shares.

**Collective compound and protocol carve.** PT-SCOPE-01, PT-COMP-01 through PT-COMP-03, and PT-AC-35 through PT-AC-39 match `_compound`, `_carve`, and the Collect arm of `unlockCallback`. Collection runs only when position liquidity is positive, through a zero-liquidity modification. Reported fees are the unsigned-converted caller deltas, not `feesAccrued`. The protocol fraction is computed only from that reported pair, only when a nonzero fee manager and a nonzero rate are both present, and both getters are read before that test. Idle donations are not separately taxed. A later add in the same compound does not start a second carve. Notification success is not a pull proof. The catch boundaries are exactly the native notify, the ERC-20 notify, and the ignored Boolean from the cleanup approval. Factory-getter failure, checked multiplication, and malformed approval return data can still abort. The draft correctly refuses “fee-manager failure can never block users.”

**Ten-basis-point paired redeem and `redeemZap`.** PT-EXIT-01 through PT-EXIT-05 match `_redeemToSelf`, `redeem`, and `redeemZap`. Both routes compound before the share check, snapshot idle, burn the caller’s full requested shares, and pay `floor(s*9990/10000)` rather than the burned amount. Liquidity and idle round separately. `redeem` skips a zero-currency transfer. `redeemZap` has no size cap and no tick guard, suppresses every addition for its Deploy, and calls the selected-currency transfer even when the final output is zero. `Redeem` records the pre-swap pair amounts and the full burned shares. A partial exit fill can succeed. There is no last-holder sweep.

**Zap cap versus compound cap.** PT-ZAP-02 and PT-COMP-04/05 match the two call sites. User-zap size is the nominal input against the input side of the vault basket, `floor(reserveIn*maxZapBps/10000)`, with equality allowed and a zero input short-circuiting that getter. After the pull, `zapDeposit` reassigns `amountIn` to the measured receipt and deploys `amountIn/2`. PT-ZAP-03 and PT-AC-19 are therefore right to use `floor(v/2)`, not half the pre-pull nominal. Compounding uses a different base: half the heavier leftover, then `floor(floor(activePoolReserve*maxZapBps/10000)/4)`, with no tick-movement check. The active-pool reserve is not the vault basket and not position liquidity.

**Idle in the basket.** PT-VIEW-02, PT-BAL-01, and PT-AC-31 match `basket` and `_idle`. Position value at the unclamped live price is added to actual idle. Native idle subtracts the reservation with checked arithmetic. A direct pool-currency transfer does not mint shares, but it can change a later quote, addition, or redemption. Other assets have no rescue route.

**Full range, salt zero.** PT-SCOPE-02, PT-INIT-02, PT-CB-03, and PT-AC-02 match `initialize` and `modifyLiquidity`. Bounds are `truncTowardZero(±887272/spacing)*spacing`. Spacing 60 yields `-887220` and `887220`. Salt is 32 zero bytes on the position read and on every modification. Initialization does not sort currencies, reject a zero or negative spacing except by division failure, or initialize the pool.

**No `getRate`.** PT-VIEW-05, PT-ABSENT-01, and PT-AC-58 match the public surface. There is no rate, ERC-4626 asset conversion, permit, external mint/burn, delegated redemption, or rescue function. `previewDeposit` returns the gross quote and does not subtract dead shares.

**Unsigned and sign-width conversions.** PT-MATH-05, PT-EXIT-02, PT-CB-03, PT-CB-06, PT-AC-47, and PT-AC-56 match the source expressions, not a checked-cast repair. Removal and collection return `uint256(uint128(callerDelta))`, so a caller delta of `-1` becomes `2^128-1`. Redemption narrows `mulDiv` liquidity with `uint128(...)` and no equality check. `LiquidityAmounts._toUint128` and `SafeCast.toUint128` do perform that check and revert `SafeCastOverflow()`; the draft correctly confines that error to the amount-to-liquidity helper. Settlement negates a negative `int128` before converting, so `int128` minimum fails the negation. The swap request is `-int256(swapAmount)` with no local upper-bound guard. The draft’s width cases are the behavior of that expression: negation of a value below `2^255`, negation failure at `2^255`, and a positive `2^256-x` above it. Do not replace any of these with a SafeCast.

**Manager-only callback, no armed request.** PT-CB-01, PT-CB-02, and PT-AC-45/46 match `onlyPoolManager` and `unlockCallback`. Sender inequality reverts `NotPoolManager` before decoding. A decoded `None` also reverts `NotPoolManager`. An out-of-range enum fails ABI decoding and is not retagged. The callback does not check an armed flag, the entered flag, a stored budget, or a nonce. Operation values are None=0, Add=1, Remove=2, Collect=3, Deploy=4. Add returns fee-minus-caller used amounts. Remove and Collect return unsigned caller deltas. Deploy’s after-tick is read after swap settlement and before the in-lock add.

**Unused `NotFactory`.** PT-INIT-03 and PT-ERROR-01 match the contract. The error is declared and has no revert site. Do not invent a factory-only guard. The first successful initializer caller becomes `factory`.

**Preview versus execution.** PT-VIEW-04, PT-VIEW-05, and PT-AC-29/30 match `previewRedeem` and the exit path. Zero supply or zero shares returns `(0,0)` before a basket read. A positive preview does not cap shares by supply or by the caller’s balance. It rounds each total basket fraction. Execution compounds first, then rounds the liquidity slice and each idle balance separately. Equality is not required. There is no zap preview.

## Checked and not requested as changes

These were the likely false readings. They match the draft.

- Paired-deposit addition has no dust threshold and ignores the Add return when minting shares. Zap issuance uses Deploy’s add-used amounts against the pre-zap basket and supply. No zap refund is performed.
- `redeemZap` validates the output token before compounding. Paired exit does not. Both reject a zero recipient before compounding.
- Protocol approval accepts empty return data or a decoded true Boolean; a false or failed call skips notification. Payout success is different: empty return data, or at least 32 bytes whose first word is exactly one, and failure is `WrappedError` with `bytes4(0)` or `transfer` and a four-byte `NativeTransferFailed` / `ERC20TransferFailed` detail. The paired native refund uses PairToken `TransferFailed`, not that wrapper.
- Tick coefficients 0 through 19, `T(0)=Q96`, and both sqrt-price extrema match `TickMath`. `InvalidTick(int24)`, `InvalidPrice()`, and `SafeCastOverflow()` are the helper errors named in PT-ERROR-03. `FullMath` denominator and rounding failures are unadorned `require`s.
- Pool-key field order matches the draft tuple. The pool id is the hash of that standard ABI encoding. The position key is the 20/3/3/32 packed hash. For the two `bytes32` words in PT-VIEW-01, `abi.encode` and the source `abi.encodePacked` are the same 64-byte image; slot0 is the low 160 bits plus the next signed 24, and both liquidity reads keep the low 128 bits. PT-CB-03 supplies the pool key and empty hook data that the compressed PT-DEPENDS-03 signature does not restate. Read together, the call is specified. That compression is not a gap.
- PT-AC-02, PT-AC-08, PT-AC-12, PT-AC-18, PT-AC-23, and PT-AC-35 match the integer definitions. The handoff is prose, tables, and mathematical contracts. It does not certify license clearance or a source-unexposed workflow, and it does not treat absent factory, fee-manager, manager-engine, hook, or token implementations as missing local requirements.

## What was not adopted from others

Peer originals and peer feedback were not read. Nothing in them is adopted or rejected here. Source, not an earlier reviewer’s prose, controlled the checks above. In particular, the draft is right to keep truncating conversions, partial fills, zero payouts, gross `minShares`, malformed-return failures, and no `getRate`, and right not to promote unused `NotFactory` or a universal fee-routing success claim into requirements.

## Limits

This pass did not rewrite the draft, edit project files, run tests or builds, or use Git. `apply_patch` is not available, so this message is the feedback body to archive. No legal conclusion is offered. Dependency engines were not executed; manager, hook, token, and fee-manager results remain conditional exactly where the draft says they are. Traceability line numbers were not treated as normative. The source text was.
