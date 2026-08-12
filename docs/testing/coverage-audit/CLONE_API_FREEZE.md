# CLONE API FREEZE — Secure pull / pretransfer (BasicVault family + peers)

**Slice:** `fix_reserve_delta` (supersedes pure in-call delta for BasicVault family) · **Law:** L-GAPS-9/10 refined by reserve-delta PRD · **WP:** WP-RSRV-0b / WP-I-CLONE-001 checklist

## Shared error (mandatory)

All packages that implement secure token pull / pretransfer credit **must**:

1. Import `contracts/interfaces/ISecurePullErrors.sol`
2. Revert with `ISecurePullErrors.TransferDeltaInsufficient(claimed, observedDelta)` when credit is short
3. **Not** invent a second algorithm library, package-local string/`require`, or `ReserveAccountingUnderflow` product error for this check

```solidity
error TransferDeltaInsufficient(uint256 claimed, uint256 observedDelta);
```

---

## BasicVault-family (MultiAssetBasicVaultRepo) — reserve-delta (canonical)

Packages that book inventory via `MultiAssetBasicVaultRepo` / `BasicVaultCommon` **must** implement:

```text
BasicVault-family (MultiAssetBasicVaultRepo):
  R = reserveOfToken[token]
  B = balanceOf(vault)
  U = B - R
  pretransferred: credit claimed iff claimed <= U else TransferDeltaInsufficient(claimed, U)
  !pretransferred: credit pull delta only (FoT-safe; do not add prior U)
  end of every money route: for each vaultToken T: R[T] = balanceOf(T)   // full expected-hold set
  unclaimed surplus absorbed; compound dust booked via sync
  I1 tests: R synced to B before free-credit attempt
```

| Rule | Requirement |
|------|-------------|
| Absolute `balanceOf >= claimed` without subtracting `R` | **FORBIDDEN** |
| Credit on pretransfer | Exactly `claimed` when `claimed <= U` (`U = B − R`) |
| `!pretransferred` | Return actual inbound **pull** delta only (may be &lt; claimed); never `U + pull` |
| Unclaimed push surplus (`U − claimed`) | **Absorbed** into `R` at end-of-op full-set sync — **not** refunded |
| Exact-out refund | Only `_refundExcess` when `maxAmount > usedAmount` (pretransferred); **before** full-set sync |
| End-of-money sync | **Full** expected-hold set (`_vaultTokens`) every successful deposit / withdraw / compound / harvest / rebalance / zap / fee-compound — not route-touched-only |
| Expected-hold | Underlyings + package sleeve + compound/rebalance residuals. **Never** vault share token |
| I1 booked inventory | After `R == B`, `pretransferred=true` with no new unbooked inflow → `TransferDeltaInsufficient(claimed, 0)` |
| Bootstrap `R = 0` | Live balance is fully unbooked until claim or absorb-sync |
| `B < R` | No production underflow product error / silent clamp; enforce INV-R1 in **tests** |
| Exact `U == claimed` required | **FORBIDDEN** (donations must not lock honest deposits) |

### Reference implementation

- Canonical: `BasicVaultCommon._secureTokenTransfer` + `_syncAllExpectedHoldReserves`
- Storage: `MultiAssetBasicVaultRepo` (`indexedex.vaults.basic` slot)
- Product law: `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md`
- Implement plan: `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md`

### Aerodrome

- Prefer **no** `_secureTokenTransfer` override (super implements reserve-delta).
- Keep `_excessToken*` for **compound product accounting** only — do **not** credit pretransfer from `balance − excessToken`.
- Full-set end sync books residual dust → I1 protects them.

---

## Non-BasicVault clones (Wave 3 / package-local)

Packages that do **not** use MultiAssetBasicVaultRepo may either:

1. Adopt the same durable baseline (`U = B − R` with a package-local booked snapshot + full end-sync), **or**
2. Remain package-local with an **explicit** checklist exception documented in Wave 3.

Until Wave 3, Uni V3/V4 SE, Slipstream, hooks peers may still use in-call delta or package-local pull; do not block BasicVault Wave 0–2 on those packages.

---

## Clone checklist (WP-I-CLONE-001 / BasicVault family)

When adding or reviewing a package that inherits `BasicVaultCommon` or books via MultiAssetBasicVaultRepo:

- [ ] Import shared `ISecurePullErrors` (no parallel error type)
- [ ] Pretransfer: `U = balanceOf − reserveOfToken`; credit claimed iff `claimed <= U`
- [ ] Pull only when `!pretransferred`; credit **pull delta only**
- [ ] No absolute inventory free credit; no reserved-dust free credit
- [ ] End **every** money route with `_syncAllExpectedHoldReserves()` **after** `_refundExcess`
- [ ] Full expected-hold set registered in `_vaultTokens` (underlyings + sleeve + compound residuals)
- [ ] Absorb unclaimed push surplus (no refund of `U − claimed`)
- [ ] Spec tests cover: I1 **booked** inventory, short `claimed > U`, absorb residual cannot re-credit, pull + INV-R1 after moneyIn


## DETF nested push (2026-08-10)

Nested callers of reserve-delta hosts **must** use push + `pretransferred=true`. The Wave 0–2 `forceApprove` + `false` nested SE workaround is **superseded** by `DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md`.
