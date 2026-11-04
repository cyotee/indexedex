# Coordinator extraction checklist

This is an analyst-side source-observation checklist, not the council draft. The four requirements originals remain independent of one another.

## Contract surface

The prior full-contract read and renewed helper inspection establish 17 named public/external methods, one payable receiver, 17 generated getters, five events and 13 declared zero-argument custom errors. The source includes factory/notification interfaces but not those implementations. All mathematical quantities are raw integers; share decimals are 18; no underlying decimal normalization is performed.

## Required exactness checkpoints

- Distinguish pre-compound, post-compound, pre-quote, pre-pull, pre-mint and pre-burn snapshots. Entry checks gross shares before genesis subtraction; no post-pull share recalculation.
- Describe all quote branches, including nonzero supply with both basket reserves zero. Checked product precedes integer square root.
- Dead-address shares are minted, not removed from totalSupply by a burn. Ordinary holder exits cannot redeem their balance; do not claim an unimplemented privileged destroy path.
- Both native and ERC20 balance donations belong to the basket. Only the operation-scoped native reservation is excluded. Native refund is to caller, not share recipient.
- ERC20 paired excess that was never selected is not pulled. Already-pulled leftovers are not universally refunded. Zap deploys all available idle, not a segregated depositor-only ledger.
- Cap checks happen on nominal zap input before measured receipt; swap uses half actual receipt. Tick movement is measured across the deploy swap and checked afterward. This cap uses the vault basket, not active pool liquidity.
- Both redemption routes run compounding first, snapshot idle before caller burn, apply the retention floor in share units before independent position/idle floors, and may allow a zero payout.
- Removal and collection return unsigned reinterpretations of signed 128-bit caller deltas. Include exact type conversion without inventing a reachable exploit.
- Exit swap disables add; no explicit full-consumption, positive-output, zap-size or tick-move guard is imposed on that route apart from the minimum output.
- Protocol routing occurs only for positive collected amounts and nonzero factory settings. Notify failure is caught; invalid factory getters and malformed approval data are not generally caught. Success is reported without an ERC20 balance audit or unconditional allowance reset.
- Compound eligibility is either idle amount strictly greater than dust. Heavy-side tie picks token0. Chosen-side dust and zero active pool liquidity yield a zero swap, but do not preclude an add attempt. Compound reserve cap is active-pool-liquidity-implied, at one quarter of the zap basis-point bound.
- Views do not compound. Deposit preview is gross at genesis. Redemption preview has zero fast paths without manager access and separately differs from execution rounding.
- Explicit callback authorization is manager equality only. Record operation payload and returned data, empty hook data, separate unlock boundaries, and settlement order. Do not add armed flags, callback reentrancy modifiers or an initialized precondition not present in the source.
- Initialization stores the first successful caller as factory. Full usable ticks are derived with signed division toward zero. No source check enforces positive/legal spacing, sorted currencies or a hook policy; downstream/arithmetic failures remain possible.
- Plain ERC20 allowance subtraction precedes transfer, including when spender equals owner; maximum allowance is unchanged. Zero spender is allowed; zero recipient is rejected. Transfers trigger no collection, fee accounting or PoolManager call.
- Event order: dead mint and recipient mint Transfer events precede Deposit; burn Transfer precedes pool exit and Redeem; zap Redeem is emitted after payout but its payload contains the pre-swap pair amounts, not final selected-currency total. Compounded may precede the route's primary event.
- Do not use idealized real-number math in place of integer fixed-point contracts, independent flooring, checked multiplication, signed arithmetic or explicit casts.

## Helper inspection

Coordinator read the full PairToken during the preceding audit; rechecked PoolKey/PoolId structure and hashing, TickMath bounds/usable tick formulas, FullMath failure/rounding semantics and Position key packing in this run. Prior run checked Currency transfers, amount deltas, LiquidityAmounts and integer square root. These are semantic requirements inputs, not an independent mathematical proof or an examination of the absent deployed manager.

## Handoff boundaries

The planner-facing document must contain original prose, interface/data tables, equations, operation ordering and acceptance criteria, not source listings or line-by-line executable pseudocode. Keep analyst source locators/provenance/council transcripts outside handoff/. Describe actual source behavior without importing the prior alternative's booked-liquidity issuance, escrow claims, fixed target, getRate or Crane package design. Any later adaptation must explicitly mark deviations.

## Additional edge checks

- Re-read swap amount encoding: converting uint256 to int256 preserves low 256 bits and the subsequent checked unary negation can panic at the signed minimum. Normal-sized positive requests encode exact input; do not invent an explicit upper-bound check absent from the source.
- Negative settlement negates the signed int128 delta before widening. The signed minimum is an arithmetic edge; no concrete manager reachability is proved.
- Currency payout transfers have a distinct wrapped failure path from the private token calls used for pulls/settlement/refunds. Their exact return-data acceptance differs; do not collapse both into one generic TransferFailed rule.
- Tick movement subtraction is signed int24 arithmetic. Factory return types are uint16 for both basis-point settings, int24 for movement, and address for manager; the target does not enforce nonnegative movement or rates <=10000.
- Some manager reads occur before a route's own later validations. State the actual ordering instead of promising every invalid amount always reaches the nominal amount error.
