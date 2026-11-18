# Identity

| Field | Value |
| --- | --- |
| Member label | minimax |
| Phase | advisory review |
| Requested role | council-member |
| Requested model and reasoning | minimax/MiniMax-M3, adaptive thinking |
| Draft ID | draft-v3-fullspread-v4-accounting-prd-20261116-r1 |
| Fresh or continued | continued |
| Initial response preserved | yes |
| This file replaces a missing initial response | no |
| Peer responses read | not read |
| Peer feedback read | not read |
| Unread members treated as support | no |

Runtime identity not exposed by this message: task identifier, session identifier, provider account, tool surface, wall-clock timing, and model build hash are **not exposed**. The message supplied only the fields above.

# Draft under review

`docs/research/v3-fullspread-v4-accounting-prd-20261116/coordinator/draft.md`, draft ID `draft-v3-fullspread-v4-accounting-prd-20261116-r1`. I opened that exact file and reviewed it. The coordinator-supplied fingerprint is recorded as not computed; I did not compute one.

What the draft contains, as read:

- A fence requirement `V3-ACC-01` that limits the copy to deposit, exit, dust, and share issuance, and that names the V4 locks it does not adopt (FS-OWN-34 through FS-OWN-37 hook rules, FS-HOOK-05, FS-HOOK-07 through FS-HOOK-10).
- Nineteen adopted requirements `V3-ACC-01` through `V3-ACC-19`, each with a copy statement: share basis over raw position liquidity, the 1,000-share genesis floor to `address(0)`, the clamped usage fee, the one-sided 49% mint, the boundary and zero-active-liquidity branches, the both-token deposit, the removal of the sleeve, the balance classes, refunds, fees on mint and exit, the one-token exit, the both-token exit, the pass-through, the pool-locked revert, the disable predicate, the manipulation limit, the external preview contract, and the dilution consequence of the copied mint formula.
- Six open decisions `V3-OPEN-01` through `V3-OPEN-06`: position import, `donate`/`compound`, selector names, existing supply, the stateful quote and Standardized Yield surface, and exact-out selector disposition.
- A Disagreement section, a Rejected alternatives section, and a Limits section that states the draft does not authorize implementation.

What the draft gets right, in my judgment, and did not get wrong: the fence in `V3-ACC-01`; the liquidation-free share basis and the floor in `V3-ACC-02` and `V3-ACC-03`; the one-sided mint shape and its boundary branches in `V3-ACC-05` and `V3-ACC-06`; the removal of the sleeve and of the reserve-based issuance in `V3-ACC-08` and `V3-ACC-09`; the exit apportionment and the all-or-nothing opposing swap in `V3-ACC-12`; the pool-lock policy as an explicit statement rather than an inherited sentence in `V3-ACC-15`; the manipulation non-claim in `V3-ACC-17`; and the protection of the external provider's `previewExchangeIn` call in `V3-ACC-18`. `V3-ACC-15` and `V3-ACC-17` match my initial response's positions exactly.

# Disposition

**requested-changes**

Two of the adopted requirements contradict either each other or the V4 lock they name, in cases that change user-visible behavior, and one dependency of the entry rule is left undefined. The six corrections in the Concerns table are each a bounded edit to a named section. The remaining requirements are, in my judgment, accurate and correctly classified.

# Concerns

