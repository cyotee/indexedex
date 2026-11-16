# DETF formal definitions (documentation-grade)

| Field | Value |
|-------|--------|
| **Status** | Phase 2 complete (2026-07-30) |
| **Scope** | True DETFs; gold empirics on Single Standard Exchange DETF |
| **Not** | Novel AMM theory, LVR re-derivation, mainnet yield math |
| **Normative law** | Threshold Modes PRD · Compound/Expansion PRD · family PRDs |
| **Measured** | [`../../scenarios/detf/singleSe/FINDINGS.md`](../../scenarios/detf/singleSe/FINDINGS.md) |

Cross-check sources: `DETFThresholdPolicy.sol`, `DETFNaturalExpansionLib.sol`, `DETFProtocolCompoundLib.sol`, Single SE gold package.

---

## 1. Roles

| Role | Symbol / name | Meaning |
|------|----------------|---------|
| **detfToken** | `D` = `address(this)` | DETF diamond is the ERC-20 share |
| **rateAsset** | settlement / “new money” | Must appear in underlying SE `tokens()` when SE is the leg |
| **pairToken** | other vault-declared token(s) | Not the rateAsset |
| **underlyingVault / SE** | `V` | `IStandardExchange` leg under the DETF |
| **vaultShare** | `s` | Share of `V` (often `address(V)`) |
| **reservePool** | Balancer V3 pool | Pricing engine for the unit |
| **reserveBpt** | BPT | Claim on pool balances |
| **bond NFT vault** | bond position registry | User + protocol + fee-recipient positions |
| **protocol NFT** | detf-owned bond id | Protocol-owned principal / rewards sink for compound |
| **rebasing claim** | claim token (when wired) | Claim on protocol-owned reserve BPT |

**Anti-patterns:** product brands (`RICH`, `mintWithWeth`) on generic DETF surfaces.

---

## 2. Liveness

| State | Predicate (conceptual) |
|-------|-------------------------|
| **Inert** | Deploy complete; reserve not live; user mint/burn of DETF against vault shares **blocked** |
| **Live** | First successful family bond established protocol reserve (`isReserveLive` / equivalent) |

- First bond / bootstrap is **synthetically ungated** (both Policy and Open).  
- Measured: D0 inert; D1 first bond → live ([FINDINGS](../../scenarios/detf/singleSe/FINDINGS.md) RQ1–RQ2).

```text
live  ⇔  isReserveLive == true
inert ⇔  ¬live
```

---

## 3. Synthetic price

**Pricing engine = reserve pool** (balances, weights, fees, rate providers). No off-pool multi-asset FX ledger.

### Definition (Policy narrative scale: 1e18 fixed-point)

Let **B** be fully diluted backing: rate-scaled claim of **owned** reserve BPT on pool balances (include BPT held by the bond NFT vault when the family peers do).

Let **S** = DETF `totalSupply` (including inventory on bond vault when peers count it).

```text
p_syn = B / S

# 1e18 fixed-point
# abstract peg p* = 1e18
```

**Gates use synthetic only** — never spot alone.

Measured hermetic post-bond Single SE + Uni V2 often sits **burn-side** of peg (~0.625e18) until inventory and market paths move `p_syn` (FINDINGS RQ3–RQ5).

---

## 4. Threshold modes and gates

Deploy-time `ThresholdMode` on `PkgArgs` → resolve → instance storage. **Not** the fee oracle. No post-deploy setter.

| Mode | Meaning |
|------|---------|
| **Policy** (0, default) | Primary mint/burn gated by synthetic vs thresholds |
| **Open** (1) | When live, threshold gates **always pass**; **never** natural expansion |

### Resolve defaults (`DETFThresholdPolicy`)

```text
mintArg == 0  →  mintThreshold = 1.05e18
burnArg == 0  →  burnThreshold = 0.95e18
```

Both modes require after resolve: `mintThreshold > burnThreshold`. Zero args **never** imply Open.

### Policy gates (when live)

```text
mintAllowed  ⇔  p_syn > mintThreshold
burnAllowed  ⇔  p_syn < burnThreshold
deadband     ⇔  burnThreshold ≤ p_syn ≤ mintThreshold   # neither mint nor burn
```

Equality is deadband (strict inequalities for allow).

### Open gates (when live)

```text
mintAllowed  ⇔  true   (subject to live + family route rules)
burnAllowed  ⇔  true
```

Stored thresholds may still equal resolved defaults for getters; gates ignore them. Open does **not** change routes (e.g. MixedBuffer still burns buffer only), fees, or inert→live.

Measured: D2–D5 (FINDINGS RQ3–RQ4, RQ7).

---

## 5. Capital seigniorage vs natural expansion

