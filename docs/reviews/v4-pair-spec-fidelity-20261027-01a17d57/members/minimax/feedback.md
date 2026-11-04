# MiniMax — advisory feedback on draft `pair-spec-fidelity-r1`

**Role:** council member, advisory pass on the immutable coordinator draft (`coordinator/draft.md`, draft identity `pair-spec-fidelity-r1`).
**Independence:** I re-read only the draft, the current `evidence/manifest.md`, the frozen evidence and my own `members/minimax/response.md`. I did not read any peer's original or feedback file, and I did not edit the draft or any other file.
**Write mechanism:** `apply_patch` is not exposed in this session — a catalog search for it (`tool_search`) returns no matching tool, and there is no apply-patch primitive in my active tool set. As in the original pass I therefore used the harness's exact-match file-edit path (`write` to create, `edit` for corrections), against the single permitted path. The draft's "Workflow" bullet already records this as a consultation-process deviation; nothing in this pass changes that.

---

## 0. Position

**Support with requested changes.** The draft's verdict, framing, evidence discipline, coverage tables and provenance qualifications are sound and I support them without qualification. My requested changes are (a) one locator-convention fix plus exact source anchors, (b) three precision additions and one cross-reference, (c) four self-corrections recorded against my own original, and (d) one classification sentence in the final. **None of them changes the verdict, the severities, or the coverage conclusions.** I found no factual error in the draft's findings.

---

## 1. Integrity clarification (verified this session)

The clarification supplied with this advisory request is **confirmed**, and the current `evidence/manifest.md` now states it correctly with the four digests distinguished. My verification, run programmatically against the delivered files:

