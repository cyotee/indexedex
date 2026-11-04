# Coordinator source checks

Evidence class: source observations from the archived bundle, followed by comparison inferences. This is not the council draft and does not incorporate peer responses.

## Independently checked before council settlement

- The original report explicitly excludes the target third-party source: original report lines 19, 266-279. Its question at line 6 asks for an independent Crane design, not a description of PairToken.
- The retrieved JSON says creationMatch and runtimeMatch are exact_match, chainId 4663, target address as supplied, verifiedAt 2026-10-12T10:33:37Z. This is Sourcify metadata, not an independent bytecode or chain-state verification.
- Archived source PairToken.sol occupies sources.md lines 4-695; original source line equals bundle line minus 3. The coordinator read the complete contract.
- Constants: original PairToken lines 59-66 declare BPS 10,000; DEAD_SHARES 1,000; RETENTION_BPS 10; DUST 1,000; DEAD address.
- Initialization: original lines 139-152 are a one-shot initializer, set factory to msg.sender, and choose min/max usable ticks from key.tickSpacing. No explicit only-factory check is executed; NotFactory is an unused declaration. A comment describes EIP-1167 clones, but the factory implementation is absent.
- positionLiquidity and basket: original lines 214-231 read PoolManager position liquidity, zero salt, live sqrt price, and both idle balances. They are not an internal booked-U ledger excluding idle funds.
- Mint: original lines 497-519 implement basket-based branches, not the report's liquidity-unit virtual-offset equation. Genesis uses sqrt(amount0 * amount1), checked multiplication, and dead shares. Existing two-sided reserves use the minimum of two floored token/reserve ratios, followed by upward-rounded used amounts capped at inputs.
- Deposit: original lines 256-290 compound first, quote before pulling tokens, measure received amounts on ERC20 pull, deploy all usable idle balances, then mint. minShares is checked before the genesis dead-share subtraction. No generic ERC20 refund of already-pulled deployment leftovers occurs.
- Zap entry: original lines 306-348 exists, swaps half the received input, bounds admission by factory maxZapBps and tick movement by maxZapTickMove, and quotes against pre-zap reserves. The report explicitly excludes this route.
- Exit: original lines 353-406 offers paired redeem and either-leg redeemZap, with payout = floor(shares * 9990 / 10000), proportional liquidity removal and proportional idle balances. It is not the report's virtual-offset principal-only configured-target exit.
- Compound: original lines 412-445 collects fees, optionally routes a protocol fraction using runtime factory getters, and redeploys idle balances. There are no fee indices, fee debts, historical fee escrow claims, or claimFees in the contract.
- _carve: original lines 449-466 uses best-effort fee-manager notification, catches notification failure, and tries clearing ERC20 approval on that failure. It does not prove a successful ERC20 notify consumed tokens, nor guarantee approval reset success.
- _ratioSwap: original lines 472-493 selects the heavier leftover side using current sqrt price, halves it, and caps by pool reserve * maxZapBps / 10000 / 4. It is not necessarily the same bound as user zap entry.
- ERC20 transfer and transferFrom: original lines 156-183 modify balances/allowances and emit events; no compound or fee crystallization. Unlimited allowance is not decremented; zero recipient reverts. Mint has no independent zero-recipient check, while deposit/zap entrypoints do.
- Callback: original lines 546-570 checks only configured PoolManager at the callback entry; _entered guards user entrypoints but is not a single-use callback authorization flag. _skipAdd prevents redeemZap proceeds being re-added. The report's armed-operation binding is an additional design requirement, not observed source behavior.
- _deployInLock: original lines 575-606 uses negative amountSpecified for exact-in swap and near-extreme sqrt limits. No explicit check verifies all requested input was consumed; a specification must not invent the report's full-fill guarantee.
- Views: PairToken exposes previewDeposit, previewRedeem, basket, positionLiquidity, poolKey, token0, token1, ERC20 getters and constants; it has no getRate or target normalization adapter.
- _pull and native handling: original lines 644-688 measure ERC20 received balance; exact native msg.value checks, reserved-native exclusion and refund-to-sender behavior are explicit. The checked code is not a proof of general fee-on-transfer safety.

## Checked helper context

The coordinator read CurrencyLibrary balance/transfer behavior, the amount-delta rounding helpers used by basket, FullMath.mulDivRoundingUp, LiquidityAmounts amount-to-liquidity branches/cast, and PriceMath.sqrt. This is focused dependency review, not a complete audit of all 28 source files.

## Integrity checks

Archived JSON parses. Archived specification matches the original after terminal-whitespace trimming. Exact original/response and archive hashes are separately recorded because apply_patch adds a terminal newline.

## Limits

No tests, compilation, deployed-state queries, factory/fee-manager implementation, ABI fetch, license-text analysis, or legal opinion. Source-equivalence, design quality, and clean-room process clearance are separate questions.
