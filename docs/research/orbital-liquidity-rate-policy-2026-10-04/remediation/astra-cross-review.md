# Astra — remediation combined cross-review

2026-10-04. Read all three other remediation originals completely, together; no peer cross-review read. Original preserved. Research only; no execution. References use prior proposal’s `O/` shorthand and full Orbital filename prefixes.

## Approved direction versus deferred choices

Adopt raw full-book/flexible proportional ownership and raw zap-terminal admission now. Preserve actual SE conversions, rated internal swaps, existing bootstrap/growth fees, radius and failure/bookkeeping semantics. Kimi’s R6 is the appropriate bounded default. Gate only partial-pricing redesign and recovery—not the entire remediation.

Reject Grok’s scaled-last-reserve fallback and MiniMax’s stale L2/reserve caching and skipped protocol mint. Absence of new storage does not authorize changed economics. `O/Common.sol:459–479,899–929,1359–1366` currently refreshes rated state or reverts. Calling discovery “informational” does not establish that stale values are harmless to consumers. Keeping old `kLast` after changing supply/backing does not prove deferred fees equal the original charge. MiniMax’s internal-call try/catch sketches also are not directly implementable as written without revisiting Solidity call boundaries. These are owner-decision designs, not this approved default.

## Required corrections

1. **No invented rounding tolerance.** Reject MiniMax’s ≤1 wei/≤MINIMUM_LIQUIDITY differential bounds. Separately floored rated numerator/denominator can overmint or undermint, amplified by supply. Acceptance is exact agreement with an independent raw-ratio reference, not closeness to old output (`O/ClaimLib.sol:317–329`; `O/Math.sol:146–171`).

2. **Rate-independent terminal function, not entire zap.** Kimi’s identical-input/changed-rate zap-output assertion is wrong: rated swaps alter contributions and the residual book. Compare terminal admission holding post-swap inventories, contributions and post-fee supply fixed. Test full zaps for exact same-state preview/execution parity; allow economically justified rate sensitivity. Fee-on dilution likewise prevents unconditional whole-join rate independence.

3. **Backing rounds up; payout rounds down.** For chosen LP mint `m`, require contributed inventory `C_i >= ceil(m*B_i/S)`, with overflow-safe comparisons and supported inverse/forward conversion checks. Proportional exits retain `floor(burn*B_i/S)`. MiniMax’s floor-used-share proposal can underfund issuance. SE deposit costs reduce credited contribution; they are not an allowance to dilute incumbents. My original requirement stands.

4. **Partial policy is genuinely unspecified.** Converting face into contribution shares fixes units but does not specify nonproportional issuance. MiniMax’s raw `_partialNavShares` with rated `R` changes the invariant incoherently. Grok/Kimi also do not complete this formula. `O/Common.sol:1633–1656` and `O/Math.sol:380–391` require a separately approved partial policy. Preserve current behavior outside explicitly approved fixes; document the unresolved defect rather than silently adopting or disabling a route.

5. **Loop bounds need accurate accounting.** Kimi’s eight/64 limits are not total search bounds. `_faceForClaim` permits eight interpolation probes, then continues interval refinement (`O/ExitQuoteLib.sol:347–373`); `_invertBufferForEffective` caps expansion at 64, followed by another refinement loop (`O/ClaimLib.sol:250–275`). Require monotonicity/domain justification, strictly decreasing intervals, expansion-overflow handling and measured total nested quote counts. Reusing the pattern is not a gas proof.

## Final acceptance and scope

Retain my production allowlist: Orbital Common, ExitQuoteLib, Math and narrowly scoped ClaimLib helpers; no Weighted/Hookless/config/interface/storage edits. Add raw-policy regression tests covering mixed decimals, mutable/nonidentity rates, zero/fee-bearing buffer output, flexible share input and projected sequential states. Preserve raw payout references and rated swaps at matched states. Pin complete exit rollback with fees both on and off when required rates fail, including unconditional L2/sync.

Use fresh artifact-built baselines and existing 31M/32M consumer caps. Grok’s classification of failures in untouched assertions as automatically unrelated is invalid: changed dependencies can break untouched tests. Attribute through matched baseline/diff evidence; never overwrite unrelated dirty work. No measured gas or passing-test evidence exists in these proposals.
