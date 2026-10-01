# New council handoff: finish L3 using the extracted SY source

## Human authorization and purpose

The human explicitly requested this handoff and will restart the council. This is a **new council**, not a silent continuation or model substitution. Complete the actual-source conversion/funding analysis and amend the implementation plan. Do not execute product implementation, builds, tests, deployments or transactions.

The old extraction blocker is resolved. Do not request another extraction, rerun failed source-download campaigns, or require a new structured reader to read the existing Markdown.

## Paste this instruction into the restarted council

> Read `docs/research/netnet-sy-conversion-2026-09-27/NEW_COUNCIL_RESTART_HANDOFF.md`. Start a new, explicitly identified four-member council under the freshly loaded, consistent model configuration. Use the completed `VERIFIED_SY_SOURCE_EXTRACTS.md` to finish the L3 source-derived conversion/funding analysis and amend implementation-plan section 6.5 and the tracker. Preserve existing product decisions. Perform four independent originals and four same-session combined cross-reviews; save originals before sharing them. Do not execute implementation. Report precisely what is resolved and what remains actual deployment/state evidence.

## 1. Identity and restart checkpoint

The previous conversation's governing instructions and preserved Grok session used `xai/grok-4.6`. The guard most recently read on disk, `.opencode/support/research-council.ts:29–38`, pins:

| Role | On-disk model at handoff |
| --- | --- |
| Moderator and Astra researcher | `openai/gpt-6-astra` |
| Grok researcher | `xai/grok-4.7` |
| MiniMax researcher | `minimax/MiniMax-M3` |
| Kimi researcher | `kimi-code-plan-global/k3` |

This is why the old moderator stopped before a new review. It is not an extraction failure or a newly discovered economic question.

After the process restart, check fresh governing instructions, agent definitions, tool schema and guard configuration for consistency. Use only the models authorized by the newly loaded environment. Do not weaken the guard or relabel historical sessions. Kimi's documented variant is `high`; confirm current configuration. Metadata checks do not attest provider truth.

Create four **new** independent researcher sessions for this new council, retain the returned IDs, and resume those IDs for cross-review. The human's request for a new council supplies the explicit restart authorization; it does not grant permission to alter configuration from a research-only role.

Historical IDs below are provenance only—**do not resume them for this round**:

