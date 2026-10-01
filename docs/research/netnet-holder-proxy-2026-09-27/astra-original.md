# Astra — holder-proxy proposal ORIGINAL

2026-09-27. Current PRD read: **v0.24**. Prior session retained; no new-round peer artifacts read. Assigned routing `openai/gpt-6-astra`, not provider attestation. Research-only; only this report written.

## Verdict: accept isolation; specify the remaining transitions

The user selects **one intended native bond per transferable wrapping NFT**, with one small reusable-package holder proxy per tokenId. Its permanent controlling owner is the **NFT contract**, not the original buyer or current wallet. NFT transfers change who can authorize operations through that contract, not proxy ownership. Deployment overhead and persistent per-target attack exposure are accepted; do not reopen pooling versus isolation.

Also selected: holder-owned native purchase, NFT-orchestrated actual NET contribution→mint/stake under the same NFT; **do not reject an otherwise valid claim merely because unsolicited notes make receipt exceed the intended-note expectation**. These selections do not alone assign every excess receipt's economic rights or final retirement behavior.

The newly stated **next processed epoch after full native collection** is a real release-policy change. v0.24 currently releases at native full maturity and expressly forbids inventing an extra lock (`606,611–613,793`). Record the new selection as superseding those passages—not as merely clarifying the old rule.

## 1. Critical source check: tokenId-only package salt collides

`lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201–218` obtains `pkg.calcSalt(args)`, hashes **package address + returned salt**, and returns an occupied instance **before processArgs**. `:326–328` predicts through the same package/salt namespace. The caller's NFT address is not automatically included. `utils/DiamondFactoryPackageAdaptor.sol:11–23` delegates salt/argument processing; caller-context assumptions need explicit tracing.

Therefore, with the same factory/package, NFT-A token 7 and NFT-B token 7 collide if `calcSalt` returns only `bytes32(7)`.

**Recommended derivation, not changed caller input:** keep holder `PkgArgs{owner, providedSalt}` and the caller-provided `providedSalt=bytes32(tokenId)`. Have the Package derive `keccak256(abi.encode(owner, providedSalt))`; the factory then applies its existing package namespace. Use identical canonical decoding for prediction and deployment. Do not replace the supplied tokenId salt with purchaser identity, `msg.sender` or `tx.origin`.

Returned-address handling must check owner, provided salt and configured dependencies before NFT registration even when the factory reused an existing instance. A permissionless attacker predeploying the **correct immutable configuration** need not gain control; rejecting all pre-existing instances can itself permit address-squatting denial. A maliciously configured/reinitialized instance must never be adopted. Fix immutable package-bound dependencies or bind every mutable identity-affecting argument; do not introduce extra unconstrained initializer payloads behind the same salt.

This callback factory deploys its proxies by CREATE2 (`225`); CREATE3 facet/package deployment does not make the holder proxy CREATE3.

## 2. Authority and intended-note registration

**Engineering requirements preserving the selection:**

- Store NFT owner once in holder Repo initialization; no human owner, ownership-transfer/renounce escape, runtime upgrade/cut or arbitrary-call asset-spend surface. “Owner” here means constrained NFT-contract authority, not EOA administration.
- Authenticate canonical initialization/callback context and prevent repeat initialization. Do not assume external factory calls originate directly from the NFT: resolve registry/factory forwarding in the plan. A declared `owner` is configuration, not proof the submitter may act for it.
- Only the NFT contract may command a holder. The NFT verifies current `ownerOf(tokenId)`/approved operator and both mapping directions, never an original-purchaser entitlement. Authenticate holder callbacks by the registered tokenId↔holder binding and an active operation context. Reject sibling-holder substitution and spoofed callbacks.
- Mint/register/initialize/purchase atomically, preventing ERC721 receiver callbacks or other reentry from using an incomplete position. Exactly **one authorized native purchase**; a reused holder cannot purchase a second intended bond.

`lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:130–138` returns the current array index before appending. Preloaded notes mean **native noteId need not be zero or equal tokenId**. Persist the actual returned noteId and verify its note fields against the authorized purchase. Pre-existing gifts never become the registered intended bond merely by occupying index zero. Use explicit lifecycle/existence flags rather than zero-index sentinels.

