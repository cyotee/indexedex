# Kimi K3 — cross-review, REQ-C04 (hook preview of zero)

- **Reviewer:** Kimi K3, continuing my first pass. My original (`kimi-original.md`) is unchanged; corrections are recorded here.
- **Date:** 2026-10-11.
- **Packet read together:** `astra-original.md`, `grok-original.md`, `minimax-original.md` (complete files, untrusted model evidence). No `*-cross.md` was read.
- **Independent re-verification this pass:** the disputed control flow in `UniswapV4DetfCommon.sol` (`:524-546`, `:550-619`, `:625-646`) was re-derived from my own prior read; the propagation hop `UniswapV4DetfMaintenanceTarget.sol:56-58` (`joinResidualAtomic` forwards to `_entryJoinResidualAtomic` with no catch) was read fresh and confirms Astra's citation in substance. No tests, shell, or edits. No consensus is claimed.

## Dispute A — zero proportional hook preview: may the single-asset fallback run, or must the parent revert immediately?

**Agree with all three peers, and with my original's primary reading: the parent reverts immediately; the fallback may not run.**

- Requirement text: OD-08 (Stage-1 REMEDIATION_PRD.md:184) — "A hook preview of `0`, or a hook join revert, rolls the parent transaction back" — restated without a mode qualifier in REQ-C04 (confirmation REMEDIATION_PRD.md:93). The current fallback path (`_joinResidualUnbalanced` returns false on the soft zero at `:605`/`:590`, then `_joinResidualCapped` runs at `:537`) is exactly the continuation OD-08 forbids.
- My original already concluded "absent an amendment, the plain text controls and the repair implements immediate rollback," flagging the death of the mode-fallback ladder as a design consequence. Astra ("the fact that another join mode could succeed does not create an exception") and Grok ("the conflicting tests are the bait") state the same conclusion more firmly. **Correction of emphasis, not substance:** I withdraw the residual framing that this is an open owner choice. No owner question exists; preserving fallback would require amending the stated requirement, which is outside any implementer's mandate. The test that encodes the forbidden continuation (`UniswapV4DetfLeftoverPreview.t.sol:52-84`, nonzero SE preview + zero unbalanced hook preview + successful single-asset join) must be converted to a rollback assertion, as all three peers also conclude.
- The ResidualGas oracle (`UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35,65-72`) — `retained_ = quoted_ == 0 || _hookPreviewIsZero(held_)` — independently confirms Grok's and Astra's "tests teach the wrong outcome" point; I had cited it, and the peer readings sharpen it: the disjunction must be split so only the SE zero preview authorizes retention.

## Dispute B — must the terminal `_updateReserve` at `:543-545` be deleted, or is reverting the hook-zero path before it is reached sufficient?

**Object to MiniMax's deletion; Astra, Grok, and my original agree: revert-before-reached is the repair, and the terminal write stays.**

- **Why deletion is wrong (new reasoning, verified against the loop bodies):** the terminal write at `:545` is not only the failure-path book — it is also the normal-completion custody sync. The join loops return the default `false` even after a fully successful deployment: the loop exits when the remaining amount reaches zero (`:554-570`/`:579-595`), and neither `_entryJoinResidualAtomic` nor the loops ever write the reserve. The `_updateReserve` calls at `:532` and `:538` fire only when a loop returned `true`, and a loop returns `true` only from the two SE-zero deferral exits (`:558-559`, `:583-584`). MiniMax's reachability claim — that after deletion the remaining paths are only early return, deferral, or already-booked — is therefore mistaken: a residual that was successfully joined to completion reaches `:545` with a reduced or zero balance and would lose its final reserve sync. That would introduce a new bookkeeping defect in the success path, the opposite of a repair.
- **What my original said and still support:** make the hook zero preview a hard revert at the point of observation (`:604-605`, `:614-615`), which makes the soft-zero breaks (`:565`, `:590`) unreachable from previews — the join itself already reverts on a zero/mismatched LP result at `:618` — and leaves `:545` reachable only from genuine completion or bounded-iteration partial progress with all previews nonzero. Astra's formulation is identical in effect: "deleting that write alone is not a repair," and reserve writes for completed settlement "need not be deleted indiscriminately." Grok's is the same: the fix is that "a hook preview of `0` must not reach that line."
- **Comment bait (unanimous, my original included):** `:548-549` ("a zero complete-route quote retains the booked remainder") and the "unmintable remainder" framing at `:543-544` must be rewritten so the terminal write is documented as post-progress custody sync, never as the response to a hook zero. MiniMax's enumeration of the SE-zero `return true` exits matches my read and is retained.

## Correction to my original (credit: Astra)

My original grouped `UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46-61` with the tests that "encode hook-zero → book." Astra's closer reading is correct: that test asserts the **SE** preview is zero first (`:48-49`), so production returns from the repaired retain helper before any hook join is attempted; its full-local-book assertion (`:58`) is valid under the OD-08 SE-zero exception. The defect there is documentary, not behavioral: `:55` ("zero unbalanced LP selects single-asset retry") and `:16` are misleading text that should be relabeled as SE-zero deferral, and the test should not be converted into a rollback case. My original's "rework three suites" item is corrected to "rework two suites (`UniswapV4DetfLeftoverPreview.t.sol:52-84`, `UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35-56`) and relabel the third."

## Adopted peer evidence

- Astra's propagation chain — sweep entry forwards into `_sweepDustBody` and the self-call `joinResidualAtomic` hop does not catch (`UniswapV4DetfMaintenanceTarget.sol:46-58`, read fresh) — confirms a revert at the preview propagates to the parent uncaught. No new catch is needed anywhere, which is the PRD's constraint.
- Astra's verification table (distinguishing SE-zero book, SE-preview revert, unbalanced-hook zero, single-asset-hook zero, join revert, and successful join with exact errors and full pre-parent state capture) is adopted as the test specification; it is stricter and better than my one-line test directive.
- MiniMax's error-surface note (reuse the existing `ResidualJoinUnavailable` vocabulary rather than inventing policy) is adopted as an implementation detail requiring no owner input.

## Remediation I still support (unchanged except as corrected above)

1. `_entryJoinResidualAtomic` reverts on a hook preview of zero in both modes (`:604-605`, `:614-615`), using existing error vocabulary; the revert propagates uncaught and rolls the parent back with no holder-reserve update.
2. The soft-zero loop exits (`:565`, `:590`) become unreachable from previews; remove or convert them to fail-hard so "zero means continue" is no longer a readable pattern.
3. Rewrite the bait comments (`:548-549`, and the scope of `:543-544`) so retention is documented as authorized only by a successful SE zero preview, and the terminal write as post-progress sync.
4. Do **not** delete the terminal `_updateReserve` at `:543-545` (Dispute B).
5. Tests: convert the two wrong-expectation suites to exact-error parent-rollback assertions with unchanged reserves; relabel the P18_R6 comments; keep the SE-zero retention positives and the funded join positives green.
6. Unchanged, as in my original and all peers: `_retainSubSharePairResidual` (`:625-637`), `_pairQuoteIsZero` (`:641-646`), no new catch, no bond/threshold/vesting redesign, no `beforeSwap` invention.

## Owner question

**None remains.** All four originals independently conclude OD-08/REQ-C04 already decides both disputed points: immediate rollback on any selected hook preview of zero, and retention of the terminal custody sync. I do not present that agreement as consensus proof; the controlling text is the citation, and my conclusion rests on my own re-read.

**Stop.**
