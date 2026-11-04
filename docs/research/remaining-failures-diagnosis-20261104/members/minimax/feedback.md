# Member feedback — remaining-failures-diagnosis-20261104

## Identity

- Member: minimax. Phase: advisory review of the coordinator draft. Model: `minimax/MiniMax-M3`.
- Owned path: `docs/research/remaining-failures-diagnosis-20261104/members/minimax/feedback.md`. No other file was written; no peer feedback was read; no forge run; no sub-agents.
- Read for this pass: the coordinator draft only, plus local compiled artifacts under `out/` used to check the draft's own bytecode citations. No peer response, no peer feedback, no previous report re-read.

## Draft under review

- Draft ID: draft-remaining-failures-diagnosis-20261104-r1
- Path: docs/research/remaining-failures-diagnosis-20261104/coordinator/draft.md
- Coordinator-supplied SHA-256: `092c8f4b1db0498a210b073b8bf86e7a4c2dea8371e6f77ad202305bcec94d0d`. Recorded as supplied; not recomputed.
- Fingerprint: not computed. No independent fingerprint was taken for this file.
- Draft read in full: yes.

## Disposition

support-with-reservations

The draft's substance holds: one cause for the seventeen clock-shaped failures (the compiled test reuses a timestamp expression across `vm.warp`), a separate and still-open observation gap for test 6, and the previous report's numeric account confirmed while its runtime alternative is excluded by the sibling. I verified the draft's bytecode citations where they were load-bearing: the Aave window (`PUSH2 0x0e10; TIMESTAMP; ADD` at `0xd16`, `DUP1` at `0xd22`, `DUP5` at `0x626a`, `PUSH4 0xf28dceb3` at `0x6270`) and the staking one-day constant (`PUSH3 0x015180` at `0x4ebd`) are byte-for-byte as the draft says, and `0x015180` = 86400 s = 1 day, `0x015f90` = 90000 s = 25 h, `0x0e10` = 3600 s = 1 h. The reservations are locator precision, one form of evidence stated more weakly than the artifact allows, and one attribution the brief asked to be grounded. None of them changes a conclusion; all four are naming corrections to draft sections.

## Concerns

