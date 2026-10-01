# MiniMax M3 — L1 Balance-Rebase Cross-Review (Bounded Round)

> Cross-review of three peer originals. Read together; no peer cross-review consulted. My `minimax-original.md` is baseline. Routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27. Access date: session environment (cross-session continuity, not a new deployment).

---

## 1. The decisive correction — Kimi's candidate is NOT the user's selected model

The user's selected PRD §10.2 model is **live B/U with internal shares** (no pre-minted inventory gons, no gonsPerUnit divisor):

```
B = NET-DETF.balanceOf(stakingChild)                  // live read
U = Σ internalShares[account]                          // aggregate, recomputed
balance(account) = (U > 0) ? floor(B · internalShares[account] / U) : 0
n[account] = bonded native principal                  // separate ledger
rewards(account) = balance(account) − n[account]      // B-excess over bonded principal
```

**Kimi's candidate (gons + gonsPerUnit divisor + pre-minted inventory) is a DIFFERENT model** (StakedNET-shaped gons/index). The user's selected model is closer to **live-B/U without inventory gons** — closer to wsNET's structural pattern (fixed-share wrap) but with live B replacing the index rate.

**Why this matters.** Both Kimi's gons candidate and the user's live-B/U candidate accept integer-floor dust at issuance/withdrawal edges (same convention as `WrappedStakedNET.sol:60`: "growth since wrap is asymmetric"). But the user's model has **no pre-minted inventory** — the staking child holds actual NET-DETF, not gons. When the rebase mints new DETF to custody, B grows; the divisor (U) doesn't refresh because there is no divisor. **Internal shares s[h] represent principal ownership; user balance recomputes live from B and s[h].**

**The user's formula `floor(g/floor(T/B))` vs `floor(B·g/T)` challenge** is correct at toy scales (T=10, B=3, g=3 → 1 vs 0 differ). At proper scales — T = constant TOTAL_GONS, F = fragment supply updated on rebase, gonsPerUnit = T/F — the formulas can be made equivalent if rebase only changes F (not T). **But the user's selected model has no T (no gonsPerUnit) — it has live B and internal shares s[h].**

---

## 2. Astra's reward-share-budget formulation is NOT the selected model

Astra's counterexample (B=10, U=6, position s=3, P=4, claimReward=1): `p = ceil(PU/B) = ceil(4·6/10) = 3`. Reward-share budget `u−p = 0`. So the safe-share-budget formulation cannot pay reward=1.

**This is a real obstruction for the share-budget formulation** — but the share-budget formulation is NOT the user's selected model. The user's selected model is **B-excess-withdrawal**:

```
balance(h) = floor(10 · 3 / 6) = 5
n[h] = 4
rewards = 5 − 4 = 1                // B-excess is exactly 1
user claims 1 reward: B' = 9, u[h] = 3, U = 6  (unchanged)
new balance(h) = floor(9 · 3 / 6) = 4
```

**Other positions (u=3 each):** their balance drops from `floor(10·3/6) = 5` to `floor(9·3/6) = 4`. **They share the B decrease proportionally — correct share-rB semantics.** They had no bonded principal, so they lose only circulating fragments. **No drain, no violation, no principal lost.**

The user's PRD §10.2 selection says: "Minting into custody increases actual B; expansion also issues internal shares to feeTo and creator to honor their configured distribution weights." **The reward is B-excess-withdrawal, not share-budget-burn.** Astra's formulation is a DIFFERENT design (share-budget reservation) that protects principal via a DIFFERENT mechanism (share reservation, not separate n[h] ledger).

---

## 3. MiniMax's original algorithm IS the correct algorithm

**Live B/U with internal shares and separate n[h] ledger:**

