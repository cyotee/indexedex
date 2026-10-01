# Grok partial-reinvestment cross-review

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Inputs | Own original (untouched). Full Astra, MiniMax, Kimi. No peer cross-reviews. |
| Date | 2026-09-27 |

Do **not** re-approve the selected process.

---

## Adopted (user)

Pre-maturity **dedicated reinvestment** of **already-funded** principal while the **native note still vests**. Old note/NFT/holder stay. Burn **requested actual** principal only; incentive-free owned-reserve quote; **new** bond, **destination-type typical lock** (numbers **later**). Remainder, rewards, **future** native proceeds stay **old tokenId**. No native move/cancel/second intended buy. **Zero current principal ≠ retire** (future vest remains). Excess **destination = same-NFT principal** (settled); **only** late-excess **timing** and **direct donations** stay H01-open.

**Purchase-epoch-passed ≠ full-collection.** Do not merge.

**Final withdrawal/retirement** keeps the v0.25 full-collection (+ recorded next-epoch) rule **as a separate path**, subject to **upcoming lock review**. That rule **must not gate** selected pre-maturity reinvestment.

---

## Epoch fields (semantics, not storage)

| Meaning | `0` |
| --- | --- |
| Purchase snapshot (processed NetNet counter at intended buy) | **Not** a `>0` “has purchased” sentinel. If the counter was 0, the stored value **is 0**. |
| Full-collection snapshot (after intended note complete **and** contributed) | Not yet fully collected — **engineer layout later** |
| **Unlock target** | **`0` = assigned Pendle market maturity** (user). **Not** unset, pending, unlocked, or fully collected |

Astra got unlock-`0`. **Kimi** “0 = unset” and **MiniMax** “0 = not yet unlocked / purchaseEpoch>0 means deposited” — **wrong**. Snapshots vs **unlock target** stay distinct; **do not prescribe structs**.

---

## Share math / PkgArgs / extras

**Shares ≠ raw principal.** Debit **corresponding** staking shares/backing so **actual** remaining principal matches the burn; **do not** `internalShares -= q` (MiniMax L04). Grok original’s “debit shares / held DETF” must mean **share-equivalent of q**, not raw-q subtraction.

**PkgArgs is not an asset allowlist** (MiniMax L01). Discovery-supported routes only; **no new routes**.

**No** extra cadence rules (Kimi L3, MiniMax unlockEpoch-as-gate-baseline). **No** lock-period numbers. **No** second approval of the process.

Blocked native `redeem` **must not be required** to reinvest **already-funded** amounts. **Do not promise** it **never** affects reinvestment: **other** required sync (epoch process, staking checkpoints) can still fail and revert the **whole** A path. Failure restores old principal.

---

## Peer corrections

| Who | Fix |
| --- | --- |
| **MiniMax** | Split 12.4a/12.4b as **final-release vs pre-maturity reinvest**, not two flavors of R41 both minting new bonds on full collection. Do not invent `purchaseEpoch>0`. Do not put destination assets in PkgArgs. |
| **Kimi** | Unlock `0` is **Pendle maturity**, not unset. H03: new bond **new tokenId**; old persists until **emptied and** final-release/retire rules — **not** retire on `P=0` alone. |
| **Grok original** | Keep A vs B split. Tighten: no raw-q share subtract; no claim that blocked `redeem` **cannot** interact via **other** deps; unlock-`0` already correct. |
| **Astra** | Closest: three **meanings**, destination-type lock later, H01 destination answered. Adopt that amendment shape. |

---

## Concrete PRD amendment

**§10 wrapper row / R19 / O03 / A08 / §12.4:849:** scope **full collection + next processed epoch** to **final principal withdrawal/retirement only**. Add **pre-maturity dedicated reinvestment**: funded `q ≤ P`, no bonus, new bond, old position intact.

**H01:** destination **same NFT principal**; leftover = late timing / donations.

**H02:** **final-release** checkpoint only; **not** an A-gate.

**H03:** new bond **new** identity; old NFT until **matured/emptied per later lock review**; **not** on zero principal alone.

**Three epoch meanings** as table above; layout later.

C05/NN-04 still for **destination** locks. C08 scan residual **unchanged**.

Confidence: **high** on A/B split and unlock-`0`; **none** on durations or share-rounding proof.
