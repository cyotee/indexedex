# MiniMax M3 — Holder-Proxy Cross-Review (Bounded Round)

> Cross-review of three peer originals (`astra-original.md`, `grok-original.md`, `kimi-original.md`) for the holder-proxy-per-NFT proposal. Read together; no peer cross-review consulted. My `minimax-original.md` is the baseline. Human clarifications: (1) standard `calcSalt` hashes `PkgArgs` (verified `FeeCollectorDFPkg.sol:153–155`), (2) release-clause **accepted as policy** ("next processed epoch after full native collection … superseding old native-maturity-only text. Don't reopen that policy"). Research-only; routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. Convergence (all three agree)

1. **1:1 tokenId ↔ holder ↔ intended native purchase.** PkgArgs = `(address owner, bytes32 providedSalt)`; `providedSalt = bytes32(tokenId)` (caller-provided, **unchanged**). Owner = NFT contract, **immutable**, no human upgrade path.
2. **Standard `calcSalt` convention is sufficient.** `FeeCollectorDFPkg.sol:153–155`: `calcSalt(bytes memory pkgArgs) public pure returns (bytes32 salt) { return abi.encode(pkgArgs)._hash(); }`. Because PkgArgs contains `owner`, hashing the whole struct naturally namespaces by `(package, owner, providedSalt)`. **Two different NFT contracts with the same tokenId cannot collide** because owner differs → different args → different address.
3. **Factory early-returns existing instance before `_processArgs`.** `DiamondPackageCallBackFactory.sol:201–218`: salt = `keccak256(abi.encode(pkg, pkg._calcSalt(pkgArgs)))`; if expected proxy exists, returns it (`:215–217`). **NFT must verify post-deploy that the returned proxy's owner == `address(this)`** and mapping was unset before registration. Squatting is benign under standard convention: any pre-deployer must commit owner = NFT contract address (per PkgArgs); they pay gas and gain nothing.
4. **`native noteId ≠ tokenId ≠ 0` under preloads.** `BondDepository.sol:130` returns `notes[to].length` post-push. Pre-deployed attackers can occupy index 0. NFT records the **actual returned `noteId`** at purchase; every other note at that address is unsolicited.
5. **One intended purchase, no global iteration.** Per-NFT map `tokenId ↔ (proxy, expectedNoteId, expectedPayout)`. Wrapper-side O(1) per position. **Upstream `redeem(to)` scan is unchanged** — isolation contains pooling, not per-target grief.
6. **Atomic collection → contribution → mint/stake under same NFT.** Reverts include native collection (PRD v0.24 §12.2 :807). Excess = `actual − expected`. **No feeTo sweep, no human upgrade, no spoof.**
7. **C08 still residual.** Holder-proxy is **not** an absolute gas bound. Per-target grief + quantify-before-execute obligation retained (NN-02 cross-review).

---

## 2. Attributed corrections to my original

### 2.1 My proposed `keccak256(abi.encode(providedSalt))` is unnecessary

My original §2: "Inside HolderProxyDFPkg._calcSalt(bytes pkgArgs): decode PkgArgs to (owner, providedSalt, …); return `keccak256(abi.encode(providedSalt))`."

**Corrected per human clarification + Kimi's source-check:** the standard convention is `keccak256(abi.encode(pkgArgs))` (verified `FeeCollectorDFPkg.sol:153–155`). Since PkgArgs contains **both** `owner` and `providedSalt`, hashing the whole struct **already includes both**. No special decoded-field hash needed. The user's instruction "use exact standard convention not special decoded-field hash" confirms this.

**Astra's custom `keccak256(abi.encode(owner, providedSalt))`** is also unnecessary — same redundancy. Grok's Q5 ("confirm `calcSalt = keccak256(owner, providedSalt)` with unchanged `providedSalt = bytes32(tokenId)`") over-specifies. **All three converged on the right answer**: just use the standard convention.

### 2.2 My Q1 (release-clause question) is now resolved, not open

My original §4 CK1 framed "next processed epoch" as an owner checkpoint. **Per human clarification: this is now the SELECTED policy, superseding PRD v0.24 §12.2 :613 ("no fresh epoch/Pendle lock may be invented").** All three peers flagged this as a real scope change; Astra explicitly said "Record the new selection as superseding those passages—not as merely clarifying the old rule." Do not reopen; record the amendment.

### 2.3 My Q7 (salt-collision safety) is answered by standard convention

