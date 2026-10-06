# Grok cross-review — internal pricing options (2026-10-05)

Original preserved. Preferences are not ratified. No oracle ban is inferred. No formula or gate is certified sufficient. No proof that any exit pairing removes cross-mode arbitrage.

## Numbers

**Astra’s cycle checks.** Book `(100,100)`, supply 100, credit 125 token1 after a 1-token fee, mint 50. Pro-rata withdrawal is `100/3` token0 and 75 token1. Swap input fee is `0.1` token0. Against virtual reserves `10000/20000`, output is `19940000/300997 ≈ 66.2465` token1. After a 1-token exit fee the entrant nets about `14.25` token1 over 126 paid. Incumbent mark at the old price 2 falls from 300 to `283⅓`. Wings are out of range and center liquidity is zero, so this vault earns none of that swap fee. Idle redemption realizes `D`, so the profit is not capped by the sleeve fraction. It is a funded mark transfer, not unbacked credit, and not a proven drain bound. Repetition is not shown to pay a constant profit.

**Kimi’s matched-price cycle checks.** Deposit 100 into `(1000,1000)` mints about 48.81 shares. Deep-pool exit at 0.3% returns about 97.59. The 2.27 gap is inventory impact to incumbents; the 0.14 is a pool fee. That loss holds only while the internal ratio equals the pool price. It does not refute Astra’s profit when they differ. Calling the internal-internal sum “48.81 + 51.19 = 100” is the continuous identity in this scaling, not a second fee.

**MiniMax’s round-trip does not close.** Fee of 0.5 is both inside the paid 100 and omitted from the invariant input. “Incumbents unchanged” and “incumbents gain 9.84” cannot both be true. The 9.83 figure counts one token and then a total; the later 41.84-style omissions from the prior round are the same class of error. Skipping `removeLiquidity` while paying 54 token0 from `D` with `F = 0` spends inventory the example never withdrew. Post-payout balances in that section do not reconcile (500, 410, and 409.83 are different books).

**Blocked and `F = 0`.** Settled rule: a blocked exit pays only from `F`, or reverts before burn. MiniMax’s blocked payout of 98 with `F = 0` is not a successful route. Their incumbent-loss figure uses 400 instead of `200/244·500 ≈ 409.84`. Zero local cover means blocked failure, not a better price than the pool.

**Finite-range `D`.** Do not treat position principal as a CP reserve ratio. Astra’s out-of-range wings and zero center liquidity are the relevant state: the swap does not reprice this vault’s `D`. MiniMax’s full-range center is a different product. Kimi’s retraction that concentrated `D` need not track the pool is right. Kimi’s later line “above price = token0” is not. `LiquidityAmounts.sol:67-75`: price at or below the range is token0; price at or above the range is token1. PRD G1 still has that backwards.

## What not to conclude

A fall in the other token per incumbent share shows that no-swap minting does not preserve token quantities. It does not rule out scalar entry. Reject that inequality as a ban.

Paired internal entitlement, settled by an external swap, is not proof against cross-mode arbitrage. Dual pro-rata exit, idle-versus-blocked quotes, execution surplus, and a price move between mint and exit are all still open. Astra states the bypass. Kimi’s “no mode-switch arbitrage” is stronger than the argument. Do not adopt it.

Price impact, pool LP fee, protocol fee, and a vault operation fee are different payees. Incumbent gain on a matched-price entry is compensation for a skewed book, not a fee. When the book ratio disagrees with the pool, that same rule can transfer mark value the other way. Do not call either case unbacked credit. Do not call either case harmless.

MiniMax’s 5 bp, 25 bp, and “capped at 50/50” statements are not bounds. The quadratic `c²/8` term is a small-deposit approximation; 100 into 200 is not small. No gate number is accepted as sufficient.

## Next comparison, not a decision

Hold entry fixed: geometric-mean mint on `B = F+ΣD+ΣE`, no entry AMM swap. Compare three exits on two states.

States: (1) internal ratio equals pool price, deep pool, vault active liquidity zero. (2) Astra’s skew, wings out of range, center liquidity zero, so `D` does not reprice on the exit swap.

Exits: ordinary pro-rata basket plus one pool swap; internal scalar quote with the pool swap used only as settlement (surplus remains backing, shortfall reverts); dual pro-rata with no swap. For each, report initiator net, incumbent mark change, external LP fee, and whether `F = 0` makes the blocked form revert. Do not score a winner. Do not drop scalar routes. A reference gate remains an optional bound the owner may name later, not an oracle-NAV mint and not a prohibition.
