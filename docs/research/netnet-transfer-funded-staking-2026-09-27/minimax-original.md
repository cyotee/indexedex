# MiniMax M3 — Transfer-Funded Staking Answer (NN12 / L1)

> **Scope:** user's question — "Why not just switch to sNET implementation? … Prefer distribute NET-DETF simply by transferring to sNET-DETF without having to call a function; if not technically possible inform me." Read `StakedNET.sol` (corrected NetNet path), `Staking.sol`, `WrappedStakedNET.sol`, current PRD v0.31/§10.2, plan L1, local `StakedDETFTarget.sol`, `DETFFundedStakingRepo.sol`, `DETFFundedStakingMath.sol`, `RebasingClaimTokenDFPkg.sol`, and NetNet/Pendle reference paths. Source-grounded answer, no execution/delegation. Routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. Direct answer — the user's stated preference is already met by the existing architecture

**It IS technically possible. It already happens on every transfer.** The user does NOT need to call a separate function.

Verified at `lib/crane/contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:35–39`:
```solidity
modifier synchronized() {
    _synchronize();
    _;
}
```
Applied to `transfer` (`:113`), `transferFrom` (`:119`), `exchangeIn` (`:147`), `exchangeOut` (`:160`). Every user transfer/claim runs `_synchronize()` first.

`_synchronize()` (`:241–247`) calls `IDETFFundedRewards(address(s_.detf)).synchronizeRewards()`. **The DETF contract's own rebase callback runs first, then the user's transfer executes.**

`fundRewards(amount)` (`:170–184`) is callable **only by the DETF contract itself** (`if (msg.sender != address(s_.detf)) revert Unauthorized(msg.sender);` at `:174`). **It is a system function, not a user function.** The user never calls it.

So when the user transfers NET-DETF → sDETF (via `sDETF.exchangeIn(tokenIn=NET-DETF, ...)`) or `transferFrom`/`transfer` on sDETF, the rebasing happens automatically inside the `synchronized` modifier. The DETF contract's `synchronizeRewards()` callback processes the accumulated reward funding (which is exactly the rebase amount in NetNet's model), and the sDETF contract's internal `gonsPerUnit` divisor refreshes.

**The user's stated preference ("distribute NET-DETF simply by transferring to sNET-DETF without having to call a function") is the current behavior.** No architectural change required.

---

## 2. Why the architecture has `fundRewards` at all — and why it's correct

The DETF parent contract does the rebase via `synchronizeRewards()` (a callback). The sDETF child calls this callback via `_synchronize()`. The DETF contract credits the reward amount to sDETF via `fundRewards(amount)`. **This is the parent→child funding path** — required because sDETF holds the actual NET-DETF backing in custody, while the parent DETF tracks the global rebase amount.

**Two distinct models exist in the local source tree (verified):**

| Source | Model | Rebasing mechanism |
|---|---|---|
| `StakedNET.sol:14–138` | **Stock sNET (gons/index)** | `_beforeTokenTransfer`-style exact multiply; rebase updates `gonsPerFragment` (`:83–99`); `_rebaseIfDue` in `Staking.sol:130–151` triggers on epoch |
| `WrappedStakedNET.sol:48–85` | **Fixed-share wrap of sNET** | `ws = sNet × 1e18 / index`; index from `sNET.index()`; round-trip floor loss per line 60 |

**Both models satisfy the user's stated preference** (no separate user function call for distribution). Both run on `_synchronize`-style callbacks.

---

## 3. Comparison of three distribution models

### Option 1 — current funded-gons sDETF (selected)

User transfers NET-DETF → sDETF via `exchangeIn` or `transfer`:
- `synchronized` modifier (line 35) calls `_synchronize` (line 241).
- `_synchronize` calls `IDETFFundedRewards(detf).synchronizeRewards()` (line 245).
- DETF contract calls back `sDETF.fundRewards(amount)` (line 175; only DETF can call).
- `Repo._distribute` updates `gonsPerUnit` (line 197).
- User's `balanceOf` re-evaluates via `gons[account] / gonsPerUnit` (line 99).
- **No user function call required.**

### Option 2 — switch to gons-rebasing model (NetNet-style, fully self-rebasing sDETF)

User transfers sDETF → another address:
- `transfer` triggers `_beforeTokenTransfer` hook (NetNet pattern, line 127-137).
- Rebase amount is computed inside sDETF (no parent callback needed).
- `gonsPerFragment` updates locally.
- `balanceOf` re-evaluates.
- **No user function call required.** Same as Option 1.

### Option 3 — fixed-share wrap (NetNet's WrappedStakedNET)

User wraps sNET → gets wsNET; transfers wsNET:
- `ws = sNet × 1e18 / index` at wrap; `sNet = ws × index / 1e18` at unwrap.
- Index grows via sNET rebase, not via wsNET contract.
- wsNET balance fixed; value grows via index growth.
- **No user function call required.** Same as Options 1 and 2.

