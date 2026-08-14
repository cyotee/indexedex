# DualLiquidity — Adversarial Catalog Map

## Status

**P0 I/K/A0/CROPS rewritten for same-tx law B** (`SEC-DETF-DL-003/004/005`, `WP-SEC-DETF-DL-*`).

Not “P0 complete” as a ship-gate slogan. A0 is closed in CODE + `test_A0_*`. I1–I3/K1 are honest same-tx (no MultiAsset `R`). ShareInflation is **A3 only**, not I/K.

## ID map

| ID | Location | Notes |
|----|----------|-------|
| **A0** | `adversarial/Adversarial_DualLiquidity_A0.t.sol`, `*MathLib.t.sol` | Donate `reserveBpt` before first mint; first mover cannot drain |
| A3-class | `*_ShareInflation.t.sol` | Post-bootstrap BPT donation. **Not I/K** |
| C reentrancy | `*_Reentrancy.t.sol`, `*_ReentrancyRedeem.t.sol` | |
| E residual | `*_Residual.t.sol` | Sweep to `feeTo`, not caller |
| F immutability | `*_Immutability.t.sol` | |
| B rate | `*_RateExtremes.t.sol` | |
| Guards | `*_Guards.t.sol` | |
| H3 / F1 / **I1–I3 / K1** / J1–J3 | `adversarial/Adversarial_DualLiquidity_Catalog.t.sol` | I/K: no hold-set; I1 no in-call transfer |
| **CROPS** | `*_Disable.t.sol` | After `setVaultAddressDisabled(true)`, share redeem / `exchangeOut` exit still work |
| Two-tx / Permit2 invert | `*_Deposits`, `*_Permit2*`, `*_NestedPush`, `*_ExactOutMatrix` | `pushThenTrue` / Permit2-`true` / surplus-refund-to-caller are **I1 reverts** |

## Law (owner-silent default B)

- `_receive` / `_receiveOut` are **same-tx inbound-delta**. Two-tx or Permit2 prefund then `true` reverts `TransferDeltaInsufficient(claimed, 0)`.
- Do **not** restore no-op `_receive` or `held − amountIn` refund.
- ShareInflation is not I.

## Run

```bash
FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/**/crossVersion/v2/**' \
  --match-test 'test_I|test_A0_|test_K1_|test_CROPS_' --fork-url base_mainnet_alchemy -vv
```
