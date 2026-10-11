# Astra — REQ-C04 bounded cross-review

Continuing Astra's successful independent first pass. The original remains unchanged and attributed. Read the complete supplied Grok, MiniMax M3 and Kimi K3 originals together, then re-read the current residual-join chain, OD-08/REQ-01 and REQ-C04. No peer cross-report was read. No code, test or PRD was edited; no shell, build or test was run. Only this assigned report was written.

## Decision

**Retain Astra's original remediation. A zero proportional-hook preview must revert the parent immediately; it must not select the single-asset fallback. Deleting the terminal reserve update is not required by this repair and is not justified by the claim that the line becomes dead.**

The supported fix is to make the existing atomic hook-join boundary return positive validated LP or revert, remove its callers' soft-zero interpretation, and correct the comments and tests that instruct a later implementer to retain or retry on hook zero. Keep the existing successful-SE-zero retention helper unchanged.

- **Severity:** Medium, as in the original.
- **Impact class:** parent-operation atomicity and residual-accounting conformance; no demonstrated principal loss.
- **Origin:** REQ-C04 / Stage-1 REQ-01 / OD-08.
- **Confidence:** High in the disputed source facts and requirement interpretation. Runtime outcomes and historical edit attribution remain unverified.

## 1. Proportional zero versus single-asset fallback

### Requirement and source recheck

`docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:184` states:

> “A hook preview of `0`, or a hook join revert, rolls the parent transaction back.”

REQ-01 repeats that rule at `:195,200`. `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/REMEDIATION_PRD.md:90–97` restates it without a final-mode or all-modes qualifier.

