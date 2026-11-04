# Astra independent review

## Identity

- Member: astra
- Profile: review
- Phase: initial independent response
- Requested role: council-member
- Requested model: `chatgpt-subscription/gpt-6-astra:high`
- Runtime model, provider, reasoning setting, and role: not exposed
- Runtime task identity: not exposed
- Peers read before submission: no
- Run: `se-fullspread-blockers-review-r2-20261102`

## Question and conclusion

Is the current blockers file consistent across its locked answers, complete enough to rewrite the full-spread PRD, and clear enough that two implementors would not diverge?

**Not yet. Four bounded clarifications remain.** The principal owner choices are substantially consistent and should be preserved. The remaining issues concern the overstated-pretransfer branch, fees realized during a deposit, exact-consumption language at integer boundaries, and the event predicate when previously booked fees are deployed.

These are not objections to the sleeve removal, liquidity-only issuance, principal-only redemption, live reserve reads, unbounded swaps, or the external rate-provider design. Differences between those locks and the old PRD are authorized replacements, not findings.

## Review findings

Locations below refer to `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`. Line numbers identify the version read in this assignment.

### R2-A01 - High: the overstated-maximum refund does not identify its balance snapshot or execution branch

**Location:** B-13, `IMPLEMENTATION_PLAN_BLOCKERS.md:280-284`; repeated at line 390. Related maintenance rules: lines 138 and 250. The admitted `docs/vaults/PRETRANSFER_DIRECTIVE.md` repeats the same wording rather than resolving it.

**Observation:** When the maximum is within the unbooked balance, the refund is maximum minus used. When the maximum exceeds that balance, the refund is instead "the unbooked balance," without pulling the shortfall. The text does not say whether that second balance is measured before processing or after processing, or whether that branch performs the requested operation.

**Why implementors can diverge:** Let the declared maximum be 100 and the entry unbooked balance be 60.

- One reader returns the entry balance of 60 and performs no conversion.
- Another processes up to 60, spends 40, and returns the remaining unbooked balance of 20.
- Processing 40 and also returning the original 60 would require another 40 from somewhere; that cannot be funded from this declared input alone.

The first two readings are materially different successful outcomes. The second is not resolved merely by banning `maximum - used`: it needs a defined balance snapshot. Output, shares, minima, and previews consequently differ. Because the booking section explicitly gives `donate()` a pretransferred path, the interaction with its no-refund remainder rule also needs a defined boundary.

**Fix direction - advice only:** Identify the balance used for the comparison and the balance used for the refund. State whether an overstated declaration is processed with the available input or returns without processing. Carry that same branch into output/minimum handling and previews, and say how it applies to donation and to any bundle leg that admits pretransfer. Preserve the locks against pulling a shortfall, spending booked balances, or refunding unrelated balances beyond the declaration in the ordinary case.

### R2-A02 - High: removing automatic compound leaves deposit-side fee attribution unspecified

**Location:** B-02, `IMPLEMENTATION_PLAN_BLOCKERS.md:78`; B-01, lines 56-58; B-10, lines 222-226; booking rules, lines 250-258; unused-input summary, line 378.

**Observation:** User operations do not call `compound()`. The booking rule expressly assigns fees collected by a withdrawal to the booked balance and excludes them from the user's payout. There is no corresponding sentence for fees realized while adding liquidity during a user deposit. The admitted PRD's FS-MONEY-01 describes deposit settlement from the net delta and returning a positive credit to the depositor, but its preceding automatic compound is displaced by B-02.

**Why implementors can diverge:** The rewrite needs to distinguish user-funded principal from any existing-position fees appearing in a deposit's liquidity-modification result. One implementor can apply the retained net-delta/refund language to the entire result. Another can separate fees, book them for holders, and calculate the user's spend and refund only from the deposit principal. Those choices affect refunds, custody, and potentially the amount credited as user-funded liquidity.

For illustration, if an operation requires 6 units of deposit principal and also realizes 10 units of earlier fees, its net result alone does not identify the user's unused input. This is an accounting example, not a measured PoolManager execution. The admitted text does not exclude this case or specify its treatment. The withdrawal-only sentence cannot silently become a complete rule for every liquidity modification.

**Fix direction - advice only:** Specify ownership and booking of fees realized on liquidity addition as well as removal. Define the user's consumed input, refund, and share-credit basis independently of such fees, consistent with the locked liquidity-only formula and prohibition on automatic compounding. Do not restore the sleeve or introduce a different issuance denominator. If an existing mechanism is intended to make this case impossible, identify that mechanism in the requirements rather than leaving the exclusion implicit.

### R2-A03 - Medium: exact exhaustion and actual-balance booking lack a common integer-boundary rule

**Location:** B-11, `IMPLEMENTATION_PLAN_BLOCKERS.md:242`; Donation and compound booking, lines 252-254; raw-liquidity units, lines 216-226.

