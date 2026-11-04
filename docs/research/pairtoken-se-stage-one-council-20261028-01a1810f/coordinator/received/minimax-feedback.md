# MiniMax advisory: coordinator archival receipt

Verbatim final response from Native task `st_01a183c3`, advisory epoch 1, on frozen draft r1.

---

# MiniMax advisory feedback — coordinator draft r1

## Identity

- Role: MiniMax, independent council member, `pairtoken-se-stage-one-council-20261028-01a1810f`, advisory pass on the coordinator's synthesis.
- Route: `minimax/MiniMax-M3` with the host-configured adaptive thinking setting — unchanged from my initial pass. No provider, account, model, or region fallback used or attempted.
- Scope of this pass: read the frozen coordinator draft and nothing else. No source file, target PRD, peer file, my own original, memory block, or other document was reopened. No research, no shell or project commands, no tests, builds, delegation, file edits, or writes. Arithmetic was used only on numbers already present in the draft.
- This feedback does not replace my original (`members/minimax/response.md`).

## Draft under review

- Immutable revision label: `pairtoken-se-stage-one-council-20261028-01a1810f-draft-r1`.
- Path: `/Users/cyotee/Projects/indexedex/docs/research/pairtoken-se-stage-one-council-20261028-01a1810f/coordinator/draft.md`.
- Read completely: 7 sections, 3 numbered technical corrections (C1-C6 headings C1-C6 across §3), 3 owner questions (Q1-Q3) plus a secondary policy table, 9 not-adopted claims (§5), and a 47-row traceability table (§6) covering all 52 numbered recommendations from the four members.
- No hash check was performed: this assignment states none is supplied or required and prohibits shell/project commands, so the draft is identified by the immutable label and path above.

## Disposition

**support-with-reservations.**

The synthesis is materially faithful to my original and to the evidence. It is honest about where the four members disagree, it declines to let my conclusions harden into owner decisions, and it is materially better than my original on two points where I was wrong.

Three of my original's claims were wrong and the draft is right to reject them. I accept those corrections without reservation, and I withdraw the underlying recommendations rather than defend them: (a) the Solidity `type(I).interfaceId` inherited-selector argument in my R3/R14; (b) the claim that the baseline releases the native reservation before the paired liquidity addition, in R6; (c) the claim that a zero tick-movement limit makes every price-moving zap revert, in R18. My R5's framing that exact parity is infeasible or too costly is also withdrawn for the reason given in §5 of the draft. My R16's "the dust branch is effectively disabled" phrasing was an overstatement and I withdraw it in favour of the draft's formulation.

The reservations are not about the draft's conclusions. They are that four items of mine that survive the corrections are dispositioned only as "rejected" and would therefore be lost from the final report, and that the draft's own body does not yet carry three of the items its §6 table dispositions. I detail these below. No requested changes to the draft's analysis are needed, and I am not asking for another round.

## Concerns

**A — Material, actionable: the surviving half of my R3 is dropped, and it survives *more strongly* after the interface-ID correction.**

My R3 made two claims. The first — that `type(IStandardExchange).interfaceId` equals the XOR of In and Out — was wrong, and the draft correctly rejects it in §5 item 1. The second — that the package must not register `IStandardExchangeOut.interfaceId` in ERC-165 — was always right, and the draft's §5 item 1 disposes of R3 entirely as an "erroneous ID argument", with §6 recording "reject inherited-ID argument; preserve explicit unsupported route semantics." Nothing in C1-C6, Q1-Q3, or the secondary table carries the ERC-165 point.

That is a loss, and the corrected semantics make it sharper rather than weaker. Under the rule the draft cites, `type(IStandardExchangeOut).interfaceId` is the XOR of that interface's own two functions (`previewExchangeOut`, `exchangeOut`), so it is non-zero and registering it *does* assert exact-output support that S1-P03 forbids — a client that probes ERC-165 would route exact-output swaps into a vault that always reverts. And `type(IStandardExchange).interfaceId` is the XOR of an empty set, i.e. `0x00000000`, so registering the "combined marker" registers the conventional "no interfaces" value.

