# Identity

- Member: **kimi**
- Role: **council-member**
- Phase: **sole advisory pass for the planning run**
- Requested model/route: **kimi-coding/k3.1-pro:high**, global route
- Runtime identity: **not exposed**

# Draft under review

- Identity: **dtf-migration-gap-closure-plan-20261116-r1**
- File: `docs/research/dtf-migration-gap-closure-plan-20261116/coordinator/draft.md`
- Coordinator-supplied SHA-256: `0fbc28eb001b2964b63b0bea527da03786c0347841bf8b3ef37a0cc020c405fc`; not recomputed.
- The complete draft was read.

# Disposition

**support**

The draft is executable and decision-complete for F1-F4 and P1.

The selected F1 mechanism is correctly placed in the already installed explicit `sweepDust()`:

- Reclassifying only booked `donationInventory` into `residualInventory` before the existing standalone budget sweep makes that capital spendable without releasing total balances.
- The existing `_sweepDustBody()` supplies the outer standalone budget transition, fixed reserve destination, bounded joins, and residual retention.
- Using one new outer `nonReentrant` guard while directly invoking the existing body operations avoids nesting the inherited `_entrySweepDust()` guard.
- Excluding bootstrap, `_sweepDustBody`, `sweepDustAtomic`, and the bond path is load-bearing: the ordinary owner purchase already invokes `_trySweepDust()`, so an earlier handoff would undermine the planned Stage 2 witness.
- The design adds no selector, withdrawal route, recovery stage, owner power, or activation mutation.

P1 is also a valid evidence design rather than a disguised pricing rewrite:

- Real Migration DETF is acquired through funded compensation, cliff claims, and receipt exit rather than direct minting or impersonation.
- The separate four-leg registered hook satisfies the SE requirement without using the ordinary parent’s reserve or relaxing `BarePairForbidden`.
- Real output DETF, actual raw inputs, an auxiliary V3 SE leg, production rate providers, capture mapping, and an independent live-hook gross oracle compose coherently.
- RawRate input and output models, non-unit rates, exact domains, and frozen/manual replacement behavior are covered without mocking the SUT.

F2 uses a single fresh controller-funded pull and preserves the production prerequisite. F3 separates instance-wide reward presentation from linear/cliff principal policy. F4 preserves historical bodies while adding current navigation. The artifact helper’s `script` action and the supplied C2-C7 command forms are consistent with the current parser.

# Concerns

| Concern |
|---|
| none |

# What was not adopted from others

The draft’s synthesis choices are justified by the current mechanisms:

- Owner-only donation-release APIs would add unnecessary permanent ABI and authority.
- A new permissionless sweep selector is unnecessary because the retained explicit sweep already supplies the required route.
- Bootstrap-time release is correctly rejected because the ordinary owner purchase implicitly sweeps.
- Buffered-hook or pure-arithmetic comparisons cannot substitute for the new observed Raw/RawRate hook oracle.
- A separate mixed hook avoids both ordinary DETF bare-pair rejection and Permit2/SUT-mutation complications.
- Persistent Migration presentation context is necessary after activation; rendering only the closed state would be insufficient.
- The QA helper pulls fresh payment once rather than combining pretransfer and pull accounting.
- Existing configured artifact/cache paths and historical gas evidence are preserved; no alternate roots or unnecessary gas campaign are introduced.

I did not reread peer planning responses; these are assessments of the draft’s disclosed synthesis, not independent peer-response verification.

# Limits

Only the complete draft and narrowly cited implementation/parser files were read where needed. No broad audit, peer-original review, commands, tests, builds, Git, RPC, delegation, or edits occurred.

`apply_patch` is unavailable, so this complete feedback is returned inline. No alternate writer was used, and the draft and originals remain preserved. This advisory neither replaces my planning proposal nor authorizes implementation, and it requests no further round.