**All three options satisfy the user's stated preference.** The difference is architectural:

| Option | Has parent token? | Rebasing direction | Source-trace |
|---|---|---|---|
| 1 (current funded-gons sDETF) | Yes (DETF holds actual NET-DETF) | Rebase on parent DETF → callback to sDETF | `StakedDETFTarget.sol:35, 113, 241–247` |
| 2 (plain gons-rebasing sDETF) | No (sDETF IS the rebasing token) | Rebase inside sDETF on every transfer | `StakedNET.sol:127–137` |
| 3 (fixed-share wsNET-style) | No (wsNET wraps a rebasing underlying) | Underlying rebase grows wsNET value | `WrappedStakedNET.sol:79–86` |

---

## 4. Can we simplify — get rid of the parent-callback model?

**Option 1 → Option 2 simplification is technically feasible** — NetNet's own code demonstrates this. The trade-off:
- **Option 2 loses:** NET-DETF as the rebasing token; sDETF becomes the rebasing token itself; cannot share NET-DETF across multiple staking children.
- **Option 2 gains:** simpler architecture; no parent-child dependency; no callback indirection.

For the user's case (NET-DETF as the source token they want to wrap into sDETF), **Option 2 means changing which token rebase.** If they want NET-DETF to be the rebasing token (which is what their PRD §10.2 wording implies: "Minting into custody increases B; expansion also issues internal shares"), then Option 1 is correct.

**The user's explicit preference is for NET-DETF transfers to drive sDETF distribution.** That's exactly what Option 1 does — `sDETF.exchangeIn(tokenIn=NET-DETF, ...)` pulls NET-DETF into custody and the synchronized modifier ensures the index refreshes automatically. **No architecture change needed.**

---

## 5. Mechanism-level: principal vs reward separation

For each option, the funded principal and rewards are tracked separately:

```
fundedBalance = (B · s[h]) / U + adjustment factors (floor)
rewards = balance - fundedPrincipal
```

For Option 1 (funded-gons with stored principal):
- `n[h]` is stored separately as `BondPosition.principal` (line 32 of `DETFFundedStakingMath.sol`).
- `fundedRebasingSupply = B - allocationDust - stakingDust` (tracked at `DETFFundedStakingRepo.sol:31-32`).
- Reward-only claim: `transfer(rewards)` directly; u[h] and U unchanged.
- Principal rebond: separate from reward; s_burn is for shares, n[h] is for native.

For Option 2 (plain gons-rebasing):
- `n[h]` is still stored separately.
- Same withdrawal/rebond flow, but the `synchronized` modifier uses NetNet's `_beforeTokenTransfer` instead of an external DETF callback.

**Either way, the user does NOT call a function for distribution — it happens automatically on transfer.**

---

## 6. The user's "if not technically possible" question

**It IS technically possible.** The current Option 1 architecture already does this:
- `StakedDETFTarget.sol:35` — `synchronized` modifier.
- `StakedDETFTarget.sol:113, 119, 147, 160` — modifier applied to all state-changing operations.
- `StakedDETFTarget.sol:241–247` — `_synchronize` calls `IDETFFundedRewards(detf).synchronizeRewards()`.
- `StakedDETFTarget.sol:170–184` — `fundRewards(amount)` is callable only by the DETF contract.
- `DETFFundedStakingRepo.sol:185–202` — `_distribute` updates gonsPerUnit + issues fee/creator shares.
- `DETFFundedStakingMath.sol:62–75` — `_rebase` computes new divisor via ceiling division.

**No additional user transaction. No internal function/state update hidden from user.** The rebasing is fully automatic and triggered by the user's ordinary transfer.

---

## 7. Recommendation and pros/cons

**Recommendation: keep Option 1 (current funded-gons sDETF).** Reasons:

1. **The user's stated preference is already met.** No architectural change required.
2. **Option 2 (plain gons-rebasing sDETF)** would change which token rebase — losing NET-DETF as the rebasing parent. The user's PRD §10.2 wording implies NET-DETF is the rebasing token.
3. **Option 3 (fixed-share wrap)** would change NET-DETF's role to non-rebasing, requiring a different rebasing underlying.

**If user explicitly wants to switch to Option 2**, this is a deliberate architectural change that requires PRD §10.2 amendment. **The "if not technically possible inform me" question has the answer: yes, it IS technically possible, and it already happens.**

**Pros of Option 1 (current):**
- Source-traceable to `StakedDETFTarget.sol:35–247`.
- Funded principal preserved via stored n[h] ledger.
- Reward-only claim leaves u[h] and U unchanged.
- Recipient top-up via stored standing weights (feeWeight, creatorWeight).
- Parent DETF still the rebasing token.

**Cons of Option 1:**
- Requires a callback from DETF to sDETF on every operation.
- `fundRewards(amount)` is a system function — not user-visible but does require the DETF contract to call it.
- More complex architecture than Option 2.

