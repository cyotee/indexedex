# Per-NFT NetNet Bond Holder Proxy — completed council consultation

Date: 2026-09-27. **Four originals and four completed same-session cross-reviews. Documentation-only consolidation.**

## 1. Disposition

Record the user's per-NFT holder design as selected, not as a new generic escrow questionnaire. The architecture separates intended native purchases and their funded entitlements by NFT tokenId, contains legitimate aggregation, and permits bounded registered-note lookup. It does not bound the native depository's history scan for any one holder.

PRD v0.25 now incorporates the selected design, standard salt convention and changed principal-release policy. NN-02 remains IN PROGRESS because excess rights, exact epoch checkpoint, replacement/retirement and engineering evidence remain incomplete. NN-01 live-evidence gates are not closed by this round.

## 2. Selected by the human

- One holder proxy per external-native-bond-backed NFT, deployed through a small reusable Package.
- Permanent proxy owner is the NFT contract. Rights follow tokenId transfer, not the original purchaser's wallet.
- Holder PkgArgs includes owner and providedSalt. NFT supplies `providedSalt = bytes32(tokenId)` unchanged. Use the exact standard Package hashing convention for the complete arguments.
- One intended native purchase per wrapper position. Record its actual returned native noteId, which can differ from tokenId/zero because arbitrary addresses can receive notes before proxy deployment.
- NFT controls atomic native collection → normal NET/Keep-YT contribution → DETF mint → staking principal under the same NFT for installments.
- Receipt above intended-note expectation must be supported. This does not yet select all excess entitlements or late-excess locks.
- Principal release/reinvestment now follows full collection of the intended native bond **and the next processed NET epoch**, explicitly superseding native-maturity-only release.
- Dedicated principal reinvestment retains its incentive-free burn/rebond calculation and no old-plus-new double claim. New funded bond creation is not another native purchase at the old holder.
- Extra deployment cost and residual per-target unsolicited-note exposure are acknowledged. No measured gas bound or assertion of economic attack infeasibility is implied.

## 3. Source-checked engineering constraints

### Standard hash, not a new salt design

`contracts/fee/collector/FeeCollectorDFPkg.sol:153–155` returns `abi.encode(pkgArgs)._hash()` for the bytes argument. The moderator directly read it at the corrected singular `fee` path. Include owner in encoded PkgArgs and preserve identical prediction/deployment encoding. Do not replace the convention with a hash of only supplied salt or a different decoded-field encoding.

`lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201–218` adds the package namespace and returns an existing account before processing new arguments. It does not independently add the NFT caller as owner namespace. Owner checks cannot repair a collision; owner-containing standard arguments prevent the cross-NFT alias.

Validate expected holder package/behavior, initialization, permanent owner, dependencies, mapping and intended-purchase state on creation and reuse. Neither blanket rejection of predeployment nor automatic adoption is sufficient. The reference factory creates callback proxies through CREATE2 (:225); package/facet CREATE3 conventions must not be confused with instance construction.

### Control and dependency propagation

The NFT authenticates tokenId owner/operator actions. The holder authenticates the NFT contract; callbacks are bound to the registered mapping/current operation. Protect receiver callbacks, reinitialization, sibling substitution, repeated purchase and all nested external calls. Owner-only entry does not remove reentrancy concerns. No human upgrade, ownership-transfer escape or arbitrary retirement-owner transfer is selected.

The native depository is still a DETF-instance PkgArgs dependency under PRD §4.1. Specify its authenticated propagation to a reusable holder without silently fixing a universal depository in holder-Package PkgInit. The user selected owner/providedSalt arguments, not a new unauthenticated configuration channel.

### Accounting versus upstream work

`lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–140` returns the note index from the append operation. `:143–165` performs aggregate redemption/pending work. A registered-note getter avoids a global NFT/history scan for intended entitlement lookup; it does not make native collection selective.

Expected payment is the intended note's currently claimable increment. Actual collection requires an operation-specific receipt measurement; whole recipient balance includes possible old cash and donations. Reconcile intended proceeds, unsolicited-note excess and other balances without manufacturing contribution credit. Atomic failure restores native claims and all credits/completion markers.

No safe note threshold, attacker-cost model or measured gas savings/overhead is claimed. Attackers may target one valuable holder rather than every NFT. Tying principal release to successful full collection means an unexecutable native claim may also keep already-funded DETF principal locked.

## 4. Narrow remaining owner checkpoint

These are PRD §12.4 H01–H03, not repeat votes on isolation or the existence of the new epoch wait.

| ID | Remaining detail | Suggested resolution for discussion |
| --- | --- | --- |
| H01 | Native-redemption excess rights and late-excess lock; separation from direct/pre-existing donations | Credit attributable native excess through the same NFT's contribution/mint/stake path, if the owner selects that treatment; separately specify what happens after intended completion/release. No feeTo sweep, excluded treasury or no-mint donation treatment is silently selected. |
| H02 | Precise epoch ordering when full collection itself processes an epoch | Mark completion only after successful atomic contribution and `claimed == payout` for the registered note; record the resulting processed epoch and require a strictly later processed epoch. Gifts/transfers do not reset it. This ordering remains proposed, not a claim that the user supplied every detail. |
| H03 | New-bond representation on principal reinvestment and old NFT/holder retirement with residual or later gifts | Preserve settled same-NFT incremental harvest; explicitly define replacement tokenId/lifecycle and any old residual entitlement. No second intended native purchase or transfer of holder control to a wallet is implied. |