| # | Draft section | Concrete defect or ambiguity | Advised correction |
| --- | --- | --- | --- |
| 1 | `V3-ACC-05` against `V3-ACC-03` | `V3-ACC-03` says an unusable first deposit reverts `MinLiquidityNotMet()` and "does not succeed as a whole-input refund". `V3-ACC-05` says that when the 49% swap is zero, unquotable, not fully spent, yields zero output, or the following mint cannot consume that output, "the call refunds the whole processed input, executes no swap, and mints nothing". On a first deposit both sentences apply at once. The V4 planner resolves it: the failed-genesis branch sets `plan_.failed`, and execution reverts `MinLiquidityNotMet()` before any refund; the refund path is the later-deposit branch, where added liquidity is zero and supply already exists. The draft cites that branch in `V3-ACC-03` but states `V3-ACC-05` without the supply condition. A reader following `V3-ACC-05` refunds a first deposit that the owner rejected; a reader following `V3-ACC-03` reverts it. | Qualify `V3-ACC-05` by supply. State that on a first deposit the failed swap or add reverts `MinLiquidityNotMet()` and moves nothing, and that the whole-input refund applies only when supply is already non-zero. Name the V4 planner's failed-genesis branch as the source of that distinction, as `V3-ACC-03` already does. |
| 2 | `V3-ACC-10`, the pretransfer sentence | `V3-ACC-10` says that when a one-token maximum exceeds the unbooked balance, the vault must "consume nothing beyond that balance, refund the unused amount, and do not pull a shortfall". The named source says the opposite for that case: if the maximum is larger than the unbooked balance on a one-token call, refund that unbooked balance, do not spend that unbooked balance, do not pull the shortfall, do not refund maximum minus used, and do not revert. Under the draft a staged balance is spent down to the amount the add needs; under the source it is left untouched and refunded whole. The draft also does not say what happens when the amount the add needs exceeds the credit: the draft's sentence permits consuming the whole credit and continuing with an under-funded add, and the current V3 code instead reverts `TransferDeltaInsufficient`. Two readers get different outcomes for the same call, and the difference is whether the caller's tokens leave the vault. | Restate the over-declared-maximum case to match the named source: nothing is spent, the whole unbooked balance is refunded, no shortfall is pulled, and the call does not revert. Separately state the case where the requested amount exceeds the credit, and say whether that reverts or refunds, so the two cases cannot be read as one. |
| 3 | `V3-ACC-05` and `V3-ACC-06`, the entry rule's subject | Both sentences turn on "the position" being strictly inside, or on "the token the position wants". The draft never says what the position is before genesis. Today the V3 vault creates the position lazily, inside the sleeve rebalance, after the deposit has already been priced and minted, and `V3-ACC-08` retires that rebalance without naming a replacement. On an empty vault the boundary test in `V3-ACC-06` is therefore undecidable: one reader derives `TickMath.minUsableTick` and `maxUsableTick` at the pool's tick spacing and fixes them before the first add; another keeps today's lazy creation and cannot answer the boundary question at all. Imported books are a further case, since `V3-OPEN-01` defers import but the entry rule still needs the bounds. | Add a requirement that states the managed position bounds, and that they are fixed before the first entry swap, so the entry rule has a subject on an empty vault. State the organic bounds, state that imported books use the imported ticks, and state that the bounds do not change after the first add. This is a decision the V4 PRD does not make for V3, so it belongs in the draft rather than in the open list. |
| 4 | `V3-ACC-18` | The section states that a full-book exit that cannot spend the opposing amount previews as a failed plan and that the provider then reads a zero rate. It does not state the provider's other zero-rate path. The provider's empty-supply call inverts a one-unit mint preview, and `V3-ACC-03` makes a first deposit below the floor revert. The draft therefore has a state in which the vault rejects the first deposit and the provider reports a zero rate for an empty vault, and no section says so. The instruction for this run forbids resolving an open product question by omission, and this one is a live consumer-visible outcome. | Extend `V3-ACC-18` to state the empty-supply outcome explicitly: when the first deposit would not exceed the floor, the mint preview is zero and the provider's empty-supply rate is zero. State that no fallback rate is added, as the section already does for the full-book case. |
| 5 | Scope, whole draft | The draft has no scope sentence naming which implementation it governs. The V3 remediation companion PRD requires the original V3 implementation under `contracts/protocols/dexes/uniswap/v3/` to be preserved in place and forbids modifying old source or repointing existing deployments, and `V3-OPEN-04` reaches only the question of migrating existing supply. Without a scope sentence, the draft could be read as changing the preserved implementation too, or as being read as authority over deployments it does not govern. | Add a scope requirement: the PRD governs the full-spread vault under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` only, the preserved older V3 implementation is not modified, and no existing deployment is repointed. Keep the existing-supply question in `V3-OPEN-04`, where it belongs. |
| 6 | `V3-ACC-08` | The section says "`rebalanceLiquidReserve` no longer moves inventory" and that the vault keeps no sleeve. It does not say whether the selector survives, and it is silent on the four sleeve views the same facet exposes. A reader who keeps them produces a different facet cut and a different public ABI than a reader who removes them, and `canOpenBoundPoolOps` is explicitly retained as the pool-lock gate, so the facet's remaining contents matter. | State the disposition of the selector and of each sleeve view: removed, or retained with a stated no-op or stated replacement meaning. Name them so the ABI surface is not left to the plan. |
| 7 | `V3-ACC-03`, the floor mint | The section copies FS-OWN-11's balance rule but drops that lock's constraint on how the `address(0)` floor is written. The current V3 vault mints its floor to `0x...dEaD`, so no V3 code path has yet written a balance at `address(0)`, and the named source states that the shared ERC-20 paths revert `ERC20InvalidReceiver` for `address(0)` and that a direct repo write is required. An implementer who reads only the draft can pick a path that reverts on the first deposit. | Either carry the lock's storage constraint into the requirement, or say in one sentence that the write path is a plan decision, so the requirement is not read as authorizing the reverting path. |

# What was not adopted from others

I read no peer response and no peer feedback, so I report only what the draft itself records, plus what the draft did not carry from my own initial response.

Recorded in the draft and not adopted:

- The usage fee is adopted as a V4 copy, and my reservation that this vault charges no usage fee today is carried in the Disagreement section rather than adopted. The draft states that the fee is not left unset. That is a defensible reading of the copy mandate; I am not reopening it here.
- The draft records that a stronger per-vintage protection for an old holder's booked claim was named as a new design and is not adopted, with the dilution consequence stated instead in `V3-ACC-19`. I read `V3-ACC-19` as correct: the copied formula produces that dilution, and the draft says so rather than papering over it.
- The draft records that a fail-closed exact-out text is proposed in `V3-OPEN-06` with named dissent, and that a retained exact-out route with the old economics is rejected. I read that as correctly refusing to let the old exact-out economics survive silently.
- The draft records that the `donate` and `compound` surface is left as a scope choice rather than a lock, and that permissionless `rebalanceLiquidReserve` is not the answer to the dust question. I agree with the second half; see Concern 6 for the first half.
- The draft records that import, migration, selector names, the stateful quote, and Standardized Yield are left open because no member supplied a source that decides them.

From my own initial response, carried into the draft: the share basis, the floor, the 49% shape and its boundary branches, the sleeve removal, the booked remainder, the refund rule, the exit apportionment and all-or-nothing opposing swap, the exit preview as the valuation of that operation, the pool-locked revert with no local fallback, the manipulation non-claim, and the protection of the provider's `previewExchangeIn` call and its two-word return.

From my own initial response, not carried into the draft: the scope sentence named in Concern 5. My other two unadopted items are not missing requirements; they are the concern above and the fee reservation the draft records.

# Limits

- This is advisory feedback on `coordinator/draft.md` at draft ID `draft-v3-fullspread-v4-accounting-prd-20261116-r1`. It does not authorize implementation, does not replace the draft, and does not replace the V4 PRD or the V3 remediation PRD.
- I computed no fingerprint and did not compare one. I opened the exact file named in the assignment and reviewed it.
- This is a continued session. My source citations come from my initial response, which preserved them; I did not reopen the V4 PRD, the V3 sources, the constant-product library, or the rate-provider facet in this pass. Concerns 1, 2, 3, 4 and 7 rest on lock text and planner branches recorded in that response.
- I read no peer response and no peer feedback, and I do not treat any unread member as supporting this draft. The dispositions attributed to other members in the "What was not adopted from others" section are the draft's own characterization, not my observation of those members' files.
- Static reading only. I ran no test, measured no gas, and verified no facet cut, storage slot, ERC-165 surface, or consumer migration list.
- My concern 1 asserts that the V4 planner's failed-genesis branch reverts rather than refunds on a first deposit. That is my reading of the planner as recorded in my initial response; I did not re-open it to re-confirm, and the coordinator should check it against the planner before adopting the correction.
- The seven concerns are the complete set I can support from what I read. Their absence elsewhere in the draft is not approval, and this feedback does not convert any open decision in `V3-OPEN-01` through `V3-OPEN-06` into a decision.