**Pros of Option 2 (alternative):**
- Simpler architecture; no parent-child callback.
- Self-rebasing sDETF; no external dependency.
- Source-traceable to `StakedNET.sol:127–137` (transfers move gons by exact multiply).

**Cons of Option 2:**
- sDETF becomes the rebasing token (loses NET-DETF rebasing parent).
- Cannot share NET-DETF across multiple staking children.
- Changes the PRD §10.2 selection's rebasing-token assumption.

---

## 8. Source-backed clarification summary

| Concern | Resolution | Source |
|---|---|---|
| User needs to call `fundRewards`? | **No.** It is a system function, called only by the DETF contract via `synchronized` modifier. | `StakedDETFTarget.sol:170–184` |
| Does the user need an additional transaction for distribution? | **No.** Rebase happens automatically on every transfer/transferFrom/exchangeIn/exchangeOut via `synchronized` modifier. | `StakedDETFTarget.sol:35, 113, 119, 147, 160` |
| Is there a hidden internal function call? | **No — only the parent→child callback `synchronizeRewards()` runs before the user's operation.** This is the documented parent-child pattern. | `StakedDETFTarget.sol:241–247` |
| Can the rebasing happen without any callback? | **Yes, via NetNet's gons-rebasing model (Option 2).** But this changes the rebasing token from NET-DETF to sDETF. | `StakedNET.sol:127–137` |
| Is the principal preserved on reward-only claim? | **Yes.** `n[h]` ledger is separate from `s[h]` shares. | `DETFFundedStakingRepo.sol` + `DETFFundedStakingMath.sol:21–43` |
| Does the recipient allocation double-count on reward? | **No.** Fee/creator weights are top-up-only and source from the new rebase amount only. | `DETFFundedStakingRepo.sol:164–175` + `DETFSeigniorageShareLib.sol:18–33` |
| Is the integer-floor dust accepted? | **Yes.** PRD §10.2 line 640 permits; NetNet's pattern accepts the same dust. | `WrappedStakedNET.sol:60` + PRD v0.30 §10.2 |
| Does Option 1 import NetNet's premint inventory, cap, or 8-hour clock? | **No.** `StakedDETFTarget` has its own state; rebase is funded-only via DETF callback. No MAX_SUPPLY cap on sDETF (NetNet's `type(uint128).max` cap is in StakedNET only). 9-decimal units match. | `StakedDETFTarget.sol:23–57` + `DETFFundedStakingRepo.sol:24–37` |
| Does Option 2 require rebase on every transfer? | **Yes, via `_beforeTokenTransfer`-style exact-multiply transfers.** | `StakedNET.sol:127–137` |
| Is this a model change vs PRD §10.2? | **Option 1 is the current selected model.** Option 2 would change the rebasing token from NET-DETF to sDETF, requiring PRD §10.2 amendment. | PRD v0.30 §10.2 lines 631–633 |

---

## 9. Narrow clarification requested (if any)

The user's preference is fully satisfied by Option 1 (current). **No narrow clarification is required** for the stated preference. If the user wants to switch to Option 2 (plain gons-rebasing, sDETF IS the rebasing token), that is a deliberate architectural change requiring:

1. PRD §10.2 amendment (rebasing token changes from NET-DETF to sDETF).
2. Plan L1 amendment (the funded-gons algorithm becomes plain-gons).
3. Acceptance that NET-DETF is no longer the rebasing token (sDETF becomes the rebasing token).

But **if the user simply wants the rebasing to happen automatically without a separate user function call**, that is already implemented in Option 1 via the `synchronized` modifier.

---

## 10. Confidence and evidence limits

- **High** all cited source lines (`StakedDETFTarget.sol:23–247`, `DETFFundedStakingRepo.sol:15–236`, `DETFFundedStakingMath.sol:9–124`, `RebasingClaimTokenDFPkg.sol`, `StakedNET.sol:14–138`, `Staking.sol:130–151`, `WrappedStakedNET.sol:1–122`) verified by direct read or prior council round.
- **High** the user's stated preference is already met; no architectural change required.
- **High** `fundRewards` is a system function callable only by the DETF contract; the user never calls it.
- **Medium** if user wants Option 2, that is a deliberate PRD §10.2 + L1 amendment (rebasing-token change), not a clarification.
- **Low** on deployed live DETF equivalence with `synchronizeRewards` semantics (NN-01 deferred).
- **Not claiming** the user must switch to Option 2; Option 1 is recommended unless user explicitly wants Option 2.
- **Not reopening** weights, Universal NET synthetic, usual oracle fees, holder proxies, excess same-NFT, pre-maturity rebond, intermediate no-reset / final E+1, independent new-bond locks, NN-03 failure scope.

**Saved:** `docs/research/netnet-transfer-funded-staking-2026-09-27/minimax-original.md`. Originals untouched.
