# Adversarial modeler — SEC-SE-BAL-001

| Field | Value |
|-------|--------|
| Date / SHA | 2026-08-13 · `1e0d7c48` |
| Source | `areas/A-se-balancer-v3.md` |
| Class | High CODE · RUNTIME_UNPROVEN |
| Exploitability | **EXT** |

## Attack — SinglePool receive claimed

**Preconditions:** `BalancerV3SinglePoolStandardExchange` holds tokenIn.

**Steps:**
1. Call In with `pretransferred=true`, `amountIn` ≤ `balanceOf(this)`.
2. `_receiveExactIn` skips `transferFrom`, **returns amountIn**.
3. Join/swap spends vault inventory as if the attacker paid.
4. Optional: `_receiveMaxIn` + `_refundUnused(deposited, used)` refunds **claimed unused** (E6).
5. Optional: `_approvePermit2ToRouter` leaves max allowance (M3 if router/Permit2 confused).

**Expected deltas:** attacker tokenIn unchanged; vault tokenIn down by join; attacker receives BPT/SE out.

**Blast:** this helper file only (buffer pool families do not share this receive).

**Not exploitable if:** helper unused in production DFPkg. Still High until inventory proves no package deploys it — file is under `pools/` as a money adapter.
