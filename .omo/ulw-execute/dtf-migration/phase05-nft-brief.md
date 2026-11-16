# Next phase: source-bound NFT surrender

The phase04 scoped commit has independent confirmation:
`5021e8d4a62bcbddc555f580ef98f8666d993aab`.
Root is creating `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05`,
branch `work/dtf-migration-phase-05`, from that exact commit. Launch only
after the warm-seed completion receipt; never use uncommitted phase04 state.

## Inputs and scope

Read the complete Migration implementation plan and applicable repository
rules. Preserve MIG-P01 through MIG-P15 and the accepted phase03 r3 accounting.
The phase04 core supplies genuine registry deployment, frozen quoting,
independent configuration/issuance, cliff bonds and irreversible activation.
It does not yet supply legacy configuration, surrender or recovery.

Read the phase01 independent report:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/phase01-verification.md`,
then its weighted and earlier-CP reports, source bindings, deployed-source
extracts and actual receipt evidence. The independent report qualifies the
older source matrix: failed operator redirection does not invalidate NFT
transfer primitives, and absent Migration integration is work to implement,
not a circular prerequisite.

Both NFT generations remain required and distinct:

- Weighted collection `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E`:
  original fixed principal minus actually claimed principal; exclude rewards
  and include still-locked principal. Read deployed return layouts exactly.
- Earlier collection `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391`:
  original LP accounting shares, not effective reward weight or fixed DETF
  principal. A live lock retains those shares after reward claims; sale burns
  the identity. Establish the admitted remaining-unit fraction from actual
  source behavior rather than inventing a claimedPrincipal field.

Historical pin: Robinhood chain 4663, block 108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
Use the existing configured archive access without exposing secrets.
Historical RPC failure is not permission to silently substitute a fresh pin.

## Required implementation behavior

Implement real source-specific NFT configuration and persistent surrender,
not a generic executor or caller-supplied credit interface. Configuration
quotes each original ETH/DTF entitlement on the frozen book. Keep source
identity, configuration replacement, immutable consumption and held custody
separate. Collection plus token ID is the identity, never numeric ID alone.
Reject unknown contributions rather than converting missing evidence to zero.

Surrender authenticates the current holder, reads actual remaining eligible
units, rejects nonexistent/burned/empty/reward-only/zero-credit identities,
takes whole NFT custody and consumes the identity exactly once, then funds a
fresh genuine 90-day bond with the proportional prequoted amount. Approved
legacy operators cannot choose or steal the new beneficiary. Do not grant
legacy operators approval over held recovery NFTs.

Configuration alone mints nothing. Withdrawn principal is never re-quoted or
silently awarded through a descendant. Replacement after consumption cannot
reopen credit, resize a delivered bond, or redirect existing custody.
Failed custody, funding or receiver callback reverts the complete operation.
Surrender works after activation without mutable approval of a transfer.
Extend the actual administration-selector removal and interfaces to cover
all newly introduced loading selectors, with no restoration route.

Use the actual Migration parent/children and registry TestBase. Do not mock,
subclass, etch, inject storage into or impersonate the SUT. A controlled
external NFT may exercise hostile callbacks but cannot replace pinned legacy
behavior. Legacy holder impersonation on a local fork is only transaction
fixture setup, never proof of authority over an infrastructure account.

Earlier mature harvest reaches a disabled SE; that failure stays explicit.
Surrender does not pretend to harvest or enable it. Fungible attribution,
TokenStaking composition, LP harvest, full recovery and operator workflows
remain open. No category is dropped and no new trusted attribution policy
is introduced by implementing these NFT paths.

## Planned workflow boundary

Root will define one phase DAG with disjoint weighted and earlier source
contract checks, a combined source-contract verification gate, one coherent
HEAVY implementation/test lane, then independent AdversarialVerify.
The source checks reuse existing evidence and execute only unresolved source
observations. They must leave exact consumed ABI, units, caller and identity
requirements, not another broad report. The implementation consumes their
verified contract and owns its production changes plus proof.

All phase nodes use the phase05 worktree above. Evidence prefix N is
`docs/incidents/2026-09-16-dtf-recovery/migration/nft/` in that worktree.
Weighted source lane writes only N/weighted/; earlier source lane only
N/earlier/; source verifier only N/source-verification/. The implementation
lane writes only N/implementation/ plus the production/test paths below.
Final verifier writes only N/verification/. Existing source evidence in
phase01 and accepted phase04 evidence are read-only.

Source lanes produce `contract.md` in their own directory; the source gate
produces N/source-verification/report.md. These are exact consumed ABI/unit/
custody contracts with cited source bytes and existing/new pinned observations,
not broad new inventories. Use separate owned local ports 18549 (weighted)
and 18550 (earlier) only if necessary. Do not run competing Forge compilers:
source checks reuse existing recorded proof and read-only RPC/probe tools,
and leave new compiled integrated proof to the implementation lane.

Implementation owns new source adapters under
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/legacy/`
and the existing Migration root repo/interfaces/targets/facets/package/factory
and TestBase as needed to install actual NFT behavior. It may add narrowly
required Migration-only issuance plumbing to the existing Migration bond
files; use the existing exact-funded production path, not a second issuer.
Ordinary/common contracts, Crane, dependencies, configuration and snapshot
math are read-only. An indispensable out-of-scope path requires a concrete
root decision, not a silent expansion.

Tests belong under the existing
`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`
and new
`test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/`.
Update machine-consumed selector/declaration expectations that genuinely
change, preserving all existing behavioral assertions. No source-prose pins.
Implementer output is N/implementation/report.md; final independent output
is N/verification/report.md. No implementation until the source gate admits
the exact adapter contract; incomplete-source findings must be stated and
resolved rather than converted into a successful route.

Required proof includes both real pinned legacy collections surrendered into
a genuine registry Migration proxy, transferred holders, current partial
principal, burned/nonexistent/reward-only rejection, whole identity
consumption, no descendant/independent double credit, fresh clocks for later
surrenders, callback rollback, configuration replacement and all new loading
selectors removed after activation. Preserve ordinary products.

Artifact-first Solar focused tests, pinned fork tests and affected ordinary
regressions require actual exit codes and source-bound evidence. Existing
passing suites are not repeated unless inputs change. No concurrent
compilers, public transactions, funding, deployment or unauthorized commits.
Every node captures owned runtime cleanup; final verification preserves all
remaining full-plan gates.
