# Independent NFT source-contract gate

Date: 2026-11-11.

**Verdict: admitted-for-nft-implementation.**

Both [weighted](../weighted/contract.md) and
[earlier](../earlier/contract.md) source contracts are sufficient for the
bounded source-specific configuration and whole-NFT surrender implementation
specified by the phase05 brief. No unresolved source fact blocks their exact
owner/position reads or approved custody calls. The earlier model is original
LP accounting shares, not weighted fixed DETF principal.

This admits those source contracts for implementation; it does not certify
an implemented receiver, atomic new-bond issuance, successful harvest,
operational allocations, or full Migration completion. The implementation
must satisfy sections 4-6 below. All non-NFT full-plan gates remain open.
Neither producer contract was edited.

## 1. Scope, baseline and evidence

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05`.
Independently observed branch: `work/dtf-migration-phase-05`.
Both HEAD and the requested commit object resolved to:
`5021e8d4a62bcbddc555f580ef98f8666d993aab`.

Root supplied the warm-seed exit-0 and initial-clean receipts. This verifier
did not repeat seeding. Its own initial status already contained the two
producer lanes under `migration/nft/`, with no tracked diff. Plain Git status
exited 128 on the existing `lib/crane` symlink; read-only status with
`--ignore-submodules=all` exited 0. The symlink was preserved.

Read completely: the phase05 brief, both producer contracts, and the original
`migration-detf-implementation-plan-r1`, including MIG-P01-P15, E1-E5,
all ten work packages, 53 acceptance dispositions and final F1-F4. The plan
is at:
`/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`.
Its absent worktree copy was not substituted with another plan.
Repository routers, relevant product law, canonical Crane architecture/testing
and IndexedEx testing guidance were consulted. The accepted phase04
correction-verification report and actual current Migration composition were
read; phase03 r3 accounting and phase01/phase04 evidence remain unchanged.

Evidence root **P1** below means:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/`.

| Reference | Independently consumed evidence |
| --- | --- |
| W | `P1/weighted/probe.sources.json`, `probe.results.json`, `probe.historical-receipts.json`, deployed-source extracts, source comparison/summary and report |
| WR | `P1/verification/weighted-replay.results.json`, source archive and exit receipt |
| E | `P1/earlier-cp/probe-alchemy-retry.source.json`, `probe-alchemy-retry.json` and report |
| ER | `P1/verification/cp-replay.json` and exit receipt |
| P | `P1/phase01-verification.md`, especially sections 2, 3 and 6 |
| A | [Independent archive audit](archive-audit.json): fingerprints, recomputed checks, preserved failures and execution limits |

Source citations such as **W/B `DETFFundedBondTarget.sol:163-187`**
mean original lines in the archived, unescaped source content, not current
repository Solidity or JSON line numbers. **E/N** means flattened
`DETFNFTVaultFacet.sol`; **E/D** means flattened
`UniswapV4SingleStandardExchangeDETFFacet.sol`.

### Exact consumed producer versions

| File | SHA-256 |
| --- | --- |
| `weighted/contract.md` | `02aad997374190bf8f5428029c8fb80eed102ba63a83752113250118bd313d85` |
| `earlier/contract.md` | `f090bb5f1bcb9ae74fe2c7a9dbbe1d87f5fced9a6b3d346867d83b92265025b1` |
| `weighted/archive-audit.json` | `3cedd67167cb74af689f26647f16bddc7466f5aec52ea853b1484c5e42ea27b4` |
| `earlier/source-evidence.json` | `b95b643ef079ac8f53d8ab2679fdf9693a27ed7a9a2a9605a7e8fd1436a20e9c` |

## 2. Authenticated source domain and exact ABI

Historical execution evidence is Robinhood chain **4663**, block
**108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
Both reused earlier executions have `freshFallback=false`; the separately
recorded fresh fallback is not this admission's execution pin. The historical
pin is not the new Migration funded quote snapshot.

