# Adversarial modeler — leftover pilot High CODE (not OWNED_ELSEWHERE)

| Field | Value |
|-------|--------|
| Date / SHA | 2026-08-13 · `1e0d7c48` |
| Sources | `A-commons-pull`, `A-se-amm-v2`, `S-sharp-edges`, `S-crops-trust` |
| Critical | **0** |

## SEC-COMMON-002 / SEC-SHARP-003 — `_secureSelfBurn` sweep

**Attacker:** EXT. **Pre:** vault holds extra `vaultShare`. **Steps:** `exchangeOut` / share-burn with `pretransferred=true`; helper burns needed shares then refunds **all leftover self-balance** to owner. **Delta:** attacker receives donated/inventory shares. **Blast:** all `_secureSelfBurn` callers (Stata Out, AMM v2). **WP:** `WP-SEC-E6-COMMON-001`.

## SEC-SHARP-002 / SEC-SE-AC-001 — `_refundExcess` max−used

**Attacker:** EXT. **Pre:** booked pair/rateAsset; fat `maxAmountIn`. **Steps:** transfer only `used`; `pretransferred=true`; refund `max−used` from book. **Blast:** Aero/Camelot/Uni V2 Out (+ Slipstream twin). **WP:** `WP-SEC-E6-COMMON-001` + `WP-SEC-E6-SE-001`.

## SEC-SE-CAM-001 — Camelot Out drop

**Attacker:** EXT (honest user is the victim). **Steps:** `exchangeOut` swap path; `_swap` sends `tokenOut` to vault; branch never transfers to recipient; `amountIn` overwritten with `amountOut` before refund. **Impact:** user loses `tokenOut`; refund math broken. **Blast:** Camelot Out only. **WP:** `WP-SEC-CAM-OUT-001`.

## SEC-SE-CAM-002 / SEC-SE-U2-001 — Route4 post-deposit convert

**Attacker:** CAP / EXT. **Steps:** Route4 deposit LP then `convertToShares` on **post-deposit** reserve → under-mint; existing holders extract seigniorage. **Blast:** Camelot + Uni V2. Aero snapshots pre-deposit (clean). **WP:** `WP-SEC-R4-SE-001`.

## SEC-SE-AC-002 / SEC-SHARP-004 — zap-in / exact-gap A0

**Attacker:** EXT on empty or stale-book vault. **Steps:** donate LP; first `exchangeIn` zap credits gap / `lastTotalAssets`; redeem absorbs donation. Aero `decimalOffset=0` worsens. **WP:** `WP-SEC-A0-SE-001` / `WP-SEC-I-SE-4626-001`.

## SEC-SHARP-006 — MultiVault PkgArgs hostile share

**Attacker:** CFG / HOS. **Steps:** `vaultShares[i]==0` aliases to `vaults[i]`; no registry lock; hostile ERC20 as share. **WP:** `WP-SEC-PKG-MV-001`.

## SEC-CROPS-001 — disable-on-exit

**Attacker:** ADM (manager owner). **Steps:** `setVaultAddressDisabled(detf, true)`; mature `closeBondMature` / `redeemClaim` / `exchangeOut` revert `_requireNotDisabled`. Inventory stuck, not stolen. **Blast:** disable-gated families (not MultiVault). **WP:** `WP-SEC-CROPS-001`.

None of the above are working mainnet scripts. Severity stays High where RUNTIME_UNPROVEN.
