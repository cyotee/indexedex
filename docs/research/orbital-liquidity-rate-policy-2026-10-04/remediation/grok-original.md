# Grok — Orbital raw-LP remediation proposal (2026-10-04)

Proposal only. Not the moderator’s final PRD. No tests run. Do not treat historical FullSpread JSON or any prior gas comment as a measured pass.

**Approved split.** LP ownership is raw inventory. Swaps, including swaps inside zaps, stay on the rated book (APEX D59/D60; agent law `docs/agent/INDEXEDEX_AGENT_LAW.md:237-240`; Orbital addendum `UNISWAP_V4_STANDARD_EXCHANGE_ORBITAL_BUFFER_HOOK_PRD.md:828-835`).

## Bounded default (no new ABI, storage, or fee waiver)

Happy path keeps today’s fee and bookkeeping formulas. A live provider still refreshes rated `reserveOfToken`, `L²`, radius, and fee-on `kLast`. The failure fallback is only for raw liquidity bookkeeping, and only by scaling reserves already stored in `MultiAssetBasicVaultRepo._reserveOfToken` (`contracts/vaults/basic/MultiAssetBasicVaultRepo.sol:82-96`). No new slot, selector, or stale flag.

1. **Full-book join** (`Common.sol:1066-1083`, flexible twin `:1577-1604`). Numerator is buffering shares from `previewExchangeIn(token, amount, se)` or the SE-share amount already in hand. Denominator is `IERC20(se).balanceOf(hook)`, or `l.reserves[token]` on a raw leg. Do not call `getRate` or `previewBufferClaimIn` for this ratio. Map used inventory back to the face pull with the existing buffer invert, not `ratedNative`.
2. **Zap terminal mint** (`ExitQuoteLib.sol:272-295`, consumed at `Common.sol:2000-2012`). Keep `_depositSales` / `zapSplitWad` on rated WAD (`ExitQuoteLib.sol:297-314`). After the simulated swaps, mint `min(dShares_i * supply / shares_i)` from `quoteShareBalance` and the raw residual, not rated `_claimIn` (`:376-381`). Execute still settles the planned swap and does not re-quote (`Common.sol:1929-1944`).
3. **Partial join** (`Common.sol:1116-1183`, `:1621-1656`). Convert offered face to shares with the buffering preview before dividing by live share balance. Stop dividing face by `_effectiveNativeAt`. One-leg adds scale only that leg’s inventory.
4. **Conversions stay.** Deposit still buffers; exit still unwraps the raw share slice (`Common.sol:1287-1357`). `previewUnwrapShares` is a payout quote, not a rate.
5. **Liveness.** Proportional join/exit must not revert because post-op `_recomputeL2` (`:472-479`, called `:1362`) or `_syncVaultReserves` (`:459-468`, called `:1366`) reads a dead provider. Same for `_requirePostUnderRadius` on a later join (`:483-487`, `:1245`). Probe `getRate` the way `getRateFailClosed` already staticcalls (`ClaimLib.sol:332-337`). On failure during a raw-liquidity frame only: `newReserve = oldReserve * newInventory / oldInventory` per touched leg, then `recomputeL2` from those reserves. If a touched leg’s stored reserve is 0, fail closed. Swaps, zap planning, and single-asset exits that swap still revert `RateProviderFailed`. Do not use the fallback to price a swap.
6. **Fees unchanged.** Fee-on `_maybeMintProtocolFee` / `_snapshotKLastIfFeeOn` (`:899-928`) still use a live rated book and still revert if the provider fails. That is not a waiver. First-mint radius stays rated (`:971-984`, `:1239-1241`). Weighted files are untouched; Weighted `kLast` stays inventory (`WeightedBufferHookTarget.sol:400-401`).

## Deferred owner branch (do not implement)

OD-1. Fee-on raw join/exit while the provider is dead: keep fail-closed (this default), skip the protocol mint, or add a recovery function. The last two need a fee waiver or new ABI. OD-2. Whether a last-rate scaled `reserveOfToken` during an outage is acceptable discovery data. Default: scale, no stale flag. OD-3. Redesign rated first mint or Orbital `kLast`. Not approved. OD-4. Identity `se == token` still rating in `effectiveNative` (`ClaimLib.sol:383-389`) versus agent law `:239`. Out of scope unless it blocks a raw ratio.

## File scope

Edit only:

- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol`
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol`

Touch `ClaimLib.sol` or `Math.sol` only to reuse an existing pure ratio. Do not change `ratedNative` swap valuation. Do not edit Weighted, hookless analytic (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/**`), `foundry.toml`, facets, selectors, or unrelated dirty files. Do not edit the family PRD; the moderator’s final plan is the instruction.

New test only: `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_RawLiquidityRates.t.sol`, inheriting the existing Orbital TestBase. Production-first (`indexedex-testing`). Non-SUT reverting provider only. Do not mock the hook. Do not rewrite `test_RP1` / `test_RP3` (`UniswapV4StandardExchangeOrbitalBufferHook_RateProvider.t.sol:66-117`): effective views and swaps stay fail-closed.

## Acceptance

- Non-identity rate (the `5e17`, held 6, minted 3, supply 12 case) does not change full-book or zap-terminal LP versus the raw share ratio. Identity rate stays preview-equal to execution on the new test.
- Partial join pulls the face that buffers to the used share count, not face-versus-rated.
- Fees off: reverting provider, proportional join and exit succeed; `L²` and `reserveOfToken` equal the scaled last reserves. Fees on: same provider, those calls revert; no skipped mint.
- Swap and zap-split quotes still move when the rate moves, and still revert on `RateProviderFailed`.
- No new selector or storage slot. Weighted tree unchanged.
- `forge build` then the new test, plus `Liquidity`, `ZapIn`, `Fees`, `RateProvider`, and `Preview` orbital tests (`CLAUDE.md` item 10; solc 0.8.35; no `via_ir`). Record gas. Do not raise `foundry.toml:38`. Do not claim the 31M comment was a measured budget.
- A failure in an untouched assertion, hookless analytic, or the historical FullSpread rejection rows is unrelated. A failure in share count, raw payout, or the new liveness assertions after this diff is attributable. Report both. Do not “fix” unrelated red tests in this pass.

## Implementer order

Raw full-book and flexible ratios, then partial unit conversion, then zap terminal mint, then the rate-probe fallback around L2/sync/radius, then the new test. Stop if the fallback would require storage, a new error selector, or a fee skip.
