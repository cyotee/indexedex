# Adversarial modeler — SEC-SE-AAVE-001 / SEC-SE-AAVE-002

| Field | Value |
|-------|--------|
| Date / SHA | 2026-08-13 · `1e0d7c48` |
| Source | `areas/A-se-aave.md` |
| Class | High CODE · RUNTIME_UNPROVEN |
| Exploitability | **EXT** single tx if inventory exists |

## SEC-SE-AAVE-001 — Loop In skip-transfer

**Attacker:** unprivileged EOA.

**Preconditions:** `AaveCrossVersionLoop` proxy holds ≥ `amountIn` of tokenA (donation, leftover deposit, or seed).

**Steps:**
1. Read `tokenA` and `previewExchangeIn` (optional).
2. Call `exchangeIn(tokenA, amountIn, IERC20(loop), 0, attacker, true, deadline)` — **no** `transferFrom`.
3. Branch `if (!pretransferred)` is skipped.
4. `depositValue = valueUsd(..., amountIn)` uses **claimed**.
5. `depositLoopAFirst` spends **vault** tokenA.
6. Attacker receives minted loop shares; redeem later via Out for tokenA.

**Expected deltas:** attacker tokenA unchanged (or increased on later Out); vault tokenA down; attacker shares up.

**Blast radius:** this DFPkg only. Not Stata (delta pull).

**Exploitability:** high if any tokenA sits on the vault. Cap Critical until hermetic proof (`Proof-first` on WP).

## SEC-SE-AAVE-002 — Loop Out burn `address(this)`

**Preconditions:** vault holds its own shares.

**Steps:**
1. Donate or leave loop shares on the vault.
2. `exchangeOut(loop, maxIn, tokenA, amountOut, attacker, true, deadline)` without transferring shares.
3. `_burn(address(this), amountIn)` consumes inventory shares.
4. `withdrawA` + `transfer` pays attacker.

**Blast:** same package. Combine with 001 in one worktree.

**Not exploitable if:** vault never holds self-shares and In is fixed first (still fix both).
