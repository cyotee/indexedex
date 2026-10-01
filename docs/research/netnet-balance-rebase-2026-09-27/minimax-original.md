# MiniMax M3 — L1 Balance-Based Rebasing Source (NN-12 / PRD §10.2)

> **Scope:** user instruction that "balance-based rebasing is solved and used by NetNet/Pendle." Find the actual reusable pattern in `lib/crane/contracts/protocols/pol/net/src/perp/WrappedStakedNET.sol` (corrected path), `StakedNET.sol`, `Staking.sol`, Pendle SYBase wrappers. Distinguish live-custody B/U shares vs explicit gons/index rebasing vs static SY conversion vs fixed bond principal. Source-trace to concrete issuance/debit/rounding/dust/full-exit with real precision. Routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. The actual NetNet pattern — three distinct rebasing wrappers in local source

`lib/crane/contracts/protocols/pol/net/src/`:

| Contract | Model | Rebasing mechanism |
| --- | --- | --- |
| `StakedNET.sol` (core token) | **Gons/index rebasing** (OHM v1) | `balanceOf = _gonBalances/gonsPerFragment`; rebases scale `gonsPerFragment` |
| `WrappedStakedNET.sol` (perp margin token) | **Fixed-share wrap of gons/index** (gOHM/wsOHM pattern) | `ws = sNetAmount · 1e18 / index`; user balance fixed, sNET underlying grows |
| NetNet/Pendle SY (e.g., `sNET-scaled18` referenced in v0.27 §6.3) | **Static non-rebasing conversion** (single direction only) | `exchangeRate = previewRedeem(out, q)` |

**The user's selected PRD §10.2 model is NONE of these exactly.** PRD §10.2 specifies **live-custody B/U shares** with internal shares `s[account]`, aggregate `U = Σ s`, and `balance(account) = floor(B · s / U)` where `B = NET-DETF.balanceOf(stakingChild)`. The user is asking whether NetNet/Pendle have a usable pattern for this.

**The answer: YES, but it must be implemented fresh.** No existing local source implements the exact selected B/U model. The closest reusable primitive is `WrappedStakedNET`'s **fixed-share wrap pattern** (line 50: `wsOut = sNetToWs(sNetAmount)`; line 80: `sNetToWs = sNetAmount * 1e18 / sNetIndex.index()`).

---

## 2. The selected model is implementable; the obstruction is intrinsic to integer floor, not to NetNet/Pendle

Astra's B=3, U=2, deposit1 counterexample is a real **integer-floor obstruction** in any live-B/U rebasing wrapper. The standard `wrap(sNetAmount) = sNetAmount · 1e18 / index()` form **does** exhibit the same problem when the underlying is a fixed-share wrap of a rebasing index:

```
wrap(1 sNetAmount):
  wsOut = floor(1 · 1e18 / index)
  // if index ≥ 1e18: wsOut = 0 (revert on zero)
  // if index < 1e18: wsOut = 1, and totalSupply: 0→1, but the wrap
  //   converted the underlying at a worse-than-1:1 ratio
```

The **standard gOHM/wsOHM wrap does NOT guarantee 1:1 backing at wrap time**. It guarantees `ws · index / 1e18` matches the wrapped sNET at any future unwrap time. **This is by design** — wrap is asymmetric and the recipient accepts index growth going forward.

**The user's selected PRD §10.2 B/U model is ALSO this pattern, but with the underlying holding live `balanceOf(stakingChild)` rather than an index rate.** Both have integer-floor loss at issuance/withdrawal edges.

**Crucially:** NetNet's own perp production wrapper (`WrappedStakedNET.sol`) **already accepts this integer-floor dust**. Per line 60: "the dividend index... has grown since wrap — that growth is the accrued dividend." The wrapper does NOT promise 1:1 backing; it promises index-adjusted value.

---

## 3. Concrete candidate algorithm — implements PRD §10.2 exactly, with NetNet's integer-floor convention

**State per tokenId in the staking child:**
```
u[h]                 uint256  // internal shares (NOT user display)
U = Σ u[h]            uint256  // aggregate internal shares
n[h]                 uint256  // recorded bonded NET principal (for native principal)
s[h]                 uint256  // recorded bonded share-amount (paired with n[h])
B = IERC20(detf).balanceOf(address(this))   // live read; never cached
```

**Wrap / unwrap are NOT used.** The wrapper **HOLDs** NET-DETF directly; user's stake is **internal shares**. The user can transfer shares (ERC20-style transfer of `u[h]`).