| Identity | Address | Runtime Keccak-256 |
| --- | --- | --- |
| Weighted NFT | `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` | `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601` |
| Earlier NFT | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` | Same proxy hash, not the same behavior |
| G: owner/approval facet | `0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279` | `0xf709b5311471ef0b02cf7ddaa8f48b9da30647ab9958a3efde1813e5ac4337b8` |
| B: weighted position/transfer facet | `0x3a07364eabA092472d40F0e6788b8891A31faD4D` | `0x325a3b9bf3e616386e03d2a14d0a1fb29820f104a5f433d0b08a88dbdd0bef52` |
| N: earlier position/transfer facet | `0x3AB85813785b43B864F9C171F7ac97d6B76c459b` | `0xe44c05ff19808e8e7096c7e470cb1d40ddaf057f4e53818f1e749621d3632027` |

Admission binds collection, historical header, actual loupe route and facet
runtime, not merely the shared proxy hash. Archived on-chain bytes and
published recompiled execution bodies agree after terminal CBOR removal.
Sourcify reports B as `exact_match`, G and N as `match`; no independent
recompilation or full metadata match for G/N is claimed. Current contract
implementations were not substituted for any legacy bytecode.

All following calls target the fixed **collection proxy**, never its facet:

| Call | Selector | Weighted / earlier route | Exact output |
| --- | --- | --- | --- |
| `ownerOf(uint256)` | `0x6352211e` | G / G | `address`; explicitly reject zero |
| `positionOf(uint256)` | `0x46f96023` | B / not selected | Weighted static tuple of five `uint256`: principal, claimedPrincipal, stakingGons, startTimestamp, vestingDuration |
| `getPosition(uint256)` | `0xeb02c301` | not selected / N | Earlier static tuple of five `uint256`: originalShares, effectiveShares, bonusMultiplier, unlockTime, rewardDebt |
| `safeTransferFrom(address,address,uint256)` | `0x42842e0e` | B / N | No return; zero native value |
| `approve(address,uint256)` | `0x095ea7b3` | G / G | No return; holder preparation |
| `getApproved(uint256)` | `0x081812fc` | G / G | `address` |
| `setApprovalForAll(address,bool)` | `0xa22cb465` | G / G | No return; holder preparation |
| `isApprovedForAll(address,address)` | `0xe985e9c5` | G / G | `bool` |

Both position tuples are 160 static bytes, with no leading dynamic offset.
Earlier also binds `positionOf` but returns the earlier tuple, making
selector-only or length-only model detection unsafe. Use explicit distinct
legacy interfaces. The admitted transfer is the three-argument overload;
do not rely on a four-argument route merely because current ERC721 code has it.

Weighted corroborating `previewClaim(uint256)` (`0xae648e90`) returns one
128-byte static tuple: vestedPrincipal, principalRemaining, principalDue,
rewardsDue. It is not required for surrender. Weighted recovery reads may
retain the separately typed `claimPrincipal` (`0xf400c743`, one uint256),
`claimRewards` (`0x6c7b69cb`, one uint256) and `claimBond` (`0x084c59ae`,
two uint256 outputs). They are not surrender steps. Earlier
`originalSharesOf` (`0x0f3767df`) corroborates tuple word zero.

## 3. Findings on units, fractions and eligibility

### S1. Weighted principal contract is supported

W/B `DETFFundedStakingMath.sol:28-43,96-117` and
`DETFFundedBondTarget.sol:127-200` establish:

```text
P0 = authenticated original principal = position.principal
Pc = live position.claimedPrincipal
Pr = P0 - Pc
C0 = frozenQuote(originalETH) + frozenQuote(originalDTF)
credit = floor(C0 * Pr / P0), using full-precision mulDiv
```

Require configured original contribution evidence, purchased ID, `P0 > 0`,
`Pc <= P0`, `Pr > 0`, positive credit and caller minimum/deadline. P0/Pc/Pr
are native nine-decimal old DETF-equivalent principal. Credit is native
nine-decimal new DETF; original ETH/DTF inputs are native 18-decimal integers.
The fraction requires no decimal rescaling. Do not use gons, reward value,
currently due principal, a live quote or a re-quote of reduced contributions.

The raw archived return bytes independently decode ID 32 to
`P0=54436459`, `Pc=8071216`, `Pr=46365243`; due-now is only `8249343`.
ID 4 retains all `281387179` principal despite only `86292556` due at the
pin. Still-locked principal remains eligible. All 43 original purchase
receipts were independently decoded and matched to their recorded principals.
IDs 44/45 being post-incident purchases is not allocation approval.

IDs 0-2 are reserved. Burned 25/42 and absent 46 have zero owner and reverting
position reads. WR's actual principal-only claim leaves ID 3 extant with
`principal == claimedPrincipal == 3772281649` and positive reward gons:
that reward-only NFT must earn zero and be rejected, not treated as eligible
because it still exists.

### S2. Earlier binary share fraction is supported, not invented

E/N `:15566-15601,16135-16143,16206-16254,16413-16454` separates original
accounting shares from boosted reward weight and reward debt.
The admitted rule is:

```text
S0 = authenticated original user-purchase NewLock.shares
Sr = live getPosition(id).originalShares
require purchased nonreserved identity, current owner, S0 > 0
require Sr > 0 and Sr == S0
credit = floor(C0 * Sr / S0) = C0
```

This equality is a source-specific consistency requirement, not a universal
LP rule. Reject a positive mismatch rather than clamping it or inventing
partial claimed principal. A zero/burned/absent identity receives no award.
The first field is neither effectiveShares nor current physical LP assets.
ID 12 has `47848240999749918187208884` accounting shares versus
`47848240999749918187208985` observed assets.

All original-share write sites in the archived NFT source were checked.
Creation initializes user shares; reward claims do not debit them; retirement
and sale remove the entire position and burn it. Partial add/remove methods
are restricted to the protocol ID; donations credit that ID
(E/N `:16331-16404,16463-16546,16922-16929`). This supports the binary
user-lock inference; it does not invent an undocumented partial user exit.

Both historical runs' 16 `NewLock` receipts independently match their
canonical receipt hashes and live original-share baselines. Actual ID 4
reward receipt pays `309005608995105` old DETF while preserving
`2281854312954086546` original shares. Sale clears all five fields and owner.
Locked ID 3 custody succeeds without requiring maturity. Reserved ID 1 has
zero original shares despite positive reward weight; reserved ID 0's positive
protocol inventory is not a user entitlement.

For original inputs, ID 3's direct `2e18` WETH and its routed intermediate
DTF are not two contributions. Unknown contributions cannot become zero.
Neither NFT position API supplies authenticated original ETH/DTF amounts;
these remain verified Stage 1 configuration inputs.

## 4. Findings on real caller authority and atomic custody

### S3. Real proxy pull is feasible without infrastructure impersonation

The holder calls the genuine Migration proxy. Migration reads live owner
and requires `msg.sender == owner`, captures that address as the only new
bond beneficiary, then calls the legacy collection as an approved spender.
Approval must belong to the actual Migration proxy, not a facet, helper or
administrator. Legacy `msg.sender` is consequently Migration. W/B
`ERC721Repo.sol:229-254` and E/N `:13541-13566` expressly accept this caller.
They impose no infrastructure-owner or EOA-only requirement on transfer.

Earlier's recipient exclusion is the **old** DETF parent
(E/N `:16982-17001`), not any contract of the DETF family. Weighted excludes
zero, its old DETF and its own collection (W/B target `:239-242`).
A distinct newly deployed Migration proxy is permitted.
Do not call earlier `redeemPosition`/`retireMaturePosition` as if NFT
ownership grants the legacy parent's `onlyOwner` authority. No such call
is necessary to surrender.

Existing production composition provides the genuine funding route:
`UniswapV4DetfMigrationAllocationTarget.sol:108-116` settles existing
participation, mints exact principal, approves the wired bond, and sets the
narrow expected synchronizer around `createMigrationPosition`.
The Migration bond target `:26-34` admits only its real parent and creates
a fresh 90-day marked position. The existing TestBase `:223-251,265-293`
deploys packages/instances through the manager registry.
The implementation must reuse this exact-funded path from the parent,
with only authorized Migration-local plumbing; a helper impersonating the
parent or a second issuer would not prove composition.

### S4. Receiver acceptance precedes ownership and authorization

Both deployed ERC721 implementations call the receiver before
`_transferFrom` changes ownership or checks the spender
(W/B repo `:153-170,229-254`; E/N `:13465-13482,13541-13566`).
The producer contracts correctly preserve this unusual order.

Use one operation-wide guard and an expected collection/ID/from/operator
context. During the selected safe pull, callback sender is the collection,
operator is Migration, from is the captured holder, and data is empty.
Accept exactly once and return `0x150b7a02`. Do not issue in the callback,
require Migration ownership there, or add a nested guard that rejects the
expected callback merely because the outer surrender is locked.
Reject unsolicited/replayed/wrong-context callbacks.

After transfer returns, require callback acceptance, actual Migration
ownership and unchanged eligible position data. Weighted requires the
five-field position to remain unchanged; earlier requires its original
share basis unchanged. Clear expected context; record whole consumption and
custody; fund one new bond, all under the same atomic operation.
Any failure rolls back custody, credit, consumption, funding and new NFT.
No safe callback or transfer event by itself proves successful custody.

Weighted transfer first synchronizes its old parent
(W/B target `:45-48,210-227`); the Migration guard must cover that external
work too. The transfer body does not claim the position's rewards despite
its comment. Earlier transfer has no corresponding synchronization or
nonReentrant modifier: do not infer a legacy lock from the weighted model.

### S5. Operator authority is not beneficiary authority

WR records approved-operator claim redirection succeeding, transaction
`0xcadefebefd78638594f2c8a2434c08d6baf16e832708bc877a5387a960fafbce`,
paying `4308806205` raw sDETF to a stranger. This agrees with W/B target
`:163-187`; it is not evidence of an unusable transfer primitive.
An approved legacy operator who is not current owner must fail Migration
surrender. A legitimate source transfer changes the eligible current owner;
the original purchaser is not permanently entitled.

Transfer deletes per-token approval; old holder-wide approvals remain keyed
to the old owner. Migration must never grant operators rights over its held
NFTs. Do not append `approve(address(0),id)` cleanup: the deployed approval
implementation rejects zero (W/B repo `:281-291`). Recovery, when separately
implemented, fixes proceeds to Migration custody, not an arbitrary caller.

## 5. Whole identity, overlap and implementation proof limits

### S6. Whole identity is sufficient for NFT replay, not global ancestry

Permanent consumption is keyed by collection plus ID, separately from
replaceable configuration and held custody. Evidence/configuration domains
also bind chain, Migration instance and snapshot. Replacement must never
reopen credit, resize a delivered bond, change its clock or redirect custody.
The same numeric ID in the other collection is a different identity.

For a weighted 1000-credit origin with 40% principal remaining, surrender
delivers 400 and consumes the whole NFT identity. The other 600 is not a
remaining NFT claim or an automatically eligible liquid descendant.
Earlier sale burns the user identity and creates a receipt representation;
that does not authorize another award. Harvest proceeds never resize the
compensation bond.

**Do not claim descendant or independent overlap is impossible merely because
the NFT is consumed.** Weighted claimed principal can already exist outside
the live NFT. An independent allocation can misdescribe the same economic
origin under a different opaque identifier. Current
`interfaces/IUniswapV4DetfMigration.sol:42-49` expressly says its IDs are not
authenticated transfer proofs; allocation target `:54-87,120-125` guards
identifier reuse, not undisclosed economic aliases.

The bounded implementation must connect known NFT original identities with
the existing independent configuration/issuance collision checks in both
directions, including replacement after consumption or independent issuance.
It must reject overlapping known origins and offer no descendant award path.
An arbitrary different ID/evidence hash is not proof of disjoint exposure.
Verified operational dataset disjointness and any general cross-representation
history mechanism remain open E2 obligations. No new signature authority,
mutable postactivation root, original-payer restriction or source-policy
exception is admitted here. Neither producer contract establishes a global
nonduplication mechanism or claims one is cryptographically impossible.

### Required next-lane observations

These are implementation acceptance obligations, not missing legacy facts:

1. Real pinned collections safely pulled by a genuine registry Migration proxy,
   with approved actual-proxy caller and successful pre-transfer callback.
   EOA custody is not receiver proof.
2. Current/transferred holders, operator rejection, live partial weighted
   principal, full earlier shares after reward claims, locked positions,
   burned/nonexistent/reserved/reward-only/zero-credit rejection and a
   claim-before-surrender race using the live fraction.
3. Collection/ID separation, permanent once-only consumption, known
   independent-origin collision rejection in both orders, no descendant
   issuance, and replacement preserving bonds/custody/consumption.
4. Configuration alone mints nothing; original quotes are frozen once;
   each success funds exactly one fresh 90-day bond for the current holder.
   Later surrenders receive later clocks, including after activation.
5. Wrong/missing/repeated callbacks, reentry, transfer/funding/receiver
   failure and complete rollback through the actual parent and children.
   Preserve phase03 r3 accounting rather than widening child authority.
6. Every newly added loading selector/interface disappears through actual
   activation cuts with no restoration route. Persistent surrender still
   works without postactivation discretionary transfer approval.
7. Artifact-first Solar focused tests, pinned legacy integration and affected
   ordinary regressions with actual exits; production TestBase and no mock,
   subclass, etch, storage injection or impersonated SUT.

## 6. Preserved failed executions and full-plan obligations

The existing weighted replay exited **0**, with **34 PASS, 1 FAIL,
2 UNPROVEN**; its 28 mined occurrences comprise 22 successes and six reverts.
The existing earlier replay exited **2**, with **18 PASS, 2 FAIL,
4 UNPROVEN**; its 24 mined occurrences comprise ten successes and 14 reverts.
These include snapshot-isolated scenarios, sometimes repeating a transaction
hash. Neither suite becomes a green complete-Migration result.

| Actual saved observation | Exact locator and qualification |
| --- | --- |
| Weighted approved custody | WR `approved_actual_whole_nft_custody`; transfer `0x0f344ce9310c30f5a50be14b9f69a7ba2110deb33254a612ff6a3f92b1fc043e`, status 1, five fields unchanged; approved EOA custodian, not a receiver contract |
| Weighted new-owner claim | WR `custodied_nft_actual_claim`; `0x40049b8b180aaf28d770b96a0b607bce5cd181b3efa5489b00cfa60db9c27cb8`, status 1, `4308806205` sDETF received; later position read rejects |
| Earlier custody/reward/sale | ER `nftRewardClaim` and `nftSale`; `0x3e3b2b3d5ad372acb94c7f5b2af467e4aba3a310be6b0fdd06316d909953e398`, `0x5dfa0bfd67a8a62b6db4867245de7a3e2332195d97a75219bc0b6dd6e9ca1d45`, `0x3d54621af7e5dff968aed64f3639d0222170d962ead7c80339f39a33ede46042`, all status 1; positive custody used holder `transferFrom`, not a safe receiver |
| Earlier nonreceiver rollback | ER transaction `0xc9aef14f6f8caba0b2bb65a13a447c4d72f08e8a4b5c913772b4353a977ee978`, status 0; does not prove successful safe pull |
| Earlier mature close | ER `nftMatureClose`; `0x61fb08ec01b576756fa25ae3ab9631613f140471c843576a2eac3774a7ff37a1`, status 0, `VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)` |

Earlier receipt redemption and the alternate direct receipt route fail with
the same `0x1ba84b43` disabled-vault error. Wrong-owner mature close also
reaches it, masking authorization. E/D `:25644-25691` has no holder check
in that public body before parent-authorized retirement; do not claim
exclusive harvest authority or safe wrong-owner withdrawal has been proved.
This concern remains open, not a demonstrated theft or a reason to pretend
the bounded surrender already harvests.

The missing-source old-DETF facet
`0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE` retains HTTP 404 and runtime
hash `0xa289425ebf221bd44551376c3459083a4d53eb30f485b48e783bf8291f7a05d6`.
Its routes `0x6a4d3f12`, `0xf5ee7c5b`, `0x36abf3dc`, `0x7cc34bb4` are not
the admitted NFT calls. Earlier owner/position reads use NFT storage;
safe transfer uses its authenticated internal ERC721 code and the recipient.
Thus this missing source does not block the admitted primitive call graph,
but remains missing evidence for broader source closure.

| Full-plan area | Unresolved obligation preserved |
| --- | --- |
| E1 / task 1 | Complete category-specific custody, authority, rollback and recovery closure; this gate admits only the two exact NFT read/custody contracts |
| E2 | Authenticated ordinary-transfer, claim, wrapper, merge and partial-surrender ancestry after activation; economic disjointness and operational allocation reconciliation |
| TokenStaking/claim-vault | Ordinary-caller atomic composition remains unproved; reassignment is not a recipient callback or permission to pull another claimant's weight |
| Fungible LP / SE recovery | New-custodian exits remain restricted or disabled; impersonating legacy infrastructure cannot supply its authority |
| E3 / E4 | Accepted bounded snapshot/genesis evidence retained; actual recovery route/domain/deployment/funding inputs remain operational gates |
| E5 / tasks 4-7 | Accepted core evidence retained; new NFT integration, source loaders, complete payout/activation matrix and all newly installed selectors require proof |
| Task 8 / MIG-P14 | Owner-only bounded staged harvest, fixed destination, operation-local deltas, whole-batch rollback and recovery/donation conservation remain open |
| Tasks 9-10 / final F1-F4 | Deterministic datasets, resumable operators, interrupted rehearsal, full-product invariants, gas/batch bounds, release validation and independent final verification remain open |

All required categories remain explicitly required: weighted liquid DETF,
earlier liquid DETF, weighted NFT, earlier NFT, weighted sDETF, earlier
receipt, legacy SY, TokenStaking/claim-vault rights, underlying SE shares,
and fungible LP tokens. No category is omitted, merged or declared absent.
No original full-plan checkbox is closed by this source gate.

## 7. Validation, failures and cleanup

A records **439 passing independent offline checks**, with **zero unresolved
failures**. Two earlier local verifier assertions incorrectly compared hex
RPC chain ID `0x1237` to numeric `4663`; both were corrected by integer
normalization and pass. Their original failed records remain in A with
explicit superseding checks, not hidden as source failures.

Checks recomputed archived input SHA-256 values, 14 weighted and nine earlier
selector/ABI/binding contracts, facet runtime hashes and execution bodies,
verbatim excerpts, all 47 weighted owner/position/preview rows, 43 weighted
purchase receipts, 16 earlier purchase baselines in each of two runs, actual
custody/reward/sale receipts and retained disabled failures. Producer PASS
counts were not used as substitutes for source or receipt inspection.

No new RPC request, fork, transaction, compiler or test suite ran. No
successful probe was duplicated. Real-Migration success/rollback and new
receiver executions are deliberately unrun here and remain the next lane's
required proof. This is a source-contract decision, not a passing production
test result.

Only this report and `archive-audit.json` were authored, both in
`nft/source-verification/`. JSON language-server diagnostics are unavailable
because configured Biome is not installed; no dependency/configuration
change was made. JSON is parser-validated. The read-only Git symlink error,
missing local plan path and resolved analysis-helper/type errors are captured
in A. Existing failed receipts and historical evidence are preserved.

Final read-back found 441 audit records: 439 passes and the two explicitly
superseded verifier comparisons, with no unresolved failure. All 21
fingerprinted input files remain unchanged; all three report links resolve.
The owned directory contains exactly this report and the audit. Final branch
and HEAD remain the required values; there is no tracked diff. Tracked
`git diff --check` completed successfully. Separate `git diff --no-index
--check /dev/null <new-file>` calls emitted no whitespace diagnostics but
each returned 1 for the new-file difference; the wrapper consequently
exited 1. That is retained as a diff-command outcome, not reported as a
passing exit-0 check or a contract failure.

This verifier created no node, listener, temporary runtime root or owned
process. Neither port 18549 nor 18550 was acquired. No cleanup is pending.
Saved source runs' snapshot restoration, node exit, closed endpoints and
removed roots were inspected, not claimed as freshly executed cleanup.
No commit, delegation, public action or main/integration operation occurred.

**Final gate: admitted-for-nft-implementation for both distinct adapters,
subject to the exact consumed contract and implementation obligations above.
Harvest, non-NFT attribution and full-plan completion remain open.**
