# MiniMax M3 — Transfer-Funded Staking Cross-Review (Bounded Round)

> Cross-review of three peer originals. Read together; no peer cross-review consulted. My `minimax-original.md` is baseline. Routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. The decisive correction to my original — plain DETF transfer does NOT currently notify sDETF

My original §6 said: "the rebasing happens automatically on every transfer via the `synchronized` modifier." **This was wrong.** The `synchronized` modifier is on `StakedDETFTarget.sol:35` and fires on `transfer/transferFrom/exchangeIn/exchangeOut` of **sDETF** (the child). It calls `IDETFFundedRewards(detf).synchronizeRewards()` (`:241–247`).

**A plain `NET-DETF.transfer(staking, amount)` does NOT invoke the modifier.** NET-DETF is the parent; `synchronized` only fires when the user calls sDETF operations. The current `_fundStakingRewards` (`UniswapV4DetfCommon.sol:373–379`) mints to DETF, approves staking, then **pulls** via `fundRewards(amount)`. It is **pull-based**, not **notification-based**.

Consequence: ad-hoc direct transfers (gifts) into the staking child sit as `accountedBacking`-ungrown custody until the next touching operation. **This matches the user's concern exactly.** `accountedBacking` only moves when `_distribute` runs (`DETFFundedStakingRepo.sol:185–202`).

**All three peers agree on this.** Grok: "If DETF already transferred, a following `fundRewards(amount)` pulls again (double-pull/revert). Cannot transfer then call." Astra: the existing component's `fundRewards` "pulls the amount through `_pullDetf`" — cannot be called after a plain transfer. Kimi: "Existing `fundRewards` is DETF-only and pulls; cannot be called after a plain transfer."

**My original was also wrong** on "no hidden internal function call." A DETF-side notification hook IS needed; it is internal (our token, our code), but it is a real call. The user just doesn't have to make it.

---

## 2. Correct recommendation — funded-gons + DETF-side notify (Option a, all three peers agree)

Astra, Grok, Kimi converge on the same recommendation: **keep the IndexedEx funded-gons component (which already solves L1 exactly) and add a new DETF-side notification hook.** This is a new adapter, **not** unchanged code. The arithmetic (1:1 gons at fixed K, exact-multiply `_toGons`/`_toAmount` in `DETFFundedStakingMath.sol:46–54`, principal stored separately as `n[h]`, standing-recipient top-up only) is preserved; only the **distribution trigger** changes.

The trigger is a new entry-point `noteFunding(amount)` on the child that runs `_distribute(amount)` once with measured delta, no pull. Reentrancy guard reuses the existing `synchronizing` flag pattern. Coverage must include all three DETF credit paths: public `transfer/transferFrom` AND direct `ERC20Repo._mint` (used by `_mintDetf` for expansion and bond G/B/R).

---

## 3. Concrete protocol (verified mechanics)

### A. Cover every credit path
`ERC20Repo._transfer:258–268` and `ERC20Repo._mint:329–346` both write balances/supply directly with **no receiver notification**. Custom NET-DETF token's transfer/transferFrom AND `_mint` paths must each detect `recipient == stakingChild` and call `noteFunding(delta)` once with measured `delta = balanceOf(stakingChild) − accountedBacking`. Outgoing staking-to-non-staking transfers (`unstake`) already debit `accountedBacking` via `_debitPrincipal` (`DETFFundedStakingRepo.sol:121`); the outbound NET-DETF transfer is a custody move, **not** funding.

### B. Principal must be marked BEFORE movement
Astra: "synchronize due expansion first, acquire the staking-operation guard, establish one-shot context bound to kind, nonce, payer/source, authorized operator, recipient/position, exact amount before `transferFrom`. Direct principal minting needs the equivalent authenticated context before `_mint`. `from==0` alone is not reward classification." For matching principal context, the child records/acknowledges receipt without distributing. Initiating operation verifies measured receipt and credits principal exactly once. **Never mint principal from an old balance surplus.**

