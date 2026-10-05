# Grok remediation cross-review (2026-10-04)

Original kept. Peers untrusted. **Correction:** my scaled `reserveOfToken` fallback is not approved. It writes a stale rated book. Retract it.

## Approved versus deferred

**Implement now.** Raw inventory for later full-book and flexible share joins, and for zap *terminal* mint only. Keep rated zap split, sphere swaps, first-mint radius, fee-on `kLast`, and live `getRate` bookkeeping. Keep raw exit payouts (`Common.sol:1287-1357`). Keep SE buffer/unwrap quotes. No new ABI/storage. No Weighted or hookless edits.

**Keep failure semantics.** A dead provider still reverts the whole raw join/exit because `_recomputeL2` (`:1362` → `:472-479`) and `_syncVaultReserves` (`:1366` → `:459-468`) read rates with fees off. Do not cache, scale, or skip. Solidity `try/catch` does not catch those internal reverts anyway.

**Defer, do not block the rest.** OD-A: recovery, stale reserves, or skipping `_maybeMintProtocolFee` (`:899-915`). MiniMax R3 is a fee skip despite the “no waiver” label. Reject it. OD-B: partial pricing. `sphereNavShares` (`Math.sol:380-391`) and `_partialDepositAtState` (`ExitQuoteLib.sol:401-424`) price a composition change on rated `R`. Putting raw shares into that `R` is not a unit fix. Do not invent a raw partial invariant, and do not disable the route. Full-book/zap work proceeds without this ruling.

## Challenges

- **≤1 wei / `MINIMUM_LIQUIDITY` (MiniMax).** Unjustified. Prior arithmetic already showed multi-share gaps. Do not accept join or zap drift bounds.
- **Zap unchanged when the rate changes (Kimi test 1; MiniMax A2).** False. `_depositSales` is rated (`ExitQuoteLib.sol:297-314`), so a rate move changes sale sizes and the post-swap basket. Rate-independence applies to proportional full-book mint when the SE share preview is unchanged, not to zap output.
- **Ceil backing versus floor payout.** Exit stays `floor(shares * balance / supply)`. New join must pull `ceil(m * B_i / S)` inventory, then the smallest face whose buffering preview meets that share count. `fullBookUsedWad` is floor (`Math.sol:165-170`) and must not be reused as the backing rule. Kimi’s “floor favors existing LPs” is not the required inequality.
- **Loop bounds.** `_faceForClaim`’s `< 8` (`ExitQuoteLib.sol:359`) is an interpolation hint; search continues. ClaimLib `guard < 64` (`:255-260`) only doubles `hi`, then reverts `SeInvertUnavailable`. Neither is an exact-inverse or gas certificate. Require `previewExchangeIn(usedFace) >= requiredShares` or revert. A zero mint must not fall back to face (`ExitQuoteLib.sol:380-381`).

## Test criteria

One new hermetic file on the existing Orbital TestBase. No mock hook.

1. Full-book reference: `m = min floor(S * C_i / B_i)` in raw face or live/projected SE shares; each used inventory `>= ceil(m * B_i / S)`; buffered face preview covers that share count and does not exceed the offer. A non-identity rate does not change `m` if the SE mint preview is unchanged.
2. Zap: same inputs at two rates may mint different LP. Given one simulated post-swap share snapshot, terminal `m` matches the raw reference and ignores a later rate. Zero share preview reverts the mint path.
3. Exit payout matches the current floor formula on a successful call. Fees off, reverting provider: whole tx reverts; `L²` and reserves unchanged because of rollback, not a cache write. Fees on, live rate: protocol mint still uses the rated book. No skipped mint.
4. Matched-state swap quote is a measured regression check, not a pre-claimed pass. Partial routes unchanged until OD-B.
5. Record gas. No historical fit, no `foundry.toml` change, no ≤1 wei gate. Hookless compile errors and old FullSpread rejection rows are unrelated, not acceptance.

**Handoff.** Edit `Common.sol` and `ExitQuoteLib.sol` only as needed for R-full-book and R-zap-terminal. Do not edit fee, L2, sync, radius, or partial NAV code in this pass.
