# Grok plan-completion cross-review

| Field | Value |
| --- | --- |
| Routing | `xai/grok-4.6` (not 4.7). Moderator typo-denial noted; **this** original session resumed. No identity bypass. |
| Inputs | Own original untouched. Full Astra, MiniMax, Kimi. **No** peer cross-reviews. |
| Date | 2026-09-27 |

**Continuity:** In-place G2–G5 **content**, not a new annex. G0/G1 still **external UNPASSED**. **Not** executed proof.

---

## Counterexamples (must go in the plan)

### 1) `B=3,U=2`, deposit `1`

Exact `m=xU/B=2/3` not integer.  
`m=0` → newcomer 0.  
`m≥1` → old `floor(4·2/3)=2`. If old **P=3**, **locked principal lost**.

**Allowed:** revert `ZeroShares` / refuse deposit (dust).  
**Forbidden:** `ceil` mint that drops old `P`.

Astra’s equality necessity is **accepted**. Grok original’s `floor`+revert is OK **only as refuse**, not as “exact credit of 1.” MiniMax/Kimi `floor(xU/B)` **without** this vector **understate** the obstruction.

### 2) `B=10,U=6`, `s=3`, `P=4`, claim reward `1`

`value=floor(10·3/6)=5`, implied reward 1.

- Pay 1, **don’t** burn shares → others `floor(9·3/6)=4` (were 5): **socialized loss**.  
- Burn 1 share, `U'=5`, this `floor(9·2/5)=3` **< P=4**: **principal lost**.

**No integer share burn preserves both `value'≥P` and other holders.**  
**Correct:** **revert the claim** (fail closed). Do **not** shave `P`. Native **display** rounding ≠ consuming locked principal.

Grok original’s `sBurn`/`ceil` withdraw **fails this vector** — **withdrawn**.

---

## Standing weights ≠ receipt shares

Reuse `DETFSeigniorageShareLib._topUpDeltas` (`:18–33`): `T=floor(O·WAD/(WAD−f−c))`; top up toward `floor(T·f/WAD)`, **never cut** on exit. `O` = ordinary **share weight**. Mint **internal shares only**, **no** DETF to `feeTo`.

**Reject MiniMax** `internalShares += floor((B+M)·w/WAD)` — treats shares as native and loads **pre-existing B** (including NFT `P`) into fee ownership.

**Reject** assigning expansion `Δ` so fee/creator **underfund** any `P`. Sequence: mint `Δ` into B first; then share top-up. If a claim would leave `value<P`, revert.

Kimi `O=0` → no new shares, `Δ` via B on remaining `U`: OK if `U>0` recipients; if `U=0,B>0` still **OrphanBacking**, not next depositor.

---

## Pretransfer

Anonymous `balance−booked` **does not identify payer** (Astra).  
**Do not** subtract a guessed force-claim `Δ` from surplus (Grok/Kimi `U_pre=B−R−c`) — that can **erase legitimate same-tx input**.

**Order:** authenticated **receipt** (pull delta / Pendle **return value** / known YT settle) → credit only that; leftover surplus = donation, **not** user. Force-claim **before** measuring user funding; don’t sync away a prior legitimate push. Bare `pretransferred=true` on arbitrary surplus = **mismatch**, not a new flag.

---

## Inner PLP/YT

**First:** `S0=√(L0·Y0)−1000`; revert if `≤1000`. **Reject MiniMax** `min(x·S/R)` at `S=0`.  
**Later:** `m=min(floor(xS/L),floor(yS/Y))`. Accepted: Astra `ceil(m·L/S)` then **this-call residual refund/SY-exit**; **not** V2 donate; **not** MiniMax “leave in book as not-LP.”  
**Locked 1000** is **never circulating**. Last user exit **must not** sweep it (reject Kimi “pay entire remaining L,Y” if that includes the lock).

Keep-YT residuals only as **quote/execution drift** under **min-out**; else **revert whole entry**.

---

## Exact-out

Closed form **per sourced layer**: Weighted `computeInGivenExactOut`+`grossUpExactOut`; BasePoolMath `:277–342`; V2 `getAmountIn`; tax `floor((y-1)·D/(D−t))+1` (Astra, `NET.sol`). Burn `q=ceil(qQuote·WAD/(WAD+p))` + **forward check**.

**Sampled `previewRedeem` +1** (Kimi) **≠** general inverse.  
**MiniMax “iterate redeem, not search”** still **not** a proof.  
**No** new Pendle SY (reject MiniMax B.4).  
**No** binary search / `InvalidRoute` if a stage has **only** exact-in preview (shared law). Composed ERC-4626 withdraw is **finished only** for G1-verified **linear/closed** stages.

---

## TWAP 3600

Price×time, same-**integer-second** coalesce, extend **predecessor** at `t−3600`. Astra: **3601 ring iff one record per distinct second** (3601 timestamps span ≥3600s) + quiet-period **extension**, not fake ticks. **Without coalescing/predecessor, do not freeze 3601.** Grok sentinel ≡ same proof. MiniMax unspecified cadence **insufficient**. Truncated-tick lib = structure only.

---

## G5 terminal

**Reject:** MiniMax/Kimi `pendingFor==0` / “all gifts redeemed” as **completion** (unauthorized **all-gift** gate). Intended note `claimed==payout` only. Intermediate **no** reset; partial reinvest **no** full-collection.

**Reject:** holder `owner` → wallet.  
**Reject:** feeTo forfeiture of late native.  
**Reject:** **never-burn** as the only design **and** **burn+strand** as silent forfeiture (Kimi).

**In-place:** `retire` may **mark DORMANT** without burning NFT **or** burn NFT **only** when intended drained **and** no **recognized** same-tokenId obligation; **unsolicited future notes are not a wait-for-all-gifts rule**. H01 **late-principal unlock** (old E+1 vs new wait) is **still unspecified** (Astra) — **do not invent**. Report that **one** residual; don’t pick a lock.

---

## Grok original — corrections

Withdrawn: ceil/floor share burns as **exact P**; `pendingFor==0` retire; protocolΔ subtraction from pretransfer. Keep: OrphanBacking revert; no full-collection on reinvest; no solver; full-book bootstrap; weights/fees/locks.

---

## Paste into plan (status)

| Gate | In-place now | Residual (not a questionnaire) |
| --- | --- | --- |
| G2 B/U | Display `floor(Bu/U)`; refuse non-integral exact `m`; **revert** claims that drop `P` or others | Integer exact-all-P **not** generally possible |
| G2 standing | `_topUpDeltas` on **O**, shares not DETF | — |
| G2 receipts | Authenticated funding only | Bare pretransfer mismatch |
| G2 inner | Geometric seed; min-ratio; refund residual; **keep min lock** | — |
| G3 | Layer closed-forms + forward check | Nonlinear SY/zap inverse **G1** |
| G4 | Full book; `C=1e18`/`open=1000e18`; 3600 predecessor | BondTerms vs next-epoch **if** live min too long |
| G5 | Intended complete; DORMANT/burn without owner-transfer | Late-**principal release** after complete |

No new SY, fees, or solver. G0/G1 unpassed.
