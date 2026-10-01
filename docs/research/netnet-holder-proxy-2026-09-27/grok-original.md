# Grok original — NetNet Bond Holder Proxy (user proposal)

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Date | 2026-09-27 |
| PRD | v0.24 §§4, 10, 12, C08 |
| Skills | Local `.claude/skills/crane-architecture`, `crane-deployment` (canonical crane skills `RC_UNAVAILABLE`) |
| Failed | `lib/crane/contracts/factories/DiamondPackageCallBackFactory.sol` (`RC_UNAVAILABLE`, not retried). BondDepository not re-read this pass (prior `RC_UNAVAILABLE`). |
| Context7 | Unused (no new external library API). |

**Legend:** **ACCEPTED** = user selection this round (do not reopen isolation). **PROPOSED** = spec-author design to preserve that selection. **QUESTION** = not settled by the user’s sentences. This is **not** an absolute gas bound (C08 still residual per-holder).

---

## 1. Holistic reading

The user **selects a custody pattern**, not a proof that `redeem` is O(1). One wrapper NFT **tokenId** ↔ one **intended** native purchase; **rights follow tokenId**, not the original buyer. A **small reusable Holder Proxy Package** deploys a holder **per NFT at purchase**. **Owner = NFT contract** (immutable, no human upgrade). **PkgArgs = owner + `providedSalt = bytes32(tokenId)`**. NFT maps tokenId ↔ holder. Holder **buys and is `to`** for the native note; NFT **orchestrates** `redeem` → Keep-YT contribution → mint/stake **under the same NFT**. **Accept paid NET ≥ expected** (gifts), **do not reject** the whole claim. Extra CREATE2 cost **accepted**. Pooling across users **mitigated**; **per-target appends remain**.

**Second clause (new vs v0.24 §10 row “native full maturity”):** after the **native bond is fully claimed**, **principal** claim/reinvestment is available at the **next processed NET epoch** (like elected reinvestment), **not** immediately at native maturity. Reinvestment **burns eligible old principal**, issues a **new staked bond**, **no contraction incentive**.

Do **not** treat this as C08 closed.

---

## 2. Factory salt (source-check)

`crane-deployment`: `factory.deploy(pkg, pkgArgs)` → `pkg.calcSalt(pkgArgs)` → CREATE2 proxy. PkgArgs on the **interface**. Skill does **not** reprint “return existing before processArgs”; that behavior was previously cited on `DiamondPackageCallBackFactory` (~`:201–218`) and is **unverified this pass**. **If** the factory returns an existing instance **before** `processArgs`/`initAccount`, a salt collision **silently hands out another NFT’s holder** with **no re-init**. That is worse than revert.

**Collision:** two NFT contracts, same **package**, `providedSalt = bytes32(1)` → same CREATE2 if `calcSalt` is **only** tokenId.

**PROPOSED (do not change caller `bytes32 tokenId`):**

```text
PkgArgs { address owner; bytes32 providedSalt; }  // providedSalt := bytes32(tokenId)
calcSalt(args) = keccak256(abi.encode(args.owner, args.providedSalt))
```

Namespace = **NFT contract + tokenId**. Same tokenId on another NFT is a **different** holder. `initAccount` must **require** `msg`/factory context sets **immutable owner = args.owner = NFT**, reject `owner==0` and owner ≠ deploying NFT.

Also: DETF `"NET-DETF"` salt (R55) is a **different package** — no collision with holder pkg.

---

## 3. Architecture vs PRD §4/12

§4: NFT child coordinates native claims; DETF holds hook LP; sNET-DETF holds DETF backing. Holder is a **new child class**, not a second product NFT and not a human admin.

**PROPOSED authority:** holder callable **only** by owner NFT (and NFT only as DETF-controlled child). **No** sibling holder → holder, **no** EOA `diamondCut`, **no** spoof `initAccount` after first init.

**native `noteId` ≠ tokenId / 0:** `deposit` returns `noteId = notes[to].length` **after** push (PRD/Sourcify ABI). Pre-spam can occupy 0. **Register the returned noteId** as the **intended** purchase. Bookkeeping uses that index; **`redeem` still scans all notes of the holder** (not a bound).

