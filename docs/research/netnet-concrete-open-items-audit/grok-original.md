# Grok original — concrete open-items audit

| Field | Value |
| --- | --- |
| Researcher | Grok (`xai/grok-4.7`), independent follow-up |
| Access date | 2026-09-28 |
| Question | Do any concrete specification gaps remain in the current NetNet–Pendle PRD, plan, and tracker? |
| Authority read | PRD v0.33; plan v0.9; `PRD_OPEN_QUESTIONS.md` as updated 2026-09-28; `CLAUDE.md`; `ROBINHOOD_MAIN.sol` default fork block and published Pendle anchors |
| Not read | Other members' artifacts for this round; historical council conclusions. Tracker links to those reports were not opened |
| Human ruling applied | Pendle documentation / the published manifest already cited by the constants file is the address source. Fork observation uses `ROBINHOOD_MAIN.DEFAULT_FORK_BLOCK`. Later fork tests validate behavior. Independent address rediscovery and block pinning are not research blockers. No execution is authorized |
| Context7 | Not used. No new external library/API claim |
| New owner questions | **None** |

Fact means the cited document says it. Inference means that text already answers a transition other notes still call open. This audit does not certify security, deployment equivalence, or that unrun tests would pass.

---

## 1. Result

The six challenged “gaps” are not missing product decisions. Current PRD and plan text already answers the reachable required transitions. What remains is implementation, later fork tests at the library’s default block, and one process-only instruction reconciliation. Tracker and plan status lines that still call those items specification blockers should be withdrawn. They do not reopen economics.

No new owner question is justified. A future fork that shows a configured body incompatible with a required rule could create one. That incompatibility is not demonstrated now, and proving it is not a precondition for this research conclusion.

---

## 2. Binding and block — withdrawn as a research blocker

**Fact.** `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:52–53` sets `DEFAULT_FORK_BLOCK = 20_714_383`. Lines 184–201 cite the Pendle chain-4663 manifest and pin `PENDLE_MARKET_FACTORY_V6`, `PENDLE_YIELD_CONTRACT_FACTORY_V6`, `PENDLE_ROUTER`, and `PENDLE_ROUTER_STATIC`. The file says not to add a perpetual market, PT, YT, or SY constant. PRD §16.1 records the same anchors and the same no-perpetual-market rule.

**Classification: IMPLEMENTATION/TEST, not a spec gap.** Later fork tests use those documented addresses and that default block. Re-deriving addresses or demanding a fresh observation block before the specification can be considered closed is withdrawn. NN-01’s “observe before spec closure” wording is evidence hygiene for the implementation handoff, not an open economic choice and not a research stop.

Configured YT V1 versus V2 is the same class. Plan §6.6 states the V1 equations and says not to apply them to a different body. That is a fork/source-integration check. It is not a reason to invent a second interest formula, and it is not an owner question until a fork shows the live body conflicts with a required rule.

---

## 3. Challenged items

### 3.1 Force-claim versus public credit and full sync

**Classification: RESOLVED. Withdraw the “reconciliation mechanism” blocker.**

| | |
| --- | --- |
| Citations | PRD §6.3 (available credit `max(B−R,0)` regardless of origin; force-claim still unbooked is the same credit; no payer witness; refund then full expected-set sync; settled receivable is not also cash). Plan §6.1 (same algorithm; in-operation protocol inflows booked to that operation; force-claim clears the native entitlement). Plan §6.5.5 steps 1 and 7 and §6.6.4 (capture credit before sync; consumed credit is not also H; clear only the settled claim; do not auto-classify every surplus as interest) |
| Reachable transition | A third party calls `YT.redeemDueInterestAndRewards(hook, …)` before the hook’s route. SY arrives. That YT’s accrued interest is zero. A later ordinary route starts |
| What older notes say is missing | An on-chain way to tell historical interest from an incentive or a donation without provenance, because raw surplus plus zero accrued does not identify the sender |
| Why existing rules answer it | Unbooked surplus is L2 credit until a supported caller consumes it or a successful route syncs it. Origin is intentionally irrelevant. Consumed units are that caller’s input, not H and not a second receivable. Units the hook itself receives from a call it made are booked by that call’s measured leg (interest versus incentive), which §6.6.3–§6.6.4 already separates. Unconsumed interest-token balance that full sync then books is held interest-token inventory minus the already listed exclusions (payables, principal-exit, exclusive notes, transient Keep-YT). Non-interest unsolicited tokens are not a sweep (PRD §13; NN-03). Asking for a historical classifier would add the provenance test L2 forbids |
| Next deliverable | Implement capture-before-sync, once-only booking, and the exclusion list. Test the force-claim-then-pretransfer and force-claim-then-sync cases already in plan §6.6.6. No new rule |