No completion predicate may silently require strangers' native notes to finish. Early funded staking-reward claims remain unaffected by the principal gate. C05/NN-04 still needs source-compatible duration/bonus treatment.

## 5. Attributed corrections and dissent

| Researcher | Initial position | Cross-review / moderator disposition |
| --- | --- | --- |
| Astra | Supported isolation; initially proposed direct owner/salt hash; detailed authority/receipt/boundary concerns | Withdrew special hash after exact standard source check; supports conditional safe reuse and precise outstanding H01–H03 |
| Grok | Supported isolation; special salt proposal and strict existing-instance rejection | Corrected salt to whole PkgArgs; requires verified returned owner/config; accepts next-epoch policy as selected |
| MiniMax M3 | Claimed salt-only cross-NFT collision intentional, no reentrancy guard needed, excess treasury and retirement-owner transfer | Corrected standard hashing/release policy but retained contradictory recommendations in final response. Reject assertions that owner guard alone suffices, PkgInit depository is selected, or proxy ownership transfers on retirement. No invented excess treasury or callback safety claim adopted. |
| Kimi K3 | Identified whole-args convention; initially overstated predeployment as necessarily benign | Supports exact config-checked reuse, unchanged native scan, and release-gate risk disclosure. Full cross-review accepts new release policy and leaves excess/lifecycle semantics open. |

Agreement exists on the user's core custody direction and unchanged residual scan problem. Not every peer recommendation is accepted, and consensus is not proof of security or economic soundness. Source citations and arguments govern consolidation; model claims remain evidence, not instructions.

## 6. Round history and preserved artifacts

Four originals were collected before peer sharing. Astra's first cross-review stopped on `RC_UNAVAILABLE: attribution or metadata unavailable` at the incorrect `contracts/fees/collector/FeeCollectorDFPkg.sol` path. A human-authorized same-path retry failed. The human then supplied `contracts/fee/collector/FeeCollectorDFPkg.sol`; ordinary read succeeded and Astra completed in its original session. Cause of the original guard's attribution response remains unknown; success at the corrected path is not a diagnosis or a guard bypass.

The user subsequently authorized the remaining three cross-reviews. Each received the other three complete ORIGINALS, not Astra's cross-review or another peer correction. Human salt/path clarifications were supplied equally as updated user context. All sessions were preserved; no participant was substituted or silently restarted. **Ten task invocations total: four originals, two interrupted Astra continuation attempts, four successful cross-reviews.** The eight substantive original/review deliverables now exist.

| Researcher | Session | Original | Completed cross-review |
| --- | --- | --- | --- |
| Astra | `ses_f1c499b6bffe6RiNjZZUSMsP8S` | [Original](astra-original.md) | [Cross-review](astra-cross-review.md) |
| Grok | `ses_f1c4384d7ffeZX74uV9yhIXbVq` | [Original](grok-original.md) | [Cross-review](grok-cross-review.md) |
| MiniMax M3 | `ses_f1c3f57edffedYs43k2PBvA5xU` | [Original](minimax-original.md) | [Cross-review](minimax-cross-review.md) |
| Kimi K3 | `ses_f1c3a8701ffeB4x8S7oRn2JnXK` | [Original](kimi-original.md) | [Cross-review](kimi-cross-review.md) |

The [partial round status](PARTIAL_ROUND_STATUS.md) remains unchanged as history; this report supersedes its incomplete-round status and its initial salt recommendation. Original reports remain unchanged, including their corrected errors. Routing reported openai/gpt-6-astra, xai/grok-4.6, minimax/MiniMax-M3 and kimi-code-plan-global/k3; metadata is not provider attestation.

## 7. Evidence limits and handoff

Local source paths/line numbers describe inspected snapshots, not pinned deployed equivalents. Relevant source-verification-service evidence from the prior UI round is preserved at [CLAIM_PATH_FINDINGS.md](../netnet-nn02-ui-2026-09-27/CLAIM_PATH_FINDINGS.md), including Sourcify records accessed 2026-09-27; it does not independently establish latest runtime or a byte-identical local adaptation. Repository configured compiler baseline remains 0.8.35; no build, test, runtime measurement or current-chain call was run in this consolidation.

Saved normative updates: PRD v0.25 §§10/12/R19/R21/R56/C08/A08/A09/A30 and tracker NN-02, with H01–H03 explicitly open. No Solidity, configuration/instructions, shell/tests/RPC/browser execution, deployment or transactions were performed. Implementation remains separate. Stop for the human checkpoint; no automatic advance to NN-03.
