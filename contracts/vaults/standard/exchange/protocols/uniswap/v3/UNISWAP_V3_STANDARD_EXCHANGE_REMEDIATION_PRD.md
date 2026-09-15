# Uniswap V3 Standard Exchange — Remediation Companion PRD

**Implementation:** See [new-version code and integration notes](../README.md) and the linked validation record. This PRD retains the broader release matrix.

**Status:** New implementation and focused regression suite complete; see validation record
**Date:** 2026-09-15
**New implementation:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/`
**Preserved implementation:** `contracts/protocols/dexes/uniswap/v3/`

## 1. Required outcome

Deliver a new V3 SE vault that manages liquidity under the same constant-product/proportional-ownership rules as the corrected V4 vault and fixes the stale-reserve pretransfer flaw. Preserve the original V3 implementation in place.

The [shared V3/V4 remediation PRD][shared] governs the security correction, version separation and release tests. The [constant-product PRD][economics] supplies the common economic specification and acceptance criteria; its V4-specific execution mechanisms must be adapted to V3 rather than copied literally. These linked requirements are normative for this new V3 version.

## 2. V3 implementation requirements

- Use the actual bound V3 pool, its position accounting, fee growth, swaps, mint callbacks, and pool lock state. Do not introduce V4 PoolManager assumptions into the V3 adapter.
- Preserve two-token activation, full-range positions, appropriate imported-position handling, complete-book share accounting, and funded local sleeve operations while the bound pool cannot be modified.
- Keep ERC20 settlement appropriate to V3. Native V4 Currency semantics are not a V3 requirement; any supported native wrapper route must independently account for its actual transfers.
- Replace token-delivery validation based on a stale total less a live deployed value. Separate local custody/operation credit from position valuation as specified by the shared PRD.
- Review V3 fee accounting independently: `_syncVaultReserves`, `_totalVaultReservesForShareMath`, fee collection and `_deployedAmounts` do not have exactly the same structure as V4.
- Review `_secureShareDelivery`, including its V3-specific self-call handling, and every token-input/refund call site. Do not presume that matching token helper logic makes all surrounding routes identical.
- Give the new facets, delegates, package and factory artifacts distinct, unambiguous identities. Deploy test instances through the IndexedEx manager registry using Crane factories.

## 3. V3 release evidence

Run all shared PT-01 through PT-11 tests on real V3 protocol and vault components. In particular:

1. An honest depositor creates a nonzero V3 position and positive local inventory.
2. A separate market trader changes the V3 pool price through an ordinary swap outside the vault.
3. A caller supplying zero tokens attempts the pretransfer route against the preserved and corrected versions.
4. The preserved-version test records the vulnerable result; the corrected version rejects false delivery and issues no shares or assets.
5. Real pretransfers and pulls still work after the same price move, including required callback/lock contexts.

Run the shared constant-product reference comparisons on V3 as well. Parameterize economic scenarios across both families while recording real fee/tick/rounding differences. A passing V4 suite is not V3 evidence.

Existing V3 TestBases and local-liquidity-buffer tests are starting points, not proof against a stale-reserve attack. A test with no position, or no intervening external swap, cannot substitute for the regression above.

## 4. Preservation and non-goals

Do not modify old V3 source, repoint existing deployments, change live settings, or assume existing immutable consumers can be migrated. Capture old/new compatibility and migration requirements, but do not execute deployment or fund movements as part of this PRD.

[shared]: ../UNISWAP_V3_V4_STANDARD_EXCHANGE_REMEDIATION_PRD.md
[economics]: ../v4/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md
