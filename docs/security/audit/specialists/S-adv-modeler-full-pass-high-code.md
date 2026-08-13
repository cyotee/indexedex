# Adversarial modeler — remaining full-pass High CODE

| Field | Value |
|-------|--------|
| Date / SHA | 2026-08-13 · `1e0d7c48` |
| Scope | High CODE not already in `S-adv-modeler-{pilot,AAVE,SLIP,BAL}` |
| Critical | **0** |

## SEC-DETF-CS-013 — missing `nonReentrant` on CS exchangeIn/bond

**Attacker:** HOS share or C-class reenter. **Steps:** configure hostile `vaultShare`; `exchangeIn`/`bond` without lock; reenter mint/bond mid-callback. **Impact:** double-credit if accounting not CEI. **Blast:** ComposedStable money targets. **WP:** `WP-SEC-DETF-CS-LOCK-001`.

## SEC-DETF-CS-014 — leftover detfToken owner/minter

**Attacker:** ADM holding leftover minter/owner on rebasing DETF token satellite. **Steps:** mint extra `detfToken` after “unowned” deploy. **Impact:** dilution. **Blast:** CS token DFPkg. **WP:** `WP-SEC-DETF-CS-TOKEN-001`.

## SEC-DETF-DL-003 / 004 — same-tx delta vs two-tx docs; A0

**Attacker:** EXT. **003:** docs/Permit2 imply two-tx pretransfer; helper only credits same-tx delta → honest integrators revert (grief) **or** if product intended two-tx, I1 hole. **004:** empty supply + residual inventory first minter drain. **WP:** `WP-SEC-DETF-DL-DELTA-001`, `WP-SEC-DETF-DL-A0-001`. Fork-first (L-SEC-5).

## SEC-DETF-UV4-002 — burn skips `_pullToken`

**Attacker:** EXT with `pretransferred=true` on burn. **Steps:** burn route does not call reserve-delta pull; credits claimed / burns without inbound. **Impact:** extract `detfToken`/inventory. **Blast:** weighted/orbital/quad Out burn helpers. **WP:** `WP-SEC-DETF-UV4-BURN-I1-001`.

## SEC-DETF-UV4-006/007 — unused Uni V4 local NFT/claim

**Attacker:** CFG/ADM on leftover packages (families wire **shared** common NFT/claim). Absolute pull + leftover owner on unused pkgs. **WP:** `WP-SEC-DETF-UV4-NFT-001`.

## SEC-DETF-UV4-008 — orbital missing `depositClaim`

**Attacker:** n/a product-law hole (PRD-locked API missing). User cannot deposit claim as specified. **WP:** `WP-SEC-DETF-UV4-ORB-CLAIM-001`.

## SEC-SE-U3-002/003/004 — Uni V3 E6 / share I1 / A0

**002:** `_refundRemainder` entire balance (same as Slipstream). **003:** zap-out burns `address(this)` shares. **004:** empty vault first mint. Pull I-ABS stays `WP-I-CLONE-001`. **WPs:** `WP-SEC-E6-U3-001`, `WP-SEC-I-U3-SHARE-001`, `WP-SEC-A0-U3-001`.

## SEC-SE-U4-002/003/004 — Uni V4 SE zap-out E6 / importPosition / A0

**002:** leftover `vaultShare` refund after zap-out burn. **003:** `importPosition` accepts untrusted PM/owner. **004:** first mint no virtual offset. **WPs:** `WP-SEC-E6-U4-001`, `WP-SEC-IMP-U4-001`, `WP-SEC-A0-U4-001`.

No mainnet scripts. All RUNTIME_UNPROVEN → stay High.
