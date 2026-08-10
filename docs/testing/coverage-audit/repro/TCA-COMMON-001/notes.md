# TCA-COMMON-001 — PAT-I-ABS runtime notes

## Finding

`BasicVaultCommon._secureTokenTransfer` when `pretransferred=true`:

```solidity
require(tokenIn.balanceOf(address(this)) >= amountTokenToDeposit, "...");
return amountTokenToDeposit; // absolute claim, not inbound delta
```

## Runtime outcome: **confirmed**

| Check | Result |
|-------|--------|
| Static CODE | Confirmed in `contracts/vaults/basic/BasicVaultCommon.sol` L33–38 |
| Hermetic test | `test_secureTokenTransfer_pretransferred_returnsAmount` **PASS** |
| Semantics | Vault is minted `DEPOSIT + DUST`; caller Alice never transfers; call with `pretransferred=true` returns `DEPOSIT` credit |
| Free-mint implication | Any prior inventory / donation / dust satisfying `balanceOf >= amount` can be claimed without a caller balance delta |
| Severity class | **Blocker CODE** (shared commons blast radius) |

## Theater co-finding

The same test **asserts** free credit as correct behavior (`"pretransferred should return amount_ directly"`). That is **PAT-THEATER-PRE**: the suite greenwashes absolute balance credit and does **not** prove I1 (no free mint when vault holds inventory without inbound transfer from the claimer).

Contrast:

- `pretransferred=false` path correctly uses `balBefore` delta (and `test_secureTokenTransfer_dustDoesNotInflateCredit` protects that path).
- Staking SE ports (Lido/EtherFi/RocketPool) and ERC4626 routes have `test_A0` / `test_FreeMint_*` that expect **revert** on no-delta pretransfer — those are the correct I1 pattern.

## Aerodrome override

`AerodromeStandardExchangeCommon` overrides pretransfer to subtract reserved excess tokens, but still **returns `amountTokenToDeposit`** without measuring an inbound delta — PAT-I-ABS residual.

## Status label

`confirmed` — Blocker CODE eligible (runtime proof satisfied L-TCA-3).
