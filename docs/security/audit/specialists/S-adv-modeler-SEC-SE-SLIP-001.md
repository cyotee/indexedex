# Adversarial modeler — SEC-SE-SLIP-001 / SEC-SE-SLIP-002

| Field | Value |
|-------|--------|
| Date / SHA | 2026-08-13 · `1e0d7c48` |
| Source | `areas/A-slipstream-buffer.md` |
| Class | High CODE · RUNTIME_UNPROVEN |
| Exploitability | **EXT** |

## SEC-SE-SLIP-001 — entire-balance In refund

**Preconditions:** Slipstream SE holds token0 and/or token1 (idle, donation, or unbooked vs CL position).

**Steps:**
1. Seed or wait for token0/token1 on vault.
2. `exchangeIn` a **minimal** funded mint (or dust) so the function reaches `_refundRemainder`.
3. `_refundRemainder(token)` does `safeTransfer(msg.sender, balanceOf(this))` for **each** token.
4. Attacker receives **all** token0+token1, including booked inventory not used by this mint.

**Expected deltas:** attacker token balances += prior vault balances; vault tokens → 0; shares minted small.

**Blast:** Slipstream In Target only (Uni V3 has the same anti-pattern — separate area).

## SEC-SE-SLIP-002 — Out max−used

**Preconditions:** booked pair tokens; attacker sets `pretransferred=true`, `maxAmountIn >> used`, transfers only `used`.

**Steps:**
1. Transfer `used` of tokenIn to vault (or rely on inventory).
2. `exchangeOut(..., maxAmountIn, ..., pretransferred=true)`.
3. Helper credits `used`; `_refundExcess` sends `max−used` from **book**.

Same class as `SEC-SE-AC-001` / `SEC-SHARP-002` on AMM v2 files.

**Not a mainnet script.** Proof-first hermetic/fork in `WP-SEC-E6-SLIP-001`.