NFT-local maps and individual intended-note reads bound registered bookkeeping without iterating all NFTs. They do not shorten native redemption (`BondDepository.sol:143–165`).

## 3. Claim composition, excess and failure

For each authorized claim, snapshot the registered note and held balances, calculate its expected vested increment, call native redemption **from the holder**, measure actual receipt and reconcile the registered note's post-claim state. `redeem(to)` selects aggregate-payment destination, not a note subset. A payout to NFT/coordinator must remain exclusively attributed to this tokenId until contribution.

Separate:

1. registered-note collection;
2. attributable excess collected from other native notes;
3. pre-existing/directly donated NET and other unrelated balances.

Accepting `actual > expected` does not authorize counting old cash twice, crediting another NFT, or sweeping to feeTo. Use measured movement rather than nominal return alone. **Proposed** excess treatment is actual funded contribution credited to this NFT, but its rights/lock need confirmation below; no new policy is silently selected.

Collection, contribution, mint/stake and completion-marker updates remain one rollback domain (PRD `807`). If Keep-YT or funding fails, native collection and all credits revert. Do not count a reverted final claim as completion. Previews should expose registered expected proceeds separately from estimated excess/aggregate availability; own-note reads cannot promise a bounded or exact aggregate preview. User limits and existing fee/bond calculations still apply.

Dedicated principal reinvestment burns only the eligible old DETF with its matching staking-claim debit, then creates funded replacement through normal bond calculations. No contraction input incentive at any nested step (`619–624,644–646`); do not simultaneously retain old backing and replacement claims.

## 4. Release change and narrow remaining decisions

**Recommended precise interpretation for confirmation:** “fully claimed” refers to the **registered intended note**, verified by its own `claimed == payout` after successful atomic contribution—not `pendingFor(holder)==0`. Otherwise a stranger's late gift can perpetually postpone release. Record the processed NET epoch at successful completion, after any underlying epoch advances within that operation; permit principal claim/reinvestment only when a later processed epoch number is observed. This is a counter transition, not elapsed eight-hour time or an epoch already processed before completion.

Ask only:

1. **Completion definition/order:** confirm registered-note completion and a strictly subsequent processed epoch, with no reset from gifts or NFT transfer. The extra wait itself is selected, not pending approval again.
2. **Excess rights:** does all attributable native-redemption excess fund this same NFT's staking principal? What release condition applies to excess collected after intended completion/release? Direct donations remain a separate classification. Accepting greater receipt is already selected.
3. **Replacement/retirement:** collection must retain the same NFT. Does later principal rebonding also retain tokenId, or issue a normal new bond? Do not assume it purchases another native note. Define whether the old NFT remains transferable/claim-capable for late gifts, or an explicit terminal entitlement policy; never burn control accidentally or wait for all possible future gifts to cease.

Early funded reward claims remain unchanged absent a contrary instruction. Principal's new dependency on *successful full collection* can leave already-funded principal locked if upstream redemption becomes unexecutable; disclose this consequence without reopening isolation.

## Amendment and acceptance approach

Add the holder beneath the NFT in §4; specify holder-specific PkgInit/PkgArgs separately from the DETF's existing configuration. Update §§10/12, R19/R44/R45/R50 and affected acceptance rows to supersede native-maturity-only release. Revise C08/NN-02 to **isolation selected; per-target liveness remains**, not “bounded redemption proven.”

Required cases: different NFT owners/same tokenId; idempotent deployment/no second purchase; spoofed owner and callbacks; preloaded native IDs; transfer-before-claim; excess receipts; failed final contribution; completion near/in the epoch-processing transaction; eligible reinvestment; and retirement/late gifts. Deterministic pre-spam and stranded notes persist; no gas/attack threshold is established.

Current CLAUDE and canonical Crane architecture/deployment read directly; package structs belong on interfaces. Local source analysis required no external lookup. No shell/RPC/tests/browser/code/configuration/delegation or PRD edit. High confidence in factory collision and native-call facts; deployment equivalence and implementation feasibility are not certified. Moderator should record accepted selections now and resolve only the narrow semantics above before executable handoff.
