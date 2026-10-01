# Kimi K3 — ORIGINAL: holder-proxy-per-NFT design assessment (user proposal, 2026-09-27)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only, not provider attestation |
| Date | 2026-09-27 |
| Scope | Holistic assessment of the user's holder-proxy proposal against PRD v0.24 §§4/10/12/C08. Research only: no shell/RPC/tests/code/config/browser, no delegation. No new-round peer artifacts read. |
| Key sources | PRD v0.24 :770–819 (§12), :1133–1135; `DiamondPackageCallBackFactory.sol:195–229`; `FeeCollectorDFPkg.sol:149–166` (calcSalt convention); `BondDepository.sol:54,104–153,183–189`; prior-round verified facts (Sourcify exact_match, ABI completeness). |

## 1. What the user has selected vs proposed (careful attribution)

**Reads as selected (custody architecture):** wrapper NFT is 1:1 with one intended native bond; rights follow tokenId on transfer; a small reusable Holder Proxy Package; one holder proxy deployed per NFT at purchase; proxy owner = the NFT contract; PkgArgs = (owner, providedSalt = bytes32(tokenId)); NFT maps tokenId ↔ holder; proxy purchases/owns the native note; NFT orchestrates claim → normal NET reserve contribution → mint/stake under the same NFT; per-target attack acknowledged, pooling mitigated, extra deployment cost accepted.

**Reads as proposed, needing explicit owner disposition (do NOT record as settled):**
- **P1 — new release clause:** principal claim/reinvestment available **next processed NET epoch after the native bond is fully claimed**, replacing v0.24 §12.2's native-full-maturity rule (:793: maturity = native full maturity; release only after the mandatory funded path). "Reinvestment burns eligible old principal and creates a new staked bond, no incentive" preserves R41. This is a genuine change to settled R19/§12.2 and must be presented as an amendment, not folded in.
- **P2 — excess acceptance:** "accept claim amount greater than expected due to unsolicited notes, not full rejection" settles *accept-vs-reject* but **not the excess's rights/destination** (see D1).

## 2. Factory salt mechanics — source-checked answers

`DiamondPackageCallBackFactory.deploy` (:201–217): `salt = keccak256(abi.encode(pkg, pkg._calcSalt(pkgArgs)))`; if the expected proxy exists it is **returned before** `_processArgs` (:218). Package convention (`FeeCollectorDFPkg.sol:153–155` and 14 sibling packages): `calcSalt(pkgArgs) = keccak256(abi.encode(pkgArgs))`.

**Consequences for the proposal:**

1. **Namespace:** effective address namespace is (package, args). With PkgArgs = (owner, tokenId-salt) and the conventional hash-of-args `calcSalt`, the address is a pure function of (pkg, owner, tokenId). **Two different NFT contracts cannot collide** for the same tokenId because owner differs → different args → different address. The recommendation the round asks for — owner+providedSalt derivation without changing the caller-provided `bytes32(tokenId)` — is satisfied by the *default convention*: keep `providedSalt = bytes32(tokenId)` verbatim in PkgArgs; owner mixing comes free because owner is a PkgArgs field inside the hashed args. No custom salt math is needed; a custom `calcSalt` that dropped owner would reintroduce cross-contract collision and must be avoided.
2. **Squatting is benign under this convention:** anyone can pre-deploy (pkg, owner=NFT-address, tokenId=k), but the resulting proxy initializes with owner = NFT contract (owner comes from args, not `msg.sender`) — a pre-deployer gains nothing but pays the deploy gas. A wrong-owner squat (owner=attacker) hashes to a *different* address and never shadows the NFT's intended proxy. Residual requirement (spec, not new decision): `initAccount` binds owner once and rejects re-initialization; the NFT verifies post-deploy that the returned proxy's recorded owner == `address(this)` and that its tokenId mapping was unset before registration (defense-in-depth against factory's return-existing path, which skips `_processArgs`).
3. **Sibling cross-call protection:** the proxy's mutation functions must be owner-only (the one NFT contract); the NFT enforces per-tokenId holder authorization internally. This preserves "rights follow tokenId, not purchaser" — the proxy is never owned by an EOA.
4. **Immutable owner / no human upgrade:** consistent with family law (§2.1: no new human administrator); nothing in the package pattern requires an upgrade path — specify none.

## 3. Native-note realities the design must encode (verified source facts)

- **noteId ≠ tokenId and ≠ 0 under preloads:** notes append to any address, including one with no code yet (`BondDepository.sol:104–140`; array keyed by address, :54). An attacker can pre-load the deterministically computable proxy address *before deployment or before the intended purchase*. Therefore: authorized registration = the `noteId` **returned by the proxy's own `deposit` call** (:130) recorded in the NFT at purchase; every other note at that address is unsolicited by construction.
- **One intended purchase, no global iteration:** wrapper-side accounting reads only the registered note via the public `notes(proxy, noteId)` getter — O(1) per position, no array scan. This part of the design is fully sound and closes the bookkeeping half of NN-02.
- **The upstream scan is unchanged:** `redeem(to)` sweeps all vested notes of the proxy (:143–153); the per-NFT proxy mitigates *pooling* (one position's grief doesn't touch another) but the per-target append/grief path persists — the user's acknowledgment is accurate, and this must not be recorded as an absolute gas bound. The quantified N*/attacker-cost study (prior round's checkpoint) is still owed before the feature is called executable; the holder-proxy design does not discharge it.
- **Excess vs expected, mixed receipts:** `redeem` returns one aggregate `paid`. Expected = registered note's newly vested amount computed from the getter (bounded read); excess = paid − expected = unsolicited gift value. User selects accept-excess (P2). Destination is open (D1 below).
- **Failed collection:** atomic revert leaves the installment unclaimed (v0.24 :774/:807) — preserved; previews must project the full compose (collect → Keep-YT → mint → stake) and report excess separately from the registered note's entitlement.
- **Persistent stranded-note risk:** pre-loaded or dust-griefed proxies can carry unclaimed value past a gas ceiling; and **retirement/late gifts** — after NFT retirement the proxy address persists and can still receive notes; whether a retired tokenId's proxy remains collectible, by whom, and to whose benefit is unspecified (D3).

