# Grok L1 cross-review

| Field | Value |
| --- | --- |
| Routing | `xai/grok-4.6` (not provider-verified). Own original **untouched**. Full Astra, MiniMax, Kimi. No peer cross-reviews. |
| Dates | This file 2026-09-28 session. Own original header **2026-09-27**. Astra access **2026-09-28**. MiniMax/Kimi **2026-09-27**. **Not rewritten.** |

**Goal:** reusable NetNet/Pendle **pattern**, not “every integer state impossible.”

---

## Algebra (Kimi identity fails)

`T=10`, `B=3`, `g=3`:

```
floor(g / floor(T/B)) = floor(3/3) = 1
floor(B*g/T)          = floor(9/10) = 0
```

**Not equal.** `gonsPerFragment = floor(T/F)` (`StakedNET:97`) is **not** `floor(B*u/U)`. Astra: substituting `K` for live B/U is **not** the selected formula.

`TOTAL_GONS` **includes preminted inventory** (`:45–47` all gons to staking). PRD `U` is **circulating ownership**. Using `T` as `U` mixes inventory gons into the denominator while `B` is DETF in the child. **Different object.**

**Write `K=T/newSupply` on rebase** (`:97`) is an **explicit global divisor refresh**. PRD §10.2: mint into custody **raises B**, ordinary **shares unchanged**, **no** distribution-index refresh. Economically similar **only if** 1:1 `B ≈ circulating fragments` is **maintained by issuance**, not by calling the two floors the same.

---

## What the sources actually promise

| Source | Promise | Units |
| --- | --- | --- |
| `Staking:88–126` | stake/unstake **nominal x NET ↔ x sNET** after epoch settle | 9-dec **1:1 displayed** |
| `StakedNET:91–97` | `r=floor(profit*supply/circulating)`; cap `uint128.max`; **then write K** | aggregate circulating **≈ +profit** except floors/cap |
| Transfer `:129` | move **exactly `x*K` gons** so `floor((g±xK)/K)=floor(g/K)±x` **at fixed K** | exact **at that K** |
| wsNET `:80–85` | `floor(x·1e18/I)` / `floor(m·I/1e18)` | **not** live `balanceOf(wrapper)` |
| SYBase | mint/burn **returned/supplied shares**; min in/out | adapter, **not** NFT `P` |

**wsNET roundtrip:** Astra: `I=1.5e9`, wrap `x=1e9` → unwrap **`999_999_999`**. That is **one whole native 9-dec unit**, not “<1 ws-unit” (Kimi **wrong**). MiniMax “index wrap accepts floor” is true; **loss can be 1 raw sNET**.

**Reachability:** `B=3,U=2` is **unreachable under NetNet 1:1 stake** (gpf unchanged, old display unchanged). It **is** reachable under **`m=floor(xU/B)` pool mint**. Do **not** say every B/U state is impossible. Do **not** say 1e27 scale removes native-unit nondivisibility when using pool mint (plan §9.1 still holds **for that mint**).

---

## Rejected proposals

**MiniMax 3.4** — pay `rewards` DETF, **leave `u` unchanged**: `B↓`, others `floor((B−r)·u/U)` drop. **Drains co-holders.** Separate `n[h]` **does not** restore their backing. **Not** NetNet unstake (which burns displayed units 1:1).

**MiniMax 3.1–3.2** — `floor(xU/B)` mint + `ceil(xU/B)` burn is the **L1 draft**, not `Staking` 1:1. wsNET is **not** structural proof for that debit.

**Kimi §2–3** — treat `U=TOTAL_GONS`, premint inventory, `uint128` cap, `INITIAL_FRAGMENTS` wire: **imports inventory/cap/index** PRD did not select.  
**Rebase full `Δ` then `fΔ` extra gons:** sNET rebase already gives **all circulating** the **full** profit. Extra `fΔ` **double-pays** recipients and **does not** remove the fee slice from ordinary. Split must be: **rebase profit = S only**, then **1:1 F,C** (plan §9.2 `mF=FU/(B+S)`), **not** `f·A` against old B (O80/B800/A100 → F=20 **reward**, not 180 ownership).

**Grok original** over-claimed 1:1 makes **all** L1 vectors unreachable; that is true **only for 1:1 fragment issuance**, not for pool-share mint. wsNET was correctly **not** custody B/U.

---

## Astra reward budget (keep, don’t oversell)

`p=ceil(P·U/B)` shares reserved; budget `u−p`; pay `x=floor(B·(u−p)/U)` with `d=ceil(xU/B)` or **x=0 keep shares**.

Protects `value'≥P` without a holder loop. **May defer** a displayed `floor(Bu/U)−P = 1` (Astra Q=1e27 sequence).

PRD §10.2 **allows native rounding / position-local dust**. It does **not** require paying every independent `rewardsDue` wei. `DETFFundedStakingMath:110–116` **reverts** `value<P`; it does **not** authorize writing `P` down. **Do not invent** “last unit waived” or “must eventually pay.” **Fact:** unpaid unit stays in the position’s share budget until a later **safe** claim; that is **rounding**, not a new cap.

---

## Plan-compatible algorithm (no new framework)

Keep PRD: live `B=DETF.balanceOf(staking)`; ordinary **shares/gons unchanged** on `B+=A`; **no** stored `accountedBacking`; **no** per-holder loop.

1. **Principal admission (pick one, both PRD-rounding-legal):**  
   - **NetNet 1:1:** at unchanged rate, credit **exactly `x` displayed** (gons `x·K` or mint `x` sDETF) while `B+=x`. Old display **unchanged**. Requires maintaining **1:1 B↔circulating** like `Staking` (inventory or mint/burn). **Does not** require copying 5B premint or `uint128` cap.  
   - **Share mint:** `m=floor(xU/B)`, revert `m=0`. Newcomer may display `x−1`. **Do not** also require old `P=B` conservation (that’s the nondivisible case).

2. **Rewards `A`:** `B+=A`; ordinary `u` **unchanged** (live B — **this is the selected no-index semantics**). Recipients: allocate `S,F,C,D` with `1e54` rps; **`mF,mC` from new F,C only**; never mint `Wf` onto old B. `D` stays in B, **not** paid twice. `G_user==0`: **queue** (`Staking:136–143`), no first-depositor grant.

3. **Debit:** **never** MiniMax 3.4. Reward: **Astra budget**. Principal `q`: burn `q` **displayed 1:1** if using (1), else share-budget analog; `P-=q` only on principal path.

4. **wsNET / SY:** optional **static face** later; **not** the child formula.

**Owner only if rights truly diverge:** whether a **budgeted-zero** last reward unit is **dust** (PRD rounding) or must remain **exactly claimable**. Everything else is issuance choice **inside** §10.2, not a new product.

G0/G1 unchanged. No configured NetNet SY verified (Astra 404; Kimi API pin **unverified here**).