Current production file: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` (abbreviated **Common** below).

- `_tryJoinResidual` selects the unbalanced route first at `:531`.
- That route calls the atomic join at `:586`.
- The selected proportional preview is obtained at `:614`, then converted to a successful zero return at `:615`.
- The loop breaks at `:590`, allowing a default false return.
- The caller can then attempt the single-asset path at `:535–539`.

**Conclusion:** the zero must become a hard failure at the point where that selected preview is observed. A positive quote from the later single-asset mode does not undo the requirement to roll back after the first selected mode's zero. The rule is not “try every mode, then revert only if the final one is zero.”

### Peer dispositions

- **Agree with Grok** (`grok-original.md:29,37–41,50–52`): the fallback-success expectation is contrary to the requirement; the zero must revert rather than reach booking.
- **Agree with MiniMax** (`minimax-original.md:13,29–31,40–41`) on converting both hook-zero returns into failure and removing soft-zero breaks. This agreement does not extend to the terminal-write deletion discussed below.
- **Agree with Kimi** (`kimi-original.md:41–44,65–67`): absent an explicit amendment, the first selected hook mode's zero already requires rollback. The alternative policy Kimi mentions would be a change to the requirement, not a current ambiguity.

All three originals substantially support immediate rollback on the first selected hook zero. This is an attribution of their written positions, not a consensus-based proof; the controlling sentence and source establish the conclusion.

**Fix direction:** do not convert proportional zero into a retry signal, relocate that behavior into an earlier probe, or catch the resulting failure to try the single-asset mode. Preserve legitimate positive-join progress handling. There is no need to delete every fallback path simply because fallback after hook zero is prohibited.

## 2. Terminal reserve update: object to mandatory deletion

### MiniMax's reachability argument is incorrect

MiniMax `minimax-original.md:33–34,50` proposes deleting `Common:545`, describing the update as dead once hook-zero returns revert. In particular, it says balances dropping to zero inside the loops would already have been synchronized at `:532` or `:538`.

The re-read does not support that claim:

- Lines `:532` and `:538` are in `_tryJoinResidual`, not inside either loop. They execute only when the corresponding helper returns **true**.
- The explicit true returns at `:558–559` and `:583–584` represent SE-zero deferral. Successful positive-LP joins do not themselves return true.
- After a successful positive join consumes the current token balance, the unbalanced loop assigns its zero ending balance to the remaining amount at `:589,594`. The next loop condition at `:579` terminates iteration. The function falls through with its default false return at `:597–598`.
- Back in `_tryJoinResidual`, `:532` is therefore skipped. The remaining balance read at `:535` is zero, so the capped branch is skipped too. **The terminal write at `:545` remains reachable and records that zero custody balance.** No hook-zero preview is needed for this normal successful-completion path.
- Bounded loop completion at `:554` or `:579` is another reason the code can return false without observing hook zero. Removing the soft-zero branches does not remove the iteration bounds or convert normal completion into an SE-zero deferral.

This is a source-level reachability argument about ordinary settlement, not a claim that a particular executed fixture took that path.

### What follows for the repair

**Object** to MiniMax's mandatory deletion and its assertion that no accounting changes follow. Deleting the write without replacing its normal synchronization responsibility can leave a pre-existing reserve book stale after successful movement. A later outer synchronization on some parent paths is not proof that this local responsibility is redundant on every caller.

**Agree with Grok** `:37–39`: the hook-zero path must revert before reaching the terminal book; the remaining book must not be documented as a response to hook zero.

**Agree with Kimi** `:42–43` on preserving synchronization after valid positive execution, with one precision: the terminal write is not only for bounded partial progress. As traced above, it can also record **complete consumption**. Its comment should describe actual post-settlement custody synchronization, not label every arrival there an “unmintable remainder.”

OD-08's prohibition is **no surviving holder-reserve update on the hook-zero failure path**. It does not forbid ordinary custody synchronization after successful positive joins. Its exclusive SE-zero rule governs book-and-wait as a deferral decision; it is not a rule that every reserve write anywhere requires an SE-zero preview.

**Fix direction:** retain the terminal synchronization for normally completed paths in this narrow repair. Make hook zero unable to return to it. If an implementer later moves or eliminates that write, they must preserve and demonstrate its legitimate caller-wide synchronization function; deleting it merely to remove a visible booking line is neither required nor sufficient for REQ-C04.

## 3. Tests: distinguish the preview that authorized the outcome

### Wrong continuation and retention expectations

Retain the original finding about:

- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/UniswapV4DetfLeftoverPreview.t.sol:52–83`: explicitly nonzero SE preview, zero proportional-hook preview, then successful alternate join. This must become a parent-rollback assertion, including no alternate join and no surviving reserve update.
- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ResidualGas.t.sol:35–41,53–56,65–72`: the SE-zero-or-hook-zero retention oracle conflates the two policies. Remove hook zero as an accepted retention reason, while retaining valid SE-zero and funded positive-join controls.

### Clarification to Kimi's grouped three-suite recommendation

Kimi `kimi-original.md:44,52` groups a third suite into expectations to convert from booking to rollback. That needs the qualification already present in parts of Kimi's text and explicit in Grok `:31` and Astra's original.

Re-read `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol:46–60`:

- `:48–49` asserts the **SE preview is zero**.
- `:54–57` separately reads hook quotes from the test.
- `:58` asserts booked custody.

A test-side observation that hook quotes are also zero does not prove the production sweep attempted a hook join. The existing retain helper may have returned earlier on the valid SE-zero signal. **Do not replace that legitimate SE-zero positive with a blanket rollback expectation.** Correct the misleading “zero unbalanced LP selects single-asset retry” text at `:55` and establish that the production hook-join path is skipped on this case. Any separate nonzero-SE case in that suite must be judged on the selected production hook result.

### Fixture limitation is not permission to mock the SUT

Object to MiniMax `:41` insofar as its proposed “hook-fixture mock” would replace the production hook/DETF path under review. The existing fallback test supplies a production-fixture starting point for the proportional-zero negative. Other branch witnesses must retain the production-path testing rules; an unavailable witness is a disclosed coverage limit, not grounds to introduce a mocked SUT or weaken the rollback assertion.

## 4. Remediation still supported

The following remains one bounded repair, not another retain-helper implementation:

1. **At `Common:605,615`, replace successful zero-return behavior with a hard failure.** The atomic operation must return positive validated LP or revert. Keep the existing positive-quote/result consistency check at `:618` and operative hook failures uncaught.
2. **Remove the zero-result soft breaks at `:565,590`.** If defensive zero-result checks are retained, they must fail hard rather than break into successful fallback or bookkeeping. Existing positive-result progress and bounded iteration remain separate.
3. **Preserve terminal custody synchronization at `:545` for normal completion.** It must be unreachable after a hook-zero failure; do not remove it on a mistaken dead-code premise.
4. **Correct comments at `:543–549` and related mode descriptions.** State that SE-zero deferral, successful hook settlement and hook-zero failure are different outcomes. A “complete-route zero” must not remain a synonym for permitted retention.
5. **Change the contradictory tests to assert parent rollback and preserve valid controls.** Check pre-parent versus post-revert book, custody, LP, supply, approvals and recipient state. Include earlier parent work in the rollback witness rather than testing only an isolated preview failure.
6. **Leave `_retainSubSharePairResidual` at `:625–637` unchanged.** Preserve actual-leftover SE-zero preview and full-local-balance booking, and do not duplicate it for hook failures. Do not add catches, reinterpret the separate probe policy, or redesign bond/threshold/vesting economics.

An existing suitable residual-join error can express hook-zero failure; the requirement does not need a new owner-selected error name. Exact-error tests should pin the chosen existing failure contract rather than accept any revert.

## 5. Corrections, questions and stop

**No correction to Astra's original remediation is needed.** This cross-review makes explicit its distinction between prohibited hook-zero deferral and legitimate terminal custody synchronization, and rejects the proposed unconditional deletion on fresh source evidence. The original's Medium severity, impact limits and attribution remain.

**No owner question remains to implement the specified repair.** Allowing single-asset fallback after a selected proportional-hook zero would require an amendment to OD-08/REQ-C04. No such amendment was supplied, and asking for one is not a prerequisite to implementing the current rule.

Unresolved dissent: MiniMax's required deletion of `:545` is not supported; its zero-custody reachability reasoning is contradicted by the current helper return values. Kimi's terminal-write description needs the complete-consumption clarification, and the three-test grouping must not erase the permitted SE-zero positive.

No fund-loss claim, runtime verification or whole-loop economic certification is made. No consensus is claimed. **Stop after this one cross-review; no implementation or further review wave is authorized.**