Requested disposition: the final report should carry three concrete PRD edits, none of which touches the owner's confirmed choice. (i) Do not register `type(IStandardExchangeOut).interfaceId`. (ii) Do not register `type(IStandardExchange).interfaceId`; it is `0x00000000` and is not a route-capability marker. (iii) Register `type(IStandardExchangeIn).interfaceId`, `type(IStandardizedYield).interfaceId`, and the rest of the intended set. The two exact-output **selectors** stay installed and keep reverting `ExchangeOutNotAvailable()`, which is precisely what S1-P03 confirmed; only the ERC-165 advertisement changes.

One related correction to the draft's framing: §5 item 1 says "do not override the owner's choice based on MiniMax's erroneous ID argument." My recommendation never sought to override S1-P03. It proposed installing the same selectors with the same revert behaviour and changing only what ERC-165 advertises. The phrase invites a reader to treat ERC-165 registration as part of the settled choice, which it is not.

**B — Acceptance, with the corroboration that supports it, and one residual.**

The draft's Solidity claim is correct and I accept it: `type(I).interfaceId` is the XOR of selectors declared directly in the interface, excluding inherited functions. Two independent in-repo corroborations support it and are worth putting in the report so the finding does not rest on a documentation citation alone. The Wings SY facet declares one interface id (`type(IStandardizedYield).interfaceId`) and installs exactly the 16 SY selectors, and `NativeStandardYieldSelectors` is explicitly built to append "Canonical Pendle selectors ... without ERC-20 duplicates" — coherent only if that id covers the 16 and not the inherited `name`/`symbol`/`decimals`. And `ERC20Facet.facetInterfaces()` returns `type(IERC20).interfaceId`, `type(IERC20Metadata).interfaceId`, and their **manually computed** XOR, which is what an implementer must do precisely because `type()` does not combine inherited sets.

Residual: §5 item 1's "independently declare the intended canonical interfaces" is too vague to be actionable on its own. The three bullets in Concern A are the specific form it should take.

**C — Acceptance of the R6 correction, with a factual note about my error and one surviving clause.**

The draft is right: at the point of the paired addition the reservation holds the refund remainder, and `_idle` subtracts it, so the refundable amount is excluded from the eligible idle. My original read "reassigned" as "released". I withdraw the alleged baseline defect and the claim that an implementer following the baseline would reintroduce one.

The surviving clause should stay: the PRD should state the invariant explicitly, because the baseline's `deposit` expresses it only implicitly through the sequencing of `_nativeReservation = msg.value - q.amount0` before `_pairedAddition()`. The proposed wording is still useful as a *statement of what the baseline already does* — the refundable remainder is a reserved, unbooked liability and is never part of the eligible idle used by the paired liquidity addition — and §5 item 2's "Keep explicit reservation invariants" already endorses this. The report should not record it as a defect.

**D — Residual of R7 that the draft does not carry.**

§5 item 3 and §6 ("no mandatory full public-method override") are right: `_standardRoute` and `_redeemVaultHeld` are `internal virtual` seams, and overriding them preserves the shared validation and the canonical `Redeem` event. I withdraw "override `redeem` in full".

Three things from R7 survive that appear nowhere in the draft's body:

1. The `isValidTokenIn`/`isValidTokenOut` derivation rule. The shared base derives both from `_contains(getTokensIn()/getTokensOut())`. The PRD requires native pools to report `getTokensIn()` as `[address(0), C0, C1]` and ERC-20 pools as `[C0, C1]`, so `isValidTokenIn(address(0))` is true on a native pool and false on an ERC-20 pool — but only if the family does not override the derivation independently. The PRD never states this, and the surface is exactly where an ERC-20 call on address zero would originate.
2. The native preview must equal native execution: `previewRedeem(address(0), s)` must return the wei amount `redeem(address(0), s)` pays, and `previewRedeem(C0, s)` that same amount expressed as wrapped native. The shared preview returns `0` for an invalid token and otherwise delegates to a single-`uint256` internal with no native awareness.
3. The concrete hazard: the shared `redeem` routes both branches through the ERC-20 `_exchangeIn`, so a native redemption reaching it with `tokenOut_ == address(0)` produces an ERC-20 call on address zero, which S1-NATIVE-01 forbids. §5 item 3's "correct internal dispatch" gestures at this but does not name it.

