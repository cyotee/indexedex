# Kimi K3 — cross-review: REQ-06 plan drafts

- **Label:** Replacement-session cross-review, resuming my plan draft (`kimi-req06-plan.md`). I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. MiniMax is the labeled replacement `ses_eb8ab99f3ffe7suGF49ryUzI6t`. The three peer drafts were read in full as untrusted output; the production file and both test files were read directly this session. Nothing was edited.
- **Date:** 2026-10-17. I did not run Forge.

## The coordinator's flag: MiniMax's zero maxRedeem after a deposit — rejected

MiniMax's SharedFacet edit (`:235-243`) replaces `assertEq(maxRedeem(u), 0, "zero receipt-exit capacity")` with `assertEq(maxRedeem(u), 0, "user holds zero shares")` — keeping the zero and changing only the message. The test he edits deposits `100 ether` into `se2` at `:179` (verified this round), so `u` holds a **nonzero** share balance; under the ruling, `maxRedeem(u)` returns that nonzero balance. His assertion fails at runtime, and it preserves the zero-cap shape the owner rejected. Refuted twice over. The closed form is Astra's (`:112`) and mine: `assertEq(IERC4626(se2).maxRedeem(u), IERC20(se2).balanceOf(u), "maxRedeem is the owner share balance")`.

MiniMax is further rejected on two more points:

- **He keeps the receipt-limited test's redeem leg** (`:195`, `:281`): with `cap == balance`, `redeem(cap)` attempts `safeTransfer` of `fullPreview > held` — `redeem` draws held receipts only (`ReceiptBackedERC4626Target.sol:166-168`, verified), so the call reverts deterministically and his own stop rule fires on cue. A plan that ships a known-failing leg is not closed. Astra and I delete that leg.
- **His command runs only SharedFacet** (`:271-275`), so the two Behavior-file edits would never execute in validation. Rejected.

## Grok's draft: one compile hole

Grok replaces `:202-211` but leaves `:212` (`assertEq(held - _receipt().balanceOf(_se()), paid)`) standing on the deleted `paid` — the file would not compile. The rest of his draft (production body, SharedFacet inline form, deletions) is correct. The full-function replacement (below) absorbs this.

## The closed plan

**Production** (unanimous, verbatim from the PRD): `maxRedeem` is `_requireFamily(); return ERC20Repo._balanceOf(owner);`; delete `_redeemFitsReceipts` and `_largestRedeemableShares` (verified this session: no other caller exists, so deletion is compile-safe); `previewRedeem`/`maxWithdraw`/`redeem`/`withdraw` and selectors untouched. One addition I adopt from Astra: replace the stale capacity NatSpec at `:72-73` ("advertised only when its receipt payout … fits in held receipts") with her neutral sentence (`:19-23`) — leaving it would re-teach the withdrawn rule, the defect class this council has repeatedly been ordered to fix.

**Tests:**

- **Behavior file, receipt-limited test** — adopt Astra's full-function replacement (`:51-66`): the fixture setup is preserved, the withdrawn cap oracle and the doomed redeem leg are gone, and the test asserts `maxRedeem == balance` plus `maxWithdraw == previewRedeem(balance)`. Her rename to `test_maxRedeem_returnsBalanceAfterBackingChange` and comment swap are adopted: the old name (`paymentIsCappedByHeldReceipts`) asserts the withdrawn rule.
- **Behavior file, zero-preview test** — assert `maxRedeem == balance` at the PRD's `:233`; `maxWithdraw == 0` at `:234` stays true and stays put (MiniMax's rewrite of it is unordered scope — rejected; Astra's message rewording is optional, not adopted). Astra's rename to `test_maxRedeem_returnsBalanceWhenPreviewIsZero` is adopted for the same reason as above.
- **SharedFacet test** — the assertion becomes the balance equality (inline form above), the `redeem(1)` zero-maximum expectation and call are deleted, and the `withdraw(1)` zero-capacity leg stays. **Keep the existing test name**: `…_zeroReceiptExitCapacity_exactReverts` still describes the retained withdraw leg accurately, and no maxRedeem claim is embedded in it — Astra's rename there is unnecessary; dropped. My draft's extra `bal_` local is withdrawn in favor of the inline form.
- **Exclusions** (all four agree): `test_maxRedeem_fullBalancePayableAtNonIntegralRate`, `APEX_D46_CapacityFixtures.t.sol:83`, `ShortRedeemERC4626` — untouched.

**Command — Astra's** (`:131-137`): the production file as the positional edited source, plus three test-roots — the concrete CrossInterface host (which she verified exists and carries both dispatch families, `:139`), SharedFacet, and APEX_D46 as a preservation witness. My directory-wide root also works but Astra's is tighter and covers the preservation check explicitly; MiniMax's single-file command is rejected above; Grok's omits the preservation witness.

## Corrections and unresolved dissent

- My draft's two test-name notes are resolved: rename where the name teaches the withdrawn rule (the two Behavior tests), keep it where it doesn't (SharedFacet). My `bal_` local is withdrawn for the inline form.
- No unresolved dissent survives: Astra's draft plus the two adjustments above is the closed plan; Grok's has the one compile hole; MiniMax's is rejected on three grounds. Consensus is not proof — the runtime result belongs to the later authorized run, and no pass ran Forge.

I did not run Forge.
