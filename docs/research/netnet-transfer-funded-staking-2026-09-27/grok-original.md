# Grok original — transfer-funded gons vs stock sNET

| Field | Value |
| --- | --- |
| Routing | `xai/grok-4.6` (not provider-verified) |
| Date | 2026-09-28 |
| Ask | Switch requirements to sNET-like gons; prefer **user** just transfers NET-DETF into sNET-DETF |

---

## Direct answer

**You cannot make a plain ERC-20 credit rebase anyone without some internal update.** Vanilla `transfer`/`_mint` (`ERC20Repo._transfer:258–268`) only moves balances. **No receiver hook.**

What you *can* do: **the user never calls a staking function.** Our **NET-DETF** (we control it) intercepts mint/transfer **to the staking child** and notifies it. That is still an **internal** call. It is **not** “zero functions.”

**Do not copy stock sNET** (`StakedNET.sol` + `Staking.sol`): `rebase` is **explicit** (`:83–99`, only `staking`); transferring NET into Staking **does not** grow sNET; `stake` is a **function** (`Staking:88–103`). Also imports **premint inventory, `uint128` cap, 8h epoch** — out of scope.

**Recommend (2): reuse existing funded-gons `StakedDETFTarget` / `DETFFundedStakingRepo` / `DETFFundedStakingMath`, with a DETF-side notify so rewards are `mint/transfer → staking` without `fundRewards` pull.** Not exists-unchanged: DETF has **no** transfer hook today; `_fundStakingRewards` (`UniswapV4DetfCommon:373–379`) **mints to DETF then `fundRewards` pulls**.

---

## Three routes

| | User extra tx? | Internal update? | Source |
| --- | --- | --- | --- |
| **(1) Stock sNET** | Yes: `stake`/`rebase` | Yes: write `gonsPerFragment` | `Staking:88–150`, `StakedNET:83–99` |
| **(2) Funded gons + DETF notify** | **No** on expansion/reward if DETF does it | **Yes**: `_distribute` | `StakedDETFTarget:169–184`, `Repo:185–202` |
| **(3) Lazy views** | No | Deferred until next mutating call | `previewDistributions:60–84` is **view-only**; public `balanceOf` uses `stakingState()` **not** pending (`IStakedDETF:36–38`) |

**(3)** does **not** pay unstake until sync. `synchronized` (`Target:35–38,241–246`) already calls `detf.synchronizeRewards()` **before** sDETF transfer/stake. Lazy **display** without settling **held vs accounted** breaks `_requireBacking` (`Repo:212–217`: `held >= accountedBacking`; **surplus is not rewards**).

---

## Why “just transfer” fails today

`fundRewards` (`Target:170–176`): **only DETF**, then **`_pullDetf` = `transferFrom`** (`:228–233`).  
If DETF **already transferred**, a following `fundRewards(amount)` **pulls again** (double-pull / revert). **Cannot** “transfer then call.”  
Unsolicited DETF sitting on staking: **ignored** as funding (`Repo:212–217`).

wsNET (`perp/WrappedStakedNET:48–86`) wrap/unwrap is **another user function** + **index**, not live notify.

---

## Recommended mechanics (2)

**Keep** IndexedEx funded gons (solves L1 **at fixed K**):

- Principal: `_toGons(x,K)=x*K` (`Math:46–48`); `_debit` full exit burns **all account gons** (`Repo:116–118`); display `gons/K` (`:81–83`). Same **exact-native at current K** as `StakedNET:129`. `_rebase` `ceilDiv` (`Math:62–74`); **no** `MAX_SUPPLY`; **zero gons → queue dust** (`:67–69`). Standing: `_allocate` `1e54` then 1:1 fee/creator gons (`Repo:190–201`); `_topUpDeltas` (`:165–174`). **Weights not redeemable gons.**
- **Do not** import NetNet premint/`INITIAL_FRAGMENTS`/8h/`MAX_SUPPLY`.
- Custom **principal cliff** still **not** `_claim` linear vest (`Math:96–116`) — keep NFT `P` + `rewardsDue=value−P`.

**Change boundary (adapter on OUR DETF, not stock ERC20):**

1. **Reward context (DETF-only):** `ERC20Repo._mint` / `_transfer` **to staking** while `rewardFunding==true` → staking `onFundedReward(delta)` that **does not pull**; runs `_distribute` on **measured** `balanceOf(staking)−accountedBacking` (cap to intended amount). Expansion: mint **directly to staking** (drop mint-to-self + approve + pull).
2. **Principal context:** **before** `transferFrom`/`_mint` of user principal, set `principalFunding(recipient,x)`; then pull/mint; staking `_creditPrincipal` **only** that receipt. **Anonymous** `transfer(staking,x)` stays **unsolicited** (not auto-stake, not auto-reward).
3. Cover **all** DETF credit paths: public `transfer`/`transferFrom` **and** `ERC20Repo._mint` (expansion, bond G/B/R).
4. **Reentrancy:** `synchronizing` already forbids nested `_synchronize` (`Target:243`). Notify **must not** call `fundRewards` (pull) and **must not** re-enter DETF mint. Use the same flag or `nonReentrant` on staking; notify from DETF **after** balances written.
5. **Allowances:** reward path **no** `forceApprove`; principal path keeps false-flag pull (`Target:201–209` — public `pretransferred=true` **rejected**).

**L1:** 1:1 gons at **unchanged K** for principal + rebase **ordinary gons only** then extra F/C gons = prior exact-native story. **Does not** make `floor(B*u/U)` pool-mint L1 vanish; we **stop using** that mint. User **permits** this model change.

---

## User vs internal

| Want | Possible? |
| --- | --- |
| User never calls `fundRewards` / `rebase` / `stake` for **expansion** | **Yes** (DETF notify) |
| Wallet `DETF.transfer(staking, x)` **alone** distributes rewards | **No** without classifying every inbound as reward (changes rights / donations) |
| Zero internal function/state | **No** |

**Narrow ask only if needed:** should **unsolicited** DETF to staking auto-`_distribute`? Default **no** (matches `_requireBacking` surplus rule).

---

## Pros / cons

**(2) funded gons + notify:** uses **existing** child; 1:1 principal; standing weights already; no 8h/premint; user-tx-free **rewards**. Cost: **DETF adapter** (not unchanged ERC20Repo); reentrancy spec; principal still an **authenticated** route.

**(1) stock sNET:** extra user/`rebase` calls; wrong clock/inventory.

**(3) lazy-only:** views lie until sync; unstake can fail backing.

**Pick (2).** `StakedDETFTarget`/`Repo`/`Math` **stay**; replace `_fundStakingRewards` pull with mint-to-staking + no-pull `_distribute`. **Not** drop-in sNET.