**Inference, not a new requirement:** “do not auto-classify every surplus as interest” in plan §6.6.4 forbids treating an unbooked balance as H before the L2 snapshot, and forbids treating a non-interest token as SY. It does not create a third permanent unclassified bucket for synced interest-token inventory.

### 3.2 Provider and caller rounding

**Classification: RESOLVED. Withdraw the rounding-choice blocker.**

| | |
| --- | --- |
| Citations | PRD §4.5 (`floor(a * 10^syDecimals * 1e18 / (q * 10^targetDecimals))`; a sample times a balance is a valuation convention, not a finite-size redemption). Plan §6.5.6 (for this SY, `q = 1e18` gives `a = Ic` and rate `Ic * 1e9`; do not replace that valuation with a whole-book redeem floor; funding uses §6.5.3). PRD §4.3 and plan §6.4 (existing Weighted helper and V4 native wrapper; fee once; do not reorder or gross up twice) |
| Reachable transition | Quote the sNET coordinate from the eligible SY book, then fund a finite NET or sNET output from SY shares |
| What older notes say is missing | A choice between `rate * book` and `floor(whole book to sNET) then scale`, and a caller scale order |
| Why existing rules answer it | Pricing uses the selected provider sample. Funding uses the fixed-state share inverse. The documents already say those integers can differ and forbid silently replacing one with the other. Caller scale order is the existing wrapper: scale after the documented 9-decimal native conversion, fee once. No owner parameter remains |
| Next deliverable | Wire those two existing functions and test that a funding debit is not computed from the sample rate. Not a new formula |

### 3.3 Owned-HLP and Keep-YT chronology

**Classification: RESOLVED as required transitions. Calldata binding is IMPLEMENTATION/TEST.**

| | |
| --- | --- |
| Citations | PRD §§5, 6.1, 7.1.1–7.1.2, 11.4 (six-step atomic rollover; Keep-YT split `floor(netSyIn * totalPt / (totalPt + pyIndex.syToAsset(totalSy)))`; empty successor reverts; no silent seed). Plan §§6.2, 6.4, 7.1, 7.2, and §6.5.5 closing paragraph (owned book before quote; actual BasePoolMath mode; allocated PLP/YT only; then the SY edge; no `h/H` shortcut; ordinary output does not liquidate) |
| Reachable transition | NET or sNET in acquires Keep-YT and buys existing DETF. Ordinary NET or sNET out spends shared SY. An owned-reserve burn or HLP position exit realizes only the owned or allocated position, then may hit the same SY edge. Rollover validates, realizes, converts, acquires successor Keep-YT, and commits, or reverts entirely |
| What older notes say is missing | A “full chronology” beyond those sections |
| Why existing rules answer it | Order, custody, failure, and the prohibition on ordinary liquidation are already normative. Exact router arguments are binding of the functions the PRD already cites (`ActionAddRemoveLiqV3.sol:236–303` in §11.4), not a new economic sequence. No incompatible required case is demonstrated |
| Next deliverable | Implement the cited order and test it. Do not treat an unwritten calldata table as an owner question |

PRD §11.3’s older “require explicit execution specification” list is superseded for the selected flow by §11.4. Leaving §11.3’s tone unchanged is editorial (NN-20), not a live gap.

### 3.4 Exact-output residual

**Classification: RESOLVED. Withdraw the residual-beneficiary blocker.**