| Prior researcher | Prior session ID |
| --- | --- |
| Astra | `ses_f1c499b6bffe6RiNjZZUSMsP8S` |
| Grok, recorded as 4.6 | `ses_f1c4384d7ffeZX74uV9yhIXbVq` |
| MiniMax | `ses_f1c3f57edffedYs43k2PBvA5xU` |
| Kimi | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` |

These IDs and prior reports come from the preserved discussion; this handoff did not revalidate their histories.

## 2. Read these current documents directly

Workspace: `/Users/cyotee/Development/projects-defi/daosys/lib/indexedex`.

1. `CLAUDE.md`, current `docs/agent/RESEARCH_COUNCIL.md`, and applicable canonical skills routed by `docs/agent/SKILL_CATALOG.md`. Read skill files directly; do not invoke a skill tool.
2. `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` (last recorded v0.33).
3. `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` (last recorded v0.7), especially §§6.4–6.5 and L3/G1 status.
4. `docs/strategies/ohm-style/netnet-pendle/PRD_OPEN_QUESTIONS.md`.
5. **Primary readable evidence:** `docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md`.

Read the current files rather than assuming version labels or historical narratives are still current. The plan still contained obsolete "not yet read" language in §6.5 at the last inspection; fix it after the new source review. Do not propagate that statement as a continuing extraction limitation.

The existing `COUNCIL_CONSOLIDATION.md` in this research directory is a **historical pre-extraction** report. Keep it and old attributed originals intact. For independent new passes, supply identical primary evidence and product requirements, not old peer conclusions. After all new originals are collected, historical reports may be consulted with their age and provenance made explicit.

## 3. Extraction status and evidence limits

The extraction was reported complete on 2026-09-28 and its Markdown has now been directly read by the moderator.

- It contains 25 complete decoded sources, target first, with ordinary line breaks.
- Its manifest reports all 25 source strings round-tripped against the JSON and the target UTF-8 keccak256 matched `0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b`.
- The present moderator did not rerun the parser/hash operation; cite the extraction manifest for those checks.
- Chain 4663; candidate SY proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`.
- Service-resolved implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`.
- Target `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY`.
- Sourcify matchId 47105638; creation/runtime `exact_match`; verified `2026-09-04T08:05:04Z`.
- Recorded external compiler: `0.8.30+commit.73712a01`, optimizer 1,000,000, Cancun, viaIR=true. These are external artifact settings, not authorization to alter local compiler policy.
- Public source URL: `https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources`.

Verification-service records are not a fresh block-pinned check of current proxy implementation, market binding, balances, caps, exemptions or allowances.

The bundle includes the exact SY base, token helper, supply-cap helper and NetNet interfaces. It does not include a separate decimal-wrapper implementation body. Determine which missing external bodies actually affect selected execution paths; do not make an unused metadata dependency a blanket blocker. Never substitute a similar implementation without labeling its evidentiary limits.

## 4. Bounded question for the new council

**For this actual `PendleStakedNetSY` compilation, what are the exact supported deposit/redemption branches, integer conversion and inverse formulas, epoch/index ordering, and receipt/minimum-output semantics needed to fund the selected NET/sNET routes? How must those integrate with the existing Weighted quote and eligible held/net-claimable SY budget without confusing price coordinates with physical funding?**

All researchers should inspect the same source evidence independently. Require:

1. A branch table for accepted input/output tokens, SY mint/burn, native amounts and decimal boundaries.
2. Current-index versus projected-index behavior, including exact floor/cap arithmetic and the zero-circulating branch.
3. A trace of actual stake/unstake/rebase ordering, including which calls can advance an overdue epoch. Compare local NetNet sources as references but do not pretend they are independently verified deployed implementations.
4. Fixed-state exact inverses, mathematical preconditions and forward verification; distinguish nominal output from actual receiver delivery and account for source arithmetic's overflow/revert domain.
5. Base/helper custody and minOut semantics: caller-held shares versus SY-internal shares, actual pull/transfer behavior and whether fees or receipt deltas are measured.
6. An explicit call sequence for held-first funding, claim-only-shortfall, recomputation where state changes, strict positive eligible-SY remainder and rollback on short delivery. Separate nominal conversion from fee/tax/claim effects at their actual hops.
7. A finite list of remaining source or deployment-state dependencies, each with its impact on a specific branch. Do not invent new economic questions or claim configuration evidence has been collected without collecting it.
8. Exact implementation-plan edits and test cases as a plan only—not executed code or tests.

Use Context7 first for any new external library/API documentation claims. No external search is needed merely to inspect the already extracted Solidity.

## 5. Settled constraints: preserve, do not reopen

The PRD remains authoritative. This summary only prevents repeating already answered questions:

- Weighted quote uses NET/sNET pricing coordinates; raw SY funding is a separately derived debit. Existing Weighted exact-in/out helpers and native wrapper rounding are already mapped in §6.4. Do not build a new reserve model or apply the swap fee twice.
- Ordinary NET/sNET output shares the same eligible held plus net-claimable SY budget, uses held SY first and claims only if short. No ordinary PLP/YT liquidation fallback. Leave a positive native SY-unit remainder after actual applicable fees/redemption; no invented percentage floor.
- HLP ownership/exit accounting uses actual Weighted/BasePoolMath mechanics and the selected liquidity mode. Do not use a universal proportional h/H shortcut for unbalanced exits or include public LP/other protected balances as owned backing.
- L1 is resolved: existing funded-gons custom staking with authenticated internal principal context and transfer-funded reward notification. Do not confuse that custom staking with this external SY's conversion.
- L2 is resolved: public pretransfer credit is `max(actualRawBalance - bookedRawBalance, 0)`, origin irrelevant, next eligible caller may consume; caller bears transfer-and-consume safety. Do not add payer-witness provenance requirements.
- NN-03 is closed. Do not reopen hypothetical arbitrary-token failure or quarantine policy.
- L4 retirement/late-rights analysis and G0/G1 evidence remain distinct. Keep this round focused on L3; neither source extraction nor a source-level inverse alone closes the whole implementation plan.

## 6. Moderator-only preliminary observations (not a reviewed conclusion)

**Do not include this section in the independent first-pass prompts.** It records the old moderator's direct inspection for the new moderator's continuity. Researchers must derive their own findings from the source. These observations are untrusted model analysis until checked and are not full-council consensus.

Line references below are to `VERIFIED_SY_SOURCE_EXTRACTS.md`, not original Solidity line numbering:

- Lines 44–45: `INDEX_BASE = 1e9`, `DECIMALS_OFFSET = 1e9`; their product is `D = 1e18`.
- Lines 80–88: NET deposit calls `stake(address(this), amountDeposited)` before reading the index; mint is `floor(amountDeposited * D / index)`. sNET deposit skips that staking call.
- Lines 90–102: NET redemption calculates `floor(shares * _syncedIndex() / D)` and calls `unstake(receiver, amount)`; sNET redemption uses the current index and `_transferOut`.
- Lines 108–125: exchange rate is `_syncedIndex() * 1e9`. The synced projection checks epoch end and queued profit, uses circulating supply, caps projected supply and reconstructs the index from gon constants. It is not simply an unconditional current-index getter or a catch-up loop.
- Lines 131–145: NET previews use the projected index; sNET previews use the current index.
- Lines 147–160: supported inputs and outputs are only NET and sNET, not scaled wrappers.
- Lines 231–246: base deposit pulls the nominal input, calls the override, checks returned shares against minSharesOut, then mints. Exact token-helper behavior still needs inspection.
- Lines 252–270: base redemption burns from caller or SY internal balance, calls the override, and compares its returned amount to minTokenOut. That comparison alone is not a receiver balance-delta check.

For a **fixed positive selected index** I and positive **nominal** native output A, the algebraic minimum share debit is `ceil(A * D / I)` for the forward map `floor(S * I / D)`. This observation is conditional on execution state, actual token/staking behavior and arithmetic domain; it is not a completed net-receipt guarantee. Inspect source and derive forward/minimality checks rather than blindly adopting it.

The previous turn made no plan edit and no new council delegation. The operator-authorized new council must perform the review and final consolidation.

## 7. Round protocol and output ownership

Suggested fresh output directory:

`docs/research/netnet-sy-conversion-post-extraction/`

Assign distinct paths:

- `astra-original.md`, `astra-cross-review.md`
- `grok-original.md`, `grok-cross-review.md`
- `minimax-original.md`, `minimax-cross-review.md`
- `kimi-original.md`, `kimi-cross-review.md`
- Moderator: `COUNCIL_CONSOLIDATION.md`

Do not overwrite existing files if this round's paths have already been used; select and record a distinct directory. Do not read peer artifacts during independent passes, including through glob/grep. Give all researchers the same question, primary evidence and requirements. Share no peer answers before collecting all four originals. For each cross-review, resume that researcher's **new original session** and provide the other three complete attributed originals together, marked untrusted. Do not supply a moderator paraphrase or previous cross-review instead.

Use only the permitted named council targets, `load_skills: []` and `run_in_background: false` on every task call. Inspect the actual task schema for the continuation field (`session_id` or `task_id`); use exactly the supported field with the returned `ses_` ID, never both or a background ID. Do not use explore/librarian/Oracle agents, categories, skill injection or model overrides. Report unavailable participants and stop on genuine identity/history/guard failure rather than replacing them.

## 8. Required consolidation and human checkpoint

After a complete eight-call round:

1. Preserve four originals, four cross-reviews, model attribution and new session IDs.
2. Write a source-backed consolidation with initial positions, corrections, agreement, dissent, confidence and evidence gaps.
3. Update plan §6.5 with the actual branch table, exact inverse preconditions, sequencing and required verification cases. Replace stale extraction/unread-body blockers without implying all external state has been verified.
4. Update the tracker with a new dated progress entry; preserve historical entries rather than rewriting the history of earlier rounds. Change PRD economics only if explicitly authorized; no new economic change is requested here.
5. State precisely whether source-level conversion mapping, complete L3 composition, and G1 deployment evidence are individually resolved or pending. Identify remaining concrete dependencies rather than a generic request for more research.
6. Return saved paths and a separate implementation handoff, then stop for the human. Writing this analysis or a test plan never authorizes executing it.
