# Grok original — L1 live B/U via NetNet/Pendle semantics

| Field | Value |
| --- | --- |
| Routing | `xai/grok-4.6` (not 4.7). Same session. |
| Date / access | 2026-09-27 local source. No live SY fetch. |
| Paths | `StakedNET.sol`, `Staking.sol`, **`perp/WrappedStakedNET.sol`** (not `src/WrappedStakedNET.sol`). `SYBase.sol`. PRD v0.30 §10.2; plan v0.2 §9/L1. |

**Not claimed:** executed proof, deployed NetNet SY, or that scale-alone fixes L1.

---

## Four mechanisms (do not mix)

| Model | What moves on reward | Display | Principal |
| --- | --- | --- | --- |
| **PRD B/U** | B↑, ordinary **shares unchanged** | `floor(B·s/U)` | NFT `P` is a **separate** native integer |
| **sNET gons** | `gonsPerFragment` **refreshed**; `TOTAL_GONS` fixed | `gons/gpf` (`StakedNET:58–60,83–99`) | **None** inside sNET; 1:1 NET↔sNET (`Staking:88–126`) |
| **wsNET** | **Fixed** ws; `index()` grows | `sNET = ws·index/1e18` (`Wrapped:79–86`) | Wrapper **not** live `balanceOf` B/U; donate-sNET does **not** raise unwrap |
| **Pendle SY** | **Fixed shares**; `exchangeRate` / `_redeem` | `deposit` mints shares; `redeem` burns shares (`SYBase:37–76`) | Static conversion, not a bond `P` |

wsNET is **gOHM-shaped index**, not custody B/U. Do **not** import it as the staking child. SY is a **rate provider / route**, not sNET-DETF.

---

## What NetNet **actually** promises (precision)

**Stake** (`Staking:88–103`): pull `amount` NET, send `amount` sNET (warmup 0). **Unstake** (`:119–126`): pull `amount` sNET, pay `amount` NET. **1:1 in current displayed units.** No `ceil(xU/B)` share burn.

**Rebase** (`StakedNET:83–99`, `Staking:134–151`):

```
circulating = totalSupply - balanceOf(staking)
if profit==0 || circulating==0: no supply change; profit stays queued
else:
  rebaseAmount = profit * totalSupply / circulating   // floor
  newSupply = min(totalSupply + rebaseAmount, uint128.max)
  gonsPerFragment = TOTAL_GONS / newSupply
```

**Aggregate circulating fragments grow by `profit` when `rebaseAmount` doesn’t hit MAX_SUPPLY** (`:91–93`). Individuals: `floor(gons/gpf)`; **sum of floors ≤ circulating**. Transfer uses `gons = value * gpf` (`:129`) — reverse `balanceForGons` floors (`:77–78`). Dust stays in gons.

**U=0 analog:** `circulating==0` → **do not rebase**; queued `distribute` remains (`Staking:136–143`). Next stakers are **not** gifted the queue until a rebase with circulating>0.

**wsNET wrap:** `ws = sNet * 1e18 / index` floor (`:80`). Unwrap inverse floor (`:85`). Index = `_indexGons/gpf` (`StakedNET:68–70`). **No per-holder loop.**

---

## Why L1’s `floor` mint / `ceil` burn is the wrong NetNet analog

Plan §9.1 assumes **pool-share** mint `m≈xU/B` against live B. NetNet **never** does that for stake:

- Deposit **does not** change `gpf`. Old **displayed** balances **unchanged**.
- New capital is **1:1 new fragments from inventory**, not `floor(xU/B)` of the pool.
- Therefore **`B=3,U=2` is not a NetNet stake state**: 1:1 + inventory keeps **displayed circulating ≈ NET in staking** except floor dust. The toxic ratio is **unreachable** under their issuance, not “fixed by 1e27 scale.”