| | |
| --- | --- |
| Citations | PRD R22 and §6.2 (exact-output delivers the requested net amount or the whole route reverts). Plan §6.1 (exact-output refunds unused input, not extra output). Plan §6.4 and §6.5.3 (`qMin` is minimum-sufficient; for `0 < I <= 1e18` it hits `y` exactly when the forward multiply is valid; for `I > 1e18` some `y` are not representable, example `I = 2e18`, `y = 1`, nominal output `2`; do not warehouse excess or drop ERC-4626; inability to deliver the required amount reverts) |
| Reachable transition | ERC-4626 or standard exact-out asks for native `y`. The SY branch’s minimal shares would deliver `y' > y` |
| What older notes say is missing | A residual owner, or a proof that the gap is unreachable, before the route may exist |
| Why existing rules answer it | Exact delivery or revert is already the rule. Refund law does not skim output. Warehousing would be a new beneficiary, which §6.5.3 refuses. The route stays for representable amounts. A non-representable amount reverts that call. Index starts at `1e9`; `I > 1e18` is a billion-fold index increase, not a missing near-term policy |
| Next deliverable | Test equality for `I <= 1e18` and revert for a constructed `I > 1e18` gap. Do not add a dust account |

### 3.5 G0

**Classification: PROCESS ONLY.**

| | |
| --- | --- |
| Citations | Plan §2.1 G0. PRD owner-approval paragraph (custom family, including this family’s NET tax and sNET rebase, approved; shared instruction files unchanged). Tracker NN-13 |
| Reachable transition | A later production implementer must not treat this PRD as an edit to shared token-policy instructions |
| What is not missing | The product behavior. Approval is recorded. Weights, fees, SY funding, claims, and locks are specified here |
| Why this is not a spec gap | G0 is a separately authorized maintainer reconciliation before production implementation authorization. This research task cannot and need not perform it. It does not leave an economic value unset |
| Next deliverable | Maintainer process, outside this council. Do not block specification or fork-test planning on it |

### 3.6 L4 terminal rights

**Classification: RESOLVED for every required transition. Withdraw L4 as a design blocker.**

| | |
| --- | --- |
| Citations | PRD §12.4 and H01–H03 (excess of the intended note credits the same NFT; intermediate collection does not reset the lock; final contribution in processed epoch E unlocks at E+1; reinvestment creates a new bond and keeps the old NFT/holder/note; zero principal does not retire future rights; unlock 0 means assigned Pendle maturity; unrelated donations are not receipts). Plan §7.3 (same rules; drained candidate is not “principal is zero while the note still vests”; do not burn recognized rights, transfer holder ownership, or treat a dormant flag as selected) |
| Reachable transitions | Reinvest all current principal while the note vests: old NFT remains. Intermediate collection: no new old-NFT lock. Final intended collection in E: unlock E+1. Withdrawal at or after that target: specified. Late proceeds of the intended note: same-NFT principal, so the position is not empty. Unrelated donation: not a receipt and not fulfillment |
| What older notes say is missing | A choice among burn, permanent retain, or abandon when the position looks mature and empty, plus “late-gift timing” |
| Why existing rules answer it | The prohibitions already pick the safe required behavior: do not burn rights, do not transfer ownership, do not retire on zero principal, and keep crediting intended-note proceeds. No user-facing transition requires a destructive retirement. Inventing burn versus abandon would be a new requirement. External payment timing is not a product parameter; the response on arrival is already specified |
| Next deliverable | Implement those prohibitions and the E+1 withdrawal. Do not add a retirement burner in order to “close” L4 |

---

## 4. Tracker rows that are not new gaps

