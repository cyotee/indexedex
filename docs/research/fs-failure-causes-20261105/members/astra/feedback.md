# Identity

- Member: astra
- Phase: advisory review
- Requested role: council-member
- Requested model: chatgpt-subscription/gpt-6-astra:high
- Runtime role, model, reasoning setting, account route, and task ID: not exposed
- Fresh or continued: continued
- Peer responses or peer feedback read for this advisory: no

# Draft under review

- Draft ID: draft-fs-failure-causes-20261105-r1
- Path: `docs/research/fs-failure-causes-20261105/coordinator/draft.md`
- Coordinator-supplied fingerprint of the pre-fingerprint-line bytes: `26c3a0f02241d084d81ed8ccdc3953d49c5d720b21888b546041a953d1c05e7e`
- Fingerprint verification: not computed.
- The complete draft was opened and read. No other file was read for this advisory.

# Disposition

requested-changes

The draft accurately preserves my central grouping: a shared one-sided sizing trigger, different consumer failure paths, and two independent dual-fixture causes. It also correctly rejects treating every hook-family failure as a `beforeSwap` wrapper. The corrections below concern the numerical evidence, partial-consumption coverage, and the source support needed to preserve those distinctions.

# Concerns

| Draft section | Why readers could diverge | Requested change, as advice |
| --- | --- | --- |
| Proposed text, section 1: coordinator-supplied `SizeReject` measurement; Preserved disagreements; Evidence gaps | The measurement is attributed to a **1 ether** face preview, but the displayed comparison operands are approximately **99.845 ether**. If those operands are the required net `n` and applied input, as the surrounding explanation suggests, they cannot describe that same 1 ether call through the planner inspected in my initial response: the earlier guard rejects gross input above the offered amount, before reaching `applied < n`. My source-derived 1 ether matrix calculation instead produced `n = 499248760185015444` and applied input `499248760185015443`. One reader could treat the supplied measurement as direct corroboration of that exact case; another could infer a different amount, different diagnostic fields, or a different source state. The draft currently leaves that inconsistency unexplained. | Clarify the diagnostic field meanings, actual offered amount, units, and source-state relationship using the coordinator's already-held evidence. If that association cannot be established, retain it only as a separately supplied, incompletely identified one-unit-shortfall example, not corroboration of the named 1 ether preview. Keep my bounded arithmetic results explicitly classified as source-derived calculations rather than reducing them to an unspecified belief about the trigger. This does not require adopting one predicate for every possible fixture or running another diagnostic. |
| Proposed text, section 1: partial-consumption bullet; Coverage adopted from responses: “Partial-consumption rows” | The blanket statement that these failures assert a residue, and the coverage phrase “same refund word,” lose an important exception. The constant-product partial-consumption test, including its inherited integration row, fails during `_seed` with `InsufficientLpOut` before reaching its partial-consumption control. The other families use different assertions: the single-buffer test rejects a refund at least 1% of the input, while the shared helper requires `0 < refund < amount`. That shared helper's error message alone does not distinguish a full refund from a zero refund. A reader could therefore wrongly classify all named partial-consumption failures as observations of the same refund assertion. | Separate the constant-product seed failure from the direct refund-assertion failures. State the two actual refund predicates and distinguish the supplied single-buffer full-refund value from the source-derived full-refund explanation for the shared helper. Keep the helper's preceding face-to-face control swap visible when describing that inference. |
| Proposed text, section 2: Orbital bullet; Evidence gaps: Orbital | “The seed accepts a zero quote” followed by “effective reserve or R is zero” preserves the terminal alternatives but omits the mechanism that distinguished Orbital in my response. Initial valuation falls back to the offered face amount when its conversion preview is zero; actual buffering permits zero returned shares; subsequent effective reserve valuation requires held SE shares. The other funded legs can support a positive radius. Without that sequence, two readers could understand this as either a generic uninitialized-radius problem or the specific mismatch between seed valuation and the actual converting-leg inventory. | Restore that short source-based sequence. Retain the honest limit that the runtime predicate was not traced, but distinguish the supported zero-effective-face-reserve explanation from an independently observed `R == 0` event, which the draft does not have. This is a clarification of diagnosis, not a request to alter the mechanism. |
| Proposed text, sections 1-4; Coverage adopted from responses | Most behavioral claims lack a source path and line. Section 2 has no per-family locators, and the limited coordinator checks elsewhere use basenames rather than full repository paths. In particular, planner locators alone do not support the separate execution-refund claim. Readers cannot verify whether similarly named targets, shared behavior files, or concrete row overrides support the adopted stage of failure. The grouped coverage table also does not identify every concrete failing file individually. | Carry forward the full repository paths and relevant line ranges already available in the admitted member material for each behavioral chain. Name all concrete failing files in the coverage table, even when several share one diagnosis. Preserve the distinction between member-read locators and coordinator-rechecked locators; do not imply every citation was independently rechecked by the coordinator. |

# What was not adopted from others

I read no peer originals or feedback. The draft's summaries are the only peer-position material considered here.

- I do not adopt the summarized MiniMax token0/token1 explanations as established causes for the same initial fixture inputs covered by my arithmetic. The draft may preserve that disagreement, but it should identify the scope and evidence class of each account rather than implying equally matched calculations of the same case.
- I do not treat the coordinator's newly supplied `SizeReject` excerpt as my observation or as corroboration of the exact 1 ether case until the numerical association described above is clear.
- I accept the caution that Native's bare assertion string does not independently identify its failing assertion. My initial source-derived explanation of the one-sided call remains an inference, not a recovered trace.
- I accept retaining the untraced-token/pull limit on the dual allowance diagnosis. The draft accurately represents my stale-route explanation as the adopted causal reading rather than a newly observed execution trace.

# Limits

This advisory uses only the complete pinned draft and the retained context of my initial independent work. I did not reopen my response, project sources, peer material, the brief, or the run record; recompute the fingerprint; run tests; or launch a sub-agent.

Only this feedback file was written. The requested changes are advice to the coordinator, not edits to the draft or project. No further advisory round is demanded.

This feedback does not replace the draft or my original response and does not authorize implementation, a haircut, a numerical search, or a code edit.