### C. Unsolicited incoming transfers are rewards (not auto-stake)
Plain positive incoming NET-DETF with **no principal/legacy-pull context** is a donation to existing distribution: parent-only notification verifies exact movement, credits accountedBacking once, distributes, tops up future weights. **Old unexplained surplus is not swept into the current receipt.** Zero transfers and staking-to-itself transfers create no reward credit. **Failed accounting reverts the whole transfer/mint.**

### D. Reentrancy and guard handling
Existing `synchronizing` flag pattern (`StakedDETFTarget.sol:243`) prevents nested `_synchronize`. **The notification hook must NOT call `fundRewards` (pull) and must NOT re-enter DETF mint.** `_distribute` is gons-only (no outbound DETF call, `DETFFundedStakingRepo.sol:185–202`); the hook cannot re-enter a DETF money path through distribution itself. Use the same flag or `nonReentrant` on staking; notify from DETF **after** balances written. **Multiple unsafe effects remain even with gons-only distribution:** oracle/NFT external reads and parent-loop reentrancy must be guarded explicitly. **Fee-recipient/oracle reads, backing reads, and read-only reentrancy must not expose spendable intermediate ledgers.**

### E. Existing fundRewards pulls — classify, do not double-distribute
Grok: existing `fundRewards` pulls via `_pullDetf` (`Target:228–233`). **Double-pull / double-distribute is a real risk.** When migrating, classify legacy reward-pull paths separately. Notify hook on inbound **does not** also call `fundRewards`; only one of them distributes per funding event. **The principal funding path keeps false-flag pull** (`Target:201–209`: public `pretransferred=true` reverts; EOA rejects).

---

## 4. L1 obstruction dissolves with funded-gons (all three peers agree, my original partially wrong)

Astra's `DETFFundedStakingMath.sol:10–11,45–74`: `K0=1e36`, `balance_i=floor(g_i/K)`, `L=floor(Q/K)`. Principal credit issues `xK` gons (exact multiply); principal debit takes `xK` gons back (exact). With `K` unchanged during principal movement:

```
floor((g_i + xK) / K) = floor(g_i/K) + x     (exact)
floor((g_i - xK) / K) = floor(g_i/K) - x     (exact)
```

**Reward claim `balance_i - P` leaves precisely `P` displayed units** without shaving principal or deferring a displayed unit. **The B=3/U=2/x=1 and B=10/U=6/s=3/P=4/reward=1 counterexamples dissolve** because principal is gons-denominated, not pool-mint. Kimi: "User permits this model change." Grok: "stop using `floor(B*u/U)` pool mint."

**My original §3 was wrong** in saying "live B/U is the user's selected model." The user has now permitted the model change. **The funded-gons model is the L1 solution.**

---

## 5. Critical corrections to my original

