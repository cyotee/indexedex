# Kimi advisory feedback - pair-spec-fidelity-r1

## Position

**SUPPORT.** I request no changes to the immutable draft.

The draft reaches the correct verdict: the supplied report is an intentional alternative design, not an accurate or complete PairToken behavior specification, and it must not be used as a source-equivalent clean-room handoff. The draft also separates that verdict from the narrower possibility that the report may remain useful as an independent design outline. It does not turn static agreement into a runtime, security, or legal-clearance claim.

## Review of findings, locators, and reasoning

The confirmed findings are supported by the original source comparison and use usable report/source locators. In particular:

- **F1-F2** correctly replace the report's `U`/offset account with PairToken's live-price, idle-inclusive basket, piecewise `_quoteShares`, geometric genesis, 1000 dead shares, and pre-subtraction `minShares` check. The gross-preview/net-genesis distinction is material and correctly retained.
- **F3-F4** correctly describe collective compounding rather than personal fee escrow. The draft improves precision by stating that collection consumes settled `callerDelta`, while `feesAccrued` is separately returned and hooks may affect caller delta. It also bounds protocol-routing claims: caught `notify` reverts do not imply all external failures are caught, approvals are always cleared, or a successful notify consumed tokens.
- **F5** has the correct `floor(s*9990/10000)` payout, separate liquidity/idle allocations, 10 bps retention, two output routes, and sender-only burn. The warnings that zero removed liquidity is not independently rejected and that the contract does not explicitly guarantee full swap consumption or positive output are important corrections to the report's invented revert domain.
- **F6-F8** correctly cover the implemented zap, pre-pull paired quote, balance-measured ERC20 receipt without share recomputation, non-universal ERC20 refunds, native reservation/refund behavior, idle/donation ownership, full-range/zero-salt initialization, and manager-only but unarmed callback. The draft does not infer fee-on-transfer safety, a deployed clone transaction, or a vulnerability from missing callback arming.
- **F9-F10** correctly distinguish `basket`, `previewDeposit`, and `previewRedeem` from the nonexistent `getRate`, including the execution/preview rounding distinction, and require source-derived interfaces and acceptance criteria rather than the alternative's invariants.

I found no material source-locator error, missing original concern, reasoning leap, or overstatement that changes the verdict or correction direction.

## Disposition of Kimi's original concerns

| Original finding | Draft disposition | Assessment |
| --- | --- | --- |
| Kimi F-01 receipt/valuation/mint | Draft F1 | Resolved with piecewise formulas, rounding, and quote/pull ordering. |
| Kimi F-02 genesis/dead shares | Draft F2 | Resolved, including gross/net and `minShares` ordering. |
| Kimi F-03 fees/protocol compounding | Draft F3-F4 | Resolved with actual delta use, collective property, carve, and failure qualifications. |
| Kimi F-04 ratio-swap algorithm | Draft F4 | Resolved with dust, tie-break, sequential floors, active-reserve quarter cap, and call sites. |
| Kimi F-05 redemption/retention | Draft F5 | Resolved with both routes, exact formulas, idle inclusion, minima, and edge cases. |
| Kimi F-06 initialization/range/salt | Draft F8 | Resolved with full-range derivation, zero salt, factory caller, and missing-target distinction. |
| Kimi F-07 entry/zap/native/ERC20 | Draft F6 | Resolved with both routes and exact transfer/reservation/order behavior. |
| Kimi F-08 donations/previews/getRate | Draft F7 and F9 | Resolved with balance-based property and real preview semantics. |
| Kimi F-09 transfers/allowances | Draft F3 and F10 | Resolved with no fee synchronization and concrete allowance behavior. |
| Kimi F-10 deployment/callback/reentrancy/factory | Draft F8 | Resolved without claiming unobserved factory/clone mechanics or a security exploit. |
| Kimi F-11 public errors/events/API | Draft F10 and complete-surface matrix | Resolved at the level needed for a correction baseline. |
| Kimi F-12 sequences/invariants | Draft F8-F10 and correction direction | Resolved by requiring source-derived sequences and acceptance criteria. |

My original clean-room/provenance qualifications are also preserved: source equivalence fails, independent-design usefulness is not certification, source exposure is documented, and no legal determination is made.

## Coverage and provenance qualifications

The every-section and complete-public-surface matrices are consistent with the original audit. The dependency section properly distinguishes full bundle reads from focused/partial reviews and does not claim that any reviewer proved every library algorithm. Missing factory, fee-manager, PoolManager, hook, token, deployment, and chain-state implementations remain explicit limits.

The archive clarification is accurate and should remain as written. The current manifest distinguishes fetched HTTP body SHA-256 `ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98` from archived JSON SHA-256 `b092a33582f4a7f6c76564b0a5ea276561b84347ab66494eea81e462442fcea0`. The archive adds one terminal newline; removing exactly that newline restores the original HTTP body and recorded digest. This is not JSON reserialization or unrecoverable response loss. Original and archived specification hashes are likewise distinguished in the manifest.

The MiniMax F11 qualification is also necessary and sufficient: `IPoolManager.modifyLiquidity`'s `feesAccrued` inflation warning is real interface evidence, but it does not by itself establish unbacked liabilities, a collected/liability mismatch, or an exploit. Donations can supply assets. The draft properly confines the confirmed fidelity point to the actual caller-delta/fee-accounting distinction and does not publish a confirmed vulnerability.

## Required corrections

None. Preserve the draft's verdict, source qualifications, archive-hash explanation, MiniMax F11 limitation, and clean-room/provenance separation in the coordinator's final revision.

This advisory supports the draft only; it is not implementation authorization or a new runtime/security review.