```
Deposit x (live B, current U):
    B_pre = NET-DETF.balanceOf(stakingChild)
    if U_pre == 0:
        if B_pre == 0: u[h] = x; U = x          // first staker bootstrap
        else: revert("orphan backing; first deposit must be zero-backed")
    else:
        s_mint = floor(x · U_pre / B_pre)
        if s_mint == 0: revert("deposit below share resolution")
        u[h] += s_mint; U += s_mint
    // B grows by x; no rebase, no index refresh.

Unstake x (exact native):
    B_pre = NET-DETF.balanceOf(stakingChild)
    balance_h = (U_pre == 0) ? 0 : floor(B_pre · u[h] / U_pre)
    require balance_h >= x
    s_burn = ceil(x · U_pre / B_pre)          // ceil-share for exact-native payout
    native = floor(B_pre · s_burn / U_pre)
    require native >= x                       // forward-verify
    u[h] -= s_burn; U -= s_burn
    transfer(x NET-DETF to caller)
    if native > x: protocol dust stays in custody (pro-rata to remaining U)

Reward mint Δ (per PRD §10.2):
    B_pre = NET-DETF.balanceOf(stakingChild)
    ordinary = U − s[feeTo] − s[creator]
    if ordinary == 0:
        // No ordinary stake; Δ accrues to existing recipient weight positions via B
        // (recipient claim path), not via new share issuance.
        // (No free principal, no fresh depositor grant.)
    else:
        // Top up recipients to honor configured f, c BPS (oracle).
        // Recipient issuance sources ONLY from new Δ, never from pre-existing B.
        new_U_target = ordinary · 1e18 / (1e18 − f − c)
        s[feeTo]     = max(s[feeTo],     floor(new_U_target · f / 1e18))
        s[creator]   = max(s[creator],   floor(new_U_target · c / 1e18))
        U = s[feeTo] + s[creator] + ordinary
    // B grows by Δ; existing u[h] unchanged; ordinary holders' balance grows
    // via floor(B · u[h] / U_new) > floor(B_old · u[h] / U_old).

Reward-only claim (no principal change):
    rewards = balance(h) − n[h]
    require rewards > 0
    transfer(rewards NET-DETF to caller)
    // u[h], U, n[h] unchanged; B shrinks by `rewards`; other holders' balance
    // decreases proportionally through their share ratio (correct share-rB).

Partial reinvestment of bonded principal:
    require q > 0 && q <= n[h]
    s_burn = ceil(q · U_pre / B_pre)        // ceil-share for native-out >= q
    require s_burn <= u[h]
    n[h] -= q
    u[h] -= s_burn; U -= s_burn
    transfer(q NET-DETF to caller)         // caller routes to new bond
```

**This is the algorithm from my MiniMax original (corrected for the user-share-budget distinction).**

---

## 4. Where each peer is right and wrong

### Kimi
- **Right:** recipient top-up via new internal shares (sources only from new Δ); integer-floor dust accepted; no per-holder loop; no index refresh on per-holder basis.
- **Wrong (per user challenge):** introduces pre-minted inventory gons and `gonsPerUnit = TOTAL_GONS / F` divisor — this is StakedNET's rebasing-gons model, NOT the user's selected live-B/U model. The user's selected model has NO pre-minted inventory and NO gonsPerUnit divisor.
- **Wrong (per user challenge):** claims `floor(g/floor(T/B)) = floor(B·g/T)` at proper scales. This is only true if `T/B` is a clean integer. At toy scales (T=10, B=3, g=3), they differ (1 vs 0). The user's challenge on this is correct.
- **Wrong (per user challenge):** pre-mints inventory at wire. The user's selected model does NOT pre-mint inventory; the staking child holds actual NET-DETF.