| ID | Classification | Why |
| --- | --- | --- |
| NN-01 | IMPLEMENTATION/TEST | Addresses and `DEFAULT_FORK_BLOCK` exist. Fresh pinning is not a research blocker |
| NN-02 / NN-15 / H01–H03 | RESOLVED for policy; IMPLEMENTATION/TEST for holder code | Custody, excess, E+1, and non-retirement are specified. Upstream scan cost is a later measurement, not a decision |
| NN-03 | RESOLVED | Closed. Do not reopen survival design |
| NN-04 | RESOLVED; fork check only | Lock timing is specified. Oracle-term matching is a fork test, escalate only if a real incompatibility appears |
| NN-05 / NN-06 | RESOLVED; IMPLEMENTATION/TEST | Weights, synthetic, fees, BasePoolMath, and inner-share equations are in the PRD and plan §6.2. Writing code is not a missing model |
| NN-07 / NN-10 / L3 | RESOLVED for the challenged composition items | Claim graph, SY inverse, provider sample, and exact-out failure rule are written. V1/V2 and live state are fork obligations |
| NN-08 / NN-09 | RESOLVED; IMPLEMENTATION/TEST | First-bond split and both TWAP contracts are in plan §§8.1–8.2. Unrun vectors are tests |
| NN-11 / L2 | RESOLVED | Do not reopen provenance |
| NN-12 / L1 | RESOLVED as model; IMPLEMENTATION/TEST for the adapter | Funded-gons and notification are selected |
| NN-13 / G0 | PROCESS ONLY | Instruction maintenance. Not a product question |
| NN-14 | IMPLEMENTATION/TEST | Rollover order is §11.4. Call arguments are binding work. No new bounty or stage is selected |
| NN-16–NN-20 | IMPLEMENTATION/TEST or editorial | Parity, ABI layout, arithmetic tests, and stale status labels. NN-20 may correct labels that this audit withdraws. That edit is documentation hygiene, not a new rule |
| L4 | RESOLVED as required behavior | See §3.6 |

---

## 5. Source-integration and fork obligations

These are not owner questions and are not research blockers under the human ruling.

1. Fork at `DEFAULT_FORK_BLOCK` against the documented Pendle factory, router, and router-static addresses. Discover the market with the factory. Read its YT. If that body is not the local V1 `InterestManagerYT`, use the body the fork returns before applying §6.6 equations.
2. Read live `interestFeeRate`, treasury, `doCacheIndexSameBlock`, expiry, and gauge `PENDLE` on that fork. Compare `PENDLE` with the market SY. A demonstrated equality is the only same-token case; spendability stays conditional and is not asked now because it is not shown.
3. Confirm NetNet staking warmup and one-epoch `stake`/`unstake` behavior on that fork before relying on NET preview parity. Local reference is not that proof. A mismatch is a fork defect to report, not a reason to design a catch-up loop.
4. Execute the vectors already written in plan §§6.5.8, 6.6.6, and 11.2. Unexecuted tests are not missing design.
5. Bind Keep-YT and rollover to the router functions already cited. Do not add a seed path for an empty successor.

---

## 6. Withdrawn blockers

The following must not be repeated as open specification or as reasons to question the owner:

- Independent re-verification of Pendle addresses or a new observation block before research can conclude.
- A force-claim provenance or event-monitor mechanism.
- A choice between provider-rate valuation and whole-book redeem valuation.
- An owned-HLP or Keep-YT sequence different from §§6.2, 6.4, 7.1–7.2, and 11.4.
- A residual beneficiary, output skim, or deletion of ERC-4626 exact-out.
- G0 as an unanswered product approval.
- L4 burn, abandon, or dormant-flag selection.
- Any new fee, reserve floor, Weighted inverse, ordinary PLP/YT liquidation, or catch of a required interest claim.

---

## 7. Confidence and limit

**Fact:** the citations above are in the current PRD v0.33, plan v0.9, tracker, and `ROBINHOOD_MAIN.sol` as read on 2026-09-28.

**Inference:** those passages close the six challenged items. Tracker sentences that still say “mechanism required” or “L3 composition pending” for those same items are stale labels, not additional requirements.

**Limit:** this pass did not re-read every historical companion linked from the tracker, and it did not run a fork. A later fork can still falsify a local formula. That is a test result, not a gap this audit is required to leave open.

**Confidence:** high that no new owner question follows from the challenged items. Medium that no unrelated paragraph outside the cited sections hides a different required choice. No certification of implementation readiness.
