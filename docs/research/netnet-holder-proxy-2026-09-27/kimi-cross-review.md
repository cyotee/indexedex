# Kimi K3 — Holder-proxy CROSS-REVIEW (Astra / Grok / MiniMax M3 originals)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Basis | Full reads of the three originals (untrusted evidence); my unchanged original; the human's two clarifications recorded as authority. No peer cross-reviews read. |

## 1. Human clarifications — adopted as settled this round

1. **Salt convention:** standard package `calcSalt` hashes the full PkgArgs (verified convention: `FeeCollectorDFPkg.sol:153–155` — path `contracts/fee/collector/`, fee singular, matching my original citation), and PkgArgs contains `owner + providedSalt` with `providedSalt = bytes32(tokenId)` unchanged. Effective address = `keccak256(abi.encode(pkg, keccak256(abi.encode(pkgArgs))))` per `DiamondPackageCallBackFactory.sol:201–217`. **No decoded-field custom hash.** This supersedes Astra's and Grok's proposed `keccak256(abi.encode(owner, providedSalt))` (functionally equivalent but non-standard) and settles against MiniMax's variant (see C1).
2. **Selected now (do not reopen):** per-NFT holder isolation, deployment cost, residual per-target exposure, rights-follow-tokenId, atomic collection→contribution→mint/stake under the same NFT — and **the release clause**: principal claim/reinvestment available **next processed NET epoch after full native collection**, expressly superseding the old native-maturity-only text (v0.24 :793, :613). My original's D2 and MiniMax's/Grok's CK1 are **answered**.

## 2. Corrections to peers (attributed)

- **C1 (MiniMax §2 — rejected, decisive):** `calcSalt = keccak256(abi.encode(providedSalt))` **drops owner**; MiniMax then calls cross-NFT collision "the intended behavior" with uniqueness "enforced at the proxy level via `require(msg.sender == owner)`." That is fatal, not intended: with owner dropped, NFT-B's deploy of tokenId 7 **early-returns NFT-A's existing proxy** (factory:215–217, before `_processArgs`), whose owner is NFT-A — MiniMax's own guard then permanently bricks NFT-B's position rather than sharing anything. The human's clarification (standard hash-of-args, which includes owner) eliminates the collision; MiniMax's rationale is wrong even though its PkgArgs shape is right.
- **C2 (MiniMax §3.3): "No reentrancy guard needed in the proxy"** is overconfident. The proxy's own surface may be simple, but the NFT-side atomic compose includes ERC-721 minting with receiver callbacks; Astra's requirement (atomic mint/register/initialize/purchase, no incomplete-position use from callbacks, authenticated holder callbacks bound to the tokenId↔holder mapping) is the correct framing. Proxy simplicity ≠ composition safety.
- **C3 (MiniMax §3.5): misapplied citation.** MiniMax argues excess cannot enter the reserve contribution "because :803 prevents it" — :803 says contributed assets must not stay *excluded from inventory*; it does not govern whether gift value is contributed. The real reason excess destination is open is product rights (new external capital vs returned principal, :803's provenance sentence), not that line.
- **C4 (Grok §2):** his conditional factory analysis (file unread this pass, `RC_UNAVAILABLE`) is confirmed by the three readers; no content error, just evidence-tier.
- **C5 (Astra, adopted — corrects my phrasing):** the callback factory deploys proxies by **CREATE2** (`:225`), not CREATE3; my "CREATE3 escrow" wording is corrected. Also adopted: **adopt-existing-instance is the right default** — with owner inside the hashed args, a pre-deployed correctly configured proxy is benign, and blanket-rejecting existing instances would itself enable squat-denial (Astra). Rule: adopt iff recorded owner/config match exactly; never adopt a maliciously configured or re-initializable instance.

## 3. Consensus retained (four-way)

noteId ≠ tokenId/0 under preloads (`BondDepository.sol:130` returns the pre-append length; register the **returned** noteId atomically at purchase); one intended purchase, no global iteration; registered-note bookkeeping is O(1) while `redeem` stays O(n) per proxy (:143–153) — isolation mitigates pooling, **not** an absolute bound; measure **actual receipt delta** vs registered-note expectation, not nominal returns; excess ≠ feeTo sweep (v0.24 :817); failed compose reverts including collection; immutable NFT-contract owner, no human upgrade, no sibling control; holder-package PkgInit/PkgArgs wiring (incl. depository reference) comes from the family's validated configuration, not a silently globalized or caller-resupplied address.

## 4. Adopted policy vs technical recommendation vs open questions

**Adopted policy (human):** §1 items 1–2, plus accept-excess (not reject).

**Technical recommendations handed to the consolidator (not owner decisions):**
- **Astra's completion-boundary semantics** for the now-settled release rule: "fully claimed" = the **registered** note's `claimed == payout` after successful atomic contribution (never `pendingFor(holder)==0`, or a late gift postpones release forever); record the processed epoch at completion; release only when a **strictly later** processed epoch number is observed; no reset from gifts or NFT transfer. I endorse this as the precise boundary.
- **Astra's consequence disclosure (adopt, sharpens the residual):** tying release to *successful full collection* means the per-target grief path now attacks the release gate itself — already-funded principal can remain locked if upstream redemption becomes unexecutable. The C08/NN-02 row should read: isolation selected; per-target liveness residual now includes release-gating.
- NFT-side idempotent-deploy handling, spoof/re-init rejection, callback authentication (§3 consensus) — plan-level specification.

**Open human questions (narrow):**
- **Q1 (excess destination) — genuine dissent.** Astra: excess enters the same NFT's funded contribution (rights/lock to confirm). MiniMax: wrapper-level treasury carried on the proxy, never common reserve, never feeTo (my earlier option (c)). The human's "accept, don't reject" does not choose. Also open: release condition for excess collected *after* intended completion (Astra Q2), and gift-note maturities (Grok).
- **Q2 (retirement/late gifts):** after retirement the proxy persists and remains appendable; no retirement beneficiary may be invented (human's guard). Astra Q3/Grok Q4/MiniMax Q3·Q6 converge: define whether the old NFT (or its terminal state) retains a claim path for late gifts, and who receives them — explicitly open.
- **Q3 (eligible old principal scope):** "burns eligible old principal" — fully collected wrapper principal only, or partial? (Grok's point, still unanswered.)

## 5. PRD amendment approach (moderator consolidation, docs only)

New §12.4 (selected custody architecture + §1.1 factory semantics as requirements); §12.2/§10 release text superseded per §1.2 with Astra's boundary wording as proposed specification; §12.3/C08 updated to "isolation selected; per-target residual incl. release-gating; quantification owed"; A09/A30 gain 1:1-mapping, salt-derivation, excess-accept, failed-collection, transfer-follows-tokenId cases. Explicit non-changes: no feeTo sweep, no invented upstream selector, no retirement beneficiary, no absolute liveness claim.

## 6. Limits

All factory/depository facts from direct reads this session; Sourcify exact_match evidence is a verification-service attestation (2026-07-16, accessed 2026-09-27), not an independent latest-runtime re-check. No execution; peer claims untrusted; originals unchanged. No further round initiated.
