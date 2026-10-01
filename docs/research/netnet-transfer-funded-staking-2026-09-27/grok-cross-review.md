# Grok transfer-funded staking cross-review

| Field | Value |
| --- | --- |
| Routing | `xai/grok-4.6` (not provider-verified). Own original untouched. Full Astra, MiniMax, Kimi. No peer cross-reviews. |
| Date | 2026-09-28 |

---

## Verdict (user-facing)

**Switch the family to IndexedEx funded-gons** (`StakedDETFTarget` / `DETFFundedStakingRepo` / `DETFFundedStakingMath`). **Do not drop in stock sNET.**

**User preference:** one ordinary **NET-DETF** `transfer`/`_mint` **to the staking child** completes **reward distribution in that tx**. **No extra user call.** That is **not** true today and **not** “already works.”

| Claim | Fact |
| --- | --- |
| MiniMax: `synchronized` on sDETF `transfer` = parent backing transfer distributes | **False.** `StakedDETFTarget:113–125,35–38,241–246` syncs **receipt-token** moves via `detf.synchronizeRewards()`. **NET-DETF** `ERC20Repo._transfer:258–268` / `_mint` **do not notify**. |
| MiniMax: raw sNET `transfer` rebases | **False.** `StakedNET:127–136` moves `x*K` gons at **current** K. Rebase is **`Staking.rebase` / `_rebaseIfDue`** (`:83–99`, `Staking:134–150`). |
| MiniMax: `exchangeIn(NET-DETF)` is the asked transfer | Different surface: **pull + `_creditPrincipal`**, not “send DETF to staking.” |
| Kimi `noteFunding` = `held − accountedBacking` | **Unsafe ingest.** Can swallow **old surplus** or **in-flight principal**. Use **this-operation delta** from parent notify only. |

**Zero internal updates:** impossible on vanilla ERC-20. **Zero extra user tx:** possible if **our** DETF notifies.

---

## Recommended design (Astra core + corrections)

**Reuse funded-gons math (L1 principal).** At fixed K: credit/debit `x*K` gons (`Math:46–48`, `Repo:93–124`). `floor((g±xK)/K)=floor(g/K)±x`. Full-account exit vs **position** dust (`:109–139`) stay distinct. **Do not** copy `_claim` linear vest (`:96–116`). **No** NetNet premint / `MAX_SUPPLY` / 8h clock.

**New adapter (does not exist unchanged):** family DETF **transfer / transferFrom / `ERC20Repo._mint`** all go through **one** funding-aware move. Public ERC20Target-only hook **misses** `_mintDetf` (`UniswapV4DetfCommon:138–140`).

**Principal (before any movement):** one-shot context `{kind, nonce, payer, operator, recipient, amount}` **then** `transferFrom`/`_mint`. Child **acks receipt, does not `_distribute`**. Initiator `_creditPrincipal` **once**. `from==0` ≠ reward. Mismatch reverts. **Never** mint principal from leftover `held−accounted`.

**Reward (no principal/legacy-pull context):** parent notifies **exact moved amount** after balances update. Child `_distribute` **that amount**, `_topUpWeights`. **Sender is not staked.** Zero amount / staking→self: **no credit**. Failed accounting **reverts the DETF transfer**.

This **is** the user’s ordinary transfer-to-staking as **donation-to-existing-distribution**, not a Grok-imposed ban on wallet transfers. **Stake credit** remains the authenticated principal path only.

**Legacy `fundRewards`:** still **pulls** (`Target:170–176,228–233`). Classify as **legacy pull context**: pull **then** distribute **once**. **Never** notify + pull the same units (double-pull / double-distribute). Custom family should **mint/transfer to staking + notify**, replacing `_fundStakingRewards` mint-to-self/approve/pull (`Common:373–379`).

**Guards:** notify **must not** `_synchronize` (`Target:241–246` already parent-calls child). `synchronizing`: only authenticated **reward** callback. Locked principal pull: only matching **ack**. Consume context before further externals.

**Even gons-only `_distribute` (`Repo:185–202`) is not effect-free:** `ownerOf` fee/creator NFTs (`Target:177–178`), oracle `seigniorageSplitOfVault` (`:236–238`), `_requireBacking` `balanceOf`, possible parent reentry. Treat as **full distribution critical section**, not “safe because no DETF moves.”

**Weights:** Q=0 + surviving Wf/Wc → F/C receipts still (`allocate` with ordinary gons 0). **All weights 0** → `MissingRewardWeight` (`Math:85–86`) — keep **reject**, don’t gift next depositor. Unconfigured/unwired child: **don’t silently skip** notify.

---

## PRD / plan amendment (exact scope)

**Replace** §10.2 / plan §9 **literal live B/U, no divisor write** with: funded gons, stored K, `accountedBacking`, allocation/staking dust; ordinary gons rebase on **authenticated reward receipts**; fee/creator **1:1 gons from new F/C only**.

**User-facing rewards:** ordinary NET-DETF transfer or mint **to staking** (parent-notified) distributes in-tx; **not** a second user `fundRewards`.

**Unchanged:** 9-dec 1:1 stake/unstake; standing weights nonredeemable; custom locks/cliffs; expansion clock; no premint/cap/8h.

**L1:** closed **by this representation**, not by proving B/U ≡ gons.

---

## Narrow residual (not a questionnaire)

Mandatory expansion already lives in a DETF tx. **Ad-hoc gifts** under this design **do** distribute same-tx (user preference). Only if product later wants gifts **pending** until next stake: that is **lazy (b)**, not the selected default.

G0/G1 still external. Adapter **unwritten/untested**.
