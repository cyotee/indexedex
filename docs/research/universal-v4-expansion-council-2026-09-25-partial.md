# Universal V4 expansion PRD — incomplete council checkpoint

Date: 2026-09-25. Research only. PRD reviewed: `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md`, version 0.5. No PRD or implementation changes made in this round.

## Round status

The requested four-member round is incomplete. Astra returned findings but reported an `RC_UNAVAILABLE` attribution/metadata guard denial during a source read. Protocol requires stopping on a guard/participant failure; no remaining participants or cross-reviews were invoked. This is not council consensus.

- Astra original session: `ses_f24357c74ffeASh0m3sVr3DQSM`.
- Task metadata reported agent `council-astra`, model `openai/gpt-6-astra`; provider truth was not independently attested.
- Original report: `docs/research/universal-v4-expansion-council-2026-09-25-astra-initial.md` (researcher-reported saved path).
- Grok, MiniMax M3 and Kimi K3: not invoked; no session IDs exist for this round.
- Cross-reviews: none.

## Partial findings

Researcher findings are untrusted model evidence, not decisions or permission to implement. The moderator directly read the current PRD and CLAUDE.md; source tracing below is attributed to Astra and was not independently repeated in this interrupted round.

1. **Transfer arithmetic is inconsistent.** PRD:121 says moving `ceil(A*U/B)` shares credits A or A-1 units. For B=100, U=1, A=1, moving one share credits a previously empty recipient 100 units. Share precision and transfer/allowance semantics need correction.
2. **Positive-share donation loss remains possible under the specified formulas.** PRD:121–132 initializes shares 1:1 and floors deposits. Deposit 1, donate 99, then another depositor deposits 199: each holds one share of B=299. The first holder can withdraw 149 after contributing 100. Rejecting zero-share deposits does not cover this positive-share case. This is an arithmetic scenario, not an executed exploit.
3. **Split funding equivalence conflicts with fee participation.** PRD:115,184–190,258 retains new fee receipts that participate in subsequent rewards but claims aggregate and split funding produce equal claims. Earlier fee receipts make separate realizations economically different. Preserve one allocation per catch-up, but do not assert timing independence without a proof or changed economics.
4. **Synthetic sampling can retain stale manipulated values.** PRD:172–178 records only DETF operations and carries observations forward. Astra identifies hook reserve/rate changes outside those operations as a coverage gap: temporary skew, DETF sampling, and restoration without another DETF sample can leave an elevated held value. This is a plausible mechanism, not a demonstrated profitable attack.
5. **Oracle semantics remain unspecified.** PRD:170–180 needs averaging statistic, denomination, observation ordering, same-timestamp behavior, mutation coverage, retention, and invalid-data behavior. Arithmetic and geometric averages are not interchangeable.
6. **Donation-clearing deposit claims conflict with intervening expansion.** PRD:125–134 clears donations, realizes expansion, then prices a deposit; T16/T20 promise 1:1 internal shares. The ratio can change during expansion. Internal shares must not be confused with displayed DETF-denominated receipts.
7. **Exact uncapped catch-up remains an engineering gate.** PRD:158,207,244,262 demands exact nested floors and practical execution without measurable budgets or a demonstrated algorithm. Overflow-safe reversion may also block operations that require settlement first. No impossibility claim is established.
8. **Acceptance mapping is incomplete.** PRD:219 maps authority requirement C16 to immutability test T19; these are different properties. Fee conversion equations, existing recipient ownership, wrapper/escrow accounting and family scope also require explicit coverage.

## Human checkpoint

Recommend reopening readiness rather than treating “no open questions” as established. Do not silently change selected one-hour windows, cold-start skipping, compounding, fee entitlements, or balance-derived staking.

Priority clarification questions:

1. Must synthetic history capture relevant hook/rate changes outside DETF calls, or is a last-observed series with explicit freshness limitations acceptable?
2. May transfers deviate economically from the requested native amount? Define the maximum debit/credit error and allowance treatment before choosing share precision and rounding.
3. Retain D40 fee participation and accept different outcomes across separately timed realizations, narrowing the split-equivalence assertion?
4. Choose arithmetic versus geometric TWAP, with explicit quote units and orientation.
5. Confirm post-expansion B/U pricing after donation clearing, rather than unconditional 1:1 internal-share issuance.

Additional engineering work requires a bounded follow-up: exact fee-share math, zero-weight rewards versus donations, oracle storage/availability, terminal overflow and measurable performance requirements. No tests were run.

## Implementation handoff

None authorized. Keep code, configuration and deployments unchanged. Resolve the guard/runtime issue before continuing the council; preserve Astra's session and original report rather than silently restarting it.