**E — Residual of R19: the disposition should be "booked to the last holder", not "abandoned", and the PRD's current sentence does not reach it.**

§5 item 4 rejects my two proposed destinations and correctly adds that operation-generated assets should not become unbooked. But the surviving requirement is not fully captured by "the draft already assigns all booked assets to the last paired exiter", because the assets in question are *not* booked. Under the booked-ledger discipline, a removal residue or an unconsumed swap output that never enters the ledger is outside the book by construction and is stranded. The PRD's S1-ACC-05 sentence covers "Unbooked unsolicited balances" only, and unsolicited balances are precisely the ones that should *not* go to the last holder.

Requested disposition: the final report should record that S1-ACC-05 must state that operation-generated residue is **booked to the last holder** (and hence is not stranded and not forfeited), and that the current sentence's scope is "unsolicited balances" only. This is consistent with the draft's own C5 principle that every settled receipt "must have one owner and be booked once".

**F — Factual correction to the draft's characterisation of my R8.**

§5 §Q1 says my `deployed_i - idleBefore_i` "can be negative". My formula applied `max(0, idleBefore_i)`, so the term cannot be negative; the objection does not apply to what I wrote. The substantive objections — that the subtraction does not trace swap-converted ownership and does not resolve fee attribution — are correct, and I withdraw the formula as a candidate. Q1's handling of R8 is otherwise fair: the problem statement is adopted, the candidate is rejected, the one-share tolerance is correctly read as a predicate allowance rather than a repair, and the "decision gate rather than reporting obligation" framing survives in C6's "objective approved economic predicates" and in Q1's requirement that a complete integer equation land in the PRD before coding. Grok's candidate is presented as unvalidated rather than endorsed, which is the correct treatment.

**G — Acceptance, with a note on the underlying reason.**

The draft's §5 item 9 is right: the baseline compares `|tickAfter - tickBefore|` and `maxZapTickMove`, so a sub-tick price move leaves the movement at zero and does not revert. My "makes every single-token zap revert in any pool whose price moves" is withdrawn. The surviving substance of R18 — that `maxZapBps` does double duty (single-depositor zap cap, and the compound swap cap at a quarter of itself) while `maxZapTickMove` bounds only the entry swap — is correctly preserved in §6 as a documentation item.

**H — Acceptance: I withdraw the feasibility framing of R5.**

The draft is right that tick-crossing state is simulatable in principle, and I should have checked the repository's existing quoters before framing exact parity as a feasibility problem. My R5's implication is withdrawn. §6's disposition ("acknowledge simulator cost; do not adopt unsupported impossibility or conservative guarantee") is fair, and Q2's demand to define the work unit ("one canonical swap-loop iteration, including empty-word/zero-liquidity progress"), to validate the 512 figure before ratifying it, and to state its effect on all money paths — including that applying it to execution can reject a manager-executable exit — is a sharper formulation of my concern than my own. I concur with Q2's recommendation of exact parity over a precisely documented admitted domain.

**I — Concession on R4, plus a precision note on the draft's stated reason.**

I concede the draft's outcome on R4 and I concede that my own option (a) was defective. The PRD's `depositPair` is payable for native pools; the canonical `IStandardExchangeMultiAssetLiquidity.joinProportional(uint256[],address,uint256,uint256)` is not payable, so its selector cannot serve a native paired deposit without changing a canonical ABI. The draft's "nonpayable join semantics" objection is therefore correct and dispositive for the paired route, and "keep the narrow paired surface" is the right call. I withdraw the proposal to adopt the canonical shapes.

The precision note: the draft's rationale conflates two different things — installing the multi-asset interface (which does bring the extra operations) with adopting an argument shape (which does not). Since the payable/nonpayable point independently settles the paired route, the report should say that rather than leave the extra-operations argument standing as the reason, so the decision is not revisited on the wrong grounds later. The core of R4 — publish exact signatures, parameter/return types, and mutability for every paired method, preview, query, compound, and donation — is correctly retained in C6.

**J — Acceptance of the R15 supersession, plus one contradiction to fix in the PRD text.**

