# Grok advisory review

## Identity

- Label: grok
- Profile: research
- Phase: one advisory review of the frozen draft
- Requested role: council-member
- Requested model: `xai/grok-4.7:xhigh`
- Runtime role, model, reasoning, and task ID: not exposed
- Peers read before submission: no

## Draft under review

- Draft ID: `draft-se-fullspread-hook-matrix-20261104-r1`
- Path: `docs/research/se-fullspread-hook-matrix-20261104/coordinator/draft.md`
- Coordinator-supplied SHA-256: `0ee55f1e89a984afe5b6f20fe2491b7220f7114bd1ea8120da99aaf57482932c`
- That hash was not recomputed. The named file opened. No other draft was reviewed.

## Disposition

requested-changes

## Concerns

The seven topology file names, leg counts, rate-target cases, disjoint PoolKey rule, and the refusal to add `asset()` or a second instance of this vault are not corrections. They are one binding. Differences from my original row are not defects.

### Replacement for plan section 12, Other SE

Internal contradiction. The paragraph sets one bind and then says that bind is not the passing proof if it is rejected, while still calling that same bind the runnable proof.

The bind is: "The hook leg token is that share." For Dual, Orbital, Weighted `N3`, Curve, and Balancer `5`, the SE argument is the PairToken vault and the leg token is that vault's share. That is `token == se`.

The same paragraph then says: if the current package rejects `token == se` without `asset()`, record it under FS-HOOK-04 and do not pass that identity variant. It also says: "The runnable proof is the share transfer the hook accepts without calling that vault."

FS-HOOK-02 item 2 keeps those apart. An identity leg is `token == se`, and a reject is not a pass. A share transfer the hook accepts without calling that vault, or a raw token, can still be the other leg. The draft collapses the identity leg and the share transfer into one sentence, then says both that the identity variant does not pass and that the share transfer is the runnable proof.

Two implementers would not copy the same row after a reject. One would stop with the FS-HOOK-04 record and no passing Dual proof. Another would invent a different leg token that is not the share. The Dual section does not resolve it. It repeats "the PairToken vault and its share" and points a mint-or-redeem call at "the FS-HOOK-04 record above," which is the identity reject, a different event.

The sentence that must be corrected is the Other SE paragraph, so that the passing leg token is either the identity bind or a named non-identity share transfer, not both, and a rejected identity bind does not remain the runnable proof.

### Replacement for plan section 12, Common adaptation

Missing binding. Two sentences in this paragraph would be copied as different tests.

"When the hook calls `exchangeIn`, `msg.sender` is the hook. Trace that refund to the entitled caller." The previous sentence says the refund goes to `msg.sender`. The trace sentence does not say whether the entitled caller is the hook, the router, or the swapper. One implementer would assert the vault refunds the hook and stop. Another would fail the row unless the swapper's balance increases by the refund.

"Include a no-refund control." The paragraph does not say what that control asserts. One implementer would assert a fully consumed input has `amountRefunded == 0`. Another would assert a donation remainder is not refunded. The seven behavior files contain neither `donate` nor `compound`, and the same paragraph forbids calling them inside the outer unlock, so the second reading has no named subject.

The exact-out bullets are the same kind of gap. "`test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` expects the revert, or a zero `previewExchangeOut`" lets either outcome satisfy the test. One implementer would `expectRevert` and not check the preview. Another would assert the preview is zero and not require the revert. The fixture bullet earlier in this section already splits those calls. The test bullet puts them back into a menu. Name the assertion on each call. Do not leave `or` as the pass condition.

## What was not adopted from others

No peer response and no peer feedback was read. Nothing from another member was adopted, and nothing from another member was rejected.

## Limits

- This feedback does not authorize implementation and does not replace the draft. No second round is requested.
- The coordinator-supplied SHA-256 was not recomputed. PairToken source, the plan, the PRD, and `response.md` were not opened in this pass. FS-HOOK-01 and FS-HOOK-02 comparisons use the sentences already read in this run.
- The draft's choice of a raw third orbital leg, two raw Curve legs, and no fixture booked getter is not treated as a defect. Those choices differ from my original. They are not the corrections above.
- Tests, installs, deploys, and Git were not run. The draft, the plan, the PRD, `response.md`, and peer files were not edited.