| Path | Capital? | When | Who receives free DETF |
|------|----------|------|-------------------------|
| **Capital seigniorage** | Yes (vault shares / family input) | Live + mode gates | User mint + fee/inventory split to bond ledger as family defines |
| **Natural expansion** | No external capital | Policy ∧ live ∧ mint-allowed ∧ time | Bond **effective shares** only (reward ledger) |

**Unlocked free DETF holders get no expansion airdrop.**

Label separately in all prose and figures.

---

## 6. Natural expansion eligibility and formula

### Eligibility predicate

```text
expand  ⇔  live
         ∧  thresholdMode == Policy
         ∧  p_syn > mintThreshold
         ∧  dt > 0 ∧ S > 0 ∧ premium > 0
```

```text
Open  ⇒  expand = false always
inert ⇒  expand = false
¬mintAllowed under Policy ⇒ expand = false
```

### Premium-closure mint (`DETFNaturalExpansionLib`)

```text
p*      = 1e18                                          # abstract peg
premium = max(p_syn - p*, 0)
dt      = min(now - lastExpansionTimestamp, catchUpMaxSeconds)

m = min(
      S * premium * r * dt / (1e18 * p_syn),
      m_max
    )

# r     = expansionClosureRatePerSecond (resolved; arg 0 → default ~10% of premium / year)
# m_max = from catch-up bps (0 → uncapped)
# if m <= 1 wei (dust): m = 0
```

Mint sinks to **bond NFT vault** → same `rewardPerShares` ledger as seigniorage inventory. No keeper.

Deploy-time only: rate / catch-up max / catch-up cap. Open never expands.

Measured: D5 Open no expansion; D8 Policy rich + warp (FINDINGS RQ8–RQ9).

---

## 7. Protocol compound

### Intent

Protocol NFT pending free DETF rewards → **single-sided DETF join** into reserve → credit BPT to **protocol principal**. Weight skew toward DETF self-leg accepted in v1.

Users and fee-recipient: **claim free DETF** while locked (v1 no user auto-compound).

### Mechanism sketch

```text
on touch / public compoundProtocolRewards():
  1. update rewards (incl. expansion when eligible)
  2. if protocol pending free DETF > dust:
       best-effort single-sided DETF join
       credit BPT → protocol NFT principal
  3. join failure: leave pending; do not fail whole user action solely for join revert
```

When claim is wired: protocol BPT ↑ ⇒ claim redemption rate **can** rise (not an APY guarantee).

Measured: D9 protocol BPT principal ↑ after `compoundProtocolRewards` (FINDINGS RQ10).

---

## 8. Preview honesty (closed-form routes)

For family-supported closed-form vault-share ↔ DETF routes:

```text
preview(amountIn)  should equal  execution(amountIn)
```

Exact equality preferred. Multi-leg proportional Balancer exits may force documented ≤ few-wei relative dust.

Measured D3 capital mint: **preview == exec exact** (diff 0) (FINDINGS RQ6).

Non-closed-form exact-out solvers: **out of scope**; prefer `InvalidRoute` / family equivalent.

---

## 9. Nested SE residual (appendix metric)

From Uni V2 SE rateProviderCompare (not re-derived here):

```text
residual ≈ mid_index × rate_index − 1
```

| State | Expected under Uni-only demand |
|-------|--------------------------------|
| **R+** (rates on) | residual ≈ 0 (mids re-mark with SE rates) |
| **R−** (rates off) | residual grows with Uni tilt; fills only if edge clears fee stack |

Research Balancer const-prod fee in those runs: **5%** — residual ≠ profit.

Cite: [`../../scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md`](../../scenarios/uniswapV2Se/rateProviderCompare/AGENT_RESEARCH_REPORT.md).

---

## 10. Composition types (taxonomy only)

Four **live** true DETF families (no removed `composed/single`):

| Family | Use when |
|--------|----------|
| Single Standard Exchange | Exactly one SE vault + DETF weighted reserve |
| Multi-vault weighted | Multiple SE vaults with distinct valuations in weighted reserve |
| Composed stable (common) | Multiple SE vaults, like-kind rate targets |
| Mixed-buffer multi-vault stable | Shared bufferToken rateAsset; burn buffer only |

v1 empirics: **Single SE only**.

---

## 11. Non-definitions (do not formalize as guarantees)

- Registered securities ETF / offchain ownership  
- Peg, APY, rebase coupon, claim APY  
- Open ⇒ free / no fees / expansion  
- Expansion to all free DETF holders  
- User auto-compound into pool  
- Protocol compound ⇒ fixed claim growth  
- Zero threshold args ⇒ Open  

---

*End of formal definitions.*