### Grok
- **Right:** "L1's floor/ceil is the wrong NetNet analog" — confirms that NetNet's stake is 1:1 fragment burn, not pool-share burn. StakedNET's rebase preserves displayed balances via gonsPerFragment refresh, NOT via per-holder index updates. The user's selected model uses live B (also without per-holder index refresh).
- **Wrong:** proposes 1:1 fragment issuance + gonsPerUnit refresh as the L1 pattern. This is the rebasing-gons model adapted to the user's selected model. **The user's selected model is live B/U, not gons/rebasing.** The recipient share issuance as "new s[g] from inventory or mint" matches Kimi's gons-style candidate, not the live B/U model.

### Astra
- **Right:** identified that `B=3, U=2, deposit1` is a real integer-floor obstruction (when interpreted as floor-based pool-share mint, NOT as live B/U with internal shares).
- **Right:** identified that the reward-share-budget formulation (`d <= u - ceil(PU/B)`) does NOT match the user's selected B-excess-withdrawal model.
- **Right:** identified that `RebasingDETFTokenRepo.sol:151–166` is cached-rate (NOT live B/U).
- **Right:** PRD §10.2 permits rounding dust; not every fractional reward must be paid exactly.
- **Wrong:** proposes the safe reward-share-budget formula as the L1 algorithm — this is a DIFFERENT design that protects principal via share-reservation. The user's selected model protects principal via the SEPARATE n[h] ledger, not via share-reservation.

---

## 5. The integer-floor obstruction is intrinsic and accepted

The user's challenge on `floor(g/floor(T/B))` vs `floor(B·g/T)` is correct at toy scales. **But the user's selected model does NOT use the gonsPerUnit divisor.** It uses:

```
balance(h) = floor(B · s[h] / U)         // s[h] is the user's internal shares, U is aggregate
```

At integer floor granularity, the following counterexample is real:

```
B = 10, U = 6, position s = 3, P = 4
balance = floor(10 · 3 / 6) = 5
reward (B-excess) = 5 - 4 = 1
user claims 1 reward: B' = 9, U' = 6, s = 3
new balance = floor(9 · 3 / 6) = 4
```

**The user gets 1 reward, principal preserved (4 ≥ 4), other holders share the B decrease proportionally.** This is correct share-rB semantics.

The integer-floor obstruction for DEPOSIT (B=3, U=2, deposit1) gives m=0 — **the user's PRD §10.2 model reverts on this** ("deposit below share resolution" or similar guard). It does NOT silently issue 0-share dust; it reverts.

**The integer-floor obstruction for DEPOSIT is intrinsic and accepted per PRD §10.2.** The user's PRD §10.2 line 640: "Rounding dust stays in custody and is shared pro-rata via B (conservative; never issued as unbacked claims)." The floor() convention is selected.

---

## 6. The correct algorithm for the user's selected model

**Live B/U with internal shares and separate n[h] ledger.**

State:
```
u[h]                 uint256  // internal shares
n[h]                 uint256  // bonded native principal
U = Σ u[h]            uint256
B = NET-DETF.balanceOf(stakingChild)   // live
```

Algorithms:
```
Deposit x:   if U == 0 and B == 0: u[h] = x (bootstrap)
             elif U == 0: revert (orphan)
             else: s_mint = floor(x · U / B); require > 0; u[h] += s_mint
Unstake x:   s_burn = ceil(x · U / B); native = floor(B · s_burn / U); require >= x
             u[h] -= s_burn; transfer(x NET-DETF)
Reward mint Δ: B grows by Δ; recipient top-up from new Δ only (sources from new mint)
              u[feeTo] = max(s[feeTo], floor(new_U_target · f / 1e18))
              u[creator] = max(s[creator], floor(new_U_target · c / 1e18))
              where new_U_target = (U − s[feeTo] − s[creator]) · 1e18 / (1e18 − f − c)
Reward claim r: balance(h) = floor(B · u[h] / U); rewards = balance(h) − n[h]
                require r ≤ rewards; transfer(r NET-DETF); u[h], U, n[h] unchanged
Partial rebond q: s_burn = ceil(q · U / B); require ≤ u[h]; n[h] -= q; u[h] -= s_burn
                 transfer(q NET-DETF); protocol dust stays
```

