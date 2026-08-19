# TCA-DETF-DL-001 / TCA-DETF-DL-002 — static proof (RUNTIME_UNPROVEN)

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Area | `T-detf-dual-liquidity` |
| Severity claimed | **Blocker CODE** (overwhelming static; no forge PoC executed this run) |
| Product | `DualLiquidity (removed)CrossVersionUniswapVault` |
| L-TCA-5 | Fork-first gold TestBase — missing fork I/K proof is **equal** severity to hermetic gaps |

## Roles (DETF law)

| Role | DualLiquidity mapping |
|------|------------------------|
| `rateAsset` / common | `commonToken` (often WETH on Base fork wiring) |
| `pairToken` | `tokenA` / `tokenB` |
| `underlyingVault` | `vaultA` / `vaultB` / `pairVault` (SE legs) |
| `vaultShare` | `vaultAShare` / `vaultBShare` / `pairVaultShare` |
| `detfToken` | diamond share `address(this)` / `shareToken` |
| `reservePool` / `reserveBpt` | Balancer weighted reserve BPT |

## Call chain — free mint (exact-in deposit / swap)

1. `exchangeIn(..., pretransferred_=true)` → `_deposit` / `_swap` after `_receive`.
2. `DualLiquidity (removed)CrossVersionUniswapVaultExchangeInTarget._receive`:

```solidity
function _receive(IERC20 tokenIn_, uint256 amountIn_, bool pretransferred_) private {
    if (!pretransferred_) {
        tokenIn_.transferFrom(msg.sender, address(this), amountIn_);
    }
    // pretransferred=true: no-op — no balance check, no delta
}
```

3. Route consumes `amountIn_` from **current diamond inventory** (join / leg swap), then mints `detfToken` shares or pays swap out.
4. `_snapshotIntermediates` + `_sweepResidual` use **pre-call** resting balances — so pre-existing donation is treated as resting capital, **not** as attacker residual. Donation is spent; attacker keeps credited shares/out.

## Call chain — free extract / steal donation (exact-out)

1. `exchangeOut(..., pretransferred_=true)` → `_receiveOut`.
2. `DualLiquidity (removed)CrossVersionUniswapVaultExchangeOutTarget._receiveOut`:

```solidity
function _receiveOut(IERC20 tokenIn_, uint256 amountIn_, bool pretransferred_) private {
    if (!pretransferred_) {
        tokenIn_.transferFrom(msg.sender, amountIn_);
    } else {
        uint256 held_ = tokenIn_.balanceOf(address(this));
        if (held_ > amountIn_) {
            tokenIn_.transfer(msg.sender, held_ - amountIn_); // refunds ALL excess held
        }
    }
}
```

3. **All** `held_` is attributed to the caller. Prior donation of `pairToken` / `rateAsset` / leg `vaultShare` is spent as attacker input **and** excess is refunded to attacker.

## Why ShareInflation / A3 is not I or K

| Suite | What it proves | What it does **not** prove |
|-------|----------------|----------------------------|
| `*_ShareInflation.t.sol` | Idle **reserveBpt** donation does not zero victim mint / free mint shares on **pull-path** deposits | `pretransferred=true` credit; donation of non-BPT intermediates; exact-out refund theft |
| Happy `test_depositPretransferred_mintsShares` | Real transfer then flag | False claim / existing inventory (PAT-THEATER-PRE) |
| Permit2 prefund suites | Happy prefund + `pretransferred=true` | I1–I3 |

## Exploit sketch (not executed this run)

```text
// live dual-liquidity vault, reserve bootstrapped
// 1) Free mint
donate pairToken amount X to linkedVault
attacker (0 balance) exchangeIn(pairToken, X, shareToken, 0, attacker, true, deadline)
// buggy: attacker receives detfToken shares funded by donation

// 2) Exact-out refund theft
donate rateAsset amount Y to linkedVault
attacker exchangeOut(rateAsset, max, pairToken, amountOut, attacker, true, deadline)
// buggy: spends donation for swap + refunds Y - amountIn to attacker
```

## BPT exception (not a fix for I)

`_depositBpt` / exact-out BPT path **reverts** `pretransferred=true` (reserve-BPT snapshot correctness). Non-BPT money paths still PAT-I-ABS.

## Runtime status

`RUNTIME_UNPROVEN` — Stage 2 acceptance for WP-I-DETF-DL-001 must forge-prove `test_I1_*` on fork TestBase before marking CODE closed.

## Commands (Stage 2)

```bash
FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**' \
  --match-test 'test_I1_' \
  --fork-url base_mainnet_alchemy -vv
```
