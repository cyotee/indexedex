# TCA-DETF-MV-001 / TCA-DETF-MV-002 — static proof (RUNTIME_UNPROVEN)

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Area | T-detf-multi-vault |
| Severity claimed | Blocker CODE (overwhelming static; no forge PoC executed this run) |

## Call chain (mint free credit)

1. `MultiVaultWeightedDetfExchangeInTarget.exchangeIn` (mint branch) calls  
   `_pullToken(tokenIn_, amountIn_, pretransferred_)` then  
   `_mintDetfFromVaultShares(legIndex_, vaultShares_, recipient_)`.
2. `MultiVaultWeightedDetfCommon._pullToken`:

```solidity
function _pullToken(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actual_) {
    if (pretransferred_) return amount_;
    // else: balBefore, transferFrom, return delta
}
```

3. **No** `balanceOf` check, **no** delta, **no** reserve snapshot when `pretransferred_=true`.
   Claimed `amount_` is credited as vaultShares received.

## Call chain (burn free extract)

1. `_burnDetfExactIn` skips `safeTransferFrom` when `pretransferred_==true`.
2. Burns `detfIn_` from `address(this)` and pays vault shares to recipient.
3. Prior donated free `detfToken` on diamond (A2 setup) can fund a burn without transfer.

## Exploit sketch (not executed this run)

```text
// live DETF, minting allowed
attacker transfers vaultShare amount X to diamond (donation)
attacker calls exchangeIn(vaultShare, X, detfToken, 0, attacker, true, deadline)
// expected if fixed: revert or zero credit
// buggy: attacker receives detfToken while retaining (or never spending) own vaultShare balance
```

## Why A1 does not disprove this

`test_A1_donateVaultShares_cannotMintFreeDetf` only asserts no auto-mint on bare transfer and victim mint with `pretransferred=false`. It never calls `pretransferred=true`.

## Runtime status

`RUNTIME_UNPROVEN` — Stage 2 WP-I-DETF-MV-001 acceptance must include I1 forge proof first.

## Commands (for Stage 2 proof)

```bash
# After I1 test lands (or throwaway local):
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/**' \
  --match-test 'test_I1_' -vv
```