The coordinator's registry finding supersedes my R15. I asserted `contentsId` semantics without reading the registry's contents-ID and pair-query implementation; the draft's sources (`VaultRegistryVaultQueryTarget.sol`, `VaultRegistryVaultRepo.sol`) show the registry hashes an address-sorted token list for pair discovery, so hashing the PoolKey face order can leave a native pool's vault undiscoverable by its pair. I accept the supersession and withdraw the "unsorted hash over the face order" recommendation.

Two consequences the final report should carry: (i) PRD S1-ARCH-05's sentence — "`contentsId = keccak256(abi.encode(tokens))` for that ordered token list" — directly contradicts C2 and must be rewritten, not merely annotated; (ii) the single-list invariant I asserted is now deliberately two lists — `vaultTokens()`/`vaultConfig().tokens` in PoolKey face order, `contentsId` over an independently sorted copy — so S1-A07 and any contents-id acceptance row must assert the split rather than "the same list". C2's two bullets carry the substance; the PRD-text conflict and the acceptance-row consequence are additions.

**K — Acceptance of the R20 sharpening.**

§5 item 6 is right on both counts: two floors can differ from one mathematical floor, and an intermediate can exceed `uint256` where a final result would fit. My proposed wording named concrete arithmetic, but the draft's instruction to pin the chosen arithmetic *and its domain* is the better requirement, and §6's disposition matches.

**L — Acceptance of R10's withdrawal, with a placement note.**

The draft is right that no deviation from baseline economics exists on the 18-decimal fact — `PairToken` is 18 decimals — and the PRD's S1-X register is defined relative to the baseline, so a Wings-relative row would be off-register. I withdraw the row proposal. The divergence from the existing V4 package (which sizes shares to the target token's decimals) is real and worth one sentence of *context* in the final report to the owner, since the owner may encounter it when comparing families; it belongs in the report narrative, not in the PRD's deviation register.

**M — Acceptance of the R11 reclassification.**

§6's "equivalent reads are preserved behavior, not unsupported scope" is correct: `StateLibrary` reads the same state the baseline hand-computed, so the *behaviour* is preserved and only the access path differs. My "unsupported scope" classification would have wrongly implied a behavioural difference. I withdraw it. The surviving substance — pin the tick derivation, the pool id, the position id, and the canonical state reads in S1-ARCH-02 — is retained in C6.

**N — Addition, not in the draft: the baseline's native settlement sequence is itself a deviation and the register does not list it.**

C4 prescribes an explicit native `sync` before settlement. If that is correct against Crane's V4 manager, then the baseline's `_resolve` path — which calls `settle{value: amount}()` for native **without** an explicit native sync — is not portable, and the family therefore departs from the baseline's settlement sequence. The PRD's S1-X register is explicitly "the baseline algorithms with the following named changes", so a settlement-sequence change belongs there or the register's scope statement needs qualifying. C4's fee paragraph already uses the phrase "Record any deliberate baseline deviation for owner review"; the same treatment should apply to settlement ordering, because it is the same class of finding and is the one place where the family knowingly diverges from the baseline's sequencing.

**O — Addition: several of my items are dispositioned only in the §6 traceability table and would be lost.**

§6 disposes of MiniMax R9 (verify zero fee-ID registration against the registry path), R16 (document `DUST = 1000` as raw units), R17 (add a "new capability, no baseline counterpart" class to the comparison-ledger taxonomy), R22 (name the `TransientStateLibrary` unlocked-state read and the explicit unlock error), and R4's ABI publication in ways that do not appear in the C1-C6 body or in the secondary policy table. Each is carried only as a table row. The final report's "PRD revision instructions" should state them explicitly, or they will fall out of the synthesis. For R22 in particular, §6 points to C4/C6, but neither section actually states the unlocked-read requirement, so the traceability row is currently the only trace.

**P — Minor, editorial: "the draft" is overloaded.**

Throughout §3 and §4 the coordinator uses "the draft" for the *target PRD* — "The draft's human-normalized formula", "The draft hashes PoolKey face order", "The draft chooses a price-sensitive accounting value" — inside a document whose own title is "coordinator draft r1". A reader of the final report, or the owner, could attribute PRD text to the coordinator's synthesis. Suggest "the PRD" / "this draft" throughout.

**Q — Minor, factual: the process note about my write mechanism.**