| Check | Result |
|---|---|
| `evidence/sourcify-sources.json` (archived, `b092a335…cea0`) with one terminal `\n` removed → SHA-256 | `ebbfbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98` — **exactly the recorded fetched HTTP body digest** |
| `evidence/specification.md` (archived, `f24991cd…963bb`) with one terminal `\n` removed → SHA-256 | `15c6d7790aa1f8eca1c36ec0d147483359e2ff7d018c56ed8240e394d2c878e3` — **exactly the published `REPORT.md` digest** |
| Archived JSON parses | yes; metadata block matches the manifest (`matchId 55980642`, `exact_match` creation/runtime, chain `4663`, address `0x56C8…7533`) |
| Archived files end with | JSON `…b'"}\n'` (one trailing newline); specification `…b's\n\n'` (one trailing newline beyond the report's own) |

So the correct rule, which the draft's "Archive hashes" bullet already states in substance: **the archive equals the fetched artifacts plus one terminal newline; removing that single newline reproduces the original bytes and the recorded digests exactly. No JSON re-serialization and no loss of the fetched response occurred.**

### 1.1 Self-correction required against my own original (request R-C7)

My original `members/minimax/response.md` F-20 and §2 concluded: *"I could not reproduce `ebbfbf46…` from any of compact / indent-2 / indent-4 / sorted re-serializations, so the original byte image is not recoverable from the pack."* That conclusion was **wrong as stated**. I tested re-serialization shapes and did not test the trailing-newline strip; the archive is the fetched body plus one `\n`, and the original bytes are exactly recoverable, as the table above shows.

- **Requested:** the final report carries the verified rule above (the draft's bullet is already right) and does not repeat any wording that implies the response was re-serialized or lost.
- **Requested:** my original file is annotated as superseded on this point rather than silently left standing or silently edited. The draft's "Archive hashes" bullet is accurate that "some originals read the manifest before its correction and report a mismatch" — that is me, and it should stay attributable; only the *conclusion* changes.
- **Minor:** my original's §2 table also described the delivered JSON as "a re-serialization of the fetched payload (compact JSON, one key per source, trailing newline)". The payload was not re-serialized; it was byte-preserved with a newline appended. Same correction, same location.

---

## 2. F-11 — I accept the draft's reframing (request R-C2)

**Position: the draft is right and my original overstated.** The bundled interface caution is real and is located exactly where the draft says: `evidence/sources.md:840-842` carries the three-line note "Note that feesAccrued can be artificially inflated by a malicious actor … For pools with a single liquidity position, actors can donate to themselves to inflate feeGrowthGlobal (and consequently feesAccrued) … atomically donating and collecting fees in the same unlockCallback may make the inflated value more extreme" (I re-read those three lines this pass; the locator is correct).

**But that warning, by itself, does not prove unbacked liabilities, a liability/collected mismatch, or an exploit in the report's design.** My original's F-11 implementation-consequence sentence went further than the frozen evidence supports: it said an attacker "would inflate `delta_i`, inflate `feePerShare_i`, and push `liability_i` above `collected_i`". That chain needs three things the bundle does not contain: the PoolManager implementation (absent), a donation path in the report's design (the report has no donation model at all), and an accounting of donated assets against `collected_i` (the report's `collected_i` is defined as fee escrow, which a donation is not).

**Requested wording for the final:**
- Keep F-11 as an **unresolved design question raised by the bundled interface's own caution**, stated as a documentation-level hazard to be resolved against the PoolManager implementation before the index-based attribution is relied on — **not** as a demonstrated vulnerability, an established liability shortfall, or a confirmed exploit.
- Keep the substantive source distinction where the draft puts it, in F3: *"The collection branch consumes settled `callerDelta` returned by `_modify(0)`, not a fee-index allocation directly based on the separately returned `feesAccrued`. Caller delta may include hook effects under the supplied interface."* That sentence is accurate against `src/pair/PairToken.sol` original lines 562-565 (the `Op.Collect` branch encodes `delta.amount0()/delta.amount1()` from `_modify(0)`) and 610-626 (`_modify` returns `callerDelta` and derives the consumed principal as `fees - callerDelta`). It is also *sharper* than my own original, which asserted the poke's caller delta "is the accrued fee amount" without the hook-effects caveat.
- Do not repeat my original's stronger phrasing anywhere in the final, and do not let the report's invariant-15 language ("remainder is never negative") appear as though a violation had been demonstrated.

---

## 3. Locator convention and anchors (request R-C1 — mechanical but worth fixing)

**The draft's preamble states:** *"Locations below use the original report's line numbers and original `src/pair/PairToken.sol` symbols. For the latter, bundle line number equals original source line plus three."* **The findings body then cites bundle line ranges only** (F1 "readable bundle lines 217-290 and 500-521"; F2 "bundle lines 62-69, 260-294, 503-511"; F3 "159-183 and 415-497"; F4 "22-32, 418-497, 579-613"; F5 "354-410, 541-550"; F6 "260-347 and 647-679"; F7 "224-234 and 647-651, receiver at 136"; F8 "124-155, 217-221, 550-644"; F9 "224-253"). The stated convention and the body are inconsistent, and the ranges are loose by a few lines at each edge. I checked each range against the original source; **none is wrong**, but a reader landing on bundle line 217 (`positionLiquidity`, original 214) does not land on `basket` (original 221), and bundle 500 (original 497, inside `_ratioSwap`) is not `_quoteShares` (original 500-519).

**Requested correction, in two parts:**
1. **Restate the convention** so it matches the body: either declare that source citations are bundle lines with the `+3` rule stated once, or convert them to original-source lines. I recommend the latter for the primary anchors, because the report and the source are both cited with original numbering and the mixed convention invites the off-by-three reading.
2. **Give exact anchors** for the statements the findings rely on. My original response already carries a full original-source line map; the anchors below are the ones the draft's findings depend on, and I verified each against the archived source:

| Symbol | Original `src/pair/PairToken.sol` lines | Draft finding that leans on it |
|---|---|---|
| `basket` | 221-230 | F1, F7, F9 |
| `previewDeposit` / `previewRedeem` | 233-240 / 243-250 | F2, F9 |
| `deposit` | 256-292 | F1, F2, F6 |
| `zapDeposit` | 308-346 | F6 |
| `redeem` / `redeemZap` | 351-363 / 366-389 | F5 |
| `_redeemToSelf` | 391-406 | F5 |
| `compound` / `_compound` | 412-414 / 416-443 | F3, F4 |
| `_carve` | 447-464 | F4 |
| `_ratioSwap` | 469-496 | F4 |
| `_quoteShares` | 500-519 | F1, F2 |
| `unlockCallback` | 550-571 | F8 |
| `_deployInLock` | 576-608 | F4, F6 |
| `_modify` | 610-626 | F3, F8 |
| `_resolve` | 628-642 | F8 |
| `_idle` | 646-649 | F7 |
| `initialize` | 138-152 | F8 |
| constants `BPS`/`DEAD_SHARES`/`RETENTION_BPS`/`DUST`/`DEAD` | 59-66 | F2, F5, F10 |

3. **F10 carries no source locator at all** ("Source: entire PairToken public surface, events/errors and token helpers"). Please anchor it: events at original 54-55 and 116-118; the 13 custom errors at 102-114; the ERC-20 core at 156-197 (`approve` 156-160, `transfer` 162-165, `transferFrom` 167-172, `_transfer` 174-181, `_mint` 183-189, `_burn` 191-197); `receive()` at 133; the 17 public getters at 47-74.

---

## 4. Precision additions (requests R-C3 to R-C6)

**R-C3 — F5: say what the removal's caller delta contains (material).**
The draft's formula is `amount_i = removalCallerDelta_i + floor(idle_i * payout / S)`. It does not say what `removalCallerDelta_i` contains, and a reader could reasonably take it for principal only. Under the bundled interface NatSpec (`evidence/sources.md:838`: "`callerDelta` The balance delta of the caller of modifyLiquidity. This is the total of both principal, fee deltas, and hook deltas if applicable"), a removal's caller delta carries **principal plus the position's accrued fees** (and may carry hook deltas). Source side: `src/pair/PairToken.sol` original 560/564 encode `delta.amount0()/delta.amount1()` from `_modify(-liqOut)`.
*Why it matters:* the report's central claim that fees are "not part of the share's redeemable property" (report L44, L127) is contradicted on the exit path by this alone, in addition to the compounding path the draft's F3 already covers. Adding the clause makes the contradiction visible on both paths.

**R-C4 — F5: the `uint128` truncation of removal amounts (observation, not a defect claim).**
Original 560 and 564 narrow `delta.amount0()/delta.amount1()` through `uint128` before widening to `uint256`. For values above `2^128-1` the widened result wraps. I flag this as an **arithmetic observation, not a demonstrated defect** — I did not execute it and no reachable amount is exhibited. Request one labeled sentence in F5 (or in a short "arithmetic observations" list) so a reimplementer does not silently reproduce or "fix" it without knowing it was noticed.

**R-C5 — Coverage → "Dependencies and limits": add the verified bundle-fidelity datum.**
The pack supports a stronger provenance statement than the draft currently makes. I parsed all 28 `## <path>` sections out of `evidence/sources.md` and compared each fenced body against `evidence/sourcify-sources.json["sources"][path]["content"]`: **28/28 byte-identical, no missing and no extra paths.** The draft's dependency section is careful about library coverage and missing implementations; adding this one line establishes that the readable bundle is a faithful rendering of the fetched payload — the strongest provenance fact the pack actually supports, and currently absent.

**R-C6 — F6: cross-reference the compound-swap consequence, and state the reconcile contrast.**
Two small additions to F6, which the draft already has the facts for:
- F6's consequence currently reads as though swap risk were confined to `zapDeposit`. F4's last sentence already establishes that "Ordinary deposit and redemption call `_compound` and can therefore cause swaps". Cross-reference it from F6 rather than repeating it.
- Add one clause contrasting the report's reconcile-or-revert rule (report L157 "If position liquidity is not that value, revert. Do not assign `U` from whatever liquidity the position happens to hold." and invariant 5 at L238) with the source's behavior, which F6 already describes factually: pulled funds that do not fit the add **remain idle** and the source performs no reconcile check on the ordinary path (the only position check is the genesis `added == 0` guard at original 285). F6 states the source behavior; the requested clause names the report rule it contradicts, which is what a reader needs to see.

---

## 5. Self-corrections I offer against my own original (requests R-C7 to R-C10)

The draft's three qualification bullets — "Clone/factory", "Nonstandard tokens", "Security" — are each tighter than my original, and the draft is right to tighten them. Please record the following as corrections to `members/minimax/response.md` rather than leaving the stronger wording to stand unannotated.

**R-C7 — my F-20 digest conclusion.** Superseded by §1 above (archive = original + one terminal newline; originals are exactly recoverable). My original's "not recoverable" wording must not be carried into the final.

**R-C8 — my F-11 implementation consequence.** Overstated relative to the frozen evidence (§2 above). The bundled interface warning is a documentation-level caution; it does not by itself prove unbacked liabilities, a liability/collected mismatch, or an exploit.

**R-C9 — my original §4.13 on the callback check.** My original said that in this source "the single check is in fact sufficient for the position's safety *as written*". That is stronger than the evidence permits, because the PoolManager implementation is absent from the bundle and the argument depends on the call graph. The draft's formulation is better: absence of the report's armed flag "establishes non-equivalence, not a demonstrated vulnerability or proof the weaker boundary is safe." The correct statement is: `onlyPoolManager` (original 120-123, 550) is the **only explicit authorization present** in the source; whether it is sufficient depends on the absent PoolManager implementation and on the fact that the clone is the only caller of `poolManager.unlock` (original 546-548).

**R-C10 — my original §4.6 on `_pull`.** My original wrote "fee-on-transfer tolerant", which reads as a general safety property. The source only *measures* the received balance (original 661-668) and does **not** recompute the share quote from that measurement. The draft's "Nonstandard tokens" bullet states this correctly; adopt its wording.

---

## 6. Where the draft is sharper than my original — endorse, no change requested

Each of these is a genuine improvement over my original and I want it preserved verbatim in the final:

- **F2:** "The `minShares` check occurs before that subtraction" and "previewDeposit returns the gross quote, not net recipient shares" — the gross/net ordering at original 272 (check) vs 285-287 (genesis branch) that my original left implicit.
- **F3:** "Caller delta may include hook effects under the supplied interface" — a correctness caveat I did not make.
- **F4:** the two caps are different objects — the compound cap is `floor(floor(pool-liquidity-implied reserve * maxZapBps/10000)/4)` (original 494-495) while the user zap is bounded by the **vault basket** reserve (original 332) — and compounding applies no tick-movement guard, unlike `zapDeposit` (original 339). My original said "poolReserve" without making that contrast explicit.
- **F5:** "A small positive burn can return zero if minima permit" and "Do not import the report's full-fill/zero-output revert guarantees" — the source clamps a zero swap output to 0 rather than reverting (original 591: `res.swapOut = outDelta > 0 ? uint256(uint128(outDelta)) : 0;`) and only checks minima.
- **F8:** "A single user action may cause multiple collect/deploy/add/remove/swap unlocks, not one report-style encompassing callback" — accurate (e.g. `deposit` performs a collect unlock then an add unlock) and a cleaner statement of the report's §8 single-callback sequencing mismatch than mine.
- **F9:** "Actual redemption floors a liquidity slice and idle allocation separately; preview floors proportional total basket amounts … exact execution equality is not guaranteed" — the preview/execution divergence I noted only in passing.
- **F10:** "`Redeem` on the zap route emits pre-swap pair amounts, not final single-token output" — original 388; a real observable-surface detail my original did not call out.
- **The "Archive hashes", "Clone/factory", "Nonstandard tokens" and "Security" bullets** — all four tighten claims my original made more strongly, and the "Archive hashes" bullet correctly identifies the terminal-newline rule.

---

## 7. Disposition of my original findings and blockers

| My original | Draft disposition | Note |
|---|---|---|
| F-01 different product | **Carried** — Verdict + Product row + F1/F3/F5 | Verdict wording matches mine; the draft adds "not a faithful specification with a few missing details" |
| F-02 share pricing | **Carried** — F1 | Draft states the piecewise rule and floors/ceilings explicitly; stronger than mine |
| F-03 fee model | **Carried** — F3 | My F-11 sub-claim moved to the qualification bullet per §2 |
| F-04 exit math | **Carried** — F5 | My `uint128` observation not carried → R-C4 |
| F-05 `getRate` absent | **Carried** — F9 | Draft adds the preview/execution equality caveat |
| F-06 zap | **Carried** — F6 | |
| F-07 factory dependencies | **Carried** — F4 | Draft adds the best-effort notification caveats I did not state |
| F-08 genesis | **Carried** — F2 | |
| F-09 10 bps retention | **Carried** — F5 | |
| F-10 protocol carve | **Carried** — F4 | Sharpened by the draft |
| F-11 `feesAccrued` hazard | **Reframed** — "MiniMax F11" bullet | My phrasing not carried → R-C8 |
| F-12 no armed flag | **Carried and tightened** — F8 + "Security" bullet | My safety claim softened → R-C9 |
| F-13 donations / idle capture | **Carried** — F7 | |
| F-14 native and pull rules | **Carried and tightened** — F6 + "Nonstandard tokens" | → R-C10 |
| F-15 ABI surface | **Carried** — F10 + public-surface table | Needs anchors → §3 part 3 |
| F-16 deposit does not reconcile idle | **Carried in substance** — F6 | Report-side rule not contrasted → R-C6 |
| F-17 permissionless initializer | **Carried** — F8 ("`NotFactory` is declared but not used") | |
| F-18 DUST / `_skipAdd` / `_reservedNative` | **Carried in substance** — F4, F5, F6 | |
| F-19 report's citations outside the bundle | **Carried** — Coverage → Evidence row and "The original report's Crane/V2 citations are different artifacts" | |
| F-20 archive digests | **Carried but my conclusion superseded** — "Archive hashes" bullet | → R-C7 |
| Blockers B1-B11 | **Carried as a requirement list** — "Clean-room handoff and correction direction" | The draft's list matches my B1-B11 content. Request: if the final keeps a numbered blocker list, adopt the B1-B11 numbering so member inputs stay traceable |

**One item from my original is not represented in the draft and should be:** my §4.16, the explicit separation of *missing requirements* from *direct contradictions* from *intentional design changes*. Measured against this source, the "intentional" bucket is empty — every rule the report states is also a contradiction of the source, because the source implements the opposite. But the report labels its own choices honestly relative to *its* baseline (report L80, L161, L175, L281-286), and the draft's Verdict already says "The old exclusion is evidence of the report's intended scope, not a restriction on this audit". **Request:** the final carry one sentence stating that the report's proposal labels are honest relative to its own IndexedEx V2/Crane baseline, while every one of those choices is a contradiction when measured against this source. That prevents the final from reading as an accusation that the report mislabelled its own epistemic status.

---

## 8. Statements I do not contest

- The Verdict, its scope ("Do not use it as a source-equivalent specification or as a source-equivalent clean-room development handoff"), and the refusal to certify the alternative design as complete or secure.
- The Coverage tables: the report-section table (23 data rows) and the public-surface table (17 data rows). I verified the surface counts against the source: **17 named public/external functions** (`initialize`, `approve`, `transfer`, `transferFrom`, `poolKey`, `token0`, `token1`, `positionLiquidity`, `basket`, `previewDeposit`, `previewRedeem`, `deposit`, `zapDeposit`, `redeem`, `redeemZap`, `compound`, `unlockCallback`), plus the payable `receive()`, plus **17 public getters/state members** (original 47-74) — both counts in the draft are correct.
- The "Dependencies and limits" section, including "Astra and Kimi report full reading of all 28 bundled files. Grok and MiniMax distinguish focused reads, partial helpers and unexamined indirect dependencies; their narrower coverage must not be recast as full independent library audits" — that is an accurate characterization of my own §7, and I want it kept.
- The three-way separation in "Clean-room handoff and correction direction", and the explicit statement that exact-match metadata, SPDX identifiers and documentary accuracy do not settle clearance. No legal conclusion is offered anywhere in the draft, and I concur with that boundary.
- The publication-state block: the advisory pass is the only one, member files remain individually owned, and final revisions are coordinator-owned rather than retroactively member-approved.

---

## 9. Summary of requested changes

| ID | Type | Request |
|---|---|---|
| R-C1 | Mechanical | Fix the locator convention and add exact original-source anchors; anchor F10 |
| R-C2 | Substance | Keep F-11 as a documentation-level caution, not a demonstrated vulnerability or liability mismatch; keep the source delta distinction in F3 |
| R-C3 | Precision | F5: state that a removal's caller delta carries principal plus accrued fees |
| R-C4 | Precision | F5: add the `uint128` narrowing of removal amounts, labeled as an observation |
| R-C5 | Coverage | Add the verified 28/28 byte-identity between the readable bundle and the source JSON |
| R-C6 | Precision | F6: cross-reference the compound-swap consequence; contrast the report's reconcile-or-revert rule |
| R-C7 | Self-correction | Annotate my original F-20: the archive restores the original body exactly |
| R-C8 | Self-correction | Annotate my original F-11: the interface warning alone proves no liability shortfall and no exploit |
| R-C9 | Self-correction | Annotate my original §4.13: `onlyPoolManager` is the only explicit authorization present; sufficiency is not established |
| R-C10 | Self-correction | Annotate my original §4.6: measured receipt is not a general fee-on-transfer safety guarantee |
| R-C11 | Framing | Add the one classification sentence separating the report's honest proposal labels from the contradictions they amount to against this source |

---

## 10. Advisory position, stated plainly

I **support** draft `pair-spec-fidelity-r1`. Its verdict, its finding set, its coverage tables, its dependency limits and its provenance qualifications all hold up against the archived source, and in eight places (F2 ordering, F3 hook caveat, F4 cap distinction, F5 zero-burn and full-fill cautions, F8 multiple-unlock point, F9 preview/execution divergence, F10 zap-route event payload, and the four qualification bullets) it is sharper than my own original. I request the eleven changes above, none of which alters the verdict, and I withdraw the three statements of mine that the draft correctly identified as overstatements (R-C7, R-C8, R-C9) together with one further tightening (R-C10).

This is the single advisory round on this draft. It is not implementation authorization, it does not modify the report or the draft, and it creates no approved clean-room process.

*Prepared by MiniMax (council member) for the advisory pass on `pair-spec-fidelity-r1`. Observations carry source locators; conclusions are inference. No file other than this feedback file was created or modified; no tests, builds, installs, deployments, Git operations, configuration changes, code changes, delegation or external messaging were performed.*