## 4. Exact narrow remaining decisions (owner-facing)

- **D1 — excess rights/destination (must be decided):** (a) contribute the excess through the same Keep-YT → mint/stake path under the same NFT (gift-funded growth credited to the holder — note :803 says registered-note proceeds are returned principal; gifts are *new external capital*, which under R15 normally enters bonded — (a) implicitly grants the gift the position's schedule); (b) contribute as reserve backing **without** minting DETF (protocol revenue); (c) retain as an excluded payable pending a rule. P2's "accept, don't reject" does not choose among these.
- **D2 — new release clause (P1) adoption:** replace native-maturity-only with "available next processed NET epoch after the registered note is fully claimed (claimed == payout)"; define behavior for partial claims before full claim; reconcile with C05/NN-04 (next-epoch durations vs oracle minimum); burn-without-incentive (R41) explicitly preserved.
- **D3 — retirement/late-gift policy:** persistent proxy collectibility and destination after NFT retirement.
- **D4 — registration discipline:** confirm registration is exactly the deposit-returned noteId; pre-existing notes at a fresh proxy are always unsolicited.
- **D5 — idempotent-deploy semantics:** NFT behavior when the factory returns an existing proxy (expected under re-entry/retries); post-deploy owner verification is specification, not an owner question.
- **D6 — single-purchase enforcement:** proxy/NFT reject a second intended purchase for the same tokenId ("one native intended purchase").

## 5. Recommended PRD amendment approach (moderator consolidation, docs only)

1. New §12.4 recording the **selected** custody architecture (holder-proxy package, 1:1, owner=NFT contract, PkgArgs shape, registration = deposit-returned noteId, owner-only proxy calls, no upgrade path, transfer-follows-tokenId) with the factory semantics from §2 as requirements.
2. Amend §12.2 with the **proposed** release clause (P1) marked as pending owner disposition — do not edit R19's selected text until answered.
3. Amend §12.3/C08 row: custody pattern selected; bookkeeping bounded O(1) per position; upstream scan unbounded; quantify-before-execute obligation retained; NN-02 remains OPEN pending D1–D3 and the gas study.
4. Explicit non-changes: no feeTo sweep of native-note proceeds (:817); no absolute liveness claim; NN-01 live checks unaffected.

## 6. Assessment verdict

The proposal is **architecturally sound and materially improves NN-02**: it converts the unbounded shared-custody problem into isolated per-position custody with O(1) wrapper bookkeeping, makes squatting economically pointless under the conventional calcSalt, and aligns with Crane deployment patterns without new human authority. It does **not** — and the user does not claim it does — bound the upstream scan; the residual is per-target grief with quantification still owed. Two product changes (P1 release clause, D1 excess destination) plus D3/D6 policy points are the narrow open set. No contradiction with settled economics found.

## 7. Limits

No execution or gas measurement; factory/package behavior cited from `DiamondPackageCallBackFactory.sol:195–229` and `FeeCollectorDFPkg.sol:149–166` read directly this session; upstream ABI certainty from the prior round's live Sourcify exact_match (accessed 2026-09-27). The user's message is treated as the proposal text; nothing beyond its explicit wording is attributed to the owner.