| # | Draft section | What I checked | Why it matters | Fix direction (advice, not an edit) |
| --- | --- | --- | --- | --- |
| C1 | Group 1, Source observation, fourth bullet (the V4 reserve liquidity artifact) | The draft cites "the second warp-call window `0x6c80` through `0x6d80` contains no `TIMESTAMP`". In `out/V4ReserveLiquidity.t.sol/CpPublicReserveLiquidityTest.json` the warp selector `PUSH4 0xe5d6bf02` appears at `0x624`, `0x663`, `0x6c6` and `0xd2d`. The range `0x6c80`–`0x6d80` contains no warp call at all; it is empty of both. | A reader cannot confirm the claim from the cited range, and "a window with no TIMESTAMP" is the weaker form of the argument. This artifact actually supports the stronger form: one 25-hour sum (`TIMESTAMP` at `0x61b` and `0x61d`, after `PUSH3 0x015f90`) precedes both `0x624` and `0x663`, and no `TIMESTAMP` lies between `0x624` and `0x663`, so the second warp cannot have re-read the clock — one computation, two consumers. | Cite `0x61b`/`0x61d`, `0x624` and `0x663` and state the one-computation/two-consumers fact, instead of citing the empty `0x6c80`–`0x6d80` window. |
| C2 | Group 1, Source observation, first and second bullets (staking and Aave windows), and the Inference paragraph that generalises from them | Each compiled `timestamp + K` is emitted as `TIMESTAMP; ADD` plus a second `TIMESTAMP; DUP2; SUB` overflow guard: staking `0x4ec1`/`0x4ec3`, Aave `0xd19`/`0xd1b`, V4 `0x61b`/`0x61d`. The draft quotes the windows as `PUSH3 0x015180; TIMESTAMP; ADD` and `PUSH2 0x0e10; TIMESTAMP; ADD`, one clock read each. | "Does not repeat `TIMESTAMP`" is easy to misread as "this window holds one clock read" when the window in fact holds a read plus its guard. It also leaves a reader unsure what pattern counts as a fresh read and what counts as a retained value. | State once in the Inference paragraph that a `TIMESTAMP` pair is one clock read plus the addition's overflow guard, so a site whose path has no pair consumes a retained value. That single sentence makes all five bullets readable on the same footing. |
| C3 | Group 1, "The supplied numbers are what that reuse produces", first sentence (the line `Error != expected error: RebalanceTooSoon(7202) != RebalanceTooSoon(3601)`) | The brief says: "Do not assume which side is actual. If you use that wording, cite the local formatter you read." The draft uses the wording and assigns the two numbers, without citing a formatter. The assignment is nevertheless forced by computation, not by print order: `7202 = 3602 + 3600` is the cooldown end the production contract must report after the first rebalance succeeded at clock `3602` (it required `block.timestamp >= 0 + 3600`), and `3601 = 1 + 3600` is the only value the retained expectation can take. | Leaving the side assignment resting on the printed order is exactly what the brief warned against, even where the result happens to be right; a reader cannot tell whether the draft reasoned from the formatter or from the arithmetic. | Either cite the local formatter that produced the comparison line, or add one sentence saying the two numbers are pinned by computation (`7202` from the cooldown arithmetic, `3601` from the retained pre-warp read) and that the conclusion therefore does not depend on which side the formatter prints first. The second option needs no new evidence. |
| C4 | Named tests table, "This draft" column, and Group 1's "Both mature-close tests revert `DeadlineExpired(3601)`" | The draft's evidence is not uniform in strength. For test 2 the retention is visible as a positive fact (`DUP1` at `0xd22` duplicating the one-hour sum; `DUP5` at `0x626a` feeding `PUSH4 0xf28dceb3`, which I re-read in the artifact). For tests 1, 5, 17 and 18 the claim rests on a path that contains no clock read. Test 18's artifact was not disassembled at all, per the draft's own Evidence gaps. | The table currently reads as if every row is equally evidenced, which overstates tests 1, 5, 17 and 18 relative to test 2 and hides the gap the draft admits for test 18. | Mark per row whether the retained value is visible in the bytecode or whether the support is the absence of a clock read on the path, and keep the "Univ3 mature-close bytecode was not separately disassembled" gap attached to the sentence that covers test 18, not only to the Evidence gaps list. |

## What was not adopted from others

- I did not adopt the draft's window-absence form of the reuse evidence for the staking, hook and prod-SE artifacts as sufficient on its own. I adopt it only where a retained value is structurally visible (test 2's `DUP1`/`DUP5`) or where one computation serves two consumers (the V4 artifact, C1). This is a strengthening of the draft, not a disagreement with it.
- I did not adopt any optimizer-pass naming. The draft names none; neither do I. The mechanism stays at "the compiled test reuses a timestamp expression", which is what the artifacts show.
- I did not read peer responses or peer feedback. The draft's "Preserved disagreements" table is the only account of peer positions I used, and from it I take only my own recorded position and the statement that the bytecode windows were adopted.
- I did not carry over the previous report's open item "Solar reuse not proved"; in the direction this draft states, that item is closed by the sibling discriminator plus the artifact citations.

This advisory neither replaces the draft nor authorizes implementation. No further round is requested.

## Limits

- No forge run and no test execution. The failure messages remain supplied runtime; nothing here reproduces them.
- Artifact freshness was verified by me only for the staking artifact: `out/TokenStaking.t.sol/TokenStaking_Test.json` records source keccak `0xb947948673fb8c039befb26f56ff81d9c1555131f3da2823e4ef0c1df9036b9d`, equal to the current file's keccak-256, and compiler `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`. I did not re-check source-hash freshness for the Aave, V4, hook or prod-SE artifacts; my reading of those is of the current `out/` tree as it stands.
- My offsets are instruction addresses in the deployed bytecode, not source lines. I did not have source maps for these artifacts, so I could not tie a bytecode window back to a source line, and I did not attempt to.
- The hook and prod-SE artifacts were not disassembled by me in this pass; C4's distinction between visible retention and path absence is carried from the draft's own citations for those two.
- The sibling `test_second_notify_during_period_extends` passing is inferred from its absence in the supplied failure list, as the draft and the brief both state; it was not re-run. It remains the load-bearing element of the exclusion of a Foundry runtime stale frame.
- This feedback is one advisory pass on one draft. It is not a second vote and carries no implementation authority.