**Observation:** A two-token maintenance call must not swap; the proportionally scarcer token "is fully used," and only the other token's excess is described as a remainder. A one-token call must leave its remainder in the processed token. The next paragraph instead requires booking the actual held balance after the simplest deposit, forbids extra attempts or fallbacks, and says a failed step reverts. B-11 says a remainder alone does not cause a revert.

**Why implementors can diverge:** The document does not state what happens if the permitted integer-liquidity operation cannot satisfy the exact-exhaustion wording. One implementor can make full consumption of the scarcer token a success invariant and revert if dust remains. Another can treat it as the proportional-sizing objective and book the actual balances left by the single permitted attempt. These differ precisely where B-11 purports to settle undeployable fees.

The zero-added-liquidity case is also not separated from an attempted step that fails: retaining and booking everything, versus invoking a zero-liquidity action that may serve another purpose, is not specified. I have not executed a rounding counterexample or verified a particular implementation's reachable dust states; the finding is the missing precedence and outcome rule, not a claim about measured V4 behavior.

**Fix direction - advice only:** State whether exact exhaustion is a required postcondition or the sizing objective subject to the established integer math. Define the outcome when the one permitted operation adds zero liquidity or leaves dust, including whether both actual token balances may be booked. Preserve no swap for an already two-token balance, no extra attempt, no swallowed failure, and no revert merely because an allowed remainder remains. This does not ask the owner to choose a different swap algorithm.

### R2-A04 - Medium: `Compounded()` has no determinate predicate for historically booked or mixed fees

**Location:** B-11, `IMPLEMENTATION_PLAN_BLOCKERS.md:234-242`; booking rules, lines 250-258; no-new-fee processing, lines 104-110.

**Observation:** `Compounded()` is emitted when fees are compounded, and not when a maintenance call compounds no fees. A booked remainder must still be processed when there are no new fees. That remainder can contain fees collected on an earlier withdrawal, donation excess, or a stray transfer. Maintenance combines these sources before depositing and books the actual residual balance.

**Why implementors can diverge:** Suppose a withdrawal collects and books fees. A later `compound()` collects no new fees but deploys that booked balance. An implementation that tests newly collected fees emits nothing; one that recognizes the booked tokens as earlier fees emits `Compounded()`. Both can point to different sentences in the file.

Mixed balances introduce another choice: the document gives no attribution order for deciding whether a partial proportional deposit deployed fee-origin tokens or left those tokens in the remainder. A pure donation and previously collected fees are economically pooled for maintenance, but the event predicate still distinguishes their origins.

**Fix direction - advice only:** Define the event predicate in terms of observable call state, explicitly covering deployment of previously booked fees, donation-only deployment, a mixed remainder, and zero added liquidity. State whether fee provenance is required or intentionally irrelevant to that predicate. Preserve the no-argument signature; this finding does not request amount fields or new swap/liquidity events.

## Coverage

I read the complete blockers file, including the 2026-11-02 owner answers, every B item, the separate booking lock, all N notes, the matrix and audit sections, and the final locked-answer summary. The following table distinguishes settled policy from the specific gaps above.