§1 records that I "reported using another Markdown writer despite the required inline fallback when apply_patch was unavailable". That is accurate and I do not contest it. For the record, the facts are: `apply_patch` was not exposed in my session (confirmed by two catalogue searches); the harness's first-class Markdown-creation tool was used at exactly the assigned path; no shell, scripting, or alternate path was used; and the substitution was disclosed in my original's *Assumptions and limits*. The report may state it that way. This advisory pass's instruction differs — no writes at all — and I have honoured it.

## What was not adopted from others

I did not read any peer's original, and I did not reopen the target PRD or any source file in this pass. I therefore speak only to the positions as characterised in the draft, and I make no independent assessment of them.

- I did not contest the spot-valuation policy in Q3. My original did not raise spot-versus-other valuation as an owner question; my only related point was the unit correction (R1, carried in C1) and that the rate's `A0`/`A1` must be the clamped removable amounts per S1-X13, which C6's piecewise definition and my R20 both require. I accept Q3 as a legitimate owner policy question and I do not ask to narrow it.
- I did not adopt the §6 characterisation of my R5 as advocating "unsupported impossibility" beyond withdrawing that framing myself, and I do not contest the draft's treatment of the other members' projection positions.
- I did not adopt the secondary-table entry "Positive-share burn with zero total payout | Reject" or the "Small genesis and donation rounding risk" entry as my own positions; they are attributed to other members and I have no evidence bearing on them, so I neither endorse nor contest them.
- I did not adopt the §6 characterisation of the registry ordering as a *Grok* contribution, because I have not read that member's original; I accept it on the draft's cited sources and on the basis that it supersedes my own unsourced assertion.
- I did not adopt the draft's §5 item 8 (Grok R13, no dead shares does not imply blanket risk acceptance) or item 9 (tick versus price) as claims I verified; item 9 I verified against the baseline's own tick comparison during my initial pass, and I concur on its merits.

## Limits

1. **Single-artifact review.** I read only `coordinator/draft.md` at the frozen identity `pairtoken-se-stage-one-council-20261028-01a1810f-draft-r1`. I did not reopen the target PRD, the baseline, the shared interfaces, my own original, peer files, memory, or any other document. Every claim I make about the draft's content is from that one read.
2. **No hash verification.** This assignment states that no hash is supplied or required and prohibits shell and project commands, so I performed no checksum. The draft is identified by its own stated immutable label and path. If the coordinator's process requires a hash attestation for this pass, that step remains outstanding on my side and should be recorded as such rather than assumed.
3. **The interface-ID correction is accepted on the draft's citation plus in-repo corroboration**, not on a fresh read of the Solidity documentation, which this pass forbids. The corroborations I rely on are the Wings SY facet's one-declared-id/16-selector correspondence, `NativeStandardYieldSelectors`'s explicit "without ERC-20 duplicates" purpose, and `ERC20Facet.facetInterfaces()`'s manual XOR of two `type()`-derived ids. If the coordinator wants this finding stated without a documentation dependency, those three in-repo facts carry it.
4. **Arithmetic** was used only on the draft's own C1 example (a `1e6` raw six-decimal book against `1e18` shares), which I re-derived and found correct: correct rate `1e6`, draft rate `1e18`, overstatement `1e12`. I introduced no new numbers.
5. **Nothing was executed.** No build, test, deployment, or Git operation occurred in this pass or in the underlying initial assessment, so all baseline-behaviour statements remain static-reading inferences. Where I now withdraw a claim (R6, R18) the withdrawal rests on source reasoning, not on observed traces.
6. **Peer positions are taken as characterised.** Where I say a position is "correct" I mean it is consistent with the draft's cited sources and with what I read in the initial pass; I have not verified the peers' underlying text and make no claim about it.
7. **This advisory pass adds no new requirements to the PRD.** Every item above is either a disposition of my own original, a correction I accept, or a narrowly scoped addition (Concerns N, O) to the report's instruction set. None proposes new behaviour for the stage-one family beyond what the draft already carries.
8. **No further round is requested.** The reservations above are for the coordinator to carry into `coordinator/resolution.md` and the final `REPORT.md`; I am not asking for the draft to be revised and re-reviewed, and my original stands unchanged in its corrected and uncorrected parts as the record of my initial assessment.