**One intended purchase, no global iteration:** NFT does **not** walk all tokenIds. Per tokenId: map → holder → `redeem(contributionRecipient)` → contribute → mint/stake **that** NFT.

**Atomicity (keep §12.2):** failed Keep-YT/mint/stake **reverts including native collection**. Previews must project **expected** vs **actual paid**. If `paid > expected`, **accept** (user). **QUESTION:** how **excess** is booked (same NFT principal vs segregated vs protocol) — **not** feeTo sweep (§13). Mixed maturities on extra notes: user did **not** select gift lock/release.

**Deterministic pre-spam:** CREATE2 address is public **before** first deposit. Attacker can `deposit(..., holder)` **before** intended buy. Isolation **contains** this to **that tokenId**. Late gifts after “fully claimed”: array **still grows**; later `redeem` still walks history; **stranded** if OOG. **Retirement:** **QUESTION** whether holder is abandoned, and who can `redeem` leftover gifts (must not be an unselected sweep).

---

## 4. Release clause vs v0.24

**Current SELECTED (§10 / §12.2):** wrapper principal locked until **full native maturity**; then collect/contribute/mint/stake; **no new epoch/Pendle lock**; rewards claimable earlier.

**User now:** principal reinvestment **available next processed NET epoch after native bond fully claimed**.

That **replaces** “already satisfied at native maturity, no fresh epoch lock” for **this** wrapper principal. **ACCEPTED as this round’s proposal to record**, **not** silently merge with §10.1 elected reinvestment **unless** the PRD says they share the **same** next-epoch rule (user analogized). **Burn old principal + new staked bond, no incentive** matches **R41** mechanics; **eligibility** of “old principal” after the new wait is **QUESTION** (fully vested wrapper principal only? partial?).

**C05** still: next-epoch duration vs oracle min.

---

## 5. Narrow remaining decisions (owner / spec)

1. **Release:** adopt **next processed epoch after native fully claimed** as **SELECTED**, and **retire** “no new lock at native maturity” for wrapper principal? Rewards-during-vest **unchanged**?
2. **Excess NET:** same NFT’s Keep-YT principal vs other book; **not** feeTo. Gift notes’ **maturity** vs intended note.
3. **Intended note registration:** require `noteId` from **this** `deposit` return; fail if holder already has unregistered notes? (preload)
4. **Retirement / late gifts:** after “fully claimed,” may holder still `redeem`? Who gets leftover?
5. **Salt:** confirm `calcSalt = keccak256(owner, providedSalt)` with **unchanged** `providedSalt = bytes32(tokenId)`.
6. **Factory idempotency:** if existing instance returned, **must revert** unless `owner` and mapping already match **this** tokenId (no silent alias).

Not asked: family re-approval; treating isolation as C08 closed; inventing `redeemNote`.

---

## 6. PRD amendment approach (docs only)

Add **§12.4 Holder Proxy (SELECTED custody, residual liveness OPEN):** 1:1 tokenId↔holder↔intended purchase; rights follow NFT; owner=NFT; PkgArgs owner+providedSalt; **calcSalt hashes owner||providedSalt**; map tokenId↔holder; register **returned noteId**; accept `paid ≥ expected`; per-target grief **disclosed**, not a bound; extra deploy cost accepted.

**§10 table:** replace wrapper principal row with **next processed NET epoch after native fully claimed**, **pending explicit owner checkbox** if consolidator will not infer it. Point reinvestment at **R41** no-bonus burn/replace under **same NFT**.

**C08:** “per-NFT holder selected; **not** an enforceable scan bound.” Keep quantify/OOG residual.

**A09/A30:** 1:1 mapping, salt uniqueness, excess-accept, failed atomic collection, transfer-follows-tokenId.

---

## 7. Limits

Factory return-existing **unverified this file**. Isolation **does not** bound `redeem`. Confidence **high** on salt-must-include-owner; **medium** on release-clause wording until the consolidator records the checkbox. No implementation.