| Item | Coverage and assessment |
| --- | --- |
| B-01 | Net the fee from new gross shares, including genesis; exclude the 1,000-share floor and recursive fee minting; preview net shares; clamp the vault's resolved usage fee to `3e17` without changing the oracle; retain `1e13` precision and zero; no fee on pass-through swaps. These choices agree with B-10 and the summary. R2-A02 concerns attribution of deposit-side collected tokens, not a different usage-fee policy. |
| B-02 | Sleeve and target removed; maintenance restricted; proxy owner initialized from oracle `feeTo()`; user routes do not compound; unbounded entry/exit limits retained; exits swap principal only; batch composition admitted. Accepted maintenance exposure remains accepted. R2-A02 identifies a consequence of removing the preceding compound, not a reason to restore it. |
| B-03 | The corrected decision and conclusion require processing booked remainders without fresh fees. Empty means no fees, donation, or booked remainder. R2-A03 and R2-A04 cover the remaining boundary and event questions. The old explanatory "no-fee sentence wins" at line 108 must not be carried forward as the operative rule. |
| B-04 | Positive supply with zero deployed liquidity is closed under the described floor and withdrawal rules. No new denominator or idle-based issuance rule is requested. |
| B-05 | Owner/operator donation; zero-supply revert; share donation burns without withdrawal; underlying donation and compound share the combined-balance one-token/two-token distinction; remainder booked rather than returned. R2-A01 asks how the exceptional overstated-pretransfer branch meets this rule; R2-A03 addresses exact consumption. |
| B-06 | Unsupported views return zero, exact-output execution still reverts, and busy/unlocked status does not itself reject a view. Reserve views use live position amounts plus unpaid fees, exclude local booked balances, and do not use a committed snapshot. These are later authority, not conflicts with the old PRD to reopen. |
| B-07 | Seven chain-specific package immutables initialize the Protocol Aware Repo; both aware facets are Crane inputs with Crane tests. Position identity is per-instance PoolKey, ticks, and salt; liquidity reads use StateLibrary for the diamond's position. No family-only identity selectors or restored local-reserve getter. The rewrite should preserve one instance repo copy rather than invent duplicate family storage. |
| B-08 | External provider per vault/target, no vault rate or provider registry/getter, no provider-count cap; test each underlying target and token ordering, including distinct pools using the same vault with different targets. The preview return migration is locked. Consumer enumeration belongs to the later PRD pass, not this response. |
| B-09 | Borrowed execution avoids nested unlock, removes and swaps the exiting principal fraction, and settles its own deltas. No sleeve fallback or unavailable-fraction error-unit decision remains. This review does not independently certify the cited V4 research. |
| B-10 | Raw liquidity determines genesis, later minting, and burning; floor included in supply; share decimals remain metadata. No rescaling or liquidity-only issuance reopening. |
| B-11 | No-argument `Compounded()` and no separate vault swap/add event are settled. R2-A03 concerns undeployable amounts; R2-A04 concerns emission, not signature. PoolManager event-field claims were not independently verified from source. |
| Donation and compound booking | Combined fees, donation, and booked remainder; branch by combined token presence; actual held residual booked; stray/non-atomic transfers can be booked; no extra attempts or swallowed failures; withdrawals book fees and pay principal; local balance excluded from reserves. R2-A01 through R2-A04 concern identified boundaries within these choices. |
| B-12 | `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)` have fixed names and arguments; caller means route caller. No ABI-choice finding. Event sufficiency as a token-amount data source remains outside this source-limited review. |
| B-13 | No origin tracking, no EOA pretransfer, no booked-balance spending, bounded declared credit, and caller-owned share burns are explicit. R2-A01 isolates the unresolved balance snapshot and execution semantics for the overstated maximum. |
| N-01 | Keep the zero-address floor and the stated mint path. No request to use a dead address. Source behavior was not independently inspected. |
| N-02 | No fee on floor or fee shares; B-01 supplies the operative rule. |
| N-03 | No sleeve-adjustment swap; this does not delete the separately authorized user or maintenance swaps. |
| N-04 | No invented quote step cap, minimum spacing, partial result, fallback, or product-level quoter choice. Mathematical quotes and the dust-tick regression stay required. The review does not reopen those decisions or treat them as achieved performance evidence. |
| N-05 | Remove `PkgInit.wrappedNative`; no wrapper getter; callers use WETH. Read with the final summary's explicit pool-boundary wrapping/unwrapping, not as prohibition of the internal native pool leg. |
| N-06 | Keep both library slots; allocation of already specified work is an engineering choice, not an owner blocker. |
| N-07 | Liquidity-only issuance remains closed. None of these findings requests a different denominator. |
| Matrix files | All seven listed behavior contracts remain in scope. Add this family without weakening other families; retain exact-output rejection and the user-refund/maintenance-booking distinction. Replace stale V4 evidence and preserve V3 rows. No historic row is a current pass. |
| Audit tests | Preserve the distinction between 023's accepted maintenance exposure, 024's principal-only quantity rule, 039's attribution rule, 044's netting rule, and 048's no-op/remainder behavior. R2-A01-R2-A04 affect the precision of the corresponding acceptance descriptions. The external 45-ID disposition was not admitted and was not inspected. |
| Final locked-answer summary | Checked every bullet against the detailed sections. It consistently repeats the major replacements and repeats the refund and booking gaps identified above. It does not independently resolve them. |

## Rewrite preservation notes

These notes do not create additional owner questions:

- The 2026-11-02 B-03 correction governs. Its older explanatory paragraph cannot reinstate "no fresh fees means no work" when a booked remainder exists.
- B-02 and B-05 expressly accept the owner/operator maintenance exposure. The audit summary should retain that scope for donation as well as compound; its compound-only shorthand must not imply donation is protected.
- B-02's rejection of a new swap/maintenance fee cap should not erase B-01's explicitly locked usage-fee clamp. They concern different rules.
- The native-ETH exclusion concerns the user surface. The final summary still allows wrapping/unwrapping at the pool boundary.
- The PRD's old sleeve, automatic compound, extra fee mint, local-plus-deployed reserves, exact-output preview revert, and unresolved external-rate-provider sentences must be replaced throughout the single rewrite, including acceptance rows. Their continued presence in the unedited PRD is not an independent defect in the later owner locks.

## Evidence and limits

Read sources were the assigned brief, the complete blockers file, and all three admitted optional context files:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`
- `docs/vaults/PRETRANSFER_DIRECTIVE.md`

The findings are requirements observations and stated reasoning from those documents. No protocol source, earlier review directory, peer response, external report, or audit source was read. No network research, sub-agents, Forge, tests, installs, or Git were used. No arithmetic execution, event ABI verification, gas measurement, or proof of production behavior is claimed.

Only this assigned response file was written. The suggested fix directions require resolution before being treated as new requirements. This response does not authorize implementation or a PRD edit, and it does not replace the blockers file or its locked owner decisions.