My original Q7 raised package-level vs proxy-owner-guard collision safety. **Standard convention `keccak256(abi.encode(PkgArgs))` is the answer.** Owner is a PkgArgs field; namespace = `(package, owner, providedSalt)`. Proxy-level `require(msg.sender == owner)` is sufficient; no package-level check needed.

### 2.4 My Q5 (atomic composition preview gas) remains engineering

Not a PRD defect; standard engineering work for the implementation plan.

---

## 3. Genuine differences among peers

- **Astra** is the strictest on idempotency: "rejecting all pre-existing instances can itself permit address-squatting denial. A maliciously configured/reinitialized instance must never be adopted. Fix immutable package-bound dependencies or bind every mutable identity-affecting argument; do not introduce extra unconstrained initializer payloads behind the same salt." Adds a specification discipline: verify `owner` + `providedSalt` + `dependencies` on adoption. **Acceptable.**
- **Grok** had `RC_UNAVAILABLE` on `DiamondPackageCallBackFactory.sol` and `FeeCollectorDFPkg.sol` and **did not directly read** either this round. Grok's calcSalt proposal (`keccak256(abi.encode(owner, providedSalt))`) is the right idea but redundantly custom; standard convention would suffice if verified.
- **Kimi** is the sharpest on the calcSalt convention (verified `FeeCollectorDFPkg.sol:153–155` and 14 sibling packages) and the only one to call out **"Squatting is benign under this convention: anyone can pre-deploy (pkg, owner=NFT-address, tokenId=k), but the resulting proxy initializes with owner = NFT contract (owner comes from args, not `msg.sender`) — a pre-deployer gains nothing but pays the deploy gas."** This is the cleanest framing.

---

## 4. Remaining narrow decisions (after release-clause acceptance)

The release clause is now **ACCEPTED**. The remaining narrow questions are all in the **excess / late-gift / replacement-retirement / idempotency** axis. None of them requires re-opening per-NFT isolation, atomic composition, or factory mechanics.

