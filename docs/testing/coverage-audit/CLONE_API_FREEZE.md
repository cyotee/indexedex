# CLONE API FREEZE — Secure pull / pretransfer delta (i-common)

**Slice:** `i-common` · **Law:** L-GAPS-9 / L-GAPS-10 · **WP:** WP-I-CLONE-001 checklist

## Shared error (mandatory)

All packages that implement secure token pull / pretransfer credit **must**:

1. Import `contracts/interfaces/ISecurePullErrors.sol`
2. Revert with `ISecurePullErrors.TransferDeltaInsufficient(claimed, observedDelta)` when `claimed > observedDelta`
3. **Not** invent a second algorithm library or a package-local string/`require` for this check

```solidity
error TransferDeltaInsufficient(uint256 claimed, uint256 observedDelta);
```

## Delta rules (implement the same semantics)

```
observedDelta = balanceAfter - balanceBefore   # over the pull window
if claimed > observedDelta:
    revert TransferDeltaInsufficient(claimed, observedDelta)
// else credit exactly claimed on pretransferred path
// !pretransferred: return observedDelta (FoT-safe)
```

| Rule | Requirement |
|------|-------------|
| Absolute `balanceOf >= claimed` without delta | **FORBIDDEN** |
| Exact `observedDelta == claimed` | **FORBIDDEN** (donations must not lock honest deposits) |
| Pretransferred, no in-call transfer, inventory present | `observedDelta == 0` → `TransferDeltaInsufficient(claimed, 0)` (I1) |
| Credit on pretransfer | Exactly `claimed` when `claimed <= observedDelta` |
| `!pretransferred` | Return actual inbound delta (may be &lt; claimed) |

## Reference implementation

- Canonical: `BasicVaultCommon._secureTokenTransfer`
- Aerodrome SE: override must remain **delta-based** (no absolute available-minus-reserved free credit). Excess/reserved tracking may remain for compound product logic only.

## Clone checklist (WP-I-CLONE-001)

When adding or reviewing a package clone of secure pull:

- [ ] Import shared `ISecurePullErrors` (no parallel error type)
- [ ] Measure `balBefore` before any optional pull
- [ ] Pull only when `!pretransferred`
- [ ] Compute `observedDelta`; pretransfer shortfall → shared error with exact args
- [ ] No absolute inventory / reserved-dust free credit
- [ ] Spec tests cover I1 (no in-call transfer + inventory), short delta, residual cannot re-credit