Reward debit is **burn `r` displayed sNET, pay `r` NET`**, not `ceil(r·U/B)` pool shares. Vector `B10,U6,s3,P4,r1` **does not apply** to 1:1 fragment burns: displayed 5, pay 1, remaining displayed 4. **`P` is not stored in sNET**; isolation is **value−P in displayed units**, then 1:1.

PRD **allows rounding**; it does **not** require every old `floor(B·s/U)≥P` after a **proportional pool mint**. Do not import that stronger invariant. Do **not** shave NFT `P`.

---

## Candidate (reuse their issuance, keep PRD B/U *display*)

**Receipt token sDETF (9-dec) + live DETF B in the staking child.** Ordinary **gons/shares do not refresh on reward.** No holder enumeration.

### State

- `B = DETF.balanceOf(staking)` live.  
- `gons[a]`, `G_user = Σ gons` (users+NFT positions only).  
- Inventory: optional **unsold gons** (OHM) **or** mint/burn sDETF 1:1 (same arithmetic if `sDETF.totalSupply` tracks circulating).  
- NFT: **`P` native DETF** (fixed until principal debit). **Not** a sDETF amount.  
- Standing **weights** `Wf,Wc` — **not** redeemable gons (`DETFSeigniorageShareLib:18–33`).

**Display (PRD):** if `G_user>0`, `bal(a)=floor(B * gons[a] / G_user)` **only after** 1:1 is restored (below). Equivalently NetNet: `bal=gons/gpf` with `gpf` implied by supply. **Do not store an authoritative `accountedBacking`.**

### Issuance (copy Staking 1:1)

`stake(x)` actual DETF in:

```
require x>0
B += x                    // transfer
gons[to] += x * gpf       // or mint x sDETF if fragments are the share unit
// gpf UNCHANGED
```

Poststate if pre-state had `B=G_user` (1:1): `B'=B+x`, `G'=G+x`, `bal_old=floor((B+x)*g_old/(G+x))=g_old` when `g_old` in fragment units and `B=G`. **Old P (≤ old bal) preserved.** New `bal=x` (floor dust at gons granularity, 9-dec).

`unstake(x)`: require `bal>=x`; `gons -= x*gpf` (or burn x sDETF); pay **exactly x** DETF.

### Rewards / expansion `A` DETF minted into staking (no per-holder loop)

Copy `StakedNET.rebase` on **circulating sDETF** with `profit=A` **or** the split below. If `G_user==0`: **queue A** (NetNet `distribute`); **do not** assign to next depositor.

When `G_user>0`, standing allocation (`plan §9.2` numbers, **1:1 fragments** not pool mints):

```
O = G_user  // ordinary gons/fragments, including prior recipient receipts
T = floor(O*WAD/(WAD-f-c))     // if f+c<WAD and O>0; else see U0
Wf = max(Wf, floor(T*f/WAD)); Wc = max(Wc, floor(T*c/WAD))
W = O+Wf+Wc
rps = floor(A * 1e54 / W)
S = floor(O*rps/1e54); F = floor(Wf*rps/1e54); C = floor(Wc*rps/1e54)
D = A-S-F-C                 // stays in B, shared by later B/U floors; do not allocate twice
```

**Apply S via rebase** (circulating fragments += S; `gpf`↓; ordinary gons unchanged).  
**Apply F,C via 1:1 sDETF/gons credit to feeTo/creator** (inventory or mint) — **new-reward-only**, not `Δshares=Wf` against old B (plan’s O80/B800/A100: F=20 fragments, **not** 20 pool shares → 180).  
`B += A` already from the mint. **1:1:** circulating sDETF increases by `S+F+C`; `D` is B-dust (sum of floors).

**O=0, Wf/Wc>0, A>0:** seed recipient fragments `F,C` 1:1 against B (plan §9.2 U0 example 40/60 of 100). **O=0,W=0:** queue (NetNet). **O=0,Bpre>0 unassigned:** not first-depositor grant.

### NFT principal / reward (displayed 1:1)

```
value = bal(position)                    // floor
require value >= P
reward = value - P
claimReward r <= reward: unstake r 1:1; P unchanged
debit principal q <= P: unstake q 1:1; P -= q
```

Poststate `value' >= P'` because both sides drop by q or r in **the same displayed unit**. **This is NetNet unstake, not ceil-share burn.** Rebond 40 of 100: `P=60`, gons reduced by 40·gpf.

### U0 / dust / full exit

- First stake `B=0,G=0`: `gons=x`, fragments x (wire-like).  
- Full exit: burn all position gons; **sub-native gons dust of that account only**.  
- `MAX_SUPPLY` cap on sNET rebase (`StakedNET:28,95`) — if hit, circulating **does not** grow by full profit; **say so**, don’t hide.

---

## Equivalence to PRD wording

`fundedBalance=floor(B·internalShares/U)` holds when **`internalShares=gons` and `U=G_user` and 1:1 `B≈circulating fragments`**. Reward **does not** write per-holder shares (rebase/`gpf` or B↑ with gons fixed). Recipient **extra** is **new 1:1 shares**, changing U, as PRD already allows.

**Do not** implement deposit as `floor(xU/B)` or reward as `ceil(rU/B)`. That is the failed L1 draft, **not** NetNet.

wsNET: optional **external** wrap of sNET-DETF later; **not** the custody formula (`wrap` uses `index()`, not `balanceOf(wrapper)`).

Pendle SY: keep **provider** `previewRedeem`/`exchangeRate` off this ledger.

**No public configured NetNet SY** read this round (NN-01).

---

## Limits

Local 2026-09-27. Rebase exactness is **aggregate circulating**, not each `floor`. Queued U0 is **their** orphan answer. G0/G1 unchanged. L1 **draft algorithms** refuted; **rebasing is solved in their code** by **1:1 fragments + gons rebase**, which **reaches** PRD B/U display without a per-holder index loop and without shaving `P`.