| ID | Question | Owner? | Options |
| --- | --- | --- | --- |
| D1 | Excess destination (P2, accepted-excess unresolved). User accepts `actual ≥ expected` but did not select a destination. PRD §12.3 :817 forbids feeTo sweep. | Yes | (a) Wrap excess into same NFT's Keep-YT reinvestment path; (b) segregated wrapper-level treasury (proxy carries cumulative; no withdrawal selector); (c) reserve backing **without** minting DETF (protocol revenue). |
| D3 | Late-gift / retirement. After NFT retirement, the proxy address persists. Can late gifts still be `redeem`'d? Who can call? Destination? | Yes | (a) NFT retirement transfers proxy control to a designated retirement beneficiary for one final harvest; (b) NFT burn also transfers control to a fixed protocol address; (c) proxy becomes claimable by anyone (do not invent). |
| D5 | Replacement rebond: does later reinvestment issue a new **native** bond or stay in the **DETF** staked bond? User said "burns eligible old principal and creates a new staked bond" → DETF staked bond (R41). | Confirm | R41 mechanics; do not silently add another native purchase. |
| D6 | Single-purchase enforcement. Proxy/NFT reject a second intended purchase for the same tokenId. | Engineering | Holder records `bool purchased`; second `deposit` reverts. |
| D4 | Registration discipline. Exactly the `noteId` returned by this proxy's `deposit`; pre-existing notes are always unsolicited. | Engineering | Holder stores `expectedNoteId` at first authorized deposit; later gifts visible via `noteCount` but not registered. |
| Idempotency | NFT verifies post-deploy that the returned proxy's `owner == address(this)` and that no tokenId↔proxy mapping was previously set. | Engineering | Same as D6 + revert if mismatch. |
| Lock-up | "Next processed epoch" — confirm it is the **counter transition** (epoch-number advance after successful contribution), not elapsed 8-hour time. (Astra §4 #1.) | Yes | Counter is recorded at successful composition; permit claim/reinvestment only when later epoch observed. |

---

## 5. Adopted policy vs technical recommendation vs human questions

### Adopted (user-selected, do not reopen)
- **AC1** Per-NFT holder-proxy pattern (1:1 tokenId ↔ holder ↔ intended purchase).
- **AC2** Holder proxy's owner = NFT contract, immutable; no human upgrade; rights follow tokenId on transfer.
- **AC3** Standard `calcSalt = keccak256(abi.encode(PkgArgs))`. PkgArgs contains `owner` + `providedSalt`. Caller-provided `providedSalt = bytes32(tokenId)` unchanged.
- **AC4** PkgInit immutables: BondDepository address only. No depository propagation beyond this single immutable (do not silently globalize across the DETF package).
- **AC5** Atomic collect → Keep-YT → mint/stake under same NFT; failed composition reverts native collection (PRD §12.2 :807 preserved).
- **AC6** Excess accepted (`actual ≥ expected`); no feeTo sweep (PRD §12.3 :817).
- **AC7** **New release clause:** principal claim/reinvestment available **next processed NET epoch after the registered note is fully claimed** (`claimed == payout`), superseding PRD v0.24 §12.2 :613 / :793 native-maturity-only.
- **AC8** Reinvestment burns eligible old principal, mints new DETF staked bond, no contraction input incentive (R41 preserved).

### Technical recommendation (spec-author / engineering)
- **TR1** Holder records `expectedNoteId` returned by `BondDepository.deposit`; never assumes tokenId or 0 (Astra §2, Kimi §3).
- **TR2** NFT verifies post-deploy: factory-returned proxy's owner == `address(this)`, mapping unset before registration (idempotency / squatting).
- **TR3** Proxy functions owner-only: `require(msg.sender == owner)`. No `diamondCut`, no `init` after first, no asset-spend surface (Astra §2; Kimi §3).
- **TR4** Atomic composition previews project `expected` separately from `actual`. If `paid > expected`, accept and route only `expected` to Keep-YT. Excess remains on proxy until D1 is decided.
- **TR5** Reinvestment distinguishes registered-note completion (`claimed == payout`) from `pendingFor(holder) == 0`. **Counter transition** (epoch number recorded at successful composition, claim/reinvestment only after a later processed epoch observed). A stranger's late gift must not perpetually postpone release.
- **TR6** NFT retirement transfers proxy control to a **retirement beneficiary** (per D3). One final atomic harvest under the same NFT's transition. Persistent proxy ownership then becomes claimable by that beneficiary only, **not** anyone (Kimi D3; Grok Q4; no new public sweep selector).
- **TR7** Per-tokenId map `tokenId ↔ (proxy, expectedNoteId, expectedPayout)`. Wrapper bookkeeping O(1). Upstream `redeem(to)` scan unchanged — isolation contains pooling, not per-target grief (NN-02 residual; not closed).

### Human questions (require owner disposition)
- **Q1 (D1)** Excess destination: same-NFT reinvestment / wrapper treasury / reserve backing (no mint). **No** feeTo sweep (PRD §12.3 :817 forbids).
- **Q2 (D3)** Late-gift / retirement policy: NFT retirement transfers proxy control to whom, with what final-harvest destination. Persistent proxy ownership after retirement.
- **Q3 (D5)** Confirm replacement rebond is R41 mechanics (DETF staked bond, no native bond) — not a second native purchase.
- **Q4 (Astra §4 #1)** Confirm release trigger is **counter transition** (post-composition epoch-number advance), not elapsed 8h time, not `pendingFor == 0` (which a late gift can poison).

---

## 6. PRD amendment approach (docs only)

Add **§12.4 Holder Proxy (SELECTED custody, residual liveness OPEN)** with:
- (AC1–AC8) recorded as selected.
- (TR1–TR7) recorded as engineering obligations.
- (Q1–Q4) recorded as open owner checkpoints.
- C08 amended: "per-NFT holder pattern selected; per-target liveness residual; not an enforceable scan bound."
- §12.2 :613 / :793 explicitly superseded by AC7 with cross-reference.

---

## 7. Confidence and evidence limits

- **High** standard `calcSalt` convention (`FeeCollectorDFPkg.sol:153–155`, directly read).
- **High** that owner-in-PkgArgs is sufficient for namespace uniqueness.
- **High** factory idempotency semantics (`DiamondPackageCallBackFactory.sol:201–218`, prior-round verified).
- **High** native `noteId ≠ tokenId` preloads (PRD §12.3 :815 + BondDepository.sol:130).
- **High** release-clause change supersedes native-maturity-only (per human).
- **Medium** on TR1–TR7 (engineering; not PRD-binding).
- **Low** on TR6 retirement beneficiary address and reentrancy posture (engineering detail).
- **Not claiming** proposal is fully specified; upstream scan is bounded; excess destination is settled; retirement/late-gift is decided.
- **Not reopening** per-NFT isolation, Keep-YT routing, shared-SY egress, four-leg HLP, atomic rollover, principal cliffs, hold-interest-token, public HLP, DETF-as-SY, fixed `NET-DETF` salt.

**Saved:** `docs/research/netnet-holder-proxy-2026-09-27/minimax-cross-review.md`. Originals untouched.
