# Grok holder-proxy cross-review

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Inputs | Own original (untouched). Full Astra, MiniMax, Kimi. **No** peer cross-reviews. |
| Source | `contracts/fee/collector/FeeCollectorDFPkg.sol:153–155` — `calcSalt(pkgArgs) = abi.encode(pkgArgs)._hash()` (**fee** singular, human-corrected path). Factory file unread this session (`RC_UNAVAILABLE`). |
| Date | 2026-09-27 |

---

## Adopted policy (do not reopen)

User: **1:1 tokenId ↔ intended native buy**; **rights follow tokenId**; **per-NFT holder**; extra deploy cost OK; **per-target grief remains** (not a gas bound); holder **`to`**; NFT orchestrates **atomic** collect → Keep-YT → mint/stake **same NFT**; **accept `paid ≥ expected`**, do not reject.

**Release (now SELECTED):** principal available **next processed NET epoch after full native collection**, **superseding** v0.24 native-maturity-only / “no extra lock” (§10/§12.2). MiniMax/Kimi “checkpoint CK1” is **obsolete**. Record the **boundary**, not a new vote:

- **Fully claimed** = **registered intended note** `claimed == payout` after **successful atomic contribution** (Astra). Not `pendingFor(holder)==0` (late gifts must not postpone forever).
- Then wait a **later processed NET epoch number**, not wall-clock 8h, not an epoch already processed **in the completion tx**.
- **Rewards-during-vest** unchanged unless the user said otherwise (they did not).
- Reinvestment: **R41** burn eligible old principal, new staked bond, **no incentive**.

C08: isolation **selected**; scan **not** proven bounded.

---

## Salt — correct Grok original

Human: **standard** `calcSalt` hashes **entire PkgArgs bytes**. PkgArgs **contains** `owner` + `providedSalt`; `providedSalt = bytes32(tokenId)` **verbatim**. Factory then namespaces with **package address**. **No** special `keccak256(owner, providedSalt)` field hash (Grok original + Astra “derive keccak(owner, salt)”). **No** MiniMax `calcSalt = hash(providedSalt only)` (that **collides** two NFTs’ tokenId 7).

Kimi §2.1 is the convention: owner mixing is **free** because owner is **in args**. Custom salt that **drops** owner is the bug.

**Early-return existing instance** (peers cite factory ~`:215–218`; unread here): NFT must **verify** returned holder’s **immutable owner == this NFT**, mapping unset or already this tokenId, **and** instance config (e.g. depository) matches. Do **not** adopt a wrong-owner squat. Correct-config predeploy (Kimi): squatter pays gas, **no control** if owner is in args and init is once.

**PkgArgs depository:** if BondDepository is **PkgArgs**, it enters the salt — **instance-local**, do **not** silently put it only in PkgInit/global and then share holders across depositories. If **PkgInit**, all holders of this **package bytecode** share one depository; a second depository needs a **different package instance**, not a hidden global.

---

## Corrections

| Source | Issue |
| --- | --- |
| **Grok original** | Special decoded-field `calcSalt`. **Withdraw.** Use FeeCollector convention. |
| **MiniMax** | Same-tokenId collision **intended** across NFTs; uniqueness only `msg.sender==owner`. **Wrong** — two NFTs would **share one holder**. Also: no reentrancy because “only last call is Treasury” — **NET transfer to holder** can callback; NFT→holder→DETF composition **needs** reentrancy/context guards (Astra). |
| **MiniMax excess “wrapper treasury” / fund future reinvest** | **Invented destination.** User only said accept ≥ expected. **Not** feeTo, **not** consolidator-chosen treasury. |
| **MiniMax** “no reentrancy needed”; `noteId = length after` vs Astra **index before append** | Peers disagree on `:130` timing. **Do not assume noteId==tokenId/0.** Persist **returned** `noteId`. |
| **Kimi** Sourcify ≡ current runtime | Verification **record**, not latest self-measured bytecode (prior UI round). |
| **Kimi P1 still pending** | Human **now** selected next-epoch-after-full-collection. |

---

## Technical (not new product)

- **Permanent owner = NFT contract**, not wallet. Transfer = who may call NFT, not proxy Ownable.
- **One intended purchase**; second intended `deposit` rejected. Unsolicited upstream `deposit(..., holder)` cannot be refused.
- **Delta:** snapshot holder NET / registered note **before** `redeem`; expected = **this note’s vested increment**; excess = **actual movement − expected**. Do not credit **preexisting** NET as this claim. Accept excess **into this operation’s measured receipt**; **rights of excess** still **QUESTION**.
- **No** invented feeTo sweep, excess protocol mint, or retirement beneficiary.
- Callbacks: mint NFT / ERC721 receiver / NET FoT / DETF before mapping complete → **incomplete-position** risk (Astra). One rollback domain if Keep-YT fails.
- Isolation **contains** pre-spam to **that** tokenId; CREATE2 still **predictable**.

---

## Still human/spec questions (narrow)

1. **Excess rights** after accept-not-reject: same NFT Keep-YT principal vs excluded payable vs other — **not** feeTo by default. **After** intended completion, later gift `redeem`?
2. **Retirement / late gifts:** holder address lives on; who may collect; do not burn control waiting for gifts to stop.
3. **Replacement:** same tokenId rebond vs new bond NFT? User said same NFT for native path; post-epoch R41 **tokenId** unspecified.
4. **Idempotent deploy** verify-or-revert rules (engineering, not economics).

**C05** still: next-epoch vs oracle min.

---

## PRD

§12.4 **SELECTED** holder pattern + standard **hash(PkgArgs)** + register **returned noteId** + accept ≥ expected + residual per-target. **§10/R19/R50:** next processed epoch after **registered-note full collection**, superseding native-maturity-only. C08: isolation selected, **not** scan-bound. Leave D-excess/retirement as OPEN rows.

Confidence: **high** on standard calcSalt + adopted isolation/release; **none** on factory line numbers this session; excess/retirement **unset**.