| My original claim | Corrected |
| --- | --- |
| "rebasing happens automatically on every transfer via the `synchronized` modifier" | **Wrong.** `synchronized` fires on sDETF operations only. Plain DETF transfer to sDETF does NOT currently notify. |
| "no hidden internal function call" | **Wrong.** An internal call IS needed: DETF-side hook on transfer/transferFrom/_mint. User just doesn't make it. |
| "recommended Option 1 unchanged" | **Wrong as stated.** The funded-gons component exists, but the DETF-side notification hook is a **new adapter**, not unchanged code. |
| "user permits model change → funded gons instead of literal live B/U" (in user's prompt) | **Confirmed by all three peers.** User permits the model change. |

---

## 6. Reclassification of existing `fundRewards`

The existing `fundRewards(amount)` (caller = DETF, pulls) is **pull-based**, not notification-based. It is used by the existing maintenance flow `UniswapV4DetfCommon.sol:373–379`. **Classify this as legacy reward-pull** and gate it carefully:

- When the DETF-side notification hook fires (new adapter), **do not also call `fundRewards`** for the same funding event.
- The hook and `fundRewards` are **mutually exclusive per funding event** — exactly one distribution per `delta`.
- If the legacy `fundRewards` is retained for the existing maintenance flow, give its pull a distinct funding context so it does not interact with the hook path.

---

## 7. Reentrancy and synchronization

Astra/Grok/Kimi converge: the existing `synchronizing` flag pattern (`StakedDETFTarget.sol:243`) prevents nested `_synchronize`. The new notification hook must NOT call `_synchronize` and must NOT re-enter DETF mint. `_distribute` is gons-only (no outbound DETF call, `DETFFundedStakingRepo.sol:185–202`).

**Multiple unsafe effects remain even with gons-only distribution:**
- Oracle reads (`s_.feeOracle.seigniorageSplitOfVault(...)` in `_topUpWeights`) — read-only but reentrancy must be blocked.
- NFT external reads (`ownerOf(DETF_FEE_TO_BOND_NFT_ID)`, `ownerOf(DETF_CREATOR_BOND_NFT_ID)` in `fundRewards`/`_distribute`) — read-only but must not permit spendable intermediate state.
- Backing reads (`s_.detf.balanceOf(address(this))` in `_requireBacking` and `_pullDetf`) — read-only.

**All these external reads must be guarded.** Read-only reentrancy is not safe-by-default; the modifier pattern (`synchronized` / `synchronizing`) must apply.

---

## 8. Zero ordinary vs zero total weights

Astra: Q0 with surviving standing weights works — ordinary allocation0, F/C still receive funded receipts. If **all** reward weights are zero, the existing math raises `MissingRewardWeight` (`DETFFundedStakingMath.sol:84`). **Preserve that explicit preactivation/weightless rejection rather than inventing a recipient or silently gifting queued funds to the next depositor.** This is not a blanket zero-circulation rejection. Zero-amount token transfers remain harmless no-ops.

---

## 9. What must NOT be in scope

- No NetNet pre-mint inventory, MAX_SUPPLY cap, 8-hour clock, or warmup import.
- No linear vesting change (custom NFT retains selected cliffs/epochs; source `_claim` linear vest at `DETFFundedStakingMath.sol:96–116` is not the custom model).
- No fee/lock changes.
- No per-holder loop.

---

## 10. Exact PRD/plan amendment scope

**Change**: PRD §10.2 wording "live B / no divisor refresh" superseded by funded-gons model (single shared divisor refreshed at reward application). New `noteFunding()` delta-based entry on the child. Custom DETF token's transfer/mint paths gain internal recipient check + call. L1 closed by exact-multiply gon accounting.

**Unchanged**: nine-decimal receipt; 1:1 native stake/unstake; funded backing and `_requireBacking`; standing fee/creator weights and their top-up algebra; early reward claims; pre-maturity rebond (re-expressed as exact gon debit: burn `StakingMath._toGons(q, gonsPerUnit)`); no NetNet inventory/cap/8h clock; no fee/lock changes; no per-holder loop.

**Reentrancy/guards**: hook executes under existing `synchronizing`-style recursion guard; `_distribute` is gons-only; hook cannot re-enter DETF mint; multiple unsafe effects require guards on oracle reads, NFT reads, backing reads, and read-only reentrancy on `_topUpWeights`/`_distribute`.

---

## 11. Confidence and evidence limits

- **High** all cited source lines (`StakedDETFTarget.sol:35, 113, 119, 147, 160, 170–247`, `DETFFundedStakingRepo.sol:93–224`, `DETFFundedStakingMath.sol:46–124`, `DETFSeigniorageShareLib.sol:18–33`, `RebasingClaimTokenDFPkg.sol`, `StakedNET.sol:127–137`, `Staking.sol:130–151`, `WrappedStakedNET.sol:48–86`) verified by direct read or prior council round.
- **High** plain DETF transfer does NOT currently notify sDETF — `synchronized` modifier is on sDETF only.
- **High** L1 counterexamples dissolve under funded-gons with 1:1 gons at fixed K.
- **High** reentrancy must guard multiple read-only paths (oracle, NFT, backing).
- **Medium** DETF-side hook requires new adapter; nothing in current tree is drop-in.
- **Low** on deployed live DETF equivalence with notify semantics (NN-01 deferred).
- **Not claiming** the DETF-side hook already exists; this is a new adapter, not unchanged code.
- **Not reopening** weights, Universal NET synthetic, usual oracle fees, holder proxies, excess same-NFT, pre-maturity rebond, intermediate no-reset / final E+1, independent new-bond locks, NN-03 failure scope.

**Saved:** `docs/research/netnet-transfer-funded-staking-2026-09-27/minimax-cross-review.md`. Originals untouched.