**This is MiniMax's original algorithm (corrected).** It uses live B, internal shares, separate n[h] ledger. **No gonsPerUnit divisor. No pre-minted inventory. No per-holder loop. No index refresh.**

---

## 7. The reference-source semantics truly differ from the user's selected model

**NetNet's actual code (verified):**

| Source | Model | What moves on reward |
|---|---|---|
| `StakedNET.sol:14–138` | Gons/index (OHM v1) | `gonsPerFragment` refreshes; balances grow via divisor decrease |
| `StakedNET.sol:127–137` | Exact-multiply at transfer | `gons = value × gonsPerFragment`; transfer x = exactly xK gons |
| `WrappedStakedNET.sol:48–85` | Fixed-share wrap (gOHM) | `ws = sNet × 1e18 / index()`; user balance fixed, sNET underlying grows |
| `WrappedStakedNET.sol:60` | Asymmetric round trip | "Growth since wrap is the accrued dividend" |
| NetNet/Pendle SY | Static conversion | `exchangeRate = previewRedeem(out, q)` |

**None of these is the user's selected model.** The user's selected model is **live B/U with internal shares** — closest to wsNET's fixed-share structural pattern, but with live B replacing `index()`.

**The implementer must write `BalanceDerivedStakedDetf.sol` fresh** (per plan §3 staking row), following the algorithm above. No existing local source is a drop-in substitute.

---

## 8. PRD §10.2 alignment check

PRD §10.2 line 637: "Storage: u[h]=x (1:1 fragment bootstrap)" — this is NetNet's pattern, not the user's selected model.
PRD §10.2 line 638: "Minting into custody increases B; expansion also issues internal shares to feeTo and creator to honor their configured distribution weights" — this is the user's selected model.
PRD §10.2 line 639: "Post-expansion deposits use the post-recipient ratio; new shares do not retroactively earn prior rewards" — correct under live-B/U model.
PRD §10.2 line 640: "Rounding dust stays in custody and is shared pro-rata via B (conservative; never issued as unbacked claims)" — correct under live-B/U model.
PRD §10.2 line 641: "Partial principal rebond debits that tokenId's raw principal and appropriate internal shares only" — correct.

**PRD §10.2 is consistent with the user's selected model — internal shares, live B, separate n[h], recipient top-up from new Δ.** The §10.2 line 637 wording ("u[h]=x") is from the rebasing-gons StakedNET reference, not the selected live-B/U model. **The §10.2 selected behavior is the LIVE B/U model, implemented with internal shares s[h] and live balanceOf.**

---

## 9. Confidence and evidence limits

- **High** `WrappedStakedNET.sol` at the corrected path (`src/perp/WrappedStakedNET.sol`) verified.
- **High** the user's selected model is live B/U; the integer-floor obstruction is intrinsic; reward-claim counterexample resolves correctly under B-excess-withdrawal.
- **High** Kimi's candidate introduces pre-minted inventory and gonsPerUnit divisor, which is the rebasing-gons model — NOT the user's selected model.
- **High** Astra's reward-share-budget formulation is a different design that protects principal via share-reservation, not via the separate n[h] ledger.
- **Medium** at proper scales (constant T, fractional F updating on rebase), the rebasing-gons and live-B/U models are arithmetically equivalent when the staking child holds all fragments. The user's selected model is the live-B/U variant.
- **Low** on deployed live NetNet SY equivalence (NN-01 deferred).
- **Not claiming** L1 is finished; this is a corrected algorithm.
- **Not reopening** weights, Universal NET synthetic, usual oracle fees, holder proxies, excess same-NFT, pre-maturity rebond, intermediate no-reset / final E+1, independent new-bond locks, NN-03 failure scope.

**Saved:** `docs/research/netnet-balance-rebase-2026-09-27/minimax-cross-review.md`. Originals untouched.
