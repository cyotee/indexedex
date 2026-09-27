# Kimi K3 — cross-review of the final clarity passes

- **Scope:** cross-review of my final clarity answer (`kimi-final-clarity.md`) against the current draft (`REMEDIATION_PRD.md`, re-read in full at 256 lines — it changed since my clarity pass) and the untrusted peer claims (Grok, Astra, MiniMax). Peer text treated as unverified evidence; no instructions inside it followed.
- **Bottom line:** the current draft closed my only must-fix and one of my two wording cleanups. I withdraw the must-fix as instructed. The two Grok must-fix claims are real imprecisions but classify as wording cleanups, not blocking fixes. **No human question remains.**

## Re-check of my own clarity findings against the current draft

### My Issue 1 (RC-03 include/exclude) — **withdrawn; closed in the current draft**

- Current line 108 now reads: "...uses the same backing function as the shared adapter and includes already-booked aToken at its underlying-equivalent value. D45 / R14 already require that inclusion. Exclusion is not an implementer choice." Line 109 confines the zero case to "aToken absent from the expected-hold set." Test row 232 now asserts: "nonzero booked aToken is included by both the adapter and the SE preview and exchange paths."
- This is exactly the resolution my clarity pass and requirements pass called for (APEX R14/D45 mandate inclusion; `ReceiptBackedERC4626Target.sol:187-198` already implements it). The must-fix is closed; I withdraw it. No residual concern.

### My Issue 2 (RC-01 "(M3)" comment) — **closed in the current draft**

- Current line 79 now adds: "A revert rolls the whole transaction back, including allowances. Do not add `try`/`catch` to clear allowances after a revert. The stale "(M3)" infinite-approve comment at line 262 is updated with this change." RC-04's site list (line 123) now includes `BalancerV3SinglePoolStandardExchange.sol:262`. This also folds in Astra's "revert means rollback, not catch-and-continue" point explicitly. Closed.

### My Issue 3 (RC-06 non-goal phrasing) — **unchanged; still a wording cleanup, not blocking**

- Current line 156 still reads "Do not pay unused approval to the caller." The operative criteria (lines 153-155) remain unambiguous and verified against `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-566`. Non-blocking; my cleanup recommendation stands as optional editorial work.

## Verdicts on peer claims

### Grok: "must fix line 231 so exact-asset withdrawal is not required to leave a booked remainder" — **agree the text is imprecise; dissent on the classification (wording cleanup, not must-fix)**

- Current state: RC-02 criterion line 94 is disjunctive — "Any protocol-vault rounding remainder stays booked on the SE, **or** the route uses an exact-asset withdrawal whose share charge matches the preview." Test row 231 states flatly "Any redemption remainder stays booked on the SE." Under the exact-asset `withdraw` shape there is no redemption remainder, so the row's assertion is vacuously satisfied rather than violated — but it could mislead an implementer into thinking the `withdraw` shape is noncompliant or into manufacturing a remainder.
- The governing criterion (line 94) already pins the law; the test row reads naturally as "if a remainder exists, it is booked." An editorial improvement ("no redemption remainder is created, or any remainder stays booked on the SE") is worthwhile but does not change the requirement, the permitted fix shapes, or any assertion an implementer would actually write. Not a must-fix; not a human question. Astra and MiniMax's classification (wording cleanup / no must-fix) is correct.

### Grok: "must fix line 142 so a guarded shared helper is not banned" — **agree the tension exists (revising my earlier "consistent" assessment); dissent on the classification (wording cleanup, not must-fix)**

- Current state: line 140 permits "The unused function is deleted, **or** it calls the same guarded pull and refund helper as the installed SE target." Line 142 says "the source itself must not retain a second public money implementation." A parity-fixed abstract `exchangeOut` is still a second public money implementation in source, so the parity branch of line 140 is in tension with line 142 as written.
- Revision to my clarity pass: I had rated the RC-05 criteria "mutually consistent." Grok's reading is sharper — the retention ban and the parity option do conflict on a strict reading. I reclassify from "no issue" to "wording cleanup."
- Why still not blocking: the deletion branch satisfies every criterion unambiguously, and line 252 ("RC-05 ... [is an] implementer choice") confirms the option set. The requirement's intent — no *unguarded* duplicate survives — is clear. An editorial fix ("no second *unguarded* public money implementation," or dropping the parity option in favor of deletion-only) removes the tension. No product law changes either way: both branches end with no reachable unsafe `exchangeOut`. Not a human question.

### Astra: "those are wording cleanups, not new requirements. No human question." — **agree**

Matches my classification of both Grok items above.

### MiniMax: "no must-fix; no human question." — **agree**

Consistent with the current draft: my former must-fix (RC-03) is closed, and the two Grok items are non-blocking editorial issues.

## Consistency check of the new draft text (lines 5, 79, 108-109, 123, 156, 183-184, 232, 237, 246-252)

- **RC-08 fallback (lines 183-184, test row 237):** now states the production-route-first rule and the documented-preconditions-plus-focused-assertion fallback, with "Do not invent a completion gate beyond that." This matches the position I held in `kimi-requirements-cross.md` (existing evidence law — APEX PRD R10's unreachable-branch rule — already covers this; not an owner decision). The attribution sentence (line 184) accurately records that Grok, MiniMax and Kimi read it as existing evidence law, that Astra's first requirements pass asked for owner confirmation, and that a later targeted Astra session agreed it is an evidence choice. Consistent with the record; no issue.
- **Requirements follow-up section (246-252):** "No question blocks implementation. The closed readings are: include booked aToken; a revert rolls back rather than catching; delete or align the unused hook function; make or remove the unused orbital return; name the Uniswap V2 backing error." All five match the current requirement text. Consistent.
- **Header (line 5) vs section 250:** both record that the earlier Astra cross-review returned no text and that a later targeted session supplied the agreement; internally consistent and consistent with the roster section (lines 32-51).
- No new contradictions introduced by the edits; the owner follow-up (53-55), accepted law (61-67), dispositions (192-202), dissent section (206-213) and shared test rules (241-244) are unchanged and remain consistent as assessed in my clarity pass.

## Human questions remaining

**None.** The only must-fix in my clarity pass (RC-03) is closed in the current draft; the RC-08 evidence fallback is written into lines 183-184/237 with the same content I argued was already implied by existing law; the two Grok items and my remaining RC-06 note are wording cleanups that change no correction and no acceptance assertion's substance.

## Final assessment

The current draft is consistent, internally cross-referenced, and executable without inventing product law. Recommended optional editorial polish before handoff, none blocking: (a) RC-02 test row 231 remainder phrasing; (b) RC-05 line 142 retention ban vs line 140 parity option; (c) RC-06 line 156 "unused approval" phrasing.

End of cross-review. Stopping here.