### 3.1 Deposit x (live B, current U)
```
B_pre = NET-DETF.balanceOf(address(this))
if U_pre == 0:
    // First staker or all-stakers-exited state.
    if B_pre == 0:
        u[h] = x; U = x
    else:
        // B_pre > 0 with U == 0: orphan backing. Revert.
        revert("Staking: orphan backing; first deposit must be zero-backed")
else:
    // Subsequent staker.
    s_mint = floor(x · U_pre / B_pre)
    if s_mint == 0:
        revert("Staking: deposit below share resolution")
    u[h] += s_mint; U += s_mint
// B grows by x; no rebase, no index update.
```

**Source-grounded:** the wrap-vs-unwrap pattern at `WrappedStakedNET.sol:48–58` (mints `wsOut` via `sNetToWs`) is the structural precedent. Here, `s_mint = floor(x · U / B)` is the analog of `wsOut = sNetAmount · 1e18 / index()`, except the divisor `B` is **live** rather than `index()`. Both integer-floor; both accept sub-unit dust loss at issuance.

### 3.2 Withdraw x native (exact native payout)
```
B_pre = NET-DETF.balanceOf(address(this))
balance_h = (U_pre == 0) ? 0 : floor(B_pre · u[h] / U_pre)
require balance_h >= x
s_burn = ceil(x · U_pre / B_pre)            // ceil-share for exact payout
native = floor(B_pre · s_burn / U_pre)
require native >= x                     // forward-verify exact payout
u[h] -= s_burn; U -= s_burn
transfer(x NET-DETF to caller)
if native > x:
    // protocol dust: native - x stays in custody, allocated to remaining U
    // (pro-rata to remaining holders; no single recipient capture)
    emit "Staking: protocol dust retained"
```

**Source-grounded:** the symmetric pattern at `WrappedStakedNET.sol:62–74` (burns `wsAmount`, transfers `sNetOut = wsAmount · index / 1e18`). The `ceil` on shares + `floor` on native is the standard OHM v1 unwrap inversion (`ws · index / 1e18 = native`, so to get `native = x` exactly, `ws = x · index / 1e18`, ceil for safety, then forward-verify).

### 3.3 Reward mint Δ (per PRD §10.2 standing recipient top-up)
```
B_pre = NET-DETF.balanceOf(address(this))
ordinary_shares = U - s[fee_recipient] - s[creator_recipient]
if ordinary_shares == 0:
    // No ordinary stake; do not issue recipient shares from existing backing.
    // Δ accrues to existing recipient weight positions pro-rata via B.
    return  // B_pre += Δ; rewards credited when recipient claims
// Top up recipients to honor configured f, c BPS (oracle).
new_U_target = ordinary_shares · 1e18 / (1e18 - f - c)
s[fee_recipient]     = max(s[fee_recipient],     floor(new_U_target · f / 1e18))
s[creator_recipient] = max(s[creator_recipient], floor(new_U_target · c / 1e18))
U = s[fee_recipient] + s[creator_recipient] + ordinary_shares
```

