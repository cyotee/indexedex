# E2 mechanism feasibility: no policy relaxation

Worktree `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-06-e2`,
branch `work/dtf-migration-phase-06-e2`, verified base
`5021e8d4a62bcbddc555f580ef98f8666d993aab`.
This phase is independent of the pending NFT commit. It writes only evidence,
not production. No Forge compilation is authorized: this evidence-only
worktree has not been seeded with out/cache. Existing dependencies are linked
for read-only use. A genuinely indispensable compiled witness must be raised
to root first so the required warm setup and scope can be established.

## Required question

Can an immutable, permissionlessly advanced verifier satisfy the original
Migration E2 contract for unmodified legacy fungibles, including complete
history, current custody freshness, proportional credit, same-block preceding
transfers, bounded continuation and long offline periods?

The prior phase established that balance-only/static allowance mechanisms
fail. It did not prove every cryptographic construction impossible. Do not
repeat that counterexample as though it answers this narrower next question.
Produce an executable construction with all required trust/availability
assumptions explicit, or demonstrate the exact unresolved/incompatible
requirement pair. A name such as light client, zk proof or receipt proof is
not a construction.

Read the original plan at its absolute main path and the complete phase01
`migration/attribution-spec.md` and `migration/evidence/phase01-verification.md`
under `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/`.
Their admitted evidence is read-only. The statement that a separate
construction decision is needed is an engineering finding, not authority
to relax the user's current requirements or a ban on this authorized
feasibility investigation.

## Fixed constraints

- Preserve every source category and transfer-following current-holder rule.
- No original-payer-only rule, static wallet allowance, required transfer
  wrapper, trusted postactivation root/signature, new owner approval, expiry,
  unclaimed-supply premint or silently two-transaction surrender.
- Atomic custody, proportional consumption and funded fresh bond must remain
  one successful operation; a prior escrow transfer is not automatically an
  acceptable replacement.
- A Stage1 authenticated baseline is permitted. Subsequent state advancement
  may be permissionless, but its canonicality, completeness and freshness
  must be verified, not asserted by an operator/RPC response.
- Unknown original inputs are not zero, and wrapper/claim descendants are
  not separate economic awards.
- Source/chain facts must come from exact deployed/pinned evidence and
  authoritative primary protocol documentation where necessary. Distinguish
  observed runtime behavior from source interpretation and inference.

Historical source pin: chain4663, L2 block108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
Orbit EVM BLOCKNUMBER differs from L2 numbering; inspect the actual chain
interfaces rather than assume Ethereum-mainnet blockhash semantics.
Explicitly label any additional pin. No fresh fallback relabeled historical.

## Four-node workflow and ownership

Evidence prefix F is
`docs/incidents/2026-09-16-dtf-recovery/migration/attribution-feasibility/`
in this worktree.

1. Anchor lane writes only F/anchors/. Establish available canonical
   header/receipt/state commitments, onchain accessibility, finality/reorg
   handling, retention windows, same-block prefix visibility and trust.
   Produce contract.md with exact interfaces and current/pinned evidence.
2. Observation lane writes only F/freshness/. Establish which state and
   execution facts a Migration call can actually authenticate after arbitrary
   ordinary transfers, including same-block balance-restoring histories.
   Reuse old evidence for old claims; add only a genuinely distinguishing
   bounded witness. Produce contract.md with tested scope and limitations.
3. Construction lane reads both and writes only F/construction/. Produce
   report.md: concrete admitted construction with proof-generation/verifier/
   continuation/custody ordering and executable boundary evidence, or precise
   demonstrated conflict/missing fact. No production API or policy is selected.
4. Independent verifier reads actual inputs and construction, writes only
   F/verification/report.md and supporting proof. Challenge canonical anchors,
   omitted transitions, same-block freshness, boundedness, long-offline
   recovery, reorgs and correlated claims. Do not demand repeated unchanged
   probes. Verdict: feasible, demonstrated-conflict, or unproven; distinguish
   unavailable evidence from an impossibility claim.

The first two lanes are disjoint and may run together. Local fork ports,
only if needed: anchors18551, freshness18552. Downstream lanes own only a
separately assigned local endpoint if a new witness is indispensable.
Use existing configured RPC aliases without printing secrets. No public
transactions, source upgrades, token state mutation/etching, SUT impersonation,
dependency/config edits, commits or delegation. Real local holder transactions
may be used on an isolated fork with their scope stated.

Any broad impossibility claim must enumerate its assumptions and what the
witness cannot rule out. Any feasible claim must actually close all six
requirements in attribution-spec section6, not only inclusion or balances.
If an owner decision is necessary, return the exact constraint conflict and
the minimum decision needed; do not answer it or implement a workaround.

All nodes retain raw commands/results and clean owned processes/ports/temp
roots. Final outputs must make a decisive finite evidence claim, not endless
research or a proposal replacing proof. This phase does not close source
categories, E2, or the full plan without its required implementation evidence.
