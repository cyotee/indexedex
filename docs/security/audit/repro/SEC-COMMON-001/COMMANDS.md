# Runtime / SHA re-check — PAT-I-ABS at 1e0d7c48

## Current SHA

```bash
git rev-parse --short HEAD
# 1e0d7c48
git rev-parse HEAD
# 1e0d7c48eff8a883837996ae700426ac5397924b
```

## Historical proof (stale for this tree)

`docs/testing/coverage-audit/repro/TCA-COMMON-001/` (2026-08-09) recorded:

```text
[PASS] test_secureTokenTransfer_pretransferred_returnsAmount()
```

That PASS meant **free credit of booked inventory** (theater). The helper body then was `require(balanceOf >= amount); return amount`.

## Re-check at 1e0d7c48 (static + targeted forge)

Static: `contracts/vaults/basic/BasicVaultCommon.sol` `_secureTokenTransfer` credits `claimed` only when `claimed <= U` where `U = balanceOf - reserveOfToken`; else `TransferDeltaInsufficient(claimed, U)`.

```bash
# Hermetic I1/I2/I3 + migrated theater-named test (now expects revert)
forge test --match-path 'test/foundry/spec/vaults/basic/**' \
  --match-test 'test_I1_|test_I2_|test_I3_|test_secureTokenTransfer_pretransferred' -vv
```

Profile: default hermetic. `via_ir`: not used. `ALCHEMY_KEY`: not required.