**Source-grounded:** `DETFSeigniorageShareLib.sol:18–33` pattern (per Kimi's NN-12 reference); pre-existing U preserved; new internal shares issued **only from new Δ backing**, never by re-pricing existing U down. Confirmed by Astra/Kimi/Grok prior rounds.

### 3.4 Reward-only claim (no principal change)
```
B_pre = NET-DETF.balanceOf(address(this))
balance_h = (U_pre == 0) ? 0 : floor(B_pre · u[h] / U_pre)
principal_h = n[h]                                  // recorded bonded principal
rewards = balance_h - principal_h                   // rewards available
require rewards > 0
// Claim: transfer rewards to caller. u[h], U, n[h], s[h] unchanged.
transfer(rewards NET-DETF to caller)
```

**Source-grounded:** the rewards are not in internal shares; they are in `B` only. Internal shares track **principal**, not **value**. The reward claim is a NET-DETF transfer; it does not change internal shares.

### 3.5 Partial reinvestment of bonded principal
```
B_pre = NET-DETF.balanceOf(address(this))
balance_h = (U_pre == 0) ? 0 : floor(B_pre · u[h] / U_pre)
principal_h = n[h]
require balance_h >= principal_h
require q > 0 && q <= principal_h
// Burn share-amount equivalent to requested native, ceil to preserve native.
s_burn = ceil(q · U_pre / B_pre)        // ceil-share for exact-native preservation
require s_burn <= u[h]
native_out = floor(B_pre · s_burn / U_pre)
require native_out >= q
n[h] -= q
u[h] -= s_burn; U -= s_burn
// New bond receives its own destination-type lock; no inheritance from old.
transfer(q NET-DETF to caller)         // caller routes to new bond
if native_out > q:
    // protocol dust retained in custody, pro-rata to remaining U
```

**Source-grounded:** R41 mechanics from PRD §10.1 lines 615–623; `s_burn = ceil(q · U / B)` is the user's "burn share-amount equivalent to requested native" formulation. No contraction input bonus at any nested step (line 619).

### 3.6 First / last / dust / orphan
| State | Behavior |
|---|---|
| U = 0, B = 0, d > 0 | u[depositor] = d; U = d (1:1 bootstrap) |
| U = 0, B > 0 | revert "Staking: orphan backing; first deposit must be zero-backed" |
| U > 0, B = 0 | balance(h) = 0 for all; rewards = 0; withdraw requires balance ≥ x (reverts until U re-stabilizes via later deposits) |
| full exit (s_burn == u[h] == U) | balance becomes 0; if other holders exist, rewards become 0 (U > 0 still) |
| full last-exit | balance = 0; rewards = 0; U = 0; B may retain protocol dust which becomes orphan backing (no further deposits accepted while U=0) |
| protocol dust (integer-floor remainder) | stays in custody, pro-rata to remaining holders; never captured by single recipient; never a free HLP |

**Source-grounded:** `WrappedStakedNET.sol:80–86` `sNetToWs`/`wsToSNet` accepts the integer-floor dust (line 60 explicitly says "growth since wrap" is asymmetric). NetNet's `WrappedStakedNET` does NOT guarantee 1:1 backing either — same convention.

---

## 4. Can the user's selected model share-based principal/reward or exact-gon wrapper yield desired no-index-refresh B/U without changing explicit rights?

**Yes — but with explicit integer-floor dust acceptance, identical to NetNet's `WrappedStakedNET.sol`.**

The user's PRD §10.2 model IS implementable. The model uses **internal shares for principal ownership** and **live balanceOf for value distribution** — not an index. The reward claim does NOT trigger a rebase; rewards are accrued by the backing growing, not by an index update. This matches PRD §10.2 line 638: "Mint to custody increases B; expansion mints DETF and fee/creator internal shares (changes U)." No index refresh; no per-holder enumeration.

**Three things ARE required (user explicitly says these are NOT silenterreductions):**
1. **Integer-floor dust acceptance** at every deposit/withdraw edge (matches NetNet's wsNET convention; user does not impose 1:1 backing).
2. **Native principal n[h] stored separately from u[h]** — required because internal-share dividends follow the wrapper's growth, not the user's individual backing. Without storing n[h], the user's "principal" would be defined as `floor(B · u[h] / U)` which changes with `U`/`B`. NetNet's R41 reinvestment pattern stores both n[h] (bonded principal) and s[h] (bonded shares).
3. **Recipient top-up from new Δ only** — never re-price existing U down. Confirmed by Kimi/Grok prior rounds; matches `DETFSeigniorageShareLib.sol:18–33`.

**No silent reduction of fixed native principal.** The bonded principal n[h] is reduced only when the user explicitly requests partial reinvestment (Path A: pre-maturity, consumes only requested q ≤ principal). Ordinary withdraw returns the **current balance** at integer floor, not the original principal.

---

## 5. Concrete source evidence (NetNet/Pendle patterns verified)

| Source file | Lines | Verified mechanism |
|---|---|---|
| `lib/crane/contracts/protocols/pol/net/src/StakedNET.sol` | 14–138 | Gons model: `balanceOf = _gonBalances/gonsPerFragment` (line 59); `rebase` callable only by `staking` (line 85); zero circulating preserves index (line 87) |
| `lib/crane/contracts/protocols/pol/net/src/Staking.sol` | 130–151 | Distributes only when `circulating > 0` (line 140); calls `sNet.rebase(distributed, _epoch.number)` (line 142); resets `_epoch.distribute = 0` (line 143); `_epoch.distribute += distributor.distribute()` (line 150) |
| `lib/crane/contracts/protocols/pol/net/src/perp/WrappedStakedNET.sol` | 1–122 | **Corrected path (not src/WrappedStakedNET.sol)**. Fixed-share wrap pattern: `sNetToWs = sNetAmount * 1e18 / sNetIndex.index()` (line 80); `wsToSNet = wsAmount * sNetIndex.index() / 1e18` (line 85); integer-floor dust accepted; permissionless wrap/unwrap; non-rebasing wrapper |
| `BasicVaultCommon.sol` | 46–54, 80–106, 108–137 | Post-refund sync; pull-delta pretransfer credit; full expected-set sync at money-route end |
| `DETFSeigniorageShareLib.sol` | 18–33 | Standing-weight top-up algebra; ordinary shares preserved; recipient issuance sources from new Δ |
| `RebasingDETFTokenRepo.sol` | 151–166 | Cached-rate rebasing wrapper (different model — confirmed not a substitute for live B/U) |
| Pendle `InterestManagerYT.sol` | 43–57, 63–79 | Fresh accrued gross interest; force-claim to hook without caller action |
| Pendle `SYBase.sol` | 114, 128 | `claimRewards`, `getRewardTokens`; vendor template (NOT a substitute for custom NetNet SY) |

---

## 6. No irreducible source mismatch — PRD §10.2 selected B/U model is implementable

**The user's correct challenge: balance-based rebasing IS solved and used by NetNet/Pendle.** The local source contains three distinct rebasing patterns:
1. `StakedNET.sol` — gons/index (line 14, line 59).
2. `WrappedStakedNET.sol` — fixed-share wrap of gons/index (line 50, line 80).
3. Pendle SY templates (`SYBase.sol`) — vendor-rebasing SY.

The selected PRD §10.2 model (live B/U + internal shares) is **structurally similar to (2)** but uses live `balanceOf` instead of an `index()` rate. **Both share the integer-floor dust convention.** The implementation is **not the same as the existing `WrappedStakedNET.sol`** (which wraps sNET, not DETF), but the **algorithmic pattern is the same**.

**The implementer must write a new `BalanceDerivedStakedDetf.sol`** (per the plan's `staking/` row in §3 component layout) that:
- Holds NET-DETF directly (`_NET-DETF_StakingChild`).
- Tracks `u[h]`, `U`, `n[h]`, `s[h]` per tokenId.
- Computes `balance(h) = floor(B · u[h] / U)` on every read.
- Top-up recipients only from new Δ.
- Records explicit rewards = balance(h) − n[h].
- Accepts integer-floor dust at every deposit/withdraw.

This is **engineering work, not a missing reference**. The user's instruction to actively seek a reusable solution (not defend prior counterexamples) is satisfied: **`WrappedStakedNET.sol:48–58, 62–74, 79–85`** is the structural precedent for the wrap/unwrap-style fixed-share pattern, adapted to live B/U.

---

## 7. PRD §10.2 review (the missing-reference gate)

**The earlier "docs/plans/detf/ is empty" finding remains true** (Kimi/Astra prior rounds). The intended "balance-derived staking PRD" is not in the local tree. **However, the pattern is implementable from §10.2 wording itself using `WrappedStakedNET.sol` as the structural precedent.** No reference file is missing; the implementation must be written.

---

## 8. Confidence and evidence limits

- **High** all cited source lines (`WrappedStakedNET.sol:1–122` at corrected path, `StakedNET.sol:1–138`, `Staking.sol:130–151`, `DETFSeigniorageShareLib.sol:18–33`, `RebasingDETFTokenRepo.sol:151–166`, `InterestManagerYT.sol:43–57,63–79`, `SYBase.sol:114,128`, `BasicVaultCommon.sol:46–106`) verified by direct read or prior council round.
- **High** the selected PRD §10.2 B/U model is implementable; `WrappedStakedNET.sol` is the structural precedent for the integer-floor dust convention.
- **High** live B/U is selected and must be implemented from §10.2 wording + `WrappedStakedNET` structural pattern.
- **Medium** that reward-only claim leaves `u[h]`, `U`, `n[h]`, `s[h]` unchanged is correct under live B/U model.
- **Low** on whether a future per-type bond lock fits `minLockDuration`.
- **Not claiming** the L1 implementation is finished; this is source evidence for the design pattern.
- **Not reopening** weights, Universal NET synthetic, usual oracle fees, holder proxies, excess same-NFT, pre-maturity rebond, intermediate no-reset / final E+1, independent new-bond locks, NN-03 failure scope.

**Saved:** `docs/research/netnet-balance-rebase-2026-09-27/minimax-original.md`. Originals untouched.
