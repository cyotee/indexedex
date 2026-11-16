# Bounded recovery of surrendered legacy NFTs

This is the next independent implementation increment under task8, not closure
of all-source recovery. Base is independently verified NFT commit
`6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`. Root created and warm-seeded
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`,
branch `work/dtf-migration-phase-07-recovery`. The seed exited0 with
NFT_RECOVERY_WARM_SEED_READY; exact branch/HEAD, clean status, artifact/cache
directories and dependency links passed NFT_RECOVERY_WORKTREE_VERIFIED.
Never use uncommitted phase05 state.

Read the original main-checkout implementation plan, especially MIG-P12-P14,
section5.6, task8 and recovery acceptance rows. Read the full phase01 independent
report and exact weighted/earlier source archives and execution evidence.
Read the accepted phase05 source contracts and runtime verification. Prior
phase01/phase04/phase05 evidence is read-only.

## Required boundary

The current proxy already takes whole custody of both legacy NFT models.
Implement bounded, current-Crane-owner-only recovery operations for those
specific custodied identities and admitted conversion routes. No generic
executor, arbitrary calldata, beneficiary, route adapter or rescue destination.
Actual proceeds stay at Migration or enter that same new DETF reserve.
Permissions remain available after activation and follow actual ownership.
Harvesting never creates personal principal, buys an ordinary bond, changes a
delivered migration bond, or reopens consumed entitlement.

Every claim/conversion/donation uses operation-local deltas and explicit
per-token undonated inventory:

`after = before + newly received claims + conversion outputs - conversion inputs - donations`.

Do not treat the parent total balance or unsolicited assets as newly recovered
proceeds. Do not count a receipt and its conversion output as two recoveries.
Protect new DETF backing, user packets, donation budgets, self-leg inventory,
legacy custody and existing funded reward rights. Clear temporary approvals.
One selected transaction is atomic; successful earlier transactions remain
recorded when a later stage fails. Repeated calls may recover genuinely new
accrual but may not recount previous outputs.

Selection must scale with selected positions, not all inventory. Measure
small/large-population gas and derive honest local operational bounds; do not
claim the permissive test gas cap is the target-chain limit.

## Distinct legacy sources and limits

- Weighted fixed-principal NFT:
  `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E`.
  Existing pinned evidence demonstrates claim to legacy sDETF, unstake to
  weighted liquid DETF, and conversion to DTF. Admit exact selectors, native
  return layouts, actual recipients and protected caller graph before coding.
  Legacy operators can redirect claims; Migration must not grant them custody
  rights, and all recovery recipients are fixed.
- Earlier LP-lock NFT:
  `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391`.
  Original accounting shares differ from boosted weight and physical LP.
  Existing evidence demonstrates reward claims and sale to earlier receipt;
  mature close and receipt redemption reach a disabled SE. Establish the
  exact currently executable stages and caller semantics. Do not fabricate a
  successful conversion/donation for a disabled route or silently change
  registry policy. Masked wrong-owner mature-close authorization remains a
  security/source limitation, not proven safe.

Historical chain4663/L2block108944663/hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`
remains the source pin. Any additional pin is separately identified. Existing
archive access is configured; no secrets or resolved private URL in evidence.

Both source models must be retained. A source gate may admit a claim/holding
stage without pretending its later disabled conversion works. The implementation
must report precisely which real stages exist and which remain blocked; no
always-successful stub or fake fallback. If no safe stage is admitted for a
source, preserve the limitation and finish the other independently admitted
work without claiming the complete two-source recovery task.

## Workflow, files and execution

Evidence prefix R is
`docs/incidents/2026-09-16-dtf-recovery/migration/nft-recovery/`
in the phase07 worktree.

Two disjoint source lanes write R/weighted/contract.md and R/earlier/contract.md
plus supporting evidence in their respective directories. They reuse verified
primitives and investigate only genuinely unresolved recovery facts. They do
not compile or edit production. Optional owned local ports18555 and18556.
Independent source gate writes only R/source-verification/report.md and
supporting evidence, admitting exact stage contracts or naming blockers.

One HEAVY implementation/proof lane consumes that gate and owns:
- New Migration recovery interface/repo/target/facet and necessary exact
  existing Migration root interface/repo/facet/package/factory/TestBase wiring
  under `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
- Typed legacy recovery interfaces/helpers under that directory's `legacy/`.
- Relevant existing/new migration spec and fork tests at their current paths.
- R/implementation/ evidence only.

Ordinary/common/Crane/dependencies/configuration/snapshot math and historical
files are read-only. Report a concrete indispensable extra path to root.
No broad rewrite of accepted NFT surrender, core accounting or reward policy.
Use a distinct facet if needed for EIP170 rather than disabling code-size
checks or altering compiler settings.

Required actual proof: genuine registry Migration proxy with genuinely
surrendered pinned NFTs; correct current owner before/after transfer and
activation; partial/mature/repeated claim stages; token identity/unit and
operation-local accounting; fixed destinations; protected backing; no new
compensation; failing middle item rolls back selected batch; smaller retry;
earlier stages survive later conversion/donation failure; malicious callback
and approval cleanup; large unrelated custody population; exact registry
disabled behavior; real successful admitted conversions and donations.
No SUT subclass, storage injection, etch, forged parent or source-owner
impersonation. External hostile dependencies may test callbacks only under
repo policy; pinned sources remain real.

Artifact-first Solar build followed by changed-input migration specs, pinned
fork cases and affected ordinary/common regressions; preserve full command,
source/artifact/receipt identity, counts/exits, failures and gas evidence.
One compiler at a time. R/implementation/report.md is the producer handoff.

Independent verifier writes only R/verification/report.md and bounded proof.
It executes the real admitted recovery paths, validates current bindings,
preserves unresolved disabled/restricted stages and avoids redundant large
suite reruns. All nodes clean owned runtime and keep warm artifacts.

No commits by implementation nodes, extra delegation, public deployment/
funding/transactions, policy relaxation or E2 construction. Root lands only
independently accepted increments. All other categories, general recovery,
operator/resume and final release gates remain open.
